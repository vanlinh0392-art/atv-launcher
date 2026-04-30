package com.atv.launcher.systembridge.wallpaper;

import android.content.Context;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.util.Log;
import android.view.Surface;

import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.common.VideoSize;
import androidx.media3.exoplayer.ExoPlayer;

import com.atv.launcher.systembridge.shared.state.BridgeStateStore;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import io.flutter.view.TextureRegistry;

public final class VideoWallpaperController {
    private static final String TAG = "FLauncherPerf";
    private static final boolean FAST_STARTUP_ENABLED = true;
    private static final long BACKGROUND_PLAYER_RELEASE_DELAY_MS = 60000L;

    private final Context appContext;
    private final TextureRegistry textureRegistry;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private TextureRegistry.SurfaceTextureEntry surfaceTextureEntry;
    private Surface surface;
    private ExoPlayer player;
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
    private boolean startupWarmupReady = !FAST_STARTUP_ENABLED;
    private long videoWarmupStartedAtNanos = 0L;
    private String activePlaybackConfigSignature = "";

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

    public VideoWallpaperController(Context context, TextureRegistry textureRegistry) {
        this.appContext = context.getApplicationContext();
        this.textureRegistry = textureRegistry;
    }

    public long ensureTextureId() {
        startupWarmupReady = true;
        ensureSurface();
        maybeStartPlayback();
        return surfaceTextureEntry.id();
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
        return map;
    }

    public void onStart() {
        mainHandler.removeCallbacks(backgroundReleaseRunnable);
        foregroundActive = true;
        if (!startupWarmupReady) {
            return;
        }
        maybeStartPlayback();
    }

    public void onStop() {
        foregroundActive = false;
        stopIntervalAdvance();
        if (player != null) {
            try {
                player.pause();
            } catch (Exception ignored) {
            }
        }
        mainHandler.removeCallbacks(backgroundReleaseRunnable);
        mainHandler.postDelayed(backgroundReleaseRunnable, BACKGROUND_PLAYER_RELEASE_DELAY_MS);
    }

    public void onDestroy() {
        mainHandler.removeCallbacks(backgroundReleaseRunnable);
        releasePlayer();
        releaseSurface();
    }

    public void onWallpaperModeChanged() {
        if (!TextUtils.equals("video", BridgeStateStore.getWallpaperMode(appContext))) {
            videoReady = false;
            lastError = "";
            releasePlayer();
            return;
        }
        maybeStartPlayback();
    }

    public void onVideoConfigChanged() {
        startupWarmupReady = true;
        activePlaybackConfigSignature = "";
        if (player != null) {
            resolvedPlaylistUris = resolvePlaylistUris();
            applyMediaItems();
            applyPlayerSettings();
            player.prepare();
            scheduleIntervalAdvance();
            if (!playbackSuppressed &&
                    !player.isPlaying() &&
                    foregroundActive &&
                    BridgeStateStore.isWallpaperVideoAutoResumeEnabled(appContext)) {
                player.play();
            }
        } else {
            maybeStartPlayback();
        }
    }

    public void setPlaybackSuppressed(boolean suppressed, String reason) {
        if (playbackSuppressed == suppressed && TextUtils.equals(playbackSuppressedReason, reason)) {
            return;
        }
        if (suppressed) {
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
                maybeStartPlayback();
            }
            return;
        }
        if (shouldResume) {
            resumeExistingPlayerIfNeeded();
        }
        scheduleIntervalAdvance();
    }

    private void maybeStartPlayback() {
        if (!foregroundActive) {
            return;
        }
        if (playbackSuppressed) {
            return;
        }
        if (!startupWarmupReady) {
            return;
        }
        if (!TextUtils.equals("video", BridgeStateStore.getWallpaperMode(appContext))) {
            return;
        }
        String desiredConfigSignature = buildConfigSignature();
        if (player != null &&
                surfaceTextureEntry != null &&
                surface != null &&
                TextUtils.equals(activePlaybackConfigSignature, desiredConfigSignature)) {
            applyPlayerSettings();
            if (BridgeStateStore.isWallpaperVideoAutoResumeEnabled(appContext) && !player.isPlaying()) {
                resumeExistingPlayerIfNeeded();
            }
            scheduleIntervalAdvance();
            return;
        }

        resolvedPlaylistUris = resolvePlaylistUris();
        if (resolvedPlaylistUris.isEmpty()) {
            videoReady = false;
            lastError = "No playable wallpaper videos were resolved.";
            return;
        }

        ensureSurface();
        releasePlayer();
        videoReady = false;
        lastError = "";
        currentIndex = 0;
        activePlaybackConfigSignature = desiredConfigSignature;
        videoWarmupStartedAtNanos = System.nanoTime();

        player = new ExoPlayer.Builder(appContext).build();
        player.setVideoSurface(surface);
        player.addListener(new Player.Listener() {
            @Override
            public void onPlaybackStateChanged(int playbackState) {
                videoReady = playbackState == Player.STATE_READY;
                if (videoReady) {
                    logPerf("time_to_video_ready", videoWarmupStartedAtNanos);
                    videoWarmupStartedAtNanos = 0L;
                    scheduleIntervalAdvance();
                }
            }

            @Override
            public void onPlayerError(PlaybackException error) {
                videoReady = false;
                lastError = error.getMessage() == null ? error.toString() : error.getMessage();
                if (!advancePlaylist()) {
                    releasePlayer();
                }
            }

            @Override
            public void onVideoSizeChanged(VideoSize size) {
                if (size.width > 0) {
                    videoWidth = size.width;
                }
                if (size.height > 0) {
                    videoHeight = size.height;
                }
            }

            @Override
            public void onMediaItemTransition(MediaItem mediaItem, int reason) {
                if (player != null) {
                    currentIndex = Math.max(0, player.getCurrentMediaItemIndex());
                }
                scheduleIntervalAdvance();
            }
        });
        applyMediaItems();
        applyPlayerSettings();
        player.prepare();
        if (BridgeStateStore.isWallpaperVideoAutoResumeEnabled(appContext)) {
            player.play();
        }
    }

    private void applyMediaItems() {
        if (player == null) {
            return;
        }
        List<MediaItem> mediaItems = new ArrayList<>();
        for (String uri : resolvedPlaylistUris) {
            if (!TextUtils.isEmpty(uri)) {
                mediaItems.add(MediaItem.fromUri(Uri.parse(uri)));
            }
        }
        player.setMediaItems(mediaItems, false);
    }

    private void applyPlayerSettings() {
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
        player.setVolume(BridgeStateStore.isWallpaperVideoMuted(appContext) ? 0f : 1f);
    }

    private List<String> resolvePlaylistUris() {
        List<String> uris = new ArrayList<>(VideoLibraryController.resolveConfiguredPlaylistUris(appContext));
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
            player.prepare();
            player.play();
            return true;
        }
        if (BridgeStateStore.isWallpaperVideoPlaylistLoopEnabled(appContext)) {
            player.seekToDefaultPosition(0);
            player.prepare();
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
        if (surfaceTextureEntry != null) {
            try {
                surfaceTextureEntry.release();
            } catch (Exception ignored) {
            }
            surfaceTextureEntry = null;
        }
    }

    private void ensureSurface() {
        if (surfaceTextureEntry != null && surface != null) {
            return;
        }
        surfaceTextureEntry = textureRegistry.createSurfaceTexture();
        surfaceTextureEntry.surfaceTexture().setDefaultBufferSize(videoWidth, videoHeight);
        surface = new Surface(surfaceTextureEntry.surfaceTexture());
    }

    private void stopIntervalAdvance() {
        mainHandler.removeCallbacks(advanceRunnable);
    }

    private void resumeExistingPlayerIfNeeded() {
        if (player == null) {
            return;
        }
        int playbackState = player.getPlaybackState();
        if (playbackState == Player.STATE_IDLE) {
            player.prepare();
        } else if (playbackState == Player.STATE_ENDED && player.getMediaItemCount() > 0) {
            int currentMediaItemIndex = Math.max(0, player.getCurrentMediaItemIndex());
            player.seekToDefaultPosition(currentMediaItemIndex);
        }
        if (!player.isPlaying() || !player.getPlayWhenReady()) {
            player.play();
        }
    }

    private boolean shouldResumeWhenUnsuppressed() {
        return foregroundActive
                && startupWarmupReady
                && TextUtils.equals("video", BridgeStateStore.getWallpaperMode(appContext))
                && BridgeStateStore.isWallpaperVideoAutoResumeEnabled(appContext);
    }

    private String buildConfigSignature() {
        StringBuilder builder = new StringBuilder();
        builder.append(BridgeStateStore.getWallpaperMode(appContext)).append('|');
        builder.append(BridgeStateStore.getWallpaperVideoSourceType(appContext)).append('|');
        builder.append(BridgeStateStore.getWallpaperVideoOrderMode(appContext)).append('|');
        builder.append(BridgeStateStore.getWallpaperVideoAdvanceMode(appContext)).append('|');
        builder.append(BridgeStateStore.getWallpaperVideoSwitchIntervalSeconds(appContext)).append('|');
        builder.append(BridgeStateStore.getWallpaperVideoRepeatCountPerItem(appContext)).append('|');
        builder.append(BridgeStateStore.isWallpaperVideoPlaylistLoopEnabled(appContext)).append('|');
        builder.append(BridgeStateStore.isWallpaperVideoLoopEnabled(appContext)).append('|');
        builder.append(BridgeStateStore.isWallpaperVideoMuted(appContext)).append('|');
        builder.append(BridgeStateStore.getWallpaperVideoFit(appContext)).append('|');
        builder.append(BridgeStateStore.getWallpaperVideoDimPercent(appContext)).append('|');
        builder.append(BridgeStateStore.getWallpaperVideoBlur(appContext)).append('|');
        builder.append(BridgeStateStore.isWallpaperVideoAutoResumeEnabled(appContext)).append('|');
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
        if ((appContext.getApplicationInfo().flags & android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) == 0) {
            return;
        }
        long elapsedMs = (System.nanoTime() - startedAtNanos) / 1_000_000L;
        Log.d(TAG, label + " elapsedMs=" + elapsedMs);
    }
}
