package com.atv.launcher.systembridge.dns;

import android.Manifest;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.provider.Settings;
import android.text.TextUtils;

import com.atv.launcher.systembridge.accessmanager.adb.LocalAdbBridge;

import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

public final class PrivateDnsController {
    public static final String MODE_OFF = "off";
    public static final String MODE_OPPORTUNISTIC = "opportunistic";
    public static final String MODE_HOSTNAME = "hostname";
    public static final String DEFAULT_DNS_HOST = "dns.adguard.com";

    private static final String PREFS_NAME = "private_dns_bridge";
    private static final String KEY_SELECTED_DNS_HOST = "selected_dns_host";
    private static final String KEY_HAS_RESTORE_SNAPSHOT = "has_restore_snapshot";
    private static final String KEY_RESTORE_MODE = "restore_mode";
    private static final String KEY_RESTORE_SPECIFIER = "restore_specifier";
    private static final String KEY_RESTORE_DEFAULT_MODE = "restore_default_mode";
    private static final String KEY_PRIVATE_DNS_MODE = "private_dns_mode";
    private static final String KEY_PRIVATE_DNS_SPECIFIER = "private_dns_specifier";
    private static final String KEY_PRIVATE_DNS_DEFAULT_MODE = "private_dns_default_mode";

    private PrivateDnsController() {
    }

    public static Map<String, Object> getStatus(Context context) {
        Snapshot snapshot = readSnapshot(context);
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("mode", snapshot.mode);
        map.put("specifier", snapshot.specifier);
        map.put("defaultMode", snapshot.defaultMode);
        map.put("effectiveMode", snapshot.effectiveMode());
        map.put("selectedHost", readSelectedDnsHost(context));
        map.put("hasWriteSecureSettings", hasWriteSecureSettings(context));
        map.put("adbEnabled", isAdbEnabled(context));
        map.put("hasRestoreSnapshot", prefs(context).getBoolean(KEY_HAS_RESTORE_SNAPSHOT, false));
        return map;
    }

    public static Map<String, Object> apply(Context context, String mode, String host) {
        String normalizedMode = normalizeMode(mode);
        String normalizedHost = normalizeHost(host);
        Snapshot before = readSnapshot(context);
        if (!prefs(context).getBoolean(KEY_HAS_RESTORE_SNAPSHOT, false)) {
            saveRestoreSnapshot(context, before);
        }
        saveSelectedDnsHost(context, normalizedHost);

        WriteResult writeResult = writeSnapshot(
                context,
                normalizedMode,
                MODE_HOSTNAME.equals(normalizedMode) ? normalizedHost : null
        );
        if (!writeResult.success) {
            return failure(context, writeResult.message);
        }

        Snapshot after = readSnapshot(context);
        boolean verified = MODE_HOSTNAME.equals(normalizedMode)
                ? MODE_HOSTNAME.equals(after.effectiveMode()) && normalizedHost.equalsIgnoreCase(nullToEmpty(after.specifier))
                : normalizedMode.equals(after.effectiveMode()) && TextUtils.isEmpty(after.specifier);
        if (!verified) {
            return failure(context, "Private DNS verification failed after apply.");
        }

        Map<String, Object> result = getStatus(context);
        result.put("success", true);
        result.put("message", MODE_HOSTNAME.equals(normalizedMode)
                ? String.format(Locale.US, "Private DNS set to %s.", normalizedHost)
                : "Private DNS updated.");
        result.put("executionPath", writeResult.path);
        return result;
    }

    public static Map<String, Object> reset(Context context) {
        Snapshot restore = readRestoreSnapshot(context);
        WriteResult writeResult;
        if (restore != null) {
            writeResult = writeSnapshot(context, normalizeMode(restore.mode), restore.specifier);
        } else {
            writeResult = writeSnapshot(context, MODE_OPPORTUNISTIC, null);
        }
        if (!writeResult.success) {
            return failure(context, writeResult.message);
        }
        clearRestoreSnapshot(context);
        Map<String, Object> result = getStatus(context);
        result.put("success", true);
        result.put("message", restore != null
                ? "Private DNS restored to the previous state."
                : "Private DNS reset to opportunistic mode.");
        result.put("executionPath", writeResult.path);
        return result;
    }

    private static Map<String, Object> failure(Context context, String message) {
        Map<String, Object> result = getStatus(context);
        result.put("success", false);
        result.put("message", message);
        return result;
    }

    private static WriteResult writeSnapshot(Context context, String mode, String specifier) {
        if (hasWriteSecureSettings(context)) {
            boolean success = writeGlobals(context, mode, specifier);
            return success
                    ? WriteResult.success("secure_settings")
                    : WriteResult.failure("Could not write Private DNS settings.");
        }

        if (!isAdbEnabled(context)) {
            return WriteResult.failure("WRITE_SECURE_SETTINGS missing and local ADB is not enabled.");
        }

        StringBuilder command = new StringBuilder();
        if (MODE_HOSTNAME.equals(mode)) {
            command.append("settings put global ").append(KEY_PRIVATE_DNS_SPECIFIER)
                    .append(" ").append(specifier).append(" && ");
            command.append("settings put global ").append(KEY_PRIVATE_DNS_MODE)
                    .append(" ").append(MODE_HOSTNAME);
        } else {
            command.append("settings put global ").append(KEY_PRIVATE_DNS_MODE)
                    .append(" ").append(mode).append(" && ");
            command.append("settings delete global ").append(KEY_PRIVATE_DNS_SPECIFIER);
        }

        LocalAdbBridge.Result adbResult = LocalAdbBridge.executeShell(context, command.toString());
        if (!adbResult.success) {
            return WriteResult.failure(TextUtils.isEmpty(adbResult.detail)
                    ? "Local ADB could not write Private DNS settings."
                    : adbResult.detail);
        }
        return WriteResult.success("local_adb");
    }

    private static boolean writeGlobals(Context context, String mode, String specifier) {
        if (MODE_HOSTNAME.equals(mode)) {
            return Settings.Global.putString(context.getContentResolver(), KEY_PRIVATE_DNS_SPECIFIER, specifier)
                    && Settings.Global.putString(context.getContentResolver(), KEY_PRIVATE_DNS_MODE, mode);
        }
        return Settings.Global.putString(context.getContentResolver(), KEY_PRIVATE_DNS_MODE, mode)
                && Settings.Global.putString(context.getContentResolver(), KEY_PRIVATE_DNS_SPECIFIER, specifier);
    }

    private static Snapshot readSnapshot(Context context) {
        return new Snapshot(
                Settings.Global.getString(context.getContentResolver(), KEY_PRIVATE_DNS_MODE),
                Settings.Global.getString(context.getContentResolver(), KEY_PRIVATE_DNS_SPECIFIER),
                Settings.Global.getString(context.getContentResolver(), KEY_PRIVATE_DNS_DEFAULT_MODE)
        );
    }

    private static SharedPreferences prefs(Context context) {
        return context.getApplicationContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    private static void saveSelectedDnsHost(Context context, String host) {
        prefs(context).edit().putString(KEY_SELECTED_DNS_HOST, host).apply();
    }

    private static String readSelectedDnsHost(Context context) {
        String stored = prefs(context).getString(KEY_SELECTED_DNS_HOST, DEFAULT_DNS_HOST);
        return normalizeHost(stored);
    }

    private static void saveRestoreSnapshot(Context context, Snapshot snapshot) {
        prefs(context).edit()
                .putBoolean(KEY_HAS_RESTORE_SNAPSHOT, true)
                .putString(KEY_RESTORE_MODE, snapshot.mode)
                .putString(KEY_RESTORE_SPECIFIER, snapshot.specifier)
                .putString(KEY_RESTORE_DEFAULT_MODE, snapshot.defaultMode)
                .apply();
    }

    private static Snapshot readRestoreSnapshot(Context context) {
        if (!prefs(context).getBoolean(KEY_HAS_RESTORE_SNAPSHOT, false)) {
            return null;
        }
        return new Snapshot(
                prefs(context).getString(KEY_RESTORE_MODE, null),
                prefs(context).getString(KEY_RESTORE_SPECIFIER, null),
                prefs(context).getString(KEY_RESTORE_DEFAULT_MODE, null)
        );
    }

    private static void clearRestoreSnapshot(Context context) {
        prefs(context).edit()
                .remove(KEY_HAS_RESTORE_SNAPSHOT)
                .remove(KEY_RESTORE_MODE)
                .remove(KEY_RESTORE_SPECIFIER)
                .remove(KEY_RESTORE_DEFAULT_MODE)
                .apply();
    }

    private static boolean hasWriteSecureSettings(Context context) {
        return context.checkCallingOrSelfPermission(Manifest.permission.WRITE_SECURE_SETTINGS)
                == PackageManager.PERMISSION_GRANTED;
    }

    private static boolean isAdbEnabled(Context context) {
        try {
            return Settings.Global.getInt(context.getContentResolver(), Settings.Global.ADB_ENABLED, 0) == 1;
        } catch (Exception ignored) {
            return false;
        }
    }

    private static String normalizeMode(String mode) {
        if (MODE_OFF.equals(mode) || MODE_HOSTNAME.equals(mode)) {
            return mode;
        }
        return MODE_OPPORTUNISTIC;
    }

    private static String normalizeHost(String host) {
        if (TextUtils.isEmpty(host)) {
            return DEFAULT_DNS_HOST;
        }
        return host.trim();
    }

    private static String nullToEmpty(String value) {
        return value == null ? "" : value;
    }

    private static final class Snapshot {
        final String mode;
        final String specifier;
        final String defaultMode;

        Snapshot(String mode, String specifier, String defaultMode) {
            this.mode = mode;
            this.specifier = specifier;
            this.defaultMode = defaultMode;
        }

        String effectiveMode() {
            return TextUtils.isEmpty(mode) ? (TextUtils.isEmpty(defaultMode) ? MODE_OPPORTUNISTIC : defaultMode) : mode;
        }
    }

    private static final class WriteResult {
        final boolean success;
        final String path;
        final String message;

        private WriteResult(boolean success, String path, String message) {
            this.success = success;
            this.path = path;
            this.message = message;
        }

        static WriteResult success(String path) {
            return new WriteResult(true, path, "");
        }

        static WriteResult failure(String message) {
            return new WriteResult(false, "", message);
        }
    }
}
