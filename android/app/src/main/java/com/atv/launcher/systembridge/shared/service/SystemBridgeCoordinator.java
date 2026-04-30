package com.atv.launcher.systembridge.shared.service;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.app.AlarmManager;
import android.app.PendingIntent;
import android.app.admin.DevicePolicyManager;
import android.app.job.JobScheduler;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.content.pm.ServiceInfo;
import android.os.PowerManager;
import android.provider.Settings;
import android.text.TextUtils;
import android.util.Log;
import android.view.accessibility.AccessibilityManager;

import com.atv.launcher.R;
import com.atv.launcher.systembridge.accessmanager.adb.LocalAdbBridge;
import com.atv.launcher.systembridge.shared.access.VoiceBridgeAccessibilityService;
import com.atv.launcher.systembridge.shared.admin.MapVoiceAdminReceiver;
import com.atv.launcher.systembridge.shared.boot.HealAlarmReceiver;
import com.atv.launcher.systembridge.shared.state.BridgeStateStore;
import com.atv.launcher.systembridge.shared.ui.BridgeToast;

import java.text.DateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

public final class SystemBridgeCoordinator {
    private static final String TAG = "SystemBridgeCore";
    public static final String EXTRA_REASON = "com.atv.launcher.extra.REASON";

    private static final String ACCESS_MANAGER_PACKAGE = "com.atv.launcher";
    private static final String ACCESS_MANAGER_KICK_ACTION = "com.atv.launcher.action.KICK_GUARDIAN";
    private static final String ACCESS_MANAGER_KICK_RECEIVER = "com.atv.launcher.systembridge.accessmanager.boot.RecoveryKickReceiver";
    private static final String ACCESS_MANAGER_REASON_EXTRA = "com.atv.launcher.systembridge.accessmanager.extra.REASON";
    private static final int JOB_ID = 0x5142;
    private static final int ALARM_REQUEST_RECURRING = 10;
    private static final int ALARM_REQUEST_WAKE_FAST = 11;
    private static final int ALARM_REQUEST_WAKE_MEDIUM = 12;
    private static final int ALARM_REQUEST_WAKE_SLOW = 13;
    private static final long ALARM_INTERVAL_MS = 9L * 60L * 1000L;
    private static final long WAKE_FAST_DELAY_MS = 1500L;
    private static final long WAKE_MEDIUM_DELAY_MS = 15000L;
    private static final long WAKE_SLOW_DELAY_MS = 45000L;
    private static final long RUNTIME_TRIGGER_THROTTLE_MS = 4000L;
    private static final long WAKE_BACKSTOP_THROTTLE_MS = 15000L;
    private static final long ACCESS_MANAGER_KICK_THROTTLE_MS = 15000L;
    private static final long LIFECYCLE_TOAST_THROTTLE_MS = 120000L;
    private static final long ADB_POLICY_THROTTLE_MS = 5000L;
    private static final long HOME_GUARD_THROTTLE_MS = 7000L;
    private static final String ADB_WIFI_KEY = "adb_wifi_enabled";
    private static final String REPAIR_OK = "ok";
    private static final String REPAIR_RESTORED = "restored";
    private static final String REPAIR_PARTIAL = "partial";
    private static final String REPAIR_FAILED = "repair_failed";
    private static final String REPAIR_MISSING_WSS = "missing_wss";
    private static final String PROJECTIVY_PACKAGE = "com.spocky.projengmenu";
    private static final String TVQA_PACKAGE = "dev.vodik7.tvquickactions";
    private static final String TVQA_FREE_PACKAGE = "dev.vodik7.tvquickactions.free";

    private SystemBridgeCoordinator() {
    }

    public static void startCore(Context context, String reason) {
        Intent intent = new Intent(context, ResidentCoreService.class);
        intent.putExtra(EXTRA_REASON, reason);
        Context appContext = context.getApplicationContext();
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                appContext.startForegroundService(intent);
            } else {
                appContext.startService(intent);
            }
        } catch (Exception exception) {
            Log.w(TAG, "Unable to start core for reason=" + reason, exception);
        }
    }

    public static void scheduleExactHeal(Context context, long delayMs, String reason) {
        scheduleExactHealInternal(context, delayMs, reason, ALARM_REQUEST_RECURRING);
    }

    public static void scheduleWakeBackstop(Context context, String reason) {
        if (!shouldScheduleWakeBackstop(context, reason)) {
            return;
        }
        scheduleExactHealInternal(context, WAKE_FAST_DELAY_MS, reason + "_wake_fast", ALARM_REQUEST_WAKE_FAST);
        scheduleExactHealInternal(context, WAKE_MEDIUM_DELAY_MS, reason + "_wake_medium", ALARM_REQUEST_WAKE_MEDIUM);
        scheduleExactHealInternal(context, WAKE_SLOW_DELAY_MS, reason + "_wake_slow", ALARM_REQUEST_WAKE_SLOW);
    }

    public static boolean shouldHandleRuntimeTrigger(Context context, String reason) {
        String normalizedReason = normalizeReason(reason);
        String triggerBucket = runtimeTriggerBucket(normalizedReason);
        if (TextUtils.isEmpty(triggerBucket)) {
            return true;
        }
        return tryAcquireEventWindow(context, "runtime_" + triggerBucket, RUNTIME_TRIGGER_THROTTLE_MS);
    }

    public static void kickAccessManager(Context context, String reason) {
        Context appContext = context.getApplicationContext();
        String normalizedReason = normalizeReason(reason);
        String kickBucket = accessManagerKickBucket(normalizedReason);
        if (TextUtils.isEmpty(kickBucket) || !isInstalled(appContext, ACCESS_MANAGER_PACKAGE)) {
            return;
        }
        if (!tryAcquireEventWindow(appContext, "accessmanager_kick_" + kickBucket, ACCESS_MANAGER_KICK_THROTTLE_MS)) {
            return;
        }

        Intent intent = new Intent(ACCESS_MANAGER_KICK_ACTION);
        intent.setComponent(new ComponentName(ACCESS_MANAGER_PACKAGE, ACCESS_MANAGER_KICK_RECEIVER));
        intent.setPackage(ACCESS_MANAGER_PACKAGE);
        intent.addFlags(Intent.FLAG_RECEIVER_FOREGROUND);
        intent.addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES);
        intent.putExtra(ACCESS_MANAGER_REASON_EXTRA, normalizedReason);
        try {
            appContext.sendBroadcast(intent);
            Log.i(TAG, "AccessManager kick sent: " + normalizedReason);
        } catch (Exception exception) {
            Log.w(TAG, "Unable to kick AccessManager for reason=" + normalizedReason, exception);
        }
    }

    private static void scheduleExactHealInternal(Context context, long delayMs, String reason, int requestCode) {
        Context appContext = context.getApplicationContext();
        AlarmManager alarmManager = (AlarmManager) appContext.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager == null) {
            return;
        }
        Intent intent = new Intent(appContext, HealAlarmReceiver.class);
        intent.putExtra(EXTRA_REASON, reason);
        PendingIntent pendingIntent = PendingIntent.getBroadcast(
                appContext,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        long triggerAt = System.currentTimeMillis() + Math.max(delayMs, 1500L);
        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent);
    }

    public static void scheduleRecurringWork(Context context) {
        scheduleExactHeal(context, ALARM_INTERVAL_MS, "alarm_tick");

        Context appContext = context.getApplicationContext();
        JobScheduler scheduler = (JobScheduler) appContext.getSystemService(Context.JOB_SCHEDULER_SERVICE);
        if (scheduler != null) {
            scheduler.cancel(JOB_ID);
        }
    }

    public static RecoverySummary ensureSystemState(Context context, String reason, boolean allowToast) {
        Context appContext = context.getApplicationContext();
        RecoverySummary summary = new RecoverySummary(reason);
        ApplyAdbPolicyResult adbPolicyResult = applyAdbAutomationPolicy(appContext, reason, false);
        summary.markIfChanged("\u2713 ADB", adbPolicyResult.changed);
        HomeGuardResult homeGuardResult = applyHomeGuard(appContext, reason);
        summary.markIfChanged("\u2713 HOME", homeGuardResult.launched);

        AccessibilityState accessibilityState = readAccessibilityState(appContext);
        AccessibilityRepairPlan repairPlan = buildTargetAccessibilityState(appContext, accessibilityState);
        AccessibilityRepairResult repairResult = applyAccessibilityRepair(appContext, accessibilityState, repairPlan);

        BridgeStateStore.setEnabledServiceSnapshot(appContext, repairResult.snapshotEnabledIds);
        BridgeStateStore.setLastAccessibilityRepairResult(appContext, repairResult.resultCode);
        BridgeStateStore.setLastMissingServiceIds(appContext, repairResult.missingIds);
        BridgeStateStore.setLastWriteSecureSettingsGranted(appContext, repairResult.writeSecureSettingsGranted);
        if (repairResult.isHealthy()) {
            long now = System.currentTimeMillis();
            BridgeStateStore.setLastAccessibilityRestoreAt(appContext, now);
            BridgeStateStore.setLastSuccessAt(appContext, now);
        }
        BridgeStateStore.setLastRecoveryReason(appContext, reason);
        scheduleRecurringWork(appContext);
        kickAccessManager(appContext, reason);

        if (allowToast && repairResult.isHealthy()) {
            String lifecycleToast = resolveLifecycleToast(appContext, reason);
            if (!TextUtils.isEmpty(lifecycleToast)) {
                BridgeToast.showState(appContext, lifecycleToast);
            }
        }
        return summary;
    }

    public static String buildStatusReport(Context context) {
        Context appContext = context.getApplicationContext();
        AccessibilityState accessibilityState = readAccessibilityState(appContext);
        String ownService = ownAccessibilityServiceId(appContext);
        PackageManager packageManager = appContext.getPackageManager();

        List<String> lines = new ArrayList<>();
        lines.add(labelFor(packageManager, appContext));
        lines.add("Package: " + appContext.getPackageName());
        lines.add("Device owner: " + yesNo(accessibilityState.deviceOwner));
        lines.add("WRITE_SECURE_SETTINGS: " + yesNo(accessibilityState.writeSecureSettingsGranted));
        lines.add("WRITE_SETTINGS: " + yesNo(Settings.System.canWrite(appContext)));
        lines.add("Battery optimization ignored: " + yesNo(isIgnoringBatteryOptimizations(appContext)));
        lines.add("ADB: " + yesNo(readGlobalInt(appContext, Settings.Global.ADB_ENABLED, 0) == 1));
        lines.add("ADB Wi-Fi: " + yesNo(readGlobalInt(appContext, ADB_WIFI_KEY, 0) == 1));
        lines.add("Accessibility master: " + yesNo(accessibilityState.accessibilityEnabled));
        lines.add("Our accessibility: " + yesNo(accessibilityState.currentEnabledSet.contains(ownService)));
        lines.add("Projectivy installed: " + yesNo(isInstalled(appContext, PROJECTIVY_PACKAGE)));
        lines.add("tvQuickActions installed: " + yesNo(
                isInstalled(appContext, TVQA_PACKAGE)
                        || isInstalled(appContext, TVQA_FREE_PACKAGE)
        ));
        lines.add("Mode: " + modeLabel(appContext, BridgeStateStore.getMode(appContext)));
        lines.add("Key mapping: " + keyProfileLabel(appContext));
        lines.add("Learning mode: " + yesNo(BridgeStateStore.isLearningMode(appContext)));
        lines.add("Last recovery: " + BridgeStateStore.getLastRecoveryReason(appContext));
        lines.add("Last success: " + formatTime(BridgeStateStore.getLastSuccessAt(appContext)));
        lines.add("Accessibility repair: " + BridgeStateStore.getLastAccessibilityRepairResult(appContext));
        lines.add("Missing services: " + formatServiceIds(BridgeStateStore.getLastMissingServiceIds(appContext)));
        lines.add("Last accessibility restore: " + formatTime(BridgeStateStore.getLastAccessibilityRestoreAt(appContext)));
        lines.add("ADB policy: " + BridgeStateStore.getAdbAutomationPolicy(appContext));
        lines.add("ADB disable on sleep: " + yesNo(BridgeStateStore.isAdbDisableOnSleepEnabled(appContext)));
        lines.add("ADB last apply: " + formatTime(BridgeStateStore.getLastAdbPolicyAppliedAt(appContext)));
        lines.add("ADB last reason: " + BridgeStateStore.getLastAdbPolicyReason(appContext));
        lines.add("ADB last state: " + BridgeStateStore.getLastAdbPolicyState(appContext));
        lines.add("Home guard default: " + yesNo(TextUtils.equals(appContext.getPackageName(), resolveCurrentHomePackage(appContext))));
        lines.add("Home guard attempt: " + formatTime(BridgeStateStore.getLastHomeGuardAttemptAt(appContext)));
        lines.add("Home guard reason: " + BridgeStateStore.getLastHomeGuardReason(appContext));
        lines.add("Home guard result: " + BridgeStateStore.getLastHomeGuardResult(appContext));
        lines.add("Home guard throttled: " + yesNo(BridgeStateStore.isHomeGuardThrottled(appContext)));
        return TextUtils.join("\n", lines);
    }

    public static Map<String, Object> buildHomeGuardStatus(Context context) {
        Context appContext = context.getApplicationContext();
        String resolvedHomePackage = resolveCurrentHomePackage(appContext);
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("isDefaultLauncher", TextUtils.equals(appContext.getPackageName(), resolvedHomePackage));
        map.put("defaultHomePackage", resolvedHomePackage);
        map.put("lastAttemptAt", BridgeStateStore.getLastHomeGuardAttemptAt(appContext));
        map.put("lastAttemptAtText", formatTime(BridgeStateStore.getLastHomeGuardAttemptAt(appContext)));
        map.put("lastReason", BridgeStateStore.getLastHomeGuardReason(appContext));
        map.put("lastResult", BridgeStateStore.getLastHomeGuardResult(appContext));
        map.put("throttled", BridgeStateStore.isHomeGuardThrottled(appContext));
        return map;
    }

    public static Map<String, Object> buildAdbAutomationStatus(Context context) {
        Context appContext = context.getApplicationContext();
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("policy", BridgeStateStore.getAdbAutomationPolicy(appContext));
        map.put("disableOnSleep", BridgeStateStore.isAdbDisableOnSleepEnabled(appContext));
        map.put("lastAppliedAt", BridgeStateStore.getLastAdbPolicyAppliedAt(appContext));
        map.put("lastAppliedAtText", formatTime(BridgeStateStore.getLastAdbPolicyAppliedAt(appContext)));
        map.put("lastReason", BridgeStateStore.getLastAdbPolicyReason(appContext));
        map.put("lastState", BridgeStateStore.getLastAdbPolicyState(appContext));
        map.put("adbEnabled", readGlobalInt(appContext, Settings.Global.ADB_ENABLED, 0) == 1);
        map.put("adbWifiEnabled", readGlobalInt(appContext, ADB_WIFI_KEY, 0) == 1);
        map.put("hasWriteSecureSettings", hasPermission(appContext, android.Manifest.permission.WRITE_SECURE_SETTINGS));
        map.put("deviceOwner", isDeviceOwner(appContext));
        map.put("localAdbAvailable", readGlobalInt(appContext, Settings.Global.ADB_ENABLED, 0) == 1);
        return map;
    }

    public static Map<String, Object> setAdbAutomationPolicy(
            Context context,
            String policy,
            boolean disableOnSleep
    ) {
        Context appContext = context.getApplicationContext();
        BridgeStateStore.setAdbAutomationPolicy(appContext, policy);
        BridgeStateStore.setAdbDisableOnSleepEnabled(appContext, disableOnSleep);
        ApplyAdbPolicyResult result = applyAdbAutomationPolicy(appContext, "manual_policy_update", true);
        Map<String, Object> map = buildAdbAutomationStatus(appContext);
        map.put("success", result.success);
        map.put("message", result.message);
        return map;
    }

    public static Map<String, Object> setAdbEnabledNow(Context context, boolean enabled) {
        Context appContext = context.getApplicationContext();
        ApplyAdbPolicyResult result;
        if (enabled) {
            String policy = BridgeStateStore.getAdbAutomationPolicy(appContext);
            int targetWifi = BridgeStateStore.ADB_POLICY_ADB_AND_WIFI.equals(policy) ? 1 : 0;
            result = applyAdbState(appContext, "manual_enable_now", 1, targetWifi, true);
        } else {
            result = applyAdbDisabledForSleep(appContext, "manual_disable_now", true);
        }
        Map<String, Object> map = buildAdbAutomationStatus(appContext);
        map.put("success", result.success);
        map.put("message", result.message);
        return map;
    }

    public static void handleSleepTransition(Context context, String reason) {
        Context appContext = context.getApplicationContext();
        if (!BridgeStateStore.isAdbDisableOnSleepEnabled(appContext)) {
            return;
        }
        applyAdbDisabledForSleep(appContext, reason, false);
    }

    public static String modeLabel(Context context, int mode) {
        if (mode == BridgeStateStore.MODE_SINGLE) {
            return context.getString(R.string.label_mode_single);
        }
        if (mode == BridgeStateStore.MODE_LONG) {
            return context.getString(R.string.label_mode_long);
        }
        if (mode == BridgeStateStore.MODE_DOUBLE_HOLD) {
            return context.getString(R.string.label_mode_double_hold);
        }
        return context.getString(R.string.label_mode_double);
    }

    private static String keyProfileLabel(Context context) {
        int keyCode = BridgeStateStore.getKeyCode(context);
        if (keyCode == BridgeStateStore.DEFAULT_KEY_CODE) {
            return context.getString(
                    R.string.label_key_profile_default,
                    BridgeStateStore.defaultVoiceKeySummary()
            );
        }
        return Integer.toString(keyCode);
    }

    private static AccessibilityState readAccessibilityState(Context context) {
        AccessibilityCatalog catalog = AccessibilityCatalog.build(context);
        String rawEnabled = readSecureString(context, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
        List<String> rawIds = splitServiceIds(rawEnabled);
        LinkedHashSet<String> normalizedIds = new LinkedHashSet<>();
        for (String rawId : rawIds) {
            addServiceId(normalizedIds, normalizeAccessibilityServiceId(context, rawId, catalog));
        }
        String ownService = normalizeAccessibilityServiceId(context, ownAccessibilityServiceId(context), catalog);
        return new AccessibilityState(
                catalog,
                rawEnabled,
                rawIds,
                new ArrayList<>(normalizedIds),
                new LinkedHashSet<>(normalizedIds),
                readSecureInt(context, Settings.Secure.ACCESSIBILITY_ENABLED, 0) == 1,
                hasPermission(context, android.Manifest.permission.WRITE_SECURE_SETTINGS),
                isDeviceOwner(context),
                TextUtils.isEmpty(ownService) ? ownAccessibilityServiceId(context) : ownService
        );
    }

    private static String normalizeAccessibilityServiceId(Context context, String rawId, AccessibilityCatalog catalog) {
        if (TextUtils.isEmpty(rawId)) {
            return null;
        }
        String normalized = catalog.normalize(rawId);
        if (!TextUtils.isEmpty(normalized)) {
            return normalized;
        }
        int slashIndex = rawId.indexOf('/');
        if (slashIndex <= 0 || slashIndex >= rawId.length() - 1) {
            return null;
        }
        String canonical = canonicalServiceId(
                rawId.substring(0, slashIndex),
                rawId.substring(slashIndex + 1)
        );
        return serviceExists(context, canonical) ? canonical : null;
    }

    private static AccessibilityRepairPlan buildTargetAccessibilityState(Context context, AccessibilityState state) {
        LinkedHashSet<String> targetEnabled = new LinkedHashSet<>();
        LinkedHashSet<String> snapshotEnabled = new LinkedHashSet<>();
        addServiceId(targetEnabled, state.ownServiceId);
        addServiceId(snapshotEnabled, state.ownServiceId);

        for (String currentId : state.currentEnabledIds) {
            addServiceId(targetEnabled, currentId);
            addServiceId(snapshotEnabled, currentId);
        }
        for (String snapshotId : BridgeStateStore.getEnabledServiceSnapshot(context)) {
            String normalized = normalizeAccessibilityServiceId(context, snapshotId, state.catalog);
            addServiceId(targetEnabled, normalized);
            addServiceId(snapshotEnabled, normalized);
        }
        for (String seededId : state.catalog.seededServiceIds()) {
            addServiceId(targetEnabled, seededId);
            addServiceId(snapshotEnabled, seededId);
        }

        LinkedHashSet<String> missingBefore = new LinkedHashSet<>();
        for (String serviceId : targetEnabled) {
            if (!state.currentEnabledSet.contains(serviceId)) {
                missingBefore.add(serviceId);
            }
        }
        return new AccessibilityRepairPlan(
                new ArrayList<>(targetEnabled),
                snapshotEnabled,
                missingBefore,
                state.ownServiceId
        );
    }

    private static AccessibilityRepairResult applyAccessibilityRepair(
            Context context,
            AccessibilityState beforeState,
            AccessibilityRepairPlan repairPlan
    ) {
        if (!beforeState.canRepairAccessibility()) {
            return verifyAccessibilityRepair(beforeState, beforeState, repairPlan, false, false, REPAIR_MISSING_WSS);
        }

        boolean wroteServices = writeSecureString(
                context,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
                TextUtils.join(":", repairPlan.targetEnabledIds)
        );
        boolean wroteMaster = writeSecureInt(context, Settings.Secure.ACCESSIBILITY_ENABLED, 1);
        syncPermittedAccessibilityServices(context, repairPlan.targetEnabledIds);

        AccessibilityState afterState = readAccessibilityState(context);
        return verifyAccessibilityRepair(beforeState, afterState, repairPlan, wroteServices, wroteMaster, null);
    }

    private static AccessibilityRepairResult verifyAccessibilityRepair(
            AccessibilityState beforeState,
            AccessibilityState afterState,
            AccessibilityRepairPlan repairPlan,
            boolean wroteServices,
            boolean wroteMaster,
            String forcedResult
    ) {
        LinkedHashSet<String> missingIds = new LinkedHashSet<>();
        for (String targetId : repairPlan.targetEnabledIds) {
            if (!afterState.currentEnabledSet.contains(targetId)) {
                missingIds.add(targetId);
            }
        }

        boolean ownEnabledAfter = afterState.currentEnabledSet.contains(repairPlan.ownServiceId);
        boolean healthy = ownEnabledAfter && afterState.accessibilityEnabled;
        boolean changed = wroteServices
                || wroteMaster
                || !beforeState.currentEnabledIds.equals(afterState.currentEnabledIds)
                || beforeState.accessibilityEnabled != afterState.accessibilityEnabled;

        String resultCode = forcedResult;
        if (TextUtils.isEmpty(resultCode)) {
            if (!healthy) {
                resultCode = REPAIR_FAILED;
            } else if (!missingIds.isEmpty()) {
                resultCode = REPAIR_PARTIAL;
            } else if (changed) {
                resultCode = REPAIR_RESTORED;
            } else {
                resultCode = REPAIR_OK;
            }
        }

        return new AccessibilityRepairResult(
                resultCode,
                changed,
                healthy,
                missingIds,
                repairPlan.snapshotEnabledIds,
                afterState.writeSecureSettingsGranted
        );
    }

    private static void syncPermittedAccessibilityServices(Context context, List<String> serviceIds) {
        if (!isDeviceOwner(context)) {
            return;
        }
        DevicePolicyManager dpm = (DevicePolicyManager) context.getSystemService(Context.DEVICE_POLICY_SERVICE);
        if (dpm == null) {
            return;
        }
        List<String> packageNames = new ArrayList<>();
        for (String serviceId : serviceIds) {
            int slashIndex = serviceId.indexOf('/');
            if (slashIndex <= 0) {
                continue;
            }
            String packageName = serviceId.substring(0, slashIndex);
            if (!packageNames.contains(packageName)) {
                packageNames.add(packageName);
            }
        }
        try {
            dpm.setPermittedAccessibilityServices(MapVoiceAdminReceiver.component(context), packageNames);
        } catch (Exception ignored) {
        }
    }

    private static HomeGuardResult applyHomeGuard(Context context, String reason) {
        String normalizedReason = normalizeReason(reason);
        if (!shouldEvaluateHomeGuard(normalizedReason)) {
            recordHomeGuardState(context, normalizedReason, "not_applicable", false, false);
            return new HomeGuardResult(false, false, "not_applicable");
        }
        if (normalizedReason.startsWith("activity_")) {
            recordHomeGuardState(context, normalizedReason, "launcher_foreground", false, false);
            return new HomeGuardResult(false, false, "launcher_foreground");
        }

        String resolvedHomePackage = resolveCurrentHomePackage(context);
        if (TextUtils.equals(context.getPackageName(), resolvedHomePackage)) {
            recordHomeGuardState(context, normalizedReason, "already_default", false, false);
            return new HomeGuardResult(false, false, "already_default");
        }

        if (!tryAcquireEventWindow(context, "home_guard_launch", HOME_GUARD_THROTTLE_MS)) {
            recordHomeGuardState(context, normalizedReason, "throttled", true, false);
            return new HomeGuardResult(false, true, "throttled");
        }

        Intent intent = buildOwnHomeIntent(context);
        if (intent == null) {
            recordHomeGuardState(context, normalizedReason, "missing_home_activity", false, true);
            return new HomeGuardResult(false, false, "missing_home_activity");
        }

        try {
            context.startActivity(intent);
            recordHomeGuardState(context, normalizedReason, "launched_targeted_home", false, true);
            return new HomeGuardResult(true, false, "launched_targeted_home");
        } catch (Exception exception) {
            recordHomeGuardState(
                    context,
                    normalizedReason,
                    "launch_failed:" + exception.getClass().getSimpleName(),
                    false,
                    true
            );
            Log.w(TAG, "Home guard launch failed for reason=" + normalizedReason, exception);
            return new HomeGuardResult(false, false, "launch_failed");
        }
    }

    private static void recordHomeGuardState(
            Context context,
            String reason,
            String result,
            boolean throttled,
            boolean attempted
    ) {
        if (attempted) {
            BridgeStateStore.setLastHomeGuardAttemptAt(context, System.currentTimeMillis());
        }
        BridgeStateStore.setLastHomeGuardReason(context, reason);
        BridgeStateStore.setLastHomeGuardResult(context, result);
        BridgeStateStore.setHomeGuardThrottled(context, throttled);
    }

    private static boolean shouldEvaluateHomeGuard(String normalizedReason) {
        if (TextUtils.isEmpty(normalizedReason)) {
            return false;
        }
        return normalizedReason.startsWith("activity_resume")
                || normalizedReason.contains("boot_completed")
                || normalizedReason.contains("quickboot_poweron")
                || normalizedReason.contains("my_package_replaced")
                || normalizedReason.contains("screen_on")
                || normalizedReason.contains("dreaming_stopped")
                || normalizedReason.contains("open_close_screen_saver")
                || normalizedReason.contains("user_present")
                || normalizedReason.contains("user_unlocked");
    }

    private static Intent buildOwnHomeIntent(Context context) {
        Intent homeIntent = new Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME)
                .setPackage(context.getPackageName())
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
        ResolveInfo resolveInfo = context.getPackageManager().resolveActivity(homeIntent, 0);
        if (resolveInfo != null
                && resolveInfo.activityInfo != null
                && !TextUtils.isEmpty(resolveInfo.activityInfo.name)) {
            homeIntent.setClassName(resolveInfo.activityInfo.packageName, resolveInfo.activityInfo.name);
            return homeIntent;
        }

        Intent queryIntent = new Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME)
                .setPackage(context.getPackageName());
        List<ResolveInfo> matches = context.getPackageManager().queryIntentActivities(queryIntent, 0);
        if (matches != null && !matches.isEmpty() && matches.get(0).activityInfo != null) {
            ActivityInfo activityInfo = matches.get(0).activityInfo;
            homeIntent.setClassName(activityInfo.packageName, activityInfo.name);
            return homeIntent;
        }
        return null;
    }

    private static String resolveCurrentHomePackage(Context context) {
        try {
            Intent intent = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
            ResolveInfo resolveInfo = context.getPackageManager().resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY);
            if (resolveInfo != null && resolveInfo.activityInfo != null && !TextUtils.isEmpty(resolveInfo.activityInfo.packageName)) {
                return resolveInfo.activityInfo.packageName;
            }
        } catch (Exception ignored) {
        }
        return "";
    }

    private static ApplyAdbPolicyResult applyAdbAutomationPolicy(
            Context context,
            String reason,
            boolean force
    ) {
        String policy = BridgeStateStore.getAdbAutomationPolicy(context);
        if (BridgeStateStore.ADB_POLICY_OFF.equals(policy)) {
            int currentAdb = readGlobalInt(context, Settings.Global.ADB_ENABLED, 0);
            int currentWifi = readGlobalInt(context, ADB_WIFI_KEY, 0);
            BridgeStateStore.setLastAdbPolicyAppliedAt(context, System.currentTimeMillis());
            BridgeStateStore.setLastAdbPolicyReason(context, normalizeReason(reason));
            BridgeStateStore.setLastAdbPolicyState(
                    context,
                    "adb=" + currentAdb + ",wifi=" + currentWifi
            );
            return new ApplyAdbPolicyResult(true, false, "ADB automation is off; current ADB state was preserved.");
        }
        int targetAdb = 0;
        int targetWifi = 0;
        if (BridgeStateStore.ADB_POLICY_ADB_ONLY.equals(policy)) {
            targetAdb = 1;
        } else if (BridgeStateStore.ADB_POLICY_ADB_AND_WIFI.equals(policy)) {
            targetAdb = 1;
            targetWifi = 1;
        }
        return applyAdbState(context, reason, targetAdb, targetWifi, force);
    }

    private static ApplyAdbPolicyResult applyAdbDisabledForSleep(
            Context context,
            String reason,
            boolean force
    ) {
        return applyAdbState(context, reason, 0, 0, force);
    }

    private static ApplyAdbPolicyResult applyAdbState(
            Context context,
            String reason,
            int targetAdb,
            int targetWifi,
            boolean force
    ) {
        String bucket = targetAdb == 0 && targetWifi == 0 ? "disable" : "enable";
        if (!force && !tryAcquireEventWindow(context, "adb_policy_" + bucket, ADB_POLICY_THROTTLE_MS)) {
            return new ApplyAdbPolicyResult(true, false, "ADB policy throttled.");
        }

        int beforeAdb = readGlobalInt(context, Settings.Global.ADB_ENABLED, 0);
        int beforeWifi = readGlobalInt(context, ADB_WIFI_KEY, 0);
        boolean adbOk = setGlobalIntWithFallback(context, Settings.Global.ADB_ENABLED, targetAdb);
        boolean wifiOk = setGlobalIntWithFallback(context, ADB_WIFI_KEY, targetWifi);
        int afterAdb = readGlobalInt(context, Settings.Global.ADB_ENABLED, 0);
        int afterWifi = readGlobalInt(context, ADB_WIFI_KEY, 0);

        boolean success = adbOk && wifiOk;
        boolean changed = beforeAdb != afterAdb || beforeWifi != afterWifi;
        BridgeStateStore.setLastAdbPolicyAppliedAt(context, System.currentTimeMillis());
        BridgeStateStore.setLastAdbPolicyReason(context, normalizeReason(reason));
        BridgeStateStore.setLastAdbPolicyState(
                context,
                "adb=" + afterAdb + ",wifi=" + afterWifi
        );

        String message;
        if (success) {
            message = changed ? "ADB automation applied." : "ADB state already matched the selected policy.";
        } else if (targetAdb == 1 && !hasPermission(context, android.Manifest.permission.WRITE_SECURE_SETTINGS)
                && !isDeviceOwner(context) && beforeAdb != 1) {
            message = "Could not enable ADB automatically. Grant WRITE_SECURE_SETTINGS or enable ADB first.";
        } else {
            message = "ADB automation could not fully apply on this firmware.";
        }
        return new ApplyAdbPolicyResult(success, changed, message);
    }

    private static boolean setGlobalIntWithFallback(Context context, String key, int value) {
        if (readGlobalInt(context, key, Integer.MIN_VALUE) == value) {
            return true;
        }
        if (hasPermission(context, android.Manifest.permission.WRITE_SECURE_SETTINGS) || isDeviceOwner(context)) {
            if (ensureGlobalInt(context, key, value)) {
                return true;
            }
        }
        if (readGlobalInt(context, Settings.Global.ADB_ENABLED, 0) != 1 && !Settings.Global.ADB_ENABLED.equals(key)) {
            return false;
        }
        if (readGlobalInt(context, Settings.Global.ADB_ENABLED, 0) != 1
                && Settings.Global.ADB_ENABLED.equals(key)
                && value == 1) {
            return false;
        }

        LocalAdbBridge.Result adbResult = LocalAdbBridge.executeShell(
                context,
                "settings put global " + key + " " + value
        );
        return adbResult.success && readGlobalInt(context, key, Integer.MIN_VALUE) == value;
    }

    private static boolean ensureGlobalInt(Context context, String key, int value) {
        boolean changed = readGlobalInt(context, key, Integer.MIN_VALUE) != value;
        DevicePolicyManager dpm = (DevicePolicyManager) context.getSystemService(Context.DEVICE_POLICY_SERVICE);
        if (changed && dpm != null && isDeviceOwner(context)) {
            try {
                dpm.setGlobalSetting(MapVoiceAdminReceiver.component(context), key, Integer.toString(value));
            } catch (Exception ignored) {
            }
        }
        if (readGlobalInt(context, key, Integer.MIN_VALUE) != value) {
            try {
                Settings.Global.putInt(context.getContentResolver(), key, value);
            } catch (Exception ignored) {
            }
        }
        return readGlobalInt(context, key, Integer.MIN_VALUE) == value;
    }

    private static boolean writeSecureInt(Context context, String key, int value) {
        boolean changed = readSecureInt(context, key, Integer.MIN_VALUE) != value;
        DevicePolicyManager dpm = (DevicePolicyManager) context.getSystemService(Context.DEVICE_POLICY_SERVICE);
        if (changed && dpm != null && isDeviceOwner(context)) {
            try {
                dpm.setSecureSetting(MapVoiceAdminReceiver.component(context), key, Integer.toString(value));
            } catch (Exception ignored) {
            }
        }
        if (readSecureInt(context, key, Integer.MIN_VALUE) != value) {
            try {
                Settings.Secure.putInt(context.getContentResolver(), key, value);
            } catch (Exception ignored) {
            }
        }
        return readSecureInt(context, key, Integer.MIN_VALUE) == value;
    }

    private static boolean writeSecureString(Context context, String key, String value) {
        boolean changed = !TextUtils.equals(readSecureString(context, key), value);
        DevicePolicyManager dpm = (DevicePolicyManager) context.getSystemService(Context.DEVICE_POLICY_SERVICE);
        if (changed && dpm != null && isDeviceOwner(context)) {
            try {
                dpm.setSecureSetting(MapVoiceAdminReceiver.component(context), key, value);
            } catch (Exception ignored) {
            }
        }
        if (!TextUtils.equals(readSecureString(context, key), value)) {
            try {
                Settings.Secure.putString(context.getContentResolver(), key, value);
            } catch (Exception ignored) {
            }
        }
        return TextUtils.equals(readSecureString(context, key), value);
    }

    private static int readGlobalInt(Context context, String key, int fallback) {
        try {
            return Settings.Global.getInt(context.getContentResolver(), key);
        } catch (Settings.SettingNotFoundException ignored) {
            return fallback;
        }
    }

    private static int readSecureInt(Context context, String key, int fallback) {
        try {
            return Settings.Secure.getInt(context.getContentResolver(), key);
        } catch (Settings.SettingNotFoundException ignored) {
            return fallback;
        }
    }

    private static String readSecureString(Context context, String key) {
        try {
            String value = Settings.Secure.getString(context.getContentResolver(), key);
            return value == null ? "" : value;
        } catch (Exception ignored) {
            return "";
        }
    }

    public static boolean isIgnoringBatteryOptimizations(Context context) {
        PowerManager powerManager = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        return powerManager != null && powerManager.isIgnoringBatteryOptimizations(context.getPackageName());
    }

    private static List<String> splitServiceIds(String raw) {
        List<String> ids = new ArrayList<>();
        if (TextUtils.isEmpty(raw)) {
            return ids;
        }
        String[] parts = raw.split(":");
        for (String part : parts) {
            if (!TextUtils.isEmpty(part)) {
                ids.add(part.trim());
            }
        }
        return ids;
    }

    private static void addServiceId(Set<String> values, String serviceId) {
        if (!TextUtils.isEmpty(serviceId)) {
            values.add(serviceId);
        }
    }

    private static String formatServiceIds(Set<String> serviceIds) {
        if (serviceIds == null || serviceIds.isEmpty()) {
            return "-";
        }
        return TextUtils.join(":", serviceIds);
    }

    public static String ownAccessibilityServiceId(Context context) {
        return canonicalServiceId(context.getPackageName(), VoiceBridgeAccessibilityService.class.getName());
    }

    private static String canonicalServiceId(String packageName, String className) {
        if (TextUtils.isEmpty(packageName) || TextUtils.isEmpty(className)) {
            return null;
        }
        String normalizedClass = className.startsWith(".")
                ? packageName + className
                : className;
        return packageName + "/" + normalizedClass;
    }

    private static boolean shouldSeedPackage(String packageName) {
        if (TextUtils.isEmpty(packageName)) {
            return false;
        }
        String lower = packageName.toLowerCase(Locale.US);
        return PROJECTIVY_PACKAGE.equals(packageName)
                || TVQA_PACKAGE.equals(packageName)
                || TVQA_FREE_PACKAGE.equals(packageName)
                || lower.contains("projectivy")
                || lower.contains("quickaction");
    }

    private static boolean shouldScheduleWakeBackstop(Context context, String reason) {
        String normalizedReason = normalizeReason(reason);
        if (!isRuntimeWakeReason(normalizedReason) && !normalizedReason.contains("connected")) {
            return true;
        }
        return tryAcquireEventWindow(context, "backstop_" + normalizedReason, WAKE_BACKSTOP_THROTTLE_MS);
    }

    private static String resolveLifecycleToast(Context context, String reason) {
        String normalizedReason = normalizeReason(reason);
        if (!isPrimaryLifecycleToastReason(normalizedReason)) {
            return null;
        }
        if (!tryAcquireEventWindow(context, "toast_lifecycle", LIFECYCLE_TOAST_THROTTLE_MS)) {
            return null;
        }
        Log.i(TAG, "Lifecycle toast allowed: " + normalizedReason);
        return context.getString(R.string.toast_lifecycle_ready, context.getString(R.string.app_name));
    }

    private static boolean tryAcquireEventWindow(Context context, String eventKey, long minIntervalMs) {
        Context appContext = context.getApplicationContext();
        long now = System.currentTimeMillis();
        long lastAt = BridgeStateStore.getEventTimestamp(appContext, eventKey);
        if (now - lastAt < minIntervalMs) {
            return false;
        }
        BridgeStateStore.setEventTimestamp(appContext, eventKey, now);
        return true;
    }

    private static boolean isRuntimeWakeReason(String normalizedReason) {
        if (TextUtils.isEmpty(normalizedReason)) {
            return false;
        }
        return normalizedReason.contains("screen_on")
                || normalizedReason.contains("user_present")
                || normalizedReason.contains("user_unlocked")
                || normalizedReason.contains("dreaming_stopped")
                || normalizedReason.contains("action_screen_on")
                || normalizedReason.contains("open_close_screen_saver")
                || normalizedReason.contains("boot_completed")
                || normalizedReason.contains("quickboot_poweron");
    }

    private static String runtimeTriggerBucket(String normalizedReason) {
        if (!isRuntimeWakeReason(normalizedReason)) {
            return null;
        }
        if (normalizedReason.contains("boot_completed") || normalizedReason.contains("quickboot_poweron")) {
            return "boot";
        }
        return "wake";
    }

    private static boolean isPrimaryLifecycleToastReason(String normalizedReason) {
        if (TextUtils.isEmpty(normalizedReason)) {
            return false;
        }
        return "android.intent.action.boot_completed".equals(normalizedReason)
                || "android.intent.action.locked_boot_completed".equals(normalizedReason)
                || "android.intent.action.quickboot_poweron".equals(normalizedReason)
                || "mitv.action.str_boot_completed".equals(normalizedReason)
                || "android.intent.action.screen_on".equals(normalizedReason)
                || "android.intent.action.user_present".equals(normalizedReason)
                || "android.intent.action.dreaming_stopped".equals(normalizedReason)
                || "com.xiaomi.mitv.action_screen_on".equals(normalizedReason)
                || "com.xiaomi.tv.action_open_close_screen_saver".equals(normalizedReason);
    }

    private static String normalizeReason(String reason) {
        if (TextUtils.isEmpty(reason)) {
            return "unknown";
        }
        return reason.trim().toLowerCase(Locale.US);
    }

    private static String accessManagerKickBucket(String normalizedReason) {
        if (TextUtils.isEmpty(normalizedReason)) {
            return null;
        }
        if (normalizedReason.contains("boot_completed") || normalizedReason.contains("quickboot_poweron")) {
            return "boot";
        }
        if (normalizedReason.contains("screen_on")
                || normalizedReason.contains("user_present")
                || normalizedReason.contains("user_unlocked")
                || normalizedReason.contains("dreaming_stopped")
                || normalizedReason.contains("open_close_screen_saver")) {
            return "wake";
        }
        if (normalizedReason.contains("my_package_replaced")) {
            return "replace";
        }
        return null;
    }

    private static boolean serviceExists(Context context, String canonicalId) {
        if (TextUtils.isEmpty(canonicalId)) {
            return false;
        }
        int slashIndex = canonicalId.indexOf('/');
        if (slashIndex <= 0 || slashIndex >= canonicalId.length() - 1) {
            return false;
        }
        ComponentName componentName = new ComponentName(
                canonicalId.substring(0, slashIndex),
                canonicalId.substring(slashIndex + 1)
        );
        try {
            context.getPackageManager().getServiceInfo(componentName, 0);
            return true;
        } catch (Exception ignored) {
            return false;
        }
    }

    private static boolean isInstalled(Context context, String packageName) {
        try {
            context.getPackageManager().getPackageInfo(packageName, 0);
            return true;
        } catch (Exception ignored) {
            return false;
        }
    }

    private static boolean isDeviceOwner(Context context) {
        DevicePolicyManager dpm = (DevicePolicyManager) context.getSystemService(Context.DEVICE_POLICY_SERVICE);
        return dpm != null && dpm.isDeviceOwnerApp(context.getPackageName());
    }

    private static boolean hasPermission(Context context, String permission) {
        return context.checkCallingOrSelfPermission(permission) == PackageManager.PERMISSION_GRANTED;
    }

    private static String labelFor(PackageManager packageManager, Context context) {
        try {
            ApplicationInfo info = packageManager.getApplicationInfo(context.getPackageName(), 0);
            return info.loadLabel(packageManager).toString();
        } catch (Exception ignored) {
            return context.getPackageName();
        }
    }

    private static String yesNo(boolean value) {
        return value ? "YES" : "NO";
    }

    private static String formatTime(long epochMillis) {
        if (epochMillis <= 0L) {
            return "-";
        }
        DateFormat format = DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.MEDIUM);
        return format.format(new Date(epochMillis));
    }

    public static final class RecoverySummary {
        private final String reason;
        private final List<String> tokens;

        RecoverySummary(String reason) {
            this.reason = reason;
            this.tokens = new ArrayList<>();
        }

        void markIfChanged(String token, boolean changed) {
            if (changed && !tokens.contains(token)) {
                tokens.add(token);
            }
        }

        public String toToastMessage() {
            if (tokens.isEmpty()) {
                return "";
            }
            return TextUtils.join(" | ", tokens);
        }

        public String getReason() {
            return reason;
        }

        public List<String> getTokens() {
            return Collections.unmodifiableList(tokens);
        }
    }

    private static final class ApplyAdbPolicyResult {
        final boolean success;
        final boolean changed;
        final String message;

        ApplyAdbPolicyResult(boolean success, boolean changed, String message) {
            this.success = success;
            this.changed = changed;
            this.message = message == null ? "" : message;
        }
    }

    private static final class HomeGuardResult {
        final boolean launched;
        final boolean throttled;
        final String result;

        HomeGuardResult(boolean launched, boolean throttled, String result) {
            this.launched = launched;
            this.throttled = throttled;
            this.result = result == null ? "" : result;
        }
    }

    private static final class AccessibilityState {
        final AccessibilityCatalog catalog;
        final String rawEnabledString;
        final List<String> rawEnabledIds;
        final List<String> currentEnabledIds;
        final Set<String> currentEnabledSet;
        final boolean accessibilityEnabled;
        final boolean writeSecureSettingsGranted;
        final boolean deviceOwner;
        final String ownServiceId;

        AccessibilityState(
                AccessibilityCatalog catalog,
                String rawEnabledString,
                List<String> rawEnabledIds,
                List<String> currentEnabledIds,
                Set<String> currentEnabledSet,
                boolean accessibilityEnabled,
                boolean writeSecureSettingsGranted,
                boolean deviceOwner,
                String ownServiceId
        ) {
            this.catalog = catalog;
            this.rawEnabledString = rawEnabledString;
            this.rawEnabledIds = rawEnabledIds;
            this.currentEnabledIds = currentEnabledIds;
            this.currentEnabledSet = currentEnabledSet;
            this.accessibilityEnabled = accessibilityEnabled;
            this.writeSecureSettingsGranted = writeSecureSettingsGranted;
            this.deviceOwner = deviceOwner;
            this.ownServiceId = ownServiceId;
        }

        boolean canRepairAccessibility() {
            return writeSecureSettingsGranted || deviceOwner;
        }
    }

    private static final class AccessibilityRepairPlan {
        final List<String> targetEnabledIds;
        final Set<String> snapshotEnabledIds;
        final Set<String> missingBeforeIds;
        final String ownServiceId;

        AccessibilityRepairPlan(
                List<String> targetEnabledIds,
                Set<String> snapshotEnabledIds,
                Set<String> missingBeforeIds,
                String ownServiceId
        ) {
            this.targetEnabledIds = targetEnabledIds;
            this.snapshotEnabledIds = snapshotEnabledIds;
            this.missingBeforeIds = missingBeforeIds;
            this.ownServiceId = ownServiceId;
        }
    }

    private static final class AccessibilityRepairResult {
        final String resultCode;
        final boolean changed;
        final boolean healthy;
        final Set<String> missingIds;
        final Set<String> snapshotEnabledIds;
        final boolean writeSecureSettingsGranted;

        AccessibilityRepairResult(
                String resultCode,
                boolean changed,
                boolean healthy,
                Set<String> missingIds,
                Set<String> snapshotEnabledIds,
                boolean writeSecureSettingsGranted
        ) {
            this.resultCode = resultCode;
            this.changed = changed;
            this.healthy = healthy;
            this.missingIds = missingIds;
            this.snapshotEnabledIds = snapshotEnabledIds;
            this.writeSecureSettingsGranted = writeSecureSettingsGranted;
        }

        boolean isHealthy() {
            return healthy;
        }

        boolean shouldShowRestore(String previousResult) {
            return healthy && (changed || !REPAIR_OK.equals(previousResult));
        }

        boolean shouldShowDegraded(String previousResult) {
            return REPAIR_MISSING_WSS.equals(resultCode) && !REPAIR_MISSING_WSS.equals(previousResult);
        }
    }

    private static final class AccessibilityCatalog {
        private final Map<String, String> aliases = new LinkedHashMap<>();
        private final LinkedHashSet<String> installedCanonicalIds = new LinkedHashSet<>();

        static AccessibilityCatalog build(Context context) {
            AccessibilityCatalog catalog = new AccessibilityCatalog();
            catalog.addService(context.getPackageName(), VoiceBridgeAccessibilityService.class.getName());

            PackageManager packageManager = context.getPackageManager();
            Intent intent = new Intent(AccessibilityService.SERVICE_INTERFACE);
            List<ResolveInfo> resolveInfos = packageManager.queryIntentServices(intent, PackageManager.GET_META_DATA);
            if (resolveInfos != null) {
                for (ResolveInfo resolveInfo : resolveInfos) {
                    ServiceInfo serviceInfo = resolveInfo.serviceInfo;
                    if (serviceInfo == null) {
                        continue;
                    }
                    catalog.addService(serviceInfo.packageName, serviceInfo.name);
                }
            }

            AccessibilityManager manager = (AccessibilityManager) context.getSystemService(Context.ACCESSIBILITY_SERVICE);
            if (manager != null) {
                List<AccessibilityServiceInfo> infos = manager.getInstalledAccessibilityServiceList();
                for (AccessibilityServiceInfo info : infos) {
                    if (info == null) {
                        continue;
                    }
                    if (!TextUtils.isEmpty(info.getId())) {
                        catalog.addAlias(info.getId(), info.getId());
                    }
                    ResolveInfo resolveInfo = info.getResolveInfo();
                    if (resolveInfo != null && resolveInfo.serviceInfo != null) {
                        catalog.addService(resolveInfo.serviceInfo.packageName, resolveInfo.serviceInfo.name);
                    }
                }
            }
            return catalog;
        }

        void addService(String packageName, String className) {
            String canonical = canonicalServiceId(packageName, className);
            if (TextUtils.isEmpty(canonical)) {
                return;
            }
            installedCanonicalIds.add(canonical);
            addAlias(canonical, canonical);
            ComponentName componentName = new ComponentName(packageName, canonical.substring(canonical.indexOf('/') + 1));
            addAlias(componentName.flattenToString(), canonical);
            addAlias(componentName.flattenToShortString(), canonical);
        }

        void addAlias(String rawId, String canonicalId) {
            if (TextUtils.isEmpty(rawId) || TextUtils.isEmpty(canonicalId)) {
                return;
            }
            aliases.put(rawId, canonicalId);
            String trimmed = rawId.trim();
            if (!TextUtils.equals(trimmed, rawId)) {
                aliases.put(trimmed, canonicalId);
            }
        }

        String normalize(String rawId) {
            if (TextUtils.isEmpty(rawId)) {
                return null;
            }
            String trimmed = rawId.trim();
            String alias = aliases.get(trimmed);
            if (!TextUtils.isEmpty(alias)) {
                return alias;
            }
            int slashIndex = trimmed.indexOf('/');
            if (slashIndex <= 0 || slashIndex >= trimmed.length() - 1) {
                return null;
            }
            String canonical = canonicalServiceId(
                    trimmed.substring(0, slashIndex),
                    trimmed.substring(slashIndex + 1)
            );
            if (!TextUtils.isEmpty(canonical) && installedCanonicalIds.contains(canonical)) {
                return canonical;
            }
            return null;
        }

        List<String> seededServiceIds() {
            List<String> serviceIds = new ArrayList<>();
            for (String canonicalId : installedCanonicalIds) {
                int slashIndex = canonicalId.indexOf('/');
                if (slashIndex <= 0) {
                    continue;
                }
                String packageName = canonicalId.substring(0, slashIndex);
                if (shouldSeedPackage(packageName)) {
                    serviceIds.add(canonicalId);
                }
            }
            return serviceIds;
        }
    }
}


