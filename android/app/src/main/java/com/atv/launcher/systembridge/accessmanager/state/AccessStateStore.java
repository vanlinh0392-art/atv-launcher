package com.atv.launcher.systembridge.accessmanager.state;

import android.content.Context;
import android.content.SharedPreferences;

import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.Set;

public final class AccessStateStore {
    private static final String KEY_MANAGED_PACKAGES = "managed_packages";
    private static final String KEY_MANAGED_SERVICE_IDS = "managed_service_ids";
    private static final String KEY_LAST_GOOD_SNAPSHOT = "last_good_snapshot";
    private static final String KEY_LAST_VERIFY_RESULT = "last_verify_result";
    private static final String KEY_LAST_REPAIR_REASON = "last_repair_reason";
    private static final String KEY_LAST_SUCCESS_AT = "last_success_at";
    private static final String KEY_EVENT_PREFIX = "event_";

    private AccessStateStore() {
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

    public static Set<String> getManagedPackageNames(Context context) {
        Set<String> stored = prefs(context).getStringSet(KEY_MANAGED_PACKAGES, Collections.emptySet());
        return new LinkedHashSet<>(stored);
    }

    public static void setManagedPackageNames(Context context, Set<String> values) {
        prefs(context).edit().putStringSet(KEY_MANAGED_PACKAGES, new LinkedHashSet<>(values)).apply();
    }

    public static Set<String> getManagedServiceIds(Context context) {
        Set<String> stored = prefs(context).getStringSet(KEY_MANAGED_SERVICE_IDS, Collections.emptySet());
        return new LinkedHashSet<>(stored);
    }

    public static void setManagedServiceIds(Context context, Set<String> values) {
        prefs(context).edit().putStringSet(KEY_MANAGED_SERVICE_IDS, new LinkedHashSet<>(values)).apply();
    }

    public static Set<String> getLastGoodSnapshot(Context context) {
        Set<String> stored = prefs(context).getStringSet(KEY_LAST_GOOD_SNAPSHOT, Collections.emptySet());
        return new LinkedHashSet<>(stored);
    }

    public static void setLastGoodSnapshot(Context context, Set<String> values) {
        prefs(context).edit().putStringSet(KEY_LAST_GOOD_SNAPSHOT, new LinkedHashSet<>(values)).apply();
    }

    public static String getLastVerifyResult(Context context) {
        return prefs(context).getString(KEY_LAST_VERIFY_RESULT, "-");
    }

    public static void setLastVerifyResult(Context context, String value) {
        prefs(context).edit().putString(KEY_LAST_VERIFY_RESULT, value).apply();
    }

    public static String getLastRepairReason(Context context) {
        return prefs(context).getString(KEY_LAST_REPAIR_REASON, "-");
    }

    public static void setLastRepairReason(Context context, String value) {
        prefs(context).edit().putString(KEY_LAST_REPAIR_REASON, value).apply();
    }

    public static long getLastSuccessAt(Context context) {
        return prefs(context).getLong(KEY_LAST_SUCCESS_AT, 0L);
    }

    public static void setLastSuccessAt(Context context, long value) {
        prefs(context).edit().putLong(KEY_LAST_SUCCESS_AT, value).apply();
    }

    public static long getEventTimestamp(Context context, String key) {
        return prefs(context).getLong(KEY_EVENT_PREFIX + key, 0L);
    }

    public static void setEventTimestamp(Context context, String key, long timestamp) {
        prefs(context).edit().putLong(KEY_EVENT_PREFIX + key, timestamp).apply();
    }
}


