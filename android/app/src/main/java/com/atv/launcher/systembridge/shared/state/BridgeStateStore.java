package com.atv.launcher.systembridge.shared.state;

import android.content.Context;
import android.content.SharedPreferences;
import android.text.TextUtils;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

public final class BridgeStateStore {
    public static final int MODE_DOUBLE = 0;
    public static final int MODE_SINGLE = 1;
    public static final int MODE_LONG = 2;
    public static final int MODE_DOUBLE_HOLD = 3;
    public static final int DEFAULT_KEY_CODE = 0;

    public static final String ADB_POLICY_OFF = "off";
    public static final String ADB_POLICY_ADB_ONLY = "adb_only";
    public static final String ADB_POLICY_ADB_AND_WIFI = "adb_and_wifi";

    public static final String WALLPAPER_SOURCE_SINGLE_FILE = "single_file";
    public static final String WALLPAPER_SOURCE_MULTI_FILE = "multi_file_playlist";
    public static final String WALLPAPER_SOURCE_FOLDER = "folder_playlist";

    public static final String WALLPAPER_ORDER_SEQUENTIAL = "sequential";
    public static final String WALLPAPER_ORDER_SHUFFLE = "shuffle";

    public static final String WALLPAPER_ADVANCE_ON_COMPLETION = "on_completion";
    public static final String WALLPAPER_ADVANCE_FIXED_INTERVAL = "fixed_interval";

    private static final int[] DEFAULT_VOICE_KEY_CODES = new int[]{0, 84, 219, 229, 231};

    private static final String KEY_MODE = "mode";
    private static final String KEY_KEY_CODE = "key_code";
    private static final String KEY_LEARNING = "learning_mode";
    private static final String KEY_INTERCEPT = "voice_intercept_enabled";
    private static final String KEY_LAST_REASON = "last_recovery_reason";
    private static final String KEY_LAST_SUCCESS = "last_success_at";
    private static final String KEY_ENABLED_SERVICES = "enabled_services_snapshot";
    private static final String KEY_LAST_ACCESSIBILITY_REPAIR_RESULT = "last_accessibility_repair_result";
    private static final String KEY_LAST_MISSING_SERVICE_IDS = "last_missing_service_ids";
    private static final String KEY_LAST_WSS_GRANTED = "last_wss_grant_state";
    private static final String KEY_LAST_RESTORE_EPOCH = "last_restore_epoch";
    private static final String KEY_LAST_PROVISIONING_VERIFY_AT = "last_provisioning_verify_at";
    private static final String KEY_ADB_AUTOMATION_POLICY = "adb_automation_policy";
    private static final String KEY_ADB_DISABLE_ON_SLEEP = "adb_disable_on_sleep";
    private static final String KEY_LAST_ADB_POLICY_APPLIED_AT = "last_adb_policy_applied_at";
    private static final String KEY_LAST_ADB_POLICY_REASON = "last_adb_policy_reason";
    private static final String KEY_LAST_ADB_POLICY_STATE = "last_adb_policy_state";
    private static final String KEY_LAST_HOME_GUARD_ATTEMPT_AT = "last_home_guard_attempt_at";
    private static final String KEY_LAST_HOME_GUARD_REASON = "last_home_guard_reason";
    private static final String KEY_LAST_HOME_GUARD_RESULT = "last_home_guard_result";
    private static final String KEY_LAST_HOME_GUARD_THROTTLED = "last_home_guard_throttled";
    private static final String KEY_WALLPAPER_MODE = "wallpaper_mode";
    private static final String KEY_WALLPAPER_ASSET_URI = "wallpaper_asset_uri";
    private static final String KEY_WALLPAPER_PREVIEW_PATH = "wallpaper_preview_path";
    private static final String KEY_WALLPAPER_VIDEO_SOURCE_TYPE = "wallpaper_video_source_type";
    private static final String KEY_WALLPAPER_VIDEO_URIS = "wallpaper_video_uris";
    private static final String KEY_WALLPAPER_VIDEO_FOLDER_URI = "wallpaper_video_folder_uri";
    private static final String KEY_WALLPAPER_VIDEO_FOLDER_BUCKET_ID = "wallpaper_video_folder_bucket_id";
    private static final String KEY_WALLPAPER_VIDEO_FOLDER_NAME = "wallpaper_video_folder_name";
    private static final String KEY_WALLPAPER_VIDEO_ORDER = "wallpaper_video_order";
    private static final String KEY_WALLPAPER_VIDEO_ADVANCE_MODE = "wallpaper_video_advance_mode";
    private static final String KEY_WALLPAPER_VIDEO_INTERVAL_SECONDS = "wallpaper_video_interval_seconds";
    private static final String KEY_WALLPAPER_VIDEO_REPEAT_COUNT_PER_ITEM = "wallpaper_video_repeat_count_per_item";
    private static final String KEY_WALLPAPER_VIDEO_PLAYLIST_LOOP = "wallpaper_video_playlist_loop";
    private static final String KEY_WALLPAPER_VIDEO_LOOP = "wallpaper_video_loop";
    private static final String KEY_WALLPAPER_VIDEO_MUTE = "wallpaper_video_mute";
    private static final String KEY_WALLPAPER_VIDEO_FIT = "wallpaper_video_fit";
    private static final String KEY_WALLPAPER_VIDEO_DIM = "wallpaper_video_dim";
    private static final String KEY_WALLPAPER_VIDEO_BLUR = "wallpaper_video_blur";
    private static final String KEY_WALLPAPER_VIDEO_AUTO_RESUME = "wallpaper_video_auto_resume";
    private static final String KEY_LAST_BACKUP_EXPORT_NAME = "last_backup_export_name";
    private static final String KEY_LAST_BACKUP_IMPORT_NAME = "last_backup_import_name";
    private static final String KEY_LAST_BACKUP_RESTORE_SUMMARY = "last_backup_restore_summary";
    private static final String KEY_LAST_BACKUP_RESTORE_AT = "last_backup_restore_at";
    private static final String KEY_TOAST_PREFIX = "toast_";
    private static final String KEY_EVENT_PREFIX = "event_";
    private static final String LIST_SEPARATOR = "\n";

    private BridgeStateStore() {
    }

    private static Context storageContext(Context context) {
        Context appContext = context.getApplicationContext();
        Context deviceProtected = appContext.createDeviceProtectedStorageContext();
        return deviceProtected != null ? deviceProtected : appContext;
    }

    private static SharedPreferences prefs(Context context) {
        Context storage = storageContext(context);
        return storage.getSharedPreferences(
                context.getPackageName() + ".state",
                Context.MODE_PRIVATE | Context.MODE_MULTI_PROCESS
        );
    }

    public static int getMode(Context context) {
        return prefs(context).getInt(KEY_MODE, MODE_DOUBLE);
    }

    public static void setMode(Context context, int mode) {
        prefs(context).edit().putInt(KEY_MODE, mode).commit();
    }

    public static int getKeyCode(Context context) {
        return prefs(context).getInt(KEY_KEY_CODE, DEFAULT_KEY_CODE);
    }

    public static void setKeyCode(Context context, int keyCode) {
        prefs(context).edit().putInt(KEY_KEY_CODE, keyCode).commit();
    }

    public static boolean isLearningMode(Context context) {
        return prefs(context).getBoolean(KEY_LEARNING, false);
    }

    public static void setLearningMode(Context context, boolean enabled) {
        prefs(context).edit().putBoolean(KEY_LEARNING, enabled).commit();
    }

    public static boolean isVoiceInterceptEnabled(Context context) {
        return prefs(context).getBoolean(KEY_INTERCEPT, true);
    }

    public static void setVoiceInterceptEnabled(Context context, boolean enabled) {
        prefs(context).edit().putBoolean(KEY_INTERCEPT, enabled).commit();
    }

    public static void resetDefaultMapping(Context context) {
        prefs(context)
                .edit()
                .putInt(KEY_MODE, MODE_DOUBLE)
                .putInt(KEY_KEY_CODE, DEFAULT_KEY_CODE)
                .putBoolean(KEY_LEARNING, false)
                .putBoolean(KEY_INTERCEPT, true)
                .commit();
    }

    public static boolean isDefaultVoiceKeyCode(int keyCode) {
        for (int candidate : DEFAULT_VOICE_KEY_CODES) {
            if (candidate == keyCode) {
                return true;
            }
        }
        return false;
    }

    public static String defaultVoiceKeySummary() {
        StringBuilder builder = new StringBuilder();
        for (int i = 0; i < DEFAULT_VOICE_KEY_CODES.length; i++) {
            if (i > 0) {
                builder.append(',');
            }
            builder.append(DEFAULT_VOICE_KEY_CODES[i]);
        }
        return builder.toString();
    }

    public static Set<String> getEnabledServiceSnapshot(Context context) {
        Set<String> stored = prefs(context).getStringSet(KEY_ENABLED_SERVICES, Collections.emptySet());
        return new LinkedHashSet<>(stored);
    }

    public static void setEnabledServiceSnapshot(Context context, Set<String> values) {
        prefs(context).edit().putStringSet(KEY_ENABLED_SERVICES, new LinkedHashSet<>(values)).apply();
    }

    public static String getLastAccessibilityRepairResult(Context context) {
        return prefs(context).getString(KEY_LAST_ACCESSIBILITY_REPAIR_RESULT, "-");
    }

    public static void setLastAccessibilityRepairResult(Context context, String result) {
        prefs(context).edit().putString(KEY_LAST_ACCESSIBILITY_REPAIR_RESULT, result).apply();
    }

    public static Set<String> getLastMissingServiceIds(Context context) {
        Set<String> stored = prefs(context).getStringSet(KEY_LAST_MISSING_SERVICE_IDS, Collections.emptySet());
        return new LinkedHashSet<>(stored);
    }

    public static void setLastMissingServiceIds(Context context, Set<String> values) {
        prefs(context).edit().putStringSet(KEY_LAST_MISSING_SERVICE_IDS, new LinkedHashSet<>(values)).apply();
    }

    public static boolean getLastWriteSecureSettingsGranted(Context context) {
        return prefs(context).getBoolean(KEY_LAST_WSS_GRANTED, false);
    }

    public static void setLastWriteSecureSettingsGranted(Context context, boolean granted) {
        prefs(context).edit().putBoolean(KEY_LAST_WSS_GRANTED, granted).apply();
    }

    public static long getLastAccessibilityRestoreAt(Context context) {
        return prefs(context).getLong(KEY_LAST_RESTORE_EPOCH, 0L);
    }

    public static void setLastAccessibilityRestoreAt(Context context, long epochMillis) {
        prefs(context).edit().putLong(KEY_LAST_RESTORE_EPOCH, epochMillis).apply();
    }

    public static long getLastProvisioningVerifyAt(Context context) {
        return prefs(context).getLong(KEY_LAST_PROVISIONING_VERIFY_AT, 0L);
    }

    public static void setLastProvisioningVerifyAt(Context context, long epochMillis) {
        prefs(context).edit().putLong(KEY_LAST_PROVISIONING_VERIFY_AT, epochMillis).apply();
    }

    public static String getLastRecoveryReason(Context context) {
        return prefs(context).getString(KEY_LAST_REASON, "-");
    }

    public static void setLastRecoveryReason(Context context, String reason) {
        prefs(context).edit().putString(KEY_LAST_REASON, reason).apply();
    }

    public static long getLastSuccessAt(Context context) {
        return prefs(context).getLong(KEY_LAST_SUCCESS, 0L);
    }

    public static void setLastSuccessAt(Context context, long epochMillis) {
        prefs(context).edit().putLong(KEY_LAST_SUCCESS, epochMillis).apply();
    }

    public static String getAdbAutomationPolicy(Context context) {
        return prefs(context).getString(KEY_ADB_AUTOMATION_POLICY, ADB_POLICY_OFF);
    }

    public static void setAdbAutomationPolicy(Context context, String policy) {
        String normalized = ADB_POLICY_ADB_ONLY.equals(policy) || ADB_POLICY_ADB_AND_WIFI.equals(policy)
                ? policy
                : ADB_POLICY_OFF;
        prefs(context).edit().putString(KEY_ADB_AUTOMATION_POLICY, normalized).apply();
    }

    public static boolean isAdbDisableOnSleepEnabled(Context context) {
        return prefs(context).getBoolean(KEY_ADB_DISABLE_ON_SLEEP, true);
    }

    public static void setAdbDisableOnSleepEnabled(Context context, boolean enabled) {
        prefs(context).edit().putBoolean(KEY_ADB_DISABLE_ON_SLEEP, enabled).apply();
    }

    public static long getLastAdbPolicyAppliedAt(Context context) {
        return prefs(context).getLong(KEY_LAST_ADB_POLICY_APPLIED_AT, 0L);
    }

    public static void setLastAdbPolicyAppliedAt(Context context, long epochMillis) {
        prefs(context).edit().putLong(KEY_LAST_ADB_POLICY_APPLIED_AT, epochMillis).apply();
    }

    public static String getLastAdbPolicyReason(Context context) {
        return prefs(context).getString(KEY_LAST_ADB_POLICY_REASON, "-");
    }

    public static void setLastAdbPolicyReason(Context context, String reason) {
        prefs(context).edit().putString(KEY_LAST_ADB_POLICY_REASON, reason).apply();
    }

    public static String getLastAdbPolicyState(Context context) {
        return prefs(context).getString(KEY_LAST_ADB_POLICY_STATE, "-");
    }

    public static void setLastAdbPolicyState(Context context, String state) {
        prefs(context).edit().putString(KEY_LAST_ADB_POLICY_STATE, state == null ? "-" : state).apply();
    }

    public static long getLastHomeGuardAttemptAt(Context context) {
        return prefs(context).getLong(KEY_LAST_HOME_GUARD_ATTEMPT_AT, 0L);
    }

    public static void setLastHomeGuardAttemptAt(Context context, long epochMillis) {
        prefs(context).edit().putLong(KEY_LAST_HOME_GUARD_ATTEMPT_AT, epochMillis).apply();
    }

    public static String getLastHomeGuardReason(Context context) {
        return prefs(context).getString(KEY_LAST_HOME_GUARD_REASON, "-");
    }

    public static void setLastHomeGuardReason(Context context, String reason) {
        prefs(context).edit().putString(KEY_LAST_HOME_GUARD_REASON, reason == null ? "-" : reason).apply();
    }

    public static String getLastHomeGuardResult(Context context) {
        return prefs(context).getString(KEY_LAST_HOME_GUARD_RESULT, "-");
    }

    public static void setLastHomeGuardResult(Context context, String result) {
        prefs(context).edit().putString(KEY_LAST_HOME_GUARD_RESULT, result == null ? "-" : result).apply();
    }

    public static boolean isHomeGuardThrottled(Context context) {
        return prefs(context).getBoolean(KEY_LAST_HOME_GUARD_THROTTLED, false);
    }

    public static void setHomeGuardThrottled(Context context, boolean throttled) {
        prefs(context).edit().putBoolean(KEY_LAST_HOME_GUARD_THROTTLED, throttled).apply();
    }

    public static long getToastTimestamp(Context context, String toastKey) {
        return prefs(context).getLong(KEY_TOAST_PREFIX + toastKey, 0L);
    }

    public static void setToastTimestamp(Context context, String toastKey, long epochMillis) {
        prefs(context).edit().putLong(KEY_TOAST_PREFIX + toastKey, epochMillis).apply();
    }

    public static long getEventTimestamp(Context context, String eventKey) {
        return prefs(context).getLong(KEY_EVENT_PREFIX + eventKey, 0L);
    }

    public static void setEventTimestamp(Context context, String eventKey, long epochMillis) {
        prefs(context).edit().putLong(KEY_EVENT_PREFIX + eventKey, epochMillis).apply();
    }

    public static String getWallpaperMode(Context context) {
        return prefs(context).getString(KEY_WALLPAPER_MODE, "gradient");
    }

    public static void setWallpaperMode(Context context, String mode) {
        prefs(context).edit().putString(KEY_WALLPAPER_MODE, mode).apply();
    }

    public static String getWallpaperAssetUri(Context context) {
        return prefs(context).getString(KEY_WALLPAPER_ASSET_URI, "");
    }

    public static void setWallpaperAssetUri(Context context, String uri) {
        prefs(context).edit().putString(KEY_WALLPAPER_ASSET_URI, uri == null ? "" : uri).apply();
    }

    public static String getWallpaperPreviewPath(Context context) {
        return prefs(context).getString(KEY_WALLPAPER_PREVIEW_PATH, "");
    }

    public static void setWallpaperPreviewPath(Context context, String path) {
        prefs(context).edit().putString(KEY_WALLPAPER_PREVIEW_PATH, path == null ? "" : path).apply();
    }

    public static String getWallpaperVideoSourceType(Context context) {
        return prefs(context).getString(KEY_WALLPAPER_VIDEO_SOURCE_TYPE, WALLPAPER_SOURCE_SINGLE_FILE);
    }

    public static void setWallpaperVideoSourceType(Context context, String sourceType) {
        String normalized = WALLPAPER_SOURCE_MULTI_FILE.equals(sourceType) || WALLPAPER_SOURCE_FOLDER.equals(sourceType)
                ? sourceType
                : WALLPAPER_SOURCE_SINGLE_FILE;
        prefs(context).edit().putString(KEY_WALLPAPER_VIDEO_SOURCE_TYPE, normalized).apply();
    }

    public static List<String> getWallpaperVideoAssetUris(Context context) {
        return deserializeList(prefs(context).getString(KEY_WALLPAPER_VIDEO_URIS, ""));
    }

    public static void setWallpaperVideoAssetUris(Context context, List<String> values) {
        List<String> sanitized = sanitizeList(values);
        SharedPreferences.Editor editor = prefs(context).edit()
                .putString(KEY_WALLPAPER_VIDEO_URIS, serializeList(sanitized));
        editor.putString(KEY_WALLPAPER_ASSET_URI, sanitized.isEmpty() ? "" : sanitized.get(0));
        editor.apply();
    }

    public static String getWallpaperVideoFolderUri(Context context) {
        return prefs(context).getString(KEY_WALLPAPER_VIDEO_FOLDER_URI, "");
    }

    public static void setWallpaperVideoFolderUri(Context context, String uri) {
        prefs(context).edit().putString(KEY_WALLPAPER_VIDEO_FOLDER_URI, uri == null ? "" : uri).apply();
    }

    public static String getWallpaperVideoFolderBucketId(Context context) {
        return prefs(context).getString(KEY_WALLPAPER_VIDEO_FOLDER_BUCKET_ID, "");
    }

    public static void setWallpaperVideoFolderBucketId(Context context, String bucketId) {
        prefs(context).edit().putString(KEY_WALLPAPER_VIDEO_FOLDER_BUCKET_ID, bucketId == null ? "" : bucketId).apply();
    }

    public static String getWallpaperVideoFolderName(Context context) {
        return prefs(context).getString(KEY_WALLPAPER_VIDEO_FOLDER_NAME, "");
    }

    public static void setWallpaperVideoFolderName(Context context, String folderName) {
        prefs(context).edit().putString(KEY_WALLPAPER_VIDEO_FOLDER_NAME, folderName == null ? "" : folderName).apply();
    }

    public static String getWallpaperVideoOrderMode(Context context) {
        return prefs(context).getString(KEY_WALLPAPER_VIDEO_ORDER, WALLPAPER_ORDER_SEQUENTIAL);
    }

    public static void setWallpaperVideoOrderMode(Context context, String mode) {
        String normalized = WALLPAPER_ORDER_SHUFFLE.equals(mode) ? WALLPAPER_ORDER_SHUFFLE : WALLPAPER_ORDER_SEQUENTIAL;
        prefs(context).edit().putString(KEY_WALLPAPER_VIDEO_ORDER, normalized).apply();
    }

    public static String getWallpaperVideoAdvanceMode(Context context) {
        return prefs(context).getString(KEY_WALLPAPER_VIDEO_ADVANCE_MODE, WALLPAPER_ADVANCE_ON_COMPLETION);
    }

    public static void setWallpaperVideoAdvanceMode(Context context, String mode) {
        String normalized = WALLPAPER_ADVANCE_FIXED_INTERVAL.equals(mode)
                ? WALLPAPER_ADVANCE_FIXED_INTERVAL
                : WALLPAPER_ADVANCE_ON_COMPLETION;
        prefs(context).edit().putString(KEY_WALLPAPER_VIDEO_ADVANCE_MODE, normalized).apply();
    }

    public static int getWallpaperVideoSwitchIntervalSeconds(Context context) {
        return prefs(context).getInt(KEY_WALLPAPER_VIDEO_INTERVAL_SECONDS, 30);
    }

    public static void setWallpaperVideoSwitchIntervalSeconds(Context context, int seconds) {
        int normalized = Math.max(5, Math.min(24 * 60 * 60, seconds));
        prefs(context).edit().putInt(KEY_WALLPAPER_VIDEO_INTERVAL_SECONDS, normalized).apply();
    }

    public static int getWallpaperVideoRepeatCountPerItem(Context context) {
        return prefs(context).getInt(KEY_WALLPAPER_VIDEO_REPEAT_COUNT_PER_ITEM, 1);
    }

    public static void setWallpaperVideoRepeatCountPerItem(Context context, int count) {
        int normalized = Math.max(1, Math.min(20, count));
        prefs(context).edit().putInt(KEY_WALLPAPER_VIDEO_REPEAT_COUNT_PER_ITEM, normalized).apply();
    }

    public static boolean isWallpaperVideoPlaylistLoopEnabled(Context context) {
        return prefs(context).getBoolean(KEY_WALLPAPER_VIDEO_PLAYLIST_LOOP, true);
    }

    public static void setWallpaperVideoPlaylistLoopEnabled(Context context, boolean enabled) {
        prefs(context).edit().putBoolean(KEY_WALLPAPER_VIDEO_PLAYLIST_LOOP, enabled).apply();
    }

    public static boolean isWallpaperVideoLoopEnabled(Context context) {
        return prefs(context).getBoolean(KEY_WALLPAPER_VIDEO_LOOP, true);
    }

    public static void setWallpaperVideoLoopEnabled(Context context, boolean enabled) {
        prefs(context).edit().putBoolean(KEY_WALLPAPER_VIDEO_LOOP, enabled).apply();
    }

    public static boolean isWallpaperVideoMuted(Context context) {
        return prefs(context).getBoolean(KEY_WALLPAPER_VIDEO_MUTE, true);
    }

    public static void setWallpaperVideoMuted(Context context, boolean muted) {
        prefs(context).edit().putBoolean(KEY_WALLPAPER_VIDEO_MUTE, muted).apply();
    }

    public static String getWallpaperVideoFit(Context context) {
        return prefs(context).getString(KEY_WALLPAPER_VIDEO_FIT, "center-crop");
    }

    public static void setWallpaperVideoFit(Context context, String fit) {
        prefs(context).edit().putString(KEY_WALLPAPER_VIDEO_FIT, fit == null ? "center-crop" : fit).apply();
    }

    public static int getWallpaperVideoDimPercent(Context context) {
        return prefs(context).getInt(KEY_WALLPAPER_VIDEO_DIM, 15);
    }

    public static void setWallpaperVideoDimPercent(Context context, int percent) {
        prefs(context).edit().putInt(KEY_WALLPAPER_VIDEO_DIM, percent).apply();
    }

    public static String getWallpaperVideoBlur(Context context) {
        return prefs(context).getString(KEY_WALLPAPER_VIDEO_BLUR, "off");
    }

    public static void setWallpaperVideoBlur(Context context, String blur) {
        prefs(context).edit().putString(KEY_WALLPAPER_VIDEO_BLUR, blur == null ? "off" : blur).apply();
    }

    public static boolean isWallpaperVideoAutoResumeEnabled(Context context) {
        return prefs(context).getBoolean(KEY_WALLPAPER_VIDEO_AUTO_RESUME, true);
    }

    public static void setWallpaperVideoAutoResumeEnabled(Context context, boolean enabled) {
        prefs(context).edit().putBoolean(KEY_WALLPAPER_VIDEO_AUTO_RESUME, enabled).apply();
    }

    public static String getLastBackupExportName(Context context) {
        return prefs(context).getString(KEY_LAST_BACKUP_EXPORT_NAME, "");
    }

    public static void setLastBackupExportName(Context context, String value) {
        prefs(context).edit().putString(KEY_LAST_BACKUP_EXPORT_NAME, value == null ? "" : value).apply();
    }

    public static String getLastBackupImportName(Context context) {
        return prefs(context).getString(KEY_LAST_BACKUP_IMPORT_NAME, "");
    }

    public static void setLastBackupImportName(Context context, String value) {
        prefs(context).edit().putString(KEY_LAST_BACKUP_IMPORT_NAME, value == null ? "" : value).apply();
    }

    public static String getLastBackupRestoreSummary(Context context) {
        return prefs(context).getString(KEY_LAST_BACKUP_RESTORE_SUMMARY, "");
    }

    public static void setLastBackupRestoreSummary(Context context, String value) {
        prefs(context).edit().putString(KEY_LAST_BACKUP_RESTORE_SUMMARY, value == null ? "" : value).apply();
    }

    public static long getLastBackupRestoreAt(Context context) {
        return prefs(context).getLong(KEY_LAST_BACKUP_RESTORE_AT, 0L);
    }

    public static void setLastBackupRestoreAt(Context context, long epochMillis) {
        prefs(context).edit().putLong(KEY_LAST_BACKUP_RESTORE_AT, epochMillis).apply();
    }

    private static List<String> sanitizeList(List<String> values) {
        List<String> sanitized = new ArrayList<>();
        if (values == null) {
            return sanitized;
        }
        for (String value : values) {
            if (!TextUtils.isEmpty(value)) {
                sanitized.add(value.trim());
            }
        }
        return sanitized;
    }

    private static List<String> deserializeList(String raw) {
        List<String> values = new ArrayList<>();
        if (TextUtils.isEmpty(raw)) {
            return values;
        }
        String[] parts = raw.split(LIST_SEPARATOR);
        for (String part : parts) {
            if (!TextUtils.isEmpty(part)) {
                values.add(part.trim());
            }
        }
        return values;
    }

    private static String serializeList(List<String> values) {
        return TextUtils.join(LIST_SEPARATOR, sanitizeList(values));
    }
}
