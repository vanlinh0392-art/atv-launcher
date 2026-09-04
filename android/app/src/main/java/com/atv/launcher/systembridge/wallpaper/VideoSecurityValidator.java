package com.atv.launcher.systembridge.wallpaper;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Environment;
import android.text.TextUtils;
import android.util.Log;

import androidx.core.content.ContextCompat;

import java.io.File;
import java.io.IOException;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

public final class VideoSecurityValidator {
    private static final String TAG = "VideoSecurityValidator";

    private static final Set<String> ALLOWED_EXTENSIONS = Collections.unmodifiableSet(new HashSet<>(Arrays.asList(
            ".mp4", ".mkv", ".webm", ".avi", ".ts", ".m2ts", ".m4v", ".3gp", ".mov"
    )));

    private VideoSecurityValidator() {
    }

    public static boolean isUriSafeForPlayback(Context context, String uriStr) {
        if (context == null || TextUtils.isEmpty(uriStr)) {
            return false;
        }

        // 1. SAF / MediaStore content URIs
        if (uriStr.startsWith("content://")) {
            if (uriStr.startsWith("content://media")
                    || uriStr.startsWith("content://com.android.externalstorage.documents")) {
                return true;
            }
            try {
                Uri parsedUri = Uri.parse(uriStr);
                String auth = parsedUri.getAuthority();
                if ("media".equals(auth) || "com.android.externalstorage.documents".equals(auth)) {
                    return true;
                }
                if (context.checkCallingOrSelfUriPermission(parsedUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        == PackageManager.PERMISSION_GRANTED) {
                    return true;
                }
            } catch (Exception e) {
                Log.w(TAG, "Error checking uri permission for: " + uriStr, e);
            }
            return false;
        }

        // 2. File path or file:// URI
        String filePath;
        if (uriStr.startsWith("file://")) {
            try {
                Uri parsed = Uri.parse(uriStr);
                filePath = parsed.getPath();
                if (filePath == null) {
                    filePath = uriStr.substring("file://".length());
                }
            } catch (Exception e) {
                filePath = uriStr.substring("file://".length());
            }
        } else if (uriStr.startsWith("/")) {
            filePath = uriStr;
        } else {
            return false;
        }

        // Extension check
        if (!hasAllowedVideoExtension(filePath)) {
            Log.w(TAG, "Rejected file with invalid video extension: " + filePath);
            return false;
        }

        // Canonical path normalization
        String canonicalPath;
        try {
            canonicalPath = new File(filePath).getCanonicalFile().getCanonicalPath();
        } catch (IOException e) {
            Log.w(TAG, "Failed to resolve canonical path for: " + filePath, e);
            return false;
        }

        if (!hasAllowedVideoExtension(canonicalPath)) {
            Log.w(TAG, "Rejected canonical path with invalid video extension: " + canonicalPath);
            return false;
        }

        // Blacklist checks: /proc, /sys, /dev, /system
        if (isSystemBlacklisted(canonicalPath)) {
            Log.w(TAG, "Security violation: system path access attempted: " + canonicalPath);
            return false;
        }

        // Blacklist check: /data/user/0/<pkg> (or /data/data/<pkg>), except internal wallpaper_assets
        String pkg = context.getPackageName();
        String user0Pkg = "/data/user/0/" + pkg;
        String dataPkg = "/data/data/" + pkg;

        String canonicalWallpaperAssetsDir = "";
        try {
            File wallpaperAssetsDir = new File(context.getFilesDir(), "wallpaper_assets");
            canonicalWallpaperAssetsDir = wallpaperAssetsDir.getCanonicalFile().getCanonicalPath();
        } catch (Exception ignored) {
        }

        boolean isInsideWallpaperAssets = !TextUtils.isEmpty(canonicalWallpaperAssetsDir)
                && (canonicalPath.equals(canonicalWallpaperAssetsDir)
                || canonicalPath.startsWith(canonicalWallpaperAssetsDir + File.separator));

        if (canonicalPath.startsWith(user0Pkg) || canonicalPath.startsWith(dataPkg)) {
            if (!isInsideWallpaperAssets) {
                Log.w(TAG, "Security violation: private app storage accessed outside wallpaper_assets: " + canonicalPath);
                return false;
            }
            return true;
        }

        // If it is inside internal wallpaper_assets, allow it
        if (isInsideWallpaperAssets) {
            return true;
        }

        // Whitelist checks: /storage/emulated/0 and USB mount points from ContextCompat.getExternalFilesDirs()
        if (canonicalPath.equals("/storage/emulated/0")
                || canonicalPath.startsWith("/storage/emulated/0/")) {
            return true;
        }

        try {
            File extStorage = Environment.getExternalStorageDirectory();
            if (extStorage != null) {
                String extPath = extStorage.getCanonicalFile().getCanonicalPath();
                if (canonicalPath.equals(extPath) || canonicalPath.startsWith(extPath + File.separator)) {
                    return true;
                }
            }
        } catch (Exception ignored) {
        }

        // Check USB mount points from ContextCompat.getExternalFilesDirs()
        File[] externalDirs = null;
        try {
            externalDirs = ContextCompat.getExternalFilesDirs(context, null);
        } catch (Throwable t) {
            try {
                externalDirs = context.getExternalFilesDirs(null);
            } catch (Exception ignored) {
            }
        }

        if (externalDirs != null) {
            for (File extDir : externalDirs) {
                if (extDir == null) {
                    continue;
                }
                try {
                    String extCanonical = extDir.getCanonicalFile().getCanonicalPath();
                    int androidDataIdx = extCanonical.indexOf("/Android/data/");
                    if (androidDataIdx > 0) {
                        String mountPoint = extCanonical.substring(0, androidDataIdx);
                        if (canonicalPath.equals(mountPoint) || canonicalPath.startsWith(mountPoint + File.separator)) {
                            return true;
                        }
                    } else {
                        if (canonicalPath.equals(extCanonical) || canonicalPath.startsWith(extCanonical + File.separator)) {
                            return true;
                        }
                    }
                } catch (Exception ignored) {
                }
            }
        }

        Log.w(TAG, "Security validation failed: path not in whitelist: " + canonicalPath);
        return false;
    }

    private static boolean hasAllowedVideoExtension(String path) {
        if (TextUtils.isEmpty(path)) {
            return false;
        }
        String lower = path.toLowerCase(Locale.US);
        for (String ext : ALLOWED_EXTENSIONS) {
            if (lower.endsWith(ext)) {
                return true;
            }
        }
        return false;
    }

    private static boolean isSystemBlacklisted(String canonicalPath) {
        return canonicalPath.equals("/proc") || canonicalPath.startsWith("/proc/")
                || canonicalPath.equals("/sys") || canonicalPath.startsWith("/sys/")
                || canonicalPath.equals("/dev") || canonicalPath.startsWith("/dev/")
                || canonicalPath.equals("/system") || canonicalPath.startsWith("/system/");
    }
}
