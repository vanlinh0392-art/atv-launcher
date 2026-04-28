package com.atv.launcher.systembridge.wallpaper;

import android.Manifest;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.provider.DocumentsContract;
import android.provider.MediaStore;
import android.text.TextUtils;

import com.atv.launcher.systembridge.shared.state.BridgeStateStore;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

public final class VideoLibraryController {
    private VideoLibraryController() {
    }

    public static Map<String, Object> getFileAccessStatus(Context context) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("hasMediaPermission", hasMediaPermission(context));
        map.put("readPermissionName", mediaPermissionName());
        map.put("openDocumentAvailable", isIntentAvailable(context, new Intent(Intent.ACTION_OPEN_DOCUMENT).setType("video/*")));
        map.put("openDocumentTreeAvailable", isIntentAvailable(context, new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)));
        map.put("mediaStoreVideoCount", countMediaStoreVideos(context));
        map.put("folderCount", -1);
        return map;
    }

    public static Map<String, Object> browseLocalVideoLibrary(Context context, String bucketId) {
        Map<String, Object> map = getFileAccessStatus(context);
        if (!hasMediaPermission(context)) {
            map.put("folders", new ArrayList<>());
            map.put("videos", new ArrayList<>());
            map.put("message", "Media permission is missing.");
            return map;
        }

        List<VideoEntry> videos = queryMediaStoreVideos(context, TextUtils.isEmpty(bucketId) ? null : bucketId);
        map.put("videos", toVideoMaps(videos));
        map.put("folders", summarizeFolders(queryMediaStoreVideos(context, null)));
        map.put("selectedBucketId", TextUtils.isEmpty(bucketId) ? "" : bucketId);
        if (!TextUtils.isEmpty(bucketId)) {
            map.put("selectedFolderName", inferFolderName(videos, bucketId));
        }
        return map;
    }

    public static List<String> resolveConfiguredPlaylistUris(Context context) {
        String sourceType = BridgeStateStore.getWallpaperVideoSourceType(context);
        List<String> configuredUris = new ArrayList<>(BridgeStateStore.getWallpaperVideoAssetUris(context));
        if (BridgeStateStore.WALLPAPER_SOURCE_FOLDER.equals(sourceType)) {
            String bucketId = BridgeStateStore.getWallpaperVideoFolderBucketId(context);
            if (!TextUtils.isEmpty(bucketId) && hasMediaPermission(context)) {
                List<VideoEntry> entries = queryMediaStoreVideos(context, bucketId);
                return toUriList(entries);
            }
            String folderUri = BridgeStateStore.getWallpaperVideoFolderUri(context);
            if (!TextUtils.isEmpty(folderUri)) {
                List<VideoEntry> entries = queryTreeVideos(context, folderUri);
                return toUriList(entries);
            }
        }

        if (configuredUris.isEmpty()) {
            String fallbackUri = BridgeStateStore.getWallpaperAssetUri(context);
            if (!TextUtils.isEmpty(fallbackUri)) {
                configuredUris.add(fallbackUri);
            }
        }
        return configuredUris;
    }

    public static Map<String, Object> browseTreeFolder(Context context, String folderUri) {
        Map<String, Object> map = new LinkedHashMap<>();
        List<VideoEntry> entries = queryTreeVideos(context, folderUri);
        map.put("folderUri", folderUri == null ? "" : folderUri);
        map.put("folderName", queryTreeDisplayName(context, folderUri));
        map.put("videos", toVideoMaps(entries));
        map.put("uris", toUriList(entries));
        map.put("primaryUri", entries.isEmpty() ? "" : entries.get(0).uri);
        return map;
    }

    private static List<Map<String, Object>> summarizeFolders(List<VideoEntry> videos) {
        LinkedHashMap<String, FolderSummary> folders = new LinkedHashMap<>();
        for (VideoEntry video : videos) {
            String bucketId = TextUtils.isEmpty(video.bucketId) ? "unknown" : video.bucketId;
            FolderSummary summary = folders.get(bucketId);
            if (summary == null) {
                summary = new FolderSummary(bucketId, video.bucketName, video.uri, 0, video.dateModifiedEpochSeconds);
                folders.put(bucketId, summary);
            }
            summary.count += 1;
            if (video.dateModifiedEpochSeconds > summary.latestModifiedEpochSeconds) {
                summary.latestModifiedEpochSeconds = video.dateModifiedEpochSeconds;
                summary.previewUri = video.uri;
            }
            if (TextUtils.isEmpty(summary.name) && !TextUtils.isEmpty(video.bucketName)) {
                summary.name = video.bucketName;
            }
        }

        List<Map<String, Object>> maps = new ArrayList<>();
        for (FolderSummary summary : folders.values()) {
            Map<String, Object> folderMap = new LinkedHashMap<>();
            folderMap.put("bucketId", summary.bucketId);
            folderMap.put("name", TextUtils.isEmpty(summary.name) ? "Folder" : summary.name);
            folderMap.put("count", summary.count);
            folderMap.put("previewUri", summary.previewUri == null ? "" : summary.previewUri);
            folderMap.put("latestModifiedEpochSeconds", summary.latestModifiedEpochSeconds);
            maps.add(folderMap);
        }
        maps.sort((left, right) -> Long.compare(
                ((Number) right.get("latestModifiedEpochSeconds")).longValue(),
                ((Number) left.get("latestModifiedEpochSeconds")).longValue()
        ));
        return maps;
    }

    private static String inferFolderName(List<VideoEntry> videos, String bucketId) {
        for (VideoEntry video : videos) {
            if (TextUtils.equals(bucketId, video.bucketId) && !TextUtils.isEmpty(video.bucketName)) {
                return video.bucketName;
            }
        }
        return "";
    }

    private static List<Map<String, Object>> toVideoMaps(List<VideoEntry> videos) {
        List<Map<String, Object>> maps = new ArrayList<>();
        for (VideoEntry video : videos) {
            Map<String, Object> videoMap = new LinkedHashMap<>();
            videoMap.put("uri", video.uri);
            videoMap.put("displayName", video.displayName);
            videoMap.put("durationMs", video.durationMs);
            videoMap.put("bucketId", video.bucketId);
            videoMap.put("bucketName", video.bucketName);
            videoMap.put("dateModifiedEpochSeconds", video.dateModifiedEpochSeconds);
            maps.add(videoMap);
        }
        return maps;
    }

    private static List<String> toUriList(List<VideoEntry> entries) {
        List<String> uris = new ArrayList<>();
        for (VideoEntry entry : entries) {
            if (!TextUtils.isEmpty(entry.uri)) {
                uris.add(entry.uri);
            }
        }
        return uris;
    }

    private static List<VideoEntry> queryMediaStoreVideos(Context context, String bucketId) {
        if (!hasMediaPermission(context)) {
            return Collections.emptyList();
        }
        ContentResolver resolver = context.getContentResolver();
        Uri collection = MediaStore.Video.Media.EXTERNAL_CONTENT_URI;
        String[] projection = new String[]{
                MediaStore.Video.Media._ID,
                MediaStore.Video.Media.DISPLAY_NAME,
                MediaStore.Video.Media.DURATION,
                MediaStore.Video.Media.BUCKET_ID,
                MediaStore.Video.Media.BUCKET_DISPLAY_NAME,
                MediaStore.Video.Media.DATE_MODIFIED
        };
        String selection = TextUtils.isEmpty(bucketId) ? null : MediaStore.Video.Media.BUCKET_ID + " = ?";
        String[] selectionArgs = TextUtils.isEmpty(bucketId) ? null : new String[]{bucketId};
        String order = MediaStore.Video.Media.DATE_MODIFIED + " DESC";

        List<VideoEntry> videos = new ArrayList<>();
        try (Cursor cursor = resolver.query(collection, projection, selection, selectionArgs, order)) {
            if (cursor == null) {
                return videos;
            }
            int idIndex = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID);
            int nameIndex = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME);
            int durationIndex = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION);
            int bucketIdIndex = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.BUCKET_ID);
            int bucketNameIndex = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.BUCKET_DISPLAY_NAME);
            int modifiedIndex = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_MODIFIED);
            while (cursor.moveToNext()) {
                long id = cursor.getLong(idIndex);
                String uri = Uri.withAppendedPath(collection, Long.toString(id)).toString();
                videos.add(new VideoEntry(
                        uri,
                        cursor.getString(nameIndex),
                        cursor.getLong(durationIndex),
                        cursor.getString(bucketIdIndex),
                        cursor.getString(bucketNameIndex),
                        cursor.getLong(modifiedIndex)
                ));
            }
        } catch (Exception ignored) {
        }
        return videos;
    }

    private static int countMediaStoreVideos(Context context) {
        if (!hasMediaPermission(context)) {
            return 0;
        }
        try (Cursor cursor = context.getContentResolver().query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                new String[]{MediaStore.Video.Media._ID},
                null,
                null,
                null
        )) {
            return cursor == null ? 0 : cursor.getCount();
        } catch (Exception ignored) {
            return 0;
        }
    }

    private static List<VideoEntry> queryTreeVideos(Context context, String treeUriString) {
        if (TextUtils.isEmpty(treeUriString)) {
            return Collections.emptyList();
        }
        List<VideoEntry> videos = new ArrayList<>();
        try {
            Uri treeUri = Uri.parse(treeUriString);
            Uri childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
                    treeUri,
                    DocumentsContract.getTreeDocumentId(treeUri)
            );
            String[] projection = new String[]{
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                    DocumentsContract.Document.COLUMN_LAST_MODIFIED
            };
            try (Cursor cursor = context.getContentResolver().query(childrenUri, projection, null, null, null)) {
                if (cursor == null) {
                    return videos;
                }
                int idIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID);
                int nameIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME);
                int mimeIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE);
                int modifiedIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_LAST_MODIFIED);
                while (cursor.moveToNext()) {
                    String mimeType = cursor.getString(mimeIndex);
                    String displayName = cursor.getString(nameIndex);
                    if (!isVideoMimeType(mimeType, displayName)) {
                        continue;
                    }
                    String documentId = cursor.getString(idIndex);
                    Uri documentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, documentId);
                    videos.add(new VideoEntry(
                            documentUri.toString(),
                            displayName,
                            0L,
                            "",
                            queryTreeDisplayName(context, treeUriString),
                            cursor.getLong(modifiedIndex) / 1000L
                    ));
                }
            }
        } catch (Exception ignored) {
        }
        videos.sort(Comparator.comparingLong((VideoEntry entry) -> entry.dateModifiedEpochSeconds).reversed());
        return videos;
    }

    private static String queryTreeDisplayName(Context context, String treeUriString) {
        if (TextUtils.isEmpty(treeUriString)) {
            return "";
        }
        try {
            Uri treeUri = Uri.parse(treeUriString);
            Uri documentUri = DocumentsContract.buildDocumentUriUsingTree(
                    treeUri,
                    DocumentsContract.getTreeDocumentId(treeUri)
            );
            String[] projection = new String[]{DocumentsContract.Document.COLUMN_DISPLAY_NAME};
            try (Cursor cursor = context.getContentResolver().query(documentUri, projection, null, null, null)) {
                if (cursor != null && cursor.moveToFirst()) {
                    int nameIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME);
                    if (nameIndex >= 0) {
                        return cursor.getString(nameIndex);
                    }
                }
            }
        } catch (Exception ignored) {
        }
        return "";
    }

    private static boolean hasMediaPermission(Context context) {
        return context.checkCallingOrSelfPermission(mediaPermissionName()) == PackageManager.PERMISSION_GRANTED;
    }

    private static String mediaPermissionName() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                ? Manifest.permission.READ_MEDIA_VIDEO
                : Manifest.permission.READ_EXTERNAL_STORAGE;
    }

    private static boolean isVideoMimeType(String mimeType, String displayName) {
        if (!TextUtils.isEmpty(mimeType) && mimeType.toLowerCase(Locale.US).startsWith("video/")) {
            return true;
        }
        if (TextUtils.isEmpty(displayName)) {
            return false;
        }
        String lower = displayName.toLowerCase(Locale.US);
        return lower.endsWith(".mp4")
                || lower.endsWith(".mkv")
                || lower.endsWith(".webm")
                || lower.endsWith(".avi")
                || lower.endsWith(".ts")
                || lower.endsWith(".mov");
    }

    private static boolean isIntentAvailable(Context context, Intent intent) {
        return !context.getPackageManager().queryIntentActivities(intent, 0).isEmpty();
    }

    private static final class FolderSummary {
        final String bucketId;
        String name;
        String previewUri;
        int count;
        long latestModifiedEpochSeconds;

        FolderSummary(String bucketId, String name, String previewUri, int count, long latestModifiedEpochSeconds) {
            this.bucketId = bucketId;
            this.name = name;
            this.previewUri = previewUri;
            this.count = count;
            this.latestModifiedEpochSeconds = latestModifiedEpochSeconds;
        }
    }

    private static final class VideoEntry {
        final String uri;
        final String displayName;
        final long durationMs;
        final String bucketId;
        final String bucketName;
        final long dateModifiedEpochSeconds;

        VideoEntry(
                String uri,
                String displayName,
                long durationMs,
                String bucketId,
                String bucketName,
                long dateModifiedEpochSeconds
        ) {
            this.uri = uri == null ? "" : uri;
            this.displayName = displayName == null ? "" : displayName;
            this.durationMs = durationMs;
            this.bucketId = bucketId == null ? "" : bucketId;
            this.bucketName = bucketName == null ? "" : bucketName;
            this.dateModifiedEpochSeconds = dateModifiedEpochSeconds;
        }
    }
}
