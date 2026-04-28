package com.atv.launcher.systembridge.wallpaper;

import android.content.Context;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
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

    private final Runnable advanceRunnable = new Runnable() {
        @Override
        public void run() {
            if (player == null || !foregroundActive) {
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

    public VideoWallpaperController(Context context, TextureRegistry textureRegistry) {
        this.appContext = context.getApplicationContext();
        this.textureRegistry = textureRegistry;
    }

    public long ensureTextureId() {
        ensureSurface();
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
        return map;
    }

    public void onStart() {
        foregroundActive = true;
        maybeStartPlayback();
    }

    public void onStop() {
        foregroundActive = false;
        releasePlayer();
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
        if (player != null) {
            resolvedPlaylistUris = resolvePlaylistUris();
            applyMediaItems();
            applyPlayerSettings();
            scheduleIntervalAdvance();
            if (!player.isPlaying() && foregroundActive && BridgeStateStore.isWallpaperVideoAutoResumeEnabled(appContext)) {
                player.prepare();
                player.play();
            }
        } else {
            maybeStartPlayback();
        }
    }

    private void maybeStartPlayback() {
        if (!foregroundActive) {
            return;
        }
        if (!TextUtils.equals("video", BridgeStateStore.getWallpaperMode(appContext))) {
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

        player = new ExoPlayer.Builder(appContext).build();
        player.setVideoSurface(surface);
        player.addListener(new Player.Listener() {
            @Override
            public void onPlaybackStateChanged(int playbackState) {
                videoReady = playbackState == Player.STATE_READY;
                if (videoReady) {
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
        if (BridgeStateStore.WALLPAPER_ORDER_SHUFFLE.equals(
                BridgeStateStore.getWallpaperVideoOrderMode(appContext)
        )) {
            Collections.shuffle(uris);
        }
        return uris;
    }

    private void scheduleIntervalAdvance() {
        mainHandler.removeCallbacks(advanceRunnable);
        if (player == null || !foregroundActive || !videoReady) {
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
        mainHandler.removeCallbacks(advanceRunnable);
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
    }

    private void ensureSurface() {
        if (surfaceTextureEntry != null && surface != null) {
            return;
        }
        surfaceTextureEntry = textureRegistry.createSurfaceTexture();
        surfaceTextureEntry.surfaceTexture().setDefaultBufferSize(videoWidth, videoHeight);
        surface = new Surface(surfaceTextureEntry.surfaceTexture());
    }
}
