package com.atv.launcher.systembridge.wallpaper;

import android.content.Context;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
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

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import io.flutter.view.TextureRegistry;

public final class VideoWallpaperController {
    private static final String TAG = "FLauncherPerf";
    private static final boolean FAST_STARTUP_ENABLED = true;
    private static final long BACKGROUND_PLAYER_RELEASE_DELAY_MS = 60000L;
    private static final long WAKE_REARM_DEBOUNCE_MS = 1500L;
    private static final long WAKE_PLAYLIST_RETRY_DELAY_MS = 750L;
    private static final int MAX_WAKE_PLAYLIST_RETRIES = 4;
    private static final int MAX_CONSECUTIVE_PLAYER_ERRORS = 3;

    private final Context appContext;
    private final TextureRegistry textureRegistry;
    private final Runnable statusChangedCallback;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final Set<String> quarantinedVideoUris = new HashSet<>();

    private TextureRegistry.SurfaceTextureEntry surfaceTextureEntry;
    private Surface surface;
    private ExoPlayer player;
    private DefaultTrackSelector trackSelector;
    private boolean foregroundActive = true;
    private boolean videoReady;
    private String lastError = "";
    private int videoWidth = 1920;
    private int videoHeight = 1080;
    private int currentIndex = 0;
    private List<String> resolvedPlaylistUris = new ArrayList<>();
    private boolean playbackSuppressed;
    private String playbackSuppressedReason = "";
    private boolean wasPlayingBeforeSuppression;
    private boolean videoAllowedByPerformanceMode = true;
    private boolean disableAudioRendererWhenMuted = true;
    private boolean audioRendererEnabled = true;
    private boolean deferForegroundResume;
    private boolean startupWarmupReady = !FAST_STARTUP_ENABLED;
    private long videoWarmupStartedAtNanos = 0L;
    private String activePlaybackConfigSignature = "";
    private long lastWakeRearmAtElapsedMs = 0L;
    private int pendingWakePlaylistRetryCount = 0;
    private int consecutivePlayerErrorCount = 0;
    private String pendingWakeReason = "";

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
            scheduleIntervalAdvance();
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
    }

    public long ensureTextureId() {
        startupWarmupReady = true;
        if (!videoAllowedByPerformanceMode) {
            return -1L;
        }
        ensureSurface();
        maybeStartPlayback(true);
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
        map.put("resolvedPlaylistUris", new ArrayList<>(resolvedPlaylistUris));
        map.put("playbackSuppressed", playbackSuppressed);
        map.put("playbackSuppressedReason", playbackSuppressedReason);
        map.put("videoAllowedByPerformanceMode", videoAllowedByPerformanceMode);
        map.put("disableAudioRendererWhenMuted", disableAudioRendererWhenMuted);
        map.put("audioRendererEnabled", resolveDesiredAudioRendererEnabled());
        map.put("deferForegroundResume", deferForegroundResume);
        return map;
    }

    public void onStart() {
        mainHandler.removeCallbacks(backgroundReleaseRunnable);
        foregroundActive = true;
        startupWarmupReady = true;
        if (shouldAutoResumeFromWake()) {
            ensureSurface();
            if (player != null && !player.isPlaying()) {
                resumeExistingPlayerIfNeeded();
            } else if (player == null) {
                maybeStartPlayback(true, true);
            }
        }
    }

    public void onScreenWake(String reason) {
        onScreenWake(reason, foregroundActive);
    }

    public void onScreenWake(String reason, boolean hostWakeEligible) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post(() -> onScreenWake(reason, hostWakeEligible));
            return;
        }

        String resolvedReason = TextUtils.isEmpty(reason) ? "screen_wake" : reason;
        if (!shouldAutoResumeFromWake()) {
            cancelWakePlaylistRetry();
            return;
        }

        long now = SystemClock.elapsedRealtime();
        boolean isForegroundDirectTrigger = "activity_resume".equals(resolvedReason)
                || "window_focus_gained".equals(resolvedReason)
                || "force_wake".equals(resolvedReason);
        if (!isForegroundDirectTrigger && lastWakeRearmAtElapsedMs > 0L
                && now - lastWakeRearmAtElapsedMs < 400L) {
            return;
        }
        lastWakeRearmAtElapsedMs = now;

        logWakeInfo("wallpaper_wake_rearm reason=" + resolvedReason);
        mainHandler.removeCallbacks(backgroundReleaseRunnable);
        foregroundActive = true;
        startupWarmupReady = true;
        pendingWakePlaylistRetryCount = 0;
        pendingWakeReason = resolvedReason;
        ensureSurface();
        if (player != null) {
            resumeExistingPlayerIfNeeded();
        } else {
            maybeStartPlayback(true, true);
        }

        scheduleMultiStageWakeRecovery(resolvedReason);
    }

    public void resumePlaybackOnFocus(String reason) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post(() -> resumePlaybackOnFocus(reason));
            return;
        }
        if (!shouldAutoResumeFromWake()) {
            return;
        }
        logWakeInfo("wallpaper_focus_resume reason=" + reason);
        mainHandler.removeCallbacks(backgroundReleaseRunnable);
        consecutivePlayerErrorCount = 0;
        quarantinedVideoUris.clear();
        foregroundActive = true;
        startupWarmupReady = true;
        ensureSurface();
        if (player != null && !player.isPlaying()) {
            resumeExistingPlayerIfNeeded();
        } else if (player == null) {
            maybeStartPlayback(true, true);
        }
        scheduleMultiStageWakeRecovery(reason);
    }

    private final List<Runnable> pendingMultiStageRunnables = new ArrayList<>();

    private void cancelPendingMultiStageWakeRecovery() {
        for (Runnable r : pendingMultiStageRunnables) {
            mainHandler.removeCallbacks(r);
        }
        pendingMultiStageRunnables.clear();
    }

    private void scheduleMultiStageWakeRecovery(String reason) {
        cancelPendingMultiStageWakeRecovery();
        long[] delays = new long[]{300L, 750L, 1500L, 2500L};
        for (long delay : delays) {
            Runnable r = new Runnable() {
                @Override
                public void run() {
                    pendingMultiStageRunnables.remove(this);
                    if (foregroundActive && !playbackSuppressed && shouldAutoResumeFromWake()) {
                        if (player == null || !player.isPlaying()) {
                            logWakeInfo("wallpaper_multi_stage_wake_retry delay=" + delay + "ms reason=" + reason);
                            ensureSurface();
                            if (player != null) {
                                resumeExistingPlayerIfNeeded();
                            } else {
                                maybeStartPlayback(true, true);
                            }
                        }
                    }
                }
            };
            pendingMultiStageRunnables.add(r);
            mainHandler.postDelayed(r, delay);
        }
    }

    public void onPause() {
        foregroundActive = false;
        stopIntervalAdvance();
        cancelWakePlaylistRetry();
        cancelPendingMultiStageWakeRecovery();
        mainHandler.removeCallbacks(backgroundReleaseRunnable);
        releasePlayer();
        releaseSurface();
    }

    public void onStop() {
        foregroundActive = false;
        stopIntervalAdvance();
        cancelWakePlaylistRetry();
        cancelPendingMultiStageWakeRecovery();
        mainHandler.removeCallbacks(backgroundReleaseRunnable);
        releasePlayer();
    }

    public void onDestroy() {
        mainHandler.removeCallbacks(backgroundReleaseRunnable);
        cancelWakePlaylistRetry();
        releasePlayer();
        releaseSurfaceAndTextureEntry();
    }

    public void onWallpaperModeChanged() {
        cancelWakePlaylistRetry();
        quarantinedVideoUris.clear();
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
        quarantinedVideoUris.clear();
        startupWarmupReady = true;
        onVideoPlaylistTopologyChanged();
        onVideoPlayerPolicyChanged();
        onVideoPresentationChanged();
    }

    public void onVideoPlaylistTopologyChanged() {
        cancelWakePlaylistRetry();
        startupWarmupReady = true;
        activePlaybackConfigSignature = "";
        if (player != null) {
            resolvedPlaylistUris = resolvePlaylistUris();
            if (resolvedPlaylistUris.isEmpty()) {
                boolean changed = setVideoReady(false)
                        | setLastError("No playable wallpaper videos were resolved.");
                releasePlayer();
                notifyStatusChangedIf(changed);
                return;
            }
            boolean changed = setCurrentIndex(0);
            applyMediaItems();
            applyPlayerPolicySettings();
            applyPresentationSettings();
            player.prepare();
            if (!playbackSuppressed &&
                    foregroundActive &&
                    BridgeStateStore.isWallpaperVideoAutoResumeEnabled(appContext) &&
                    !deferForegroundResume) {
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
                && !player.isPlaying()
                && !deferForegroundResume) {
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
        if (this.deferForegroundResume == deferForegroundResume) {
            return false;
        }
        this.deferForegroundResume = deferForegroundResume;
        return true;
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
            if (shouldResume && !deferForegroundResume) {
                maybeStartPlayback(false);
            }
            return;
        }
        if (shouldResume && !deferForegroundResume) {
            resumeExistingPlayerIfNeeded();
            scheduleIntervalAdvance();
        }
    }

    private void maybeStartPlayback(boolean explicitWarmup) {
        maybeStartPlayback(explicitWarmup, false);
    }

    private void maybeStartPlayback(boolean explicitWarmup, boolean retryEmptyPlaylist) {
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
        if (deferForegroundResume && !explicitWarmup) {
            return;
        }
        if (!TextUtils.equals("video", BridgeStateStore.getWallpaperMode(appContext))) {
            return;
        }
        String desiredConfigSignature = buildPlaybackTopologySignature();
        if (player != null &&
                surfaceTextureEntry != null &&
                surface != null &&
                TextUtils.equals(activePlaybackConfigSignature, desiredConfigSignature)) {
            cancelWakePlaylistRetry();
            applyPlayerPolicySettings();
            applyPresentationSettings();
            if (BridgeStateStore.isWallpaperVideoAutoResumeEnabled(appContext)
                    && !player.isPlaying()
                    && (explicitWarmup || !deferForegroundResume)) {
                resumeExistingPlayerIfNeeded();
            }
            scheduleIntervalAdvance();
            return;
        }

        resolvedPlaylistUris = resolvePlaylistUris();
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
        boolean resetStatusChanged = setVideoReady(false)
                | setLastError("")
                | setCurrentIndex(0);
        activePlaybackConfigSignature = desiredConfigSignature;
        videoWarmupStartedAtNanos = System.nanoTime();
        notifyStatusChangedIf(resetStatusChanged);

        DefaultRenderersFactory renderersFactory = new DefaultRenderersFactory(appContext)
                .setEnableDecoderFallback(true);
        trackSelector = new DefaultTrackSelector(appContext);
        player = new ExoPlayer.Builder(appContext, renderersFactory)
                .setTrackSelector(trackSelector)
                .build();
        player.setVideoSurface(surface);
        player.addListener(new Player.Listener() {
            @Override
            public void onPlaybackStateChanged(int playbackState) {
                if (playbackState == Player.STATE_READY) {
                    consecutivePlayerErrorCount = 0;
                    boolean statusChanged = setVideoReady(true);
                    cancelPendingMultiStageWakeRecovery();
                    logPerf("time_to_video_ready", videoWarmupStartedAtNanos);
                    videoWarmupStartedAtNanos = 0L;
                    scheduleIntervalAdvance();
                    notifyStatusChangedIf(statusChanged);
                } else if (playbackState == Player.STATE_ENDED) {
                    scheduleIntervalAdvance();
                }
            }

            @Override
            public void onRenderedFirstFrame() {
                consecutivePlayerErrorCount = 0;
                boolean statusChanged = setVideoReady(true);
                notifyStatusChangedIf(statusChanged);
            }

            @Override
            public void onPlayerError(PlaybackException error) {
                consecutivePlayerErrorCount++;
                String errorMsg = error.getMessage() == null ? error.toString() : error.getMessage();
                Log.w(TAG, "ExoPlayer onPlayerError (attempt " + consecutivePlayerErrorCount + "): " + errorMsg);

                boolean isTransient = isCodecContentionOrTransientError(errorMsg);

                int currentItemIndex = player != null ? player.getCurrentMediaItemIndex() : -1;
                if (!isTransient && currentItemIndex >= 0 && currentItemIndex < resolvedPlaylistUris.size()) {
                    String failedUri = resolvedPlaylistUris.get(currentItemIndex);
                    quarantinedVideoUris.add(failedUri);
                    Log.w(TAG, "Quarantined permanent faulty video wallpaper URI: " + failedUri);
                }

                boolean statusChanged = setVideoReady(false)
                        | setLastError(isTransient ? "" : errorMsg);
                notifyStatusChangedIf(statusChanged);
                releasePlayer();
                releaseSurface();

                int maxRetries = isTransient ? 5 : MAX_CONSECUTIVE_PLAYER_ERRORS;
                if (consecutivePlayerErrorCount < maxRetries) {
                    long delayMs = isTransient ? (350L * consecutivePlayerErrorCount) : (800L * consecutivePlayerErrorCount);
                    if (foregroundActive && !playbackSuppressed && shouldAutoResumeFromWake()) {
                        mainHandler.postDelayed(() -> {
                            if (foregroundActive && !playbackSuppressed && shouldAutoResumeFromWake()) {
                                logWakeInfo("wallpaper_auto_recover_after_error isTransient=" + isTransient + " attempt=" + consecutivePlayerErrorCount);
                                ensureSurface();
                                maybeStartPlayback(true, true);
                            }
                        }, delayMs);
                    }
                } else {
                    Log.e(TAG, "ExoPlayer onPlayerError: Max error recovery attempts reached (isTransient=" + isTransient + "). Pausing recovery loop.");
                }
            }

            @Override
            public void onVideoSizeChanged(VideoSize size) {
                notifyStatusChangedIf(setVideoSize(size.width, size.height));
            }

            @Override
            public void onMediaItemTransition(MediaItem mediaItem, int reason) {
                boolean statusChanged = false;
                if (player != null) {
                    statusChanged = setCurrentIndex(
                            Math.max(0, player.getCurrentMediaItemIndex())
                    );
                }
                scheduleIntervalAdvance();
                notifyStatusChangedIf(statusChanged);
            }
        });
        applyMediaItems();
        applyPlayerPolicySettings();
        applyPresentationSettings();
        player.prepare();
        if (BridgeStateStore.isWallpaperVideoAutoResumeEnabled(appContext)
                && (explicitWarmup || !deferForegroundResume)) {
            player.play();
        }
    }

    private void applyMediaItems() {
        if (player == null) {
            return;
        }
        List<MediaItem> mediaItems = new ArrayList<>();
        for (String uriStr : resolvedPlaylistUris) {
            if (!TextUtils.isEmpty(uriStr)) {
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
        player.setMediaItems(mediaItems, false);
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
        } else if (BridgeStateStore.WALLPAPER_ADVANCE_FIXED_INTERVAL.equals(advanceMode)) {
            player.setRepeatMode(Player.REPEAT_MODE_OFF);
        } else {
            player.setRepeatMode(
                    BridgeStateStore.isWallpaperVideoPlaylistLoopEnabled(appContext)
                            ? Player.REPEAT_MODE_ALL
                            : Player.REPEAT_MODE_OFF
            );
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
        List<String> rawUris = new ArrayList<>(VideoLibraryController.resolveConfiguredPlaylistUris(appContext));
        List<String> uris = new ArrayList<>();
        for (String uri : rawUris) {
            if (!quarantinedVideoUris.contains(uri)) {
                uris.add(uri);
            }
        }
        if (uris.isEmpty() && !rawUris.isEmpty() && quarantinedVideoUris.size() >= rawUris.size()) {
            Log.e(TAG, "All " + rawUris.size() + " video wallpaper URIs are quarantined due to decoder errors.");
            return Collections.emptyList();
        }
        String advanceMode = BridgeStateStore.getWallpaperVideoAdvanceMode(appContext);
        if (BridgeStateStore.WALLPAPER_ORDER_SHUFFLE.equals(
                BridgeStateStore.getWallpaperVideoOrderMode(appContext)
        )) {
            Collections.shuffle(uris);
        }
        int repeatCountPerItem = BridgeStateStore.getWallpaperVideoRepeatCountPerItem(appContext);
        if (repeatCountPerItem <= 1
                || uris.size() <= 1
                || BridgeStateStore.WALLPAPER_ADVANCE_FIXED_INTERVAL.equals(advanceMode)) {
            return uris;
        }
        List<String> expanded = new ArrayList<>(uris.size() * repeatCountPerItem);
        for (String uri : uris) {
            for (int i = 0; i < repeatCountPerItem; i++) {
                expanded.add(uri);
            }
        }
        return expanded;
    }

    private void scheduleIntervalAdvance() {
        stopIntervalAdvance();
        if (player == null || !foregroundActive || !videoReady || playbackSuppressed) {
            return;
        }
        if (!player.isPlaying() && !player.getPlayWhenReady()) {
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
        long delayMs = Math.max(5L, BridgeStateStore.getWallpaperVideoSwitchIntervalSeconds(appContext)) * 1000L;
        mainHandler.postDelayed(advanceRunnable, delayMs);
    }

    private boolean advancePlaylist() {
        if (player == null || player.getMediaItemCount() <= 1) {
            return false;
        }
        if (player.hasNextMediaItem()) {
            player.seekToNextMediaItem();
            player.play();
            return true;
        }
        if (BridgeStateStore.isWallpaperVideoPlaylistLoopEnabled(appContext)) {
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
        if (surfaceTextureEntry == null) {
            try {
                surfaceTextureEntry = textureRegistry.createSurfaceTexture();
            } catch (Exception e) {
                Log.w(TAG, "Failed to create SurfaceTexture: " + e.getMessage());
                return;
            }
        }
        if (surfaceTextureEntry == null) {
            return;
        }
        try {
            surfaceTextureEntry.surfaceTexture().setDefaultBufferSize(videoWidth, videoHeight);
        } catch (Exception e) {
            Log.w(TAG, "Failed to set default buffer size on SurfaceTexture: " + e.getMessage());
        }
        if (surface == null || !surface.isValid()) {
            if (surface != null) {
                try {
                    surface.release();
                } catch (Exception ignored) {
                }
            }
            try {
                surface = new Surface(surfaceTextureEntry.surfaceTexture());
            } catch (Exception e) {
                Log.w(TAG, "Surface creation failed: " + e.getMessage());
                return;
            }
        }
        if (player != null && surface != null && surface.isValid()) {
            try {
                player.setVideoSurface(surface);
            } catch (Exception ignored) {
            }
        }
    }

    private void stopIntervalAdvance() {
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
