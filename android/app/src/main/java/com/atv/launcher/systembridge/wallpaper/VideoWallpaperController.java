package com.atv.launcher.systembridge.wallpaper;

import android.app.ActivityManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.database.ContentObserver;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import android.os.SystemClock;
import android.provider.MediaStore;
import android.text.TextUtils;
import android.util.Log;
import android.view.Surface;

import androidx.media3.common.C;
import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.common.VideoSize;
import androidx.media3.exoplayer.DefaultRenderersFactory;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector;

import com.atv.launcher.systembridge.shared.state.BridgeStateStore;

import java.io.File;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import io.flutter.view.TextureRegistry;

public final class VideoWallpaperController {
    private static final String TAG = "FLauncherPerf";
    private static final boolean FAST_STARTUP_ENABLED = true;
    private static final long APP_SWITCH_RELEASE_DELAY_MS = 60000L;
    private static final long WAKE_PLAYLIST_RETRY_DELAY_MS = 750L;
    private static final int MAX_WAKE_PLAYLIST_RETRIES = 4;
    private static final int MAX_CONSECUTIVE_PLAYER_ERRORS = 3;
    private static final long WAKE_COOLDOWN_MS = 3500L;
    private static final long MIN_PLAY_BEFORE_ADVANCE_MS = 2000L;
    private static final long ADVANCE_THROTTLE_MS = 2500L;
    private static final long MIN_LEGITIMATE_PLAYBACK_DURATION_MS = 1200L;
    private static final int MAX_GLITCH_RETRIES = 3;
    private static final long RESUME_DEBOUNCE_MS = 350L;

    private final Context appContext;
    private final TextureRegistry textureRegistry;
    private Runnable statusChangedCallback;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    public void updateStatusCallback(Runnable callback) {
        this.statusChangedCallback = callback;
    }

    private TextureRegistry.SurfaceTextureEntry surfaceTextureEntry;
    private Surface surface;
    private ExoPlayer player;
    private DefaultTrackSelector trackSelector;
    private boolean foregroundActive = true;
    private boolean videoReady;
    private boolean hasRenderedFirstFrameEver = false;
    private String lastError = "";
    private int videoWidth = 1920;
    private int videoHeight = 1080;
    private int currentIndex = 0;
    private int savedMediaIndex = 0;
    private long savedPositionMs = 0L;
    private List<String> resolvedPlaylistUris = new ArrayList<>();
    private final List<String> cachedResolvedPlaylistUris = new ArrayList<>();
    private String cachedResolvedTopologySignature = "";
    private final List<String> cachedShuffledPlaylistUris = new ArrayList<>();
    private String cachedShuffledConfigSignature = "";
    private final Set<String> quarantinedUris = Collections.synchronizedSet(new HashSet<>());
    private boolean playbackSuppressed;
    private String playbackSuppressedReason = "";
    private boolean wasPlayingBeforeSuppression;
    private boolean videoAllowedByPerformanceMode = true;
    private boolean disableAudioRendererWhenMuted = true;
    private boolean audioRendererEnabled = true;
    private boolean startupWarmupReady = !FAST_STARTUP_ENABLED;
    private long videoWarmupStartedAtNanos = 0L;
    private String activePlaybackConfigSignature = "";
    private int pendingWakePlaylistRetryCount = 0;
    private int consecutivePlayerErrorCount = 0;
    private String pendingWakeReason = "";
    private long wakeRearmStartedAtNanos = 0L;
    private long lifecycleEpoch = 0L;
    private long lastWakeElapsedRealtimeMs = 0L;
    private long lastResumeElapsedRealtimeMs = 0L;
    private long lastAdvanceElapsedRealtimeMs = 0L;
    private long targetAdvanceUptimeMs = 0L;
    private boolean isAdvanceScheduled = false;
    private long currentItemStartedAtMs = 0L;
    private int consecutiveGlitchRetryCount = 0;

    private BroadcastReceiver storageReceiver;
    private ContentObserver mediaStoreObserver;
    private boolean storageWatchdogRegistered = false;
    private String pendingStorageReloadReason = "";

    private final Runnable storageReloadRunnable = new Runnable() {
        @Override
        public void run() {
            if (!TextUtils.equals("video", BridgeStateStore.getWallpaperMode(appContext))) {
                return;
            }
            Log.i(TAG, "StorageMountWatchdog: reloading playlist reason=" + pendingStorageReloadReason);
            List<String> freshUris = resolvePlaylistUris(false);
            if (!freshUris.isEmpty()) {
                if (player == null) {
                    if (foregroundActive && shouldAutoResumeFromWake()) {
                        ensureSurface();
                        maybeStartPlayback(true, false, true);
                    }
                } else if (!isSamePlaylist(resolvedPlaylistUris, freshUris)) {
                    onVideoPlaylistTopologyChanged();
                }
            }
        }
    };

    private final Runnable advanceRunnable = new Runnable() {
        @Override
        public void run() {
            if (player == null || !foregroundActive || playbackSuppressed) {
                return;
            }
            if (!BridgeStateStore.WALLPAPER_ADVANCE_FIXED_INTERVAL.equals(
                    BridgeStateStore.getWallpaperVideoAdvanceMode(appContext))
            ) {
                return;
            }
            if (player.getMediaItemCount() <= 1) {
                return;
            }
            advancePlaylist();
            scheduleIntervalAdvance(true);
        }
    };

    private final Runnable backgroundReleaseRunnable = this::releasePlayer;

    private final Runnable wakePlaylistRetryRunnable = new Runnable() {
        @Override
        public void run() {
            if (pendingWakePlaylistRetryCount <= 0) {
                return;
            }
            if (!shouldAutoResumeFromWake()) {
                cancelWakePlaylistRetry();
                return;
            }
            logWakeInfo("wallpaper_wake_rearm_retry reason=" + pendingWakeReason
                    + " attempt=" + pendingWakePlaylistRetryCount);
            maybeStartPlayback(true, true);
        }
    };

    public VideoWallpaperController(
            Context context,
            TextureRegistry textureRegistry,
            Runnable statusChangedCallback
    ) {
        this.appContext = context.getApplicationContext();
        this.textureRegistry = textureRegistry;
        this.statusChangedCallback = statusChangedCallback;
        registerStorageWatchdog();
    }

    public long ensureTextureId() {
        startupWarmupReady = true;
        if (!videoAllowedByPerformanceMode) {
            return -1L;
        }
        ensureSurface();
        if (player == null) {
            maybeStartPlayback(true);
        }
        return surfaceTextureEntry != null ? surfaceTextureEntry.id() : -1L;
    }

    public Map<String, Object> getStatus() {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("mode", BridgeStateStore.getWallpaperMode(appContext));
        map.put("assetUri", BridgeStateStore.getWallpaperAssetUri(appContext));
        map.put("previewPath", BridgeStateStore.getWallpaperPreviewPath(appContext));
        map.put("sourceType", BridgeStateStore.getWallpaperVideoSourceType(appContext));
        map.put("assetUris", new ArrayList<>(BridgeStateStore.getWallpaperVideoAssetUris(appContext)));
        map.put("folderUri", BridgeStateStore.getWallpaperVideoFolderUri(appContext));
        map.put("folderBucketId", BridgeStateStore.getWallpaperVideoFolderBucketId(appContext));
        map.put("folderName", BridgeStateStore.getWallpaperVideoFolderName(appContext));
        map.put("orderMode", BridgeStateStore.getWallpaperVideoOrderMode(appContext));
        map.put("advanceMode", BridgeStateStore.getWallpaperVideoAdvanceMode(appContext));
        map.put("switchIntervalSeconds", BridgeStateStore.getWallpaperVideoSwitchIntervalSeconds(appContext));
        map.put("repeatCountPerItem", BridgeStateStore.getWallpaperVideoRepeatCountPerItem(appContext));
        map.put("playlistLoop", BridgeStateStore.isWallpaperVideoPlaylistLoopEnabled(appContext));
        map.put("textureId", surfaceTextureEntry != null ? surfaceTextureEntry.id() : -1L);
        map.put("loop", BridgeStateStore.isWallpaperVideoLoopEnabled(appContext));
        map.put("mute", BridgeStateStore.isWallpaperVideoMuted(appContext));
        map.put("fit", BridgeStateStore.getWallpaperVideoFit(appContext));
        map.put("dimPercent", BridgeStateStore.getWallpaperVideoDimPercent(appContext));
        map.put("blur", BridgeStateStore.getWallpaperVideoBlur(appContext));
        map.put("autoResume", BridgeStateStore.isWallpaperVideoAutoResumeEnabled(appContext));
        map.put("videoReady", videoReady);
        map.put("lastError", lastError);
        map.put("videoWidth", videoWidth);
        map.put("videoHeight", videoHeight);
        map.put("currentIndex", currentIndex);
        map.put("resolvedPlaylistUris", new ArrayList<>(resolvedPlaylistUris.isEmpty() ? cachedResolvedPlaylistUris : resolvedPlaylistUris));
        map.put("playbackSuppressed", playbackSuppressed);
        map.put("playbackSuppressedReason", playbackSuppressedReason);
        map.put("videoAllowedByPerformanceMode", videoAllowedByPerformanceMode);
        map.put("disableAudioRendererWhenMuted", disableAudioRendererWhenMuted);
        map.put("audioRendererEnabled", resolveDesiredAudioRendererEnabled());
        map.put("deferForegroundResume", false);
        return map;
    }

    public void resumePlayback(String reason) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post(() -> resumePlayback(reason));
            return;
        }

        String resolvedReason = TextUtils.isEmpty(reason) ? "resume" : reason;
        if (!shouldAutoResumeFromWake()) {
            cancelWakePlaylistRetry();
            return;
        }

        long now = SystemClock.elapsedRealtime();

        // 1. DEBOUNCE GUARD: Chặn bão sự kiện (home_reentry, start, resume, focus...)
        if (player != null && player.getMediaItemCount() > 0 && surface != null && surface.isValid()) {
            boolean isAlreadyActiveOrStarting = player.isPlaying() || player.getPlayWhenReady();
            if (isAlreadyActiveOrStarting && (now - lastResumeElapsedRealtimeMs < RESUME_DEBOUNCE_MS)) {
                Log.d(TAG, "wallpaper_resume debounced: already active (reason=" + resolvedReason
                        + ", elapsed=" + (now - lastResumeElapsedRealtimeMs) + "ms)");
                return;
            }
        }

        lastResumeElapsedRealtimeMs = now;
        wakeRearmStartedAtNanos = System.nanoTime();
        lastWakeElapsedRealtimeMs = now;
        consecutiveGlitchRetryCount = 0;
        logWakeInfo("wallpaper_resume reason=" + resolvedReason);
        mainHandler.removeCallbacks(backgroundReleaseRunnable);
        foregroundActive = true;
        startupWarmupReady = true;
        pendingWakePlaylistRetryCount = 0;
        pendingWakeReason = resolvedReason;
        consecutivePlayerErrorCount = 0;

        if (player != null && player.isPlaying() && surface != null && surface.isValid()) {
            return;
        }

        // 2. FAST-PATH (0ms DELAY): Surface & Player còn nguyên vẹn trong RAM và đã có playlist!
        // TUYỆT ĐỐI KHÔNG releaseSurface() hay ensureSurface() ở đây!
        if (player != null && player.getMediaItemCount() > 0 && surface != null && surface.isValid()) {
            int state = player.getPlaybackState();
            if (state == Player.STATE_IDLE) {
                player.prepare();
            } else if (state == Player.STATE_ENDED) {
                player.seekToDefaultPosition(Math.max(0, player.getCurrentMediaItemIndex()));
            }
            player.setPlayWhenReady(true);
            player.play();
            scheduleIntervalAdvance();
            if (state == Player.STATE_READY) {
                notifyStatusChangedIf(setVideoReady(true));
            }
            Log.i(TAG, "wallpaper_resume fast-path 0ms success (reason=" + resolvedReason + ", state=" + state + ")");
            return;
        }

        // 3. SLOW-PATH: Chỉ chạy khi Surface bị mất/invalid (sau TV STR wake) hoặc player == null (sau 60s background)
        ensureSurface();
        currentItemStartedAtMs = SystemClock.elapsedRealtime();

        if (player != null && player.getMediaItemCount() > 0 && surface != null && surface.isValid()) {
            try {
                player.setVideoSurface(surface);
                int state = player.getPlaybackState();
                if (state == Player.STATE_IDLE) {
                    player.prepare();
                } else if (state == Player.STATE_ENDED) {
                    player.seekToDefaultPosition(Math.max(0, player.getCurrentMediaItemIndex()));
                }
                player.setPlayWhenReady(true);
                player.play();
                scheduleIntervalAdvance();
                if (state == Player.STATE_READY) {
                    notifyStatusChangedIf(setVideoReady(true));
                }
                Log.i(TAG, "wallpaper_resume slow-path rebind success (reason=" + resolvedReason + ")");
                return;
            } catch (Exception e) {
                Log.w(TAG, "wallpaper_resume rebind surface failed: " + e.getMessage());
            }
        }

        maybeStartPlayback(true, true, true);
    }

    public void onStart() {
        resumePlayback("activity_start");
    }

    public void onScreenWake(String reason) {
        resumePlayback(reason);
    }

    public void onScreenWake(String reason, boolean hostWakeEligible) {
        resumePlayback(reason);
    }

    public void resumePlaybackOnFocus(String reason) {
        resumePlayback(reason);
    }

    public void onPause() {
        onPause(isDeviceInteractive());
    }

    public void onPause(boolean isInteractive) {
        foregroundActive = false;
        lifecycleEpoch++;
        stopIntervalAdvance();
        cancelWakePlaylistRetry();
        mainHandler.removeCallbacks(backgroundReleaseRunnable);
        pausePlayer();

        if (!isInteractive) {
            // TV is sleeping (!isInteractive): Hot-Standby
            // Keep surface and player intact in RAM for instant 0ms wake
            logWakeInfo("wallpaper_hot_standby_entered: kept surface and player in RAM");
        } else {
            // User switched to another app on active TV (isInteractive == true):
            // Delay release by 60s to yield VDEC hardware decoder to external media apps.
            mainHandler.postDelayed(backgroundReleaseRunnable, APP_SWITCH_RELEASE_DELAY_MS);
            logWakeInfo("wallpaper_app_switch: delayed release scheduled in " + APP_SWITCH_RELEASE_DELAY_MS + "ms");
        }
    }

    public void onStop() {
        onStop(isDeviceInteractive());
    }

    public void onStop(boolean isInteractive) {
        onPause(isInteractive);
    }

    private void pausePlayer() {
        stopIntervalAdvance();
        if (player != null) {
            try {
                savedMediaIndex = Math.max(0, player.getCurrentMediaItemIndex());
                savedPositionMs = Math.max(0L, player.getCurrentPosition());
                player.pause();
            } catch (Exception ignored) {
            }
        }
    }

    public void onDestroy() {
        mainHandler.removeCallbacks(backgroundReleaseRunnable);
        cancelWakePlaylistRetry();
        unregisterStorageWatchdog();
        releasePlayer();
        releaseSurfaceAndTextureEntry();
    }

    public void onWallpaperModeChanged() {
        cancelWakePlaylistRetry();
        savedMediaIndex = 0;
        savedPositionMs = 0L;
        cachedShuffledPlaylistUris.clear();
        cachedShuffledConfigSignature = "";
        cachedResolvedPlaylistUris.clear();
        cachedResolvedTopologySignature = "";
        quarantinedUris.clear();
        if (!TextUtils.equals("video", BridgeStateStore.getWallpaperMode(appContext))) {
            boolean changed = setVideoReady(false) | setLastError("");
            releasePlayer();
            releaseSurfaceAndTextureEntry();
            notifyStatusChangedIf(changed);
            return;
        }
        maybeStartPlayback(false);
    }

    public void onVideoConfigChanged() {
        cancelWakePlaylistRetry();
        cachedShuffledPlaylistUris.clear();
        cachedShuffledConfigSignature = "";
        cachedResolvedPlaylistUris.clear();
        cachedResolvedTopologySignature = "";
        quarantinedUris.clear();
        startupWarmupReady = true;
        onVideoPlaylistTopologyChanged();
        onVideoPlayerPolicyChanged();
        onVideoPresentationChanged();
    }

    public void onVideoPlaylistTopologyChanged() {
        cancelWakePlaylistRetry();
        startupWarmupReady = true;
        activePlaybackConfigSignature = "";
        cachedShuffledPlaylistUris.clear();
        cachedShuffledConfigSignature = "";
        cachedResolvedPlaylistUris.clear();
        cachedResolvedTopologySignature = "";
        quarantinedUris.clear();
        savedMediaIndex = 0;
        savedPositionMs = 0L;
        if (player != null) {
            resolvedPlaylistUris = resolvePlaylistUris(false);
            if (resolvedPlaylistUris.isEmpty()) {
                boolean changed = setVideoReady(false)
                        | setLastError("No playable wallpaper videos were resolved.");
                releasePlayer();
                notifyStatusChangedIf(changed);
                return;
            }
            boolean changed = setCurrentIndex(0);
            applyMediaItems(0, 0L);
            applyPlayerPolicySettings();
            applyPresentationSettings();
            player.prepare();
            if (!playbackSuppressed &&
                    foregroundActive &&
                    BridgeStateStore.isWallpaperVideoAutoResumeEnabled(appContext)) {
                resumeExistingPlayerIfNeeded();
            }
            scheduleIntervalAdvance();
            notifyStatusChangedIf(changed);
        } else {
            maybeStartPlayback(false);
        }
    }

    public void onVideoPlayerPolicyChanged() {
        startupWarmupReady = true;
        if (player == null) {
            maybeStartPlayback(false);
            return;
        }
        applyPlayerPolicySettings();
        if (!playbackSuppressed
                && foregroundActive
                && BridgeStateStore.isWallpaperVideoAutoResumeEnabled(appContext)
                && !player.isPlaying()) {
            resumeExistingPlayerIfNeeded();
        }
        scheduleIntervalAdvance();
    }

    public void onVideoPresentationChanged() {
        startupWarmupReady = true;
        if (player == null) {
            maybeStartPlayback(false);
            return;
        }
        applyPresentationSettings();
    }

    public boolean setVideoAllowedByPerformanceMode(boolean allowed) {
        if (videoAllowedByPerformanceMode == allowed) {
            return false;
        }
        videoAllowedByPerformanceMode = allowed;
        if (!allowed) {
            startupWarmupReady = false;
            releasePlayer();
            releaseSurfaceAndTextureEntry();
        }
        return true;
    }

    public boolean setDisableAudioRendererWhenMuted(boolean disable) {
        if (disableAudioRendererWhenMuted == disable) {
            return false;
        }
        disableAudioRendererWhenMuted = disable;
        if (player != null) {
            applyPresentationSettings();
        }
        return true;
    }

    public boolean setDeferForegroundResume(boolean deferForegroundResume) {
        return false;
    }

    public void setPlaybackSuppressed(boolean suppressed, String reason) {
        if (playbackSuppressed == suppressed && TextUtils.equals(playbackSuppressedReason, reason)) {
            return;
        }
        if (suppressed) {
            cancelWakePlaylistRetry();
            wasPlayingBeforeSuppression = player != null
                    ? player.isPlaying() || player.getPlayWhenReady()
                    : shouldResumeWhenUnsuppressed();
            playbackSuppressed = true;
            playbackSuppressedReason = reason == null ? "" : reason;
            stopIntervalAdvance();
            if (player != null) {
                player.pause();
            }
            return;
        }

        playbackSuppressed = false;
        playbackSuppressedReason = "";
        boolean shouldResume = wasPlayingBeforeSuppression;
        wasPlayingBeforeSuppression = false;
        if (!foregroundActive) {
            return;
        }
        if (player == null) {
            if (shouldResume) {
                maybeStartPlayback(false);
            }
            return;
        }
        if (shouldResume) {
            resumeExistingPlayerIfNeeded();
            scheduleIntervalAdvance();
        }
    }

    private void maybeStartPlayback(boolean explicitWarmup) {
        maybeStartPlayback(explicitWarmup, false, false);
    }

    private void maybeStartPlayback(boolean explicitWarmup, boolean retryEmptyPlaylist) {
        maybeStartPlayback(explicitWarmup, retryEmptyPlaylist, false);
    }

    private void maybeStartPlayback(boolean explicitWarmup, boolean retryEmptyPlaylist, boolean allowCache) {
        if (!foregroundActive) {
            return;
        }
        if (playbackSuppressed) {
            return;
        }
        if (!startupWarmupReady) {
            return;
        }
        if (!videoAllowedByPerformanceMode) {
            return;
        }
        if (!TextUtils.equals("video", BridgeStateStore.getWallpaperMode(appContext))) {
            return;
        }
        String desiredConfigSignature = buildPlaybackTopologySignature();
        if (player != null &&
                surfaceTextureEntry != null &&
                surface != null &&
                surface.isValid() &&
                TextUtils.equals(activePlaybackConfigSignature, desiredConfigSignature)) {
            cancelWakePlaylistRetry();
            applyPlayerPolicySettings();
            applyPresentationSettings();
            if (BridgeStateStore.isWallpaperVideoAutoResumeEnabled(appContext)
                    && !player.isPlaying()) {
                resumeExistingPlayerIfNeeded();
            }
            scheduleIntervalAdvance();
            return;
        }

        resolvedPlaylistUris = resolvePlaylistUris(allowCache);
        if (resolvedPlaylistUris.isEmpty()) {
            boolean changed = setVideoReady(false)
                    | setLastError("No playable wallpaper videos were resolved.");
            notifyStatusChangedIf(changed);
            if (retryEmptyPlaylist) {
                scheduleWakePlaylistRetryIfNeeded();
            }
            return;
        }

        cancelWakePlaylistRetry();
        ensureSurface();
        releasePlayer();

        int targetIndex = (savedMediaIndex >= 0 && savedMediaIndex < resolvedPlaylistUris.size())
                ? savedMediaIndex : 0;
        long targetPosition = (savedMediaIndex == targetIndex && savedPositionMs > 0L)
                ? savedPositionMs : 0L;

        boolean readyChanged = false;
        if (surfaceTextureEntry == null || !hasRenderedFirstFrameEver) {
            readyChanged = setVideoReady(false);
        }
        boolean resetStatusChanged = readyChanged
                | setLastError("")
                | setCurrentIndex(targetIndex);
        activePlaybackConfigSignature = desiredConfigSignature;
        videoWarmupStartedAtNanos = System.nanoTime();
        notifyStatusChangedIf(resetStatusChanged);

        DefaultRenderersFactory renderersFactory = new DefaultRenderersFactory(appContext)
                .setEnableDecoderFallback(true);
        trackSelector = new DefaultTrackSelector(appContext);
        androidx.media3.common.AudioAttributes audioAttributes = new androidx.media3.common.AudioAttributes.Builder()
                .setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                .build();
        player = new ExoPlayer.Builder(appContext, renderersFactory)
                .setTrackSelector(trackSelector)
                .setAudioAttributes(audioAttributes, true)
                .build();
        player.setVideoSurface(surface);
        player.addListener(new Player.Listener() {
            @Override
            public void onPlaybackStateChanged(int playbackState) {
                if (playbackState == Player.STATE_READY) {
                    consecutivePlayerErrorCount = 0;
                    consecutiveGlitchRetryCount = 0;
                    if (currentItemStartedAtMs == 0L) {
                        currentItemStartedAtMs = SystemClock.elapsedRealtime();
                    }
                    boolean statusChanged = setVideoReady(true);
                    logPerf("time_to_video_ready", videoWarmupStartedAtNanos);
                    videoWarmupStartedAtNanos = 0L;
                    scheduleIntervalAdvance(false);
                    notifyStatusChangedIf(statusChanged);
                } else if (playbackState == Player.STATE_ENDED) {
                    handlePlaybackEnded();
                }
            }

            @Override
            public void onIsPlayingChanged(boolean isPlaying) {
                if (isPlaying) {
                    consecutivePlayerErrorCount = 0;
                    boolean statusChanged = setVideoReady(true);
                    notifyStatusChangedIf(statusChanged);
                }
            }

            @Override
            public void onRenderedFirstFrame() {
                hasRenderedFirstFrameEver = true;
                consecutivePlayerErrorCount = 0;
                consecutiveGlitchRetryCount = 0;
                if (currentItemStartedAtMs == 0L) {
                    currentItemStartedAtMs = SystemClock.elapsedRealtime();
                }
                boolean statusChanged = setVideoReady(true);
                if (wakeRearmStartedAtNanos > 0L) {
                    long elapsedMs = (System.nanoTime() - wakeRearmStartedAtNanos) / 1_000_000L;
                    Log.i(TAG, "wallpaper_wake_to_first_frame elapsedMs=" + elapsedMs + " reason=" + pendingWakeReason);
                    wakeRearmStartedAtNanos = 0L;
                }
                notifyStatusChangedIf(statusChanged);
            }

            @Override
            public void onPlayerError(PlaybackException error) {
                consecutivePlayerErrorCount++;
                String rawMsg = error.getMessage() == null ? error.toString() : error.getMessage();
                String errorMsg = maskSensitiveText(rawMsg);
                Log.w(TAG, "ExoPlayer onPlayerError (attempt " + consecutivePlayerErrorCount + "): " + errorMsg);

                long now = SystemClock.elapsedRealtime();
                boolean inWakeCooldown = (now - lastWakeElapsedRealtimeMs < WAKE_COOLDOWN_MS);

                if (isContainerOrFileNotFoundError(error, rawMsg)) {
                    if (!inWakeCooldown) {
                        String failedUri = resolveCurrentFailedUri();
                        if (!TextUtils.isEmpty(failedUri)) {
                            quarantinedUris.add(failedUri);
                            if (failedUri.startsWith("file://")) {
                                quarantinedUris.add(failedUri.substring(7));
                            } else if (failedUri.startsWith("/")) {
                                quarantinedUris.add("file://" + failedUri);
                            }
                            cachedResolvedPlaylistUris.remove(failedUri);
                            Log.w(TAG, "Quarantined broken video URI: " + maskSensitiveText(failedUri));
                        }
                        if (player != null && player.getMediaItemCount() > 1) {
                            int failedIndex = player.getCurrentMediaItemIndex();
                            boolean advanced = advancePlaylist();
                            if (advanced) {
                                consecutivePlayerErrorCount = 0;
                                player.prepare();
                                if (failedIndex >= 0 && failedIndex < player.getMediaItemCount()) {
                                    try {
                                        player.removeMediaItem(failedIndex);
                                    } catch (Exception ignored) {
                                    }
                                }
                                scheduleIntervalAdvance(true);
                                return;
                            }
                        }
                    } else {
                        Log.i(TAG, "onPlayerError: Suppressed quarantine/advance during wake cooldown");
                    }
                }

                boolean isTransient = isCodecContentionOrTransientError(rawMsg);

                boolean statusChanged = setVideoReady(false)
                        | setLastError(isTransient ? "" : errorMsg);
                notifyStatusChangedIf(statusChanged);
                releasePlayer();
                if (isTransient) {
                    releaseSurface();
                }

                if (isTransient && consecutivePlayerErrorCount == 1) {
                    forceReleaseExternalCodecHolders();
                }

                if (consecutivePlayerErrorCount <= MAX_CONSECUTIVE_PLAYER_ERRORS) {
                    long delayMs = 600L * consecutivePlayerErrorCount;
                    if (foregroundActive && !playbackSuppressed && shouldAutoResumeFromWake()) {
                        mainHandler.postDelayed(() -> {
                            if (foregroundActive && !playbackSuppressed && shouldAutoResumeFromWake()) {
                                logWakeInfo("wallpaper_auto_recover_after_error attempt=" + consecutivePlayerErrorCount);
                                ensureSurface();
                                maybeStartPlayback(true, true, true);
                            }
                        }, delayMs);
                    }
                } else {
                    Log.w(TAG, "ExoPlayer: Max consecutive errors reached. Awaiting next trigger.");
                }
            }

            @Override
            public void onVideoSizeChanged(VideoSize size) {
                notifyStatusChangedIf(setVideoSize(size.width, size.height));
            }

            @Override
            public void onMediaItemTransition(MediaItem mediaItem, int reason) {
                currentItemStartedAtMs = SystemClock.elapsedRealtime();
                consecutiveGlitchRetryCount = 0;
                boolean statusChanged = false;
                if (player != null) {
                    int nextIdx = Math.max(0, player.getCurrentMediaItemIndex());
                    savedMediaIndex = nextIdx;
                    savedPositionMs = 0L;
                    statusChanged = setCurrentIndex(nextIdx);
                }
                scheduleIntervalAdvance(true);
                notifyStatusChangedIf(statusChanged);
            }
        });
        applyMediaItems(targetIndex, targetPosition);
        applyPlayerPolicySettings();
        applyPresentationSettings();
        player.prepare();
        if (BridgeStateStore.isWallpaperVideoAutoResumeEnabled(appContext)) {
            player.play();
        }
    }

    private void applyMediaItems(int startIndex, long startPositionMs) {
        if (player == null) {
            return;
        }
        List<MediaItem> mediaItems = new ArrayList<>();
        List<String> urisToApply = resolvedPlaylistUris.isEmpty() ? cachedResolvedPlaylistUris : resolvedPlaylistUris;
        for (String uriStr : urisToApply) {
            if (!TextUtils.isEmpty(uriStr) && !quarantinedUris.contains(uriStr)) {
                try {
                    Uri parsedUri;
                    if (uriStr.startsWith("/") || uriStr.startsWith("file://")) {
                        parsedUri = uriStr.startsWith("/") ? Uri.fromFile(new java.io.File(uriStr)) : Uri.parse(uriStr);
                    } else {
                        parsedUri = Uri.parse(uriStr);
                    }
                    mediaItems.add(MediaItem.fromUri(parsedUri));
                } catch (Exception ignored) {}
            }
        }
        if (startIndex >= 0 && startIndex < mediaItems.size()) {
            player.setMediaItems(mediaItems, startIndex, startPositionMs);
        } else {
            player.setMediaItems(mediaItems, false);
        }
    }

    private void applyPlayerPolicySettings() {
        if (player == null) {
            return;
        }
        int itemCount = Math.max(1, player.getMediaItemCount());
        String advanceMode = BridgeStateStore.getWallpaperVideoAdvanceMode(appContext);
        if (itemCount <= 1) {
            player.setRepeatMode(
                    BridgeStateStore.isWallpaperVideoLoopEnabled(appContext)
                            ? Player.REPEAT_MODE_ONE
                            : Player.REPEAT_MODE_OFF
            );
        } else {
            // Đặt REPEAT_MODE_OFF cho playlist để ứng dụng làm chủ chuyển bài trong handlePlaybackEnded().
            // Triệt tiêu hoàn toàn hiện tượng ExoPlayer tự động nhảy bài ngầm khi dính Fake EOS lúc wake.
            player.setRepeatMode(Player.REPEAT_MODE_OFF);
        }
    }

    private void applyPresentationSettings() {
        if (player == null) {
            return;
        }
        applyAudioRendererPolicy(resolveDesiredAudioRendererEnabled());
        player.setVolume(BridgeStateStore.isWallpaperVideoMuted(appContext) ? 0f : 1f);
    }

    private List<String> resolvePlaylistUris() {
        return resolvePlaylistUris(false);
    }

    private List<String> resolvePlaylistUris(boolean allowCache) {
        String currentTopologySignature = buildPlaybackTopologySignature();
        if (allowCache && !cachedResolvedPlaylistUris.isEmpty()
                && TextUtils.equals(cachedResolvedTopologySignature, currentTopologySignature)) {
            boolean hasInvalid = false;
            for (String uri : cachedResolvedPlaylistUris) {
                if (quarantinedUris.contains(uri) || !VideoSecurityValidator.isUriSafeForPlayback(appContext, uri)) {
                    hasInvalid = true;
                    break;
                }
            }
            if (!hasInvalid) {
                return new ArrayList<>(cachedResolvedPlaylistUris);
            }
        }

        List<String> rawUris = new ArrayList<>(VideoLibraryController.resolveConfiguredPlaylistUris(appContext));
        List<String> safeUris = new ArrayList<>();
        for (String uri : rawUris) {
            if (!TextUtils.isEmpty(uri)
                    && !quarantinedUris.contains(uri)
                    && VideoSecurityValidator.isUriSafeForPlayback(appContext, uri)) {
                safeUris.add(uri);
            }
        }
        if (safeUris.isEmpty()) {
            if (allowCache && !cachedResolvedPlaylistUris.isEmpty()) {
                List<String> safeCached = new ArrayList<>();
                for (String uri : cachedResolvedPlaylistUris) {
                    if (!quarantinedUris.contains(uri) && VideoSecurityValidator.isUriSafeForPlayback(appContext, uri)) {
                        safeCached.add(uri);
                    }
                }
                if (!safeCached.isEmpty()) {
                    Log.i(TAG, "resolvePlaylistUris: safeUris empty on wake, using cachedResolvedPlaylistUris count=" + safeCached.size());
                    return safeCached;
                }
            }
            return Collections.emptyList();
        }
        String advanceMode = BridgeStateStore.getWallpaperVideoAdvanceMode(appContext);
        List<String> uris;
        if (BridgeStateStore.WALLPAPER_ORDER_SHUFFLE.equals(
                BridgeStateStore.getWallpaperVideoOrderMode(appContext)
        )) {
            if (cachedShuffledConfigSignature.equals(currentTopologySignature)
                    && cachedShuffledPlaylistUris.size() == safeUris.size()
                    && cachedShuffledPlaylistUris.containsAll(safeUris)) {
                uris = new ArrayList<>(cachedShuffledPlaylistUris);
            } else {
                uris = new ArrayList<>(safeUris);
                Collections.shuffle(uris);
                cachedShuffledPlaylistUris.clear();
                cachedShuffledPlaylistUris.addAll(uris);
                cachedShuffledConfigSignature = currentTopologySignature;
            }
        } else {
            uris = new ArrayList<>(safeUris);
            cachedShuffledPlaylistUris.clear();
            cachedShuffledConfigSignature = "";
        }
        int repeatCountPerItem = BridgeStateStore.getWallpaperVideoRepeatCountPerItem(appContext);
        List<String> finalUris;
        if (repeatCountPerItem <= 1
                || uris.size() <= 1
                || BridgeStateStore.WALLPAPER_ADVANCE_FIXED_INTERVAL.equals(advanceMode)) {
            finalUris = uris;
        } else {
            finalUris = new ArrayList<>(uris.size() * repeatCountPerItem);
            for (String uri : uris) {
                for (int i = 0; i < repeatCountPerItem; i++) {
                    finalUris.add(uri);
                }
            }
        }
        cachedResolvedPlaylistUris.clear();
        cachedResolvedPlaylistUris.addAll(finalUris);
        cachedResolvedTopologySignature = currentTopologySignature;
        return finalUris;
    }

    private void scheduleIntervalAdvance() {
        scheduleIntervalAdvance(false);
    }

    private void scheduleIntervalAdvance(boolean resetDeadline) {
        if (player == null || !foregroundActive || !videoReady || playbackSuppressed) {
            stopIntervalAdvance();
            return;
        }
        if (!player.isPlaying() && !player.getPlayWhenReady()) {
            stopIntervalAdvance();
            return;
        }
        if (!BridgeStateStore.WALLPAPER_ADVANCE_FIXED_INTERVAL.equals(
                BridgeStateStore.getWallpaperVideoAdvanceMode(appContext))
        ) {
            stopIntervalAdvance();
            return;
        }
        if (player.getMediaItemCount() <= 1) {
            stopIntervalAdvance();
            return;
        }
        long now = SystemClock.elapsedRealtime();
        long intervalMs = Math.max(5L, BridgeStateStore.getWallpaperVideoSwitchIntervalSeconds(appContext)) * 1000L;

        if (resetDeadline || !isAdvanceScheduled || now >= targetAdvanceUptimeMs) {
            stopIntervalAdvance();
            targetAdvanceUptimeMs = now + intervalMs;
            isAdvanceScheduled = true;
            mainHandler.postDelayed(advanceRunnable, intervalMs);
        } else {
            long remainingMs = Math.max(100L, targetAdvanceUptimeMs - now);
            mainHandler.removeCallbacks(advanceRunnable);
            isAdvanceScheduled = true;
            mainHandler.postDelayed(advanceRunnable, remainingMs);
        }
    }

    private void handlePlaybackEnded() {
        if (player == null) {
            return;
        }
        long now = SystemClock.elapsedRealtime();
        long duration = player.getDuration();
        long position = player.getCurrentPosition();
        long playedWallTimeMs = currentItemStartedAtMs > 0L ? (now - currentItemStartedAtMs) : 0L;
        long timeSinceWakeMs = lastWakeElapsedRealtimeMs > 0L ? (now - lastWakeElapsedRealtimeMs) : Long.MAX_VALUE;

        // 1. Tiêu chuẩn video hoàn thành hợp lệ: >= 90% duration HOẶC playedWallTimeMs >= 2000ms
        boolean isDurationKnown = duration > 0L && duration != C.TIME_UNSET;
        boolean reachedNinetyPercent = isDurationKnown && (position >= (long) (duration * 0.90f));
        boolean playedAtLeastTwoSeconds = playedWallTimeMs >= MIN_PLAY_BEFORE_ADVANCE_MS;
        boolean isValidNaturalCompletion = reachedNinetyPercent || playedAtLeastTwoSeconds;

        // 2. Phát hiện Decoder Wake Glitch (trong thời gian wake cooldown hoặc played time < 1200ms)
        boolean inWakeCooldown = (timeSinceWakeMs < WAKE_COOLDOWN_MS);
        boolean isWakeGlitch = inWakeCooldown || (!isValidNaturalCompletion && playedWallTimeMs < MIN_LEGITIMATE_PLAYBACK_DURATION_MS);

        if (isWakeGlitch) {
            consecutiveGlitchRetryCount++;
            Log.w(TAG, "PlaybackDurationGuard: Detected wake decoder glitch (timeSinceWake=" + timeSinceWakeMs
                    + "ms, playedWallTime=" + playedWallTimeMs + "ms). Rebinding surface and resuming current item at "
                    + savedPositionMs + "ms (attempt " + consecutiveGlitchRetryCount + ")");
            releaseSurface();
            ensureSurface();
            mainHandler.postDelayed(() -> {
                if (player != null && foregroundActive && !playbackSuppressed) {
                    int targetIdx = Math.max(0, player.getCurrentMediaItemIndex());
                    long resumePos = Math.max(0L, savedPositionMs);
                    player.seekTo(targetIdx, resumePos);
                    player.prepare();
                    player.play();
                }
            }, 300L);
            return; // CHẶN ĐỨNG, TUYỆT ĐỐI KHÔNG NEXT BÀI!
        }

        // 3. Xử lý khi video kết thúc hợp lệ
        consecutiveGlitchRetryCount = 0;
        String advanceMode = BridgeStateStore.getWallpaperVideoAdvanceMode(appContext);
        if (BridgeStateStore.WALLPAPER_ADVANCE_FIXED_INTERVAL.equals(advanceMode)) {
            // Ở chế độ fixed_interval, nếu video ngắn hết trước thời gian interval, lặp lại video hiện tại
            player.seekTo(player.getCurrentMediaItemIndex(), 0L);
            player.prepare();
            player.play();
        } else {
            // Chế độ On Video End: Chuyển sang video tiếp theo
            advancePlaylist();
        }
    }

    private boolean advancePlaylist() {
        if (player == null || player.getMediaItemCount() <= 1) {
            return false;
        }
        long now = SystemClock.elapsedRealtime();

        // Guard 1: Wake Cooldown (Ngăn chuyển bài khi TV vừa mở máy)
        if (now - lastWakeElapsedRealtimeMs < WAKE_COOLDOWN_MS) {
            Log.d(TAG, "advancePlaylist suppressed: in wake cooldown (" + (now - lastWakeElapsedRealtimeMs) + "ms)");
            return false;
        }

        // Guard 2: Throttle Guard (Chặn next dồn dập liên tiếp)
        if (now - lastAdvanceElapsedRealtimeMs < ADVANCE_THROTTLE_MS) {
            Log.d(TAG, "advancePlaylist suppressed: transition throttle active (" + (now - lastAdvanceElapsedRealtimeMs) + "ms)");
            return false;
        }

        // Guard 3: Min Playback Guard (Video phải phát thực sự tối thiểu 2 giây)
        long currentPos = player.getCurrentPosition();
        if (currentPos > 0L && currentPos < MIN_PLAY_BEFORE_ADVANCE_MS) {
            Log.d(TAG, "advancePlaylist suppressed: current position < " + MIN_PLAY_BEFORE_ADVANCE_MS + "ms (pos=" + currentPos + "ms)");
            return false;
        }

        if (player.hasNextMediaItem()) {
            lastAdvanceElapsedRealtimeMs = now;
            player.seekToNextMediaItem();
            player.play();
            return true;
        }
        if (BridgeStateStore.isWallpaperVideoPlaylistLoopEnabled(appContext)) {
            lastAdvanceElapsedRealtimeMs = now;
            player.seekToDefaultPosition(0);
            player.play();
            return true;
        }
        return false;
    }

    private void releasePlayer() {
        stopIntervalAdvance();
        mainHandler.removeCallbacks(backgroundReleaseRunnable);
        if (player != null) {
            try {
                player.stop();
            } catch (Exception ignored) {
            }
            try {
                player.release();
            } catch (Exception ignored) {
            }
            player = null;
        }
        trackSelector = null;
        notifyStatusChangedIf(setVideoReady(false));
        activePlaybackConfigSignature = "";
    }

    private void releaseSurface() {
        if (player != null) {
            try {
                player.clearVideoSurface();
            } catch (Exception ignored) {
            }
        }
        if (surface != null) {
            try {
                surface.release();
            } catch (Exception ignored) {
            }
            surface = null;
        }
    }

    private void releaseSurfaceAndTextureEntry() {
        releaseSurface();
        if (surfaceTextureEntry != null) {
            try {
                surfaceTextureEntry.release();
            } catch (Exception ignored) {
            }
            surfaceTextureEntry = null;
        }
    }

    private void ensureSurface() {
        boolean isNewTexture = false;
        if (surfaceTextureEntry == null) {
            try {
                surfaceTextureEntry = textureRegistry.createSurfaceTexture();
                isNewTexture = true;
            } catch (Exception e) {
                Log.w(TAG, "Failed to create SurfaceTexture: " + e.getMessage());
                return;
            }
        }
        if (surfaceTextureEntry == null) {
            return;
        }
        if (isNewTexture) {
            try {
                surfaceTextureEntry.surfaceTexture().setDefaultBufferSize(1920, 1080);
            } catch (Exception e) {
                Log.w(TAG, "Failed to set default buffer size on SurfaceTexture: " + e.getMessage());
            }
        }
        boolean surfaceRecreated = false;
        if (surface == null || !surface.isValid()) {
            if (surface != null) {
                try {
                    surface.release();
                } catch (Exception ignored) {
                }
            }
            try {
                surface = new Surface(surfaceTextureEntry.surfaceTexture());
                surfaceRecreated = true;
            } catch (Exception e) {
                Log.w(TAG, "Surface creation failed: " + e.getMessage());
                releaseSurfaceAndTextureEntry();
                return;
            }
        }
        if (surfaceRecreated && player != null && surface != null && surface.isValid()) {
            try {
                player.setVideoSurface(surface);
            } catch (Exception ignored) {
            }
        }
    }


    private boolean isDeviceInteractive() {
        try {
            PowerManager pm = (PowerManager) appContext.getSystemService(Context.POWER_SERVICE);
            return pm == null || pm.isInteractive();
        } catch (Exception ignored) {
            return true;
        }
    }

    private void registerStorageWatchdog() {
        if (storageWatchdogRegistered) {
            return;
        }
        try {
            storageReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    if (intent == null) return;
                    String action = intent.getAction();
                    if (TextUtils.isEmpty(action)) return;
                    Log.i(TAG, "StorageMountWatchdog received action: " + action);
                    triggerPlaylistReloadFromStorage("storage_broadcast_" + action);
                }
            };

            IntentFilter filterWithScheme = new IntentFilter();
            filterWithScheme.addAction(Intent.ACTION_MEDIA_MOUNTED);
            filterWithScheme.addAction(Intent.ACTION_MEDIA_UNMOUNTED);
            filterWithScheme.addAction(Intent.ACTION_MEDIA_SCANNER_FINISHED);
            filterWithScheme.addAction(Intent.ACTION_MEDIA_EJECT);
            filterWithScheme.addDataScheme("file");
            if (Build.VERSION.SDK_INT >= 33) {
                appContext.registerReceiver(storageReceiver, filterWithScheme, Context.RECEIVER_NOT_EXPORTED);
            } else {
                appContext.registerReceiver(storageReceiver, filterWithScheme);
            }

            IntentFilter filterNoScheme = new IntentFilter();
            filterNoScheme.addAction(Intent.ACTION_MEDIA_SCANNER_FINISHED);
            if (Build.VERSION.SDK_INT >= 33) {
                appContext.registerReceiver(storageReceiver, filterNoScheme, Context.RECEIVER_NOT_EXPORTED);
            } else {
                appContext.registerReceiver(storageReceiver, filterNoScheme);
            }
        } catch (Exception e) {
            Log.w(TAG, "Failed to register storage receiver: " + e.getMessage());
        }

        try {
            mediaStoreObserver = new ContentObserver(mainHandler) {
                @Override
                public void onChange(boolean selfChange, Uri uri) {
                    super.onChange(selfChange, uri);
                    Log.d(TAG, "MediaStore video content changed, uri=" + maskUri(uri != null ? uri.toString() : ""));
                    triggerPlaylistReloadFromStorage("mediastore_change");
                }
            };
            appContext.getContentResolver().registerContentObserver(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    true,
                    mediaStoreObserver
            );
        } catch (Exception e) {
            Log.w(TAG, "Failed to register MediaStore ContentObserver: " + e.getMessage());
        }
        storageWatchdogRegistered = true;
    }

    private void unregisterStorageWatchdog() {
        if (!storageWatchdogRegistered) {
            return;
        }
        mainHandler.removeCallbacks(storageReloadRunnable);
        if (storageReceiver != null) {
            try {
                appContext.unregisterReceiver(storageReceiver);
            } catch (Exception ignored) {
            }
            storageReceiver = null;
        }
        if (mediaStoreObserver != null) {
            try {
                appContext.getContentResolver().unregisterContentObserver(mediaStoreObserver);
            } catch (Exception ignored) {
            }
            mediaStoreObserver = null;
        }
        storageWatchdogRegistered = false;
    }

    private void triggerPlaylistReloadFromStorage(String reason) {
        pendingStorageReloadReason = reason;
        mainHandler.removeCallbacks(storageReloadRunnable);
        mainHandler.postDelayed(storageReloadRunnable, 1000L);
    }

    public static String maskUri(String uri) {
        if (TextUtils.isEmpty(uri)) {
            return "";
        }
        if (uri.startsWith("content://")) {
            try {
                Uri parsed = Uri.parse(uri);
                String lastSeg = parsed.getLastPathSegment();
                return "content://" + parsed.getAuthority() + "/.../"
                        + (lastSeg != null && lastSeg.length() > 4 ? lastSeg.substring(0, 2) + "***" : "***");
            } catch (Exception ignored) {
                return "content://***";
            }
        }
        int lastSlash = uri.lastIndexOf('/');
        if (lastSlash != -1 && lastSlash < uri.length() - 1) {
            String fileName = uri.substring(lastSlash + 1);
            int dot = fileName.lastIndexOf('.');
            String ext = dot >= 0 ? fileName.substring(dot) : "";
            return ".../" + (fileName.length() > 4 ? fileName.substring(0, 2) + "***" + ext : "***" + ext);
        }
        return "***";
    }

    private static String maskSensitiveText(String text) {
        if (TextUtils.isEmpty(text)) return "";
        return text.replaceAll("content://[^\\s]+", "content://***")
                .replaceAll("/storage/[^\\s]+", "/storage/***")
                .replaceAll("/data/[^\\s]+", "/data/***");
    }

    private static boolean isSamePlaylist(List<String> a, List<String> b) {
        if (a == b) return true;
        if (a == null || b == null) return false;
        if (a.size() != b.size()) return false;
        return a.equals(b);
    }

    private void stopIntervalAdvance() {
        isAdvanceScheduled = false;
        mainHandler.removeCallbacks(advanceRunnable);
    }

    private void resumeExistingPlayerIfNeeded() {
        if (player == null) {
            maybeStartPlayback(true, true);
            return;
        }
        ensureSurface();
        int playbackState = player.getPlaybackState();
        if (playbackState == Player.STATE_IDLE) {
            player.prepare();
        } else if (playbackState == Player.STATE_ENDED && player.getMediaItemCount() > 0) {
            int currentMediaItemIndex = Math.max(0, player.getCurrentMediaItemIndex());
            player.seekToDefaultPosition(currentMediaItemIndex);
        }
        player.setPlayWhenReady(true);
        player.play();
        if (playbackState == Player.STATE_READY) {
            notifyStatusChangedIf(setVideoReady(true));
        }
    }

    private boolean shouldResumeWhenUnsuppressed() {
        return foregroundActive
                && startupWarmupReady
                && videoAllowedByPerformanceMode
                && TextUtils.equals("video", BridgeStateStore.getWallpaperMode(appContext))
                && BridgeStateStore.isWallpaperVideoAutoResumeEnabled(appContext);
    }

    private boolean shouldAutoResumeFromWake() {
        return TextUtils.equals("video", BridgeStateStore.getWallpaperMode(appContext))
                && BridgeStateStore.isWallpaperVideoAutoResumeEnabled(appContext)
                && videoAllowedByPerformanceMode
                && !playbackSuppressed;
    }

    private void scheduleWakePlaylistRetryIfNeeded() {
        if (pendingWakePlaylistRetryCount >= MAX_WAKE_PLAYLIST_RETRIES) {
            logWakeInfo("wallpaper_wake_rearm_retry_exhausted reason=" + pendingWakeReason);
            return;
        }
        pendingWakePlaylistRetryCount += 1;
        mainHandler.removeCallbacks(wakePlaylistRetryRunnable);
        mainHandler.postDelayed(wakePlaylistRetryRunnable, WAKE_PLAYLIST_RETRY_DELAY_MS);
    }

    private void cancelWakePlaylistRetry() {
        pendingWakePlaylistRetryCount = 0;
        pendingWakeReason = "";
        mainHandler.removeCallbacks(wakePlaylistRetryRunnable);
    }

    private String buildPlaybackTopologySignature() {
        StringBuilder builder = new StringBuilder();
        builder.append(BridgeStateStore.getWallpaperMode(appContext)).append('|');
        builder.append(BridgeStateStore.getWallpaperVideoSourceType(appContext)).append('|');
        builder.append(BridgeStateStore.getWallpaperVideoOrderMode(appContext)).append('|');
        builder.append(BridgeStateStore.getWallpaperVideoAdvanceMode(appContext)).append('|');
        builder.append(BridgeStateStore.getWallpaperVideoRepeatCountPerItem(appContext)).append('|');
        builder.append(BridgeStateStore.getWallpaperVideoFolderUri(appContext)).append('|');
        builder.append(BridgeStateStore.getWallpaperVideoFolderBucketId(appContext)).append('|');
        builder.append(BridgeStateStore.getWallpaperVideoFolderName(appContext)).append('|');
        for (String uri : BridgeStateStore.getWallpaperVideoAssetUris(appContext)) {
            builder.append(uri).append(';');
        }
        return builder.toString();
    }

    private void logPerf(String label, long startedAtNanos) {
        if (startedAtNanos == 0L) {
            return;
        }
        if (!isDebuggableBuild()) {
            return;
        }
        long elapsedMs = (System.nanoTime() - startedAtNanos) / 1_000_000L;
        Log.d(TAG, label + " elapsedMs=" + elapsedMs);
    }

    private void logWakeInfo(String message) {
        Log.i(TAG, message);
    }

    private boolean isDebuggableBuild() {
        return (appContext.getApplicationInfo().flags & android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0;
    }

    private boolean resolveDesiredAudioRendererEnabled() {
        return videoAllowedByPerformanceMode
                && (!BridgeStateStore.isWallpaperVideoMuted(appContext)
                || !disableAudioRendererWhenMuted);
    }

    private void applyAudioRendererPolicy(boolean enabled) {
        audioRendererEnabled = enabled;
        if (trackSelector == null) {
            return;
        }
        trackSelector.setParameters(
                trackSelector.buildUponParameters()
                        .setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, !enabled)
                        .build()
        );
    }

    private boolean isCodecContentionOrTransientError(String errorMsg) {
        if (TextUtils.isEmpty(errorMsg)) {
            return true;
        }
        return errorMsg.contains("0x80001013")
                || errorMsg.contains("NO_RESOURCES")
                || errorMsg.contains("DecoderInitException")
                || errorMsg.contains("MediaCodec")
                || errorMsg.contains("Surface")
                || errorMsg.contains("ExoPlaybackException")
                || errorMsg.contains("resource")
                || errorMsg.contains("busy");
    }

    private String resolveCurrentFailedUri() {
        if (player != null) {
            try {
                MediaItem currentItem = player.getCurrentMediaItem();
                if (currentItem != null && currentItem.localConfiguration != null
                        && currentItem.localConfiguration.uri != null) {
                    return currentItem.localConfiguration.uri.toString();
                }
                int currentMediaIndex = player.getCurrentMediaItemIndex();
                if (currentMediaIndex >= 0 && currentMediaIndex < resolvedPlaylistUris.size()) {
                    return resolvedPlaylistUris.get(currentMediaIndex);
                }
            } catch (Exception ignored) {
            }
        }
        if (currentIndex >= 0 && currentIndex < resolvedPlaylistUris.size()) {
            return resolvedPlaylistUris.get(currentIndex);
        }
        return null;
    }

    private boolean isContainerOrFileNotFoundError(PlaybackException error, String rawMsg) {
        if (error != null) {
            int code = error.errorCode;
            if (code == PlaybackException.ERROR_CODE_IO_FILE_NOT_FOUND
                    || code == PlaybackException.ERROR_CODE_PARSING_CONTAINER_MALFORMED
                    || code == PlaybackException.ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED
                    || code == PlaybackException.ERROR_CODE_PARSING_MANIFEST_MALFORMED
                    || code == PlaybackException.ERROR_CODE_PARSING_MANIFEST_UNSUPPORTED
                    || code == PlaybackException.ERROR_CODE_DECODING_FORMAT_UNSUPPORTED) {
                return true;
            }
        }
        if (TextUtils.isEmpty(rawMsg)) {
            return false;
        }
        String lower = rawMsg.toLowerCase(Locale.US);
        return lower.contains("filenotfound")
                || lower.contains("nosuchfile")
                || lower.contains("parserexception")
                || lower.contains("unrecognizedinputformat")
                || lower.contains("extractorexception")
                || lower.contains("malformed")
                || lower.contains("error_code_io_file_not_found");
    }

    @SuppressWarnings("deprecation")
    private void forceReleaseExternalCodecHolders() {
        try {
            ActivityManager am = (ActivityManager)
                    appContext.getSystemService(Context.ACTIVITY_SERVICE);
            if (am == null) return;

            String ourPackage = appContext.getPackageName();
            List<ActivityManager.RunningTaskInfo> tasks = am.getRunningTasks(10);
            if (tasks != null) {
                for (ActivityManager.RunningTaskInfo task : tasks) {
                    String pkg = task.baseActivity != null
                            ? task.baseActivity.getPackageName() : null;
                    if (pkg == null || pkg.equals(ourPackage)) continue;
                    if (pkg.startsWith("com.android.") || pkg.equals("android") || pkg.startsWith("com.google.")) continue;
                    Log.i(TAG, "Releasing background VDEC holder: " + pkg);
                    am.killBackgroundProcesses(pkg);
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "Failed to release external codec holders: " + e.getMessage());
        }
    }

    private void notifyStatusChangedIf(boolean changed) {
        if (!changed) {
            return;
        }
        notifyStatusChanged();
    }

    private void notifyStatusChanged() {
        if (statusChangedCallback == null) {
            return;
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            statusChangedCallback.run();
            return;
        }
        mainHandler.post(statusChangedCallback);
    }

    private boolean setVideoReady(boolean ready) {
        if (videoReady == ready) {
            return false;
        }
        videoReady = ready;
        return true;
    }

    private boolean setLastError(String error) {
        String normalized = error == null ? "" : error;
        if (TextUtils.equals(lastError, normalized)) {
            return false;
        }
        lastError = normalized;
        return true;
    }

    private boolean setVideoSize(int width, int height) {
        boolean changed = false;
        if (width > 0 && videoWidth != width) {
            videoWidth = width;
            changed = true;
        }
        if (height > 0 && videoHeight != height) {
            videoHeight = height;
            changed = true;
        }
        return changed;
    }

    private boolean setCurrentIndex(int index) {
        if (currentIndex == index) {
            return false;
        }
        currentIndex = index;
        return true;
    }
}
