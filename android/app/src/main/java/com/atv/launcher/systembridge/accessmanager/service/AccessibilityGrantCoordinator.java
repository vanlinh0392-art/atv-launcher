package com.atv.launcher.systembridge.accessmanager.service;

import android.Manifest;
import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.app.AlarmManager;
import android.app.job.JobInfo;
import android.app.job.JobScheduler;
import android.app.PendingIntent;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.content.pm.ServiceInfo;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.provider.Settings;
import android.text.TextUtils;
import android.util.Log;
import android.view.accessibility.AccessibilityManager;

import com.atv.launcher.R;
import com.atv.launcher.systembridge.accessmanager.adb.LocalAdbBridge;
import com.atv.launcher.systembridge.accessmanager.boot.GuardianAlarmReceiver;
import com.atv.launcher.systembridge.accessmanager.logic.AccessManagerLogic;
import com.atv.launcher.systembridge.accessmanager.model.AppEntry;
import com.atv.launcher.systembridge.accessmanager.state.AccessStateStore;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

public final class AccessibilityGrantCoordinator {
    private static final String TAG = "AccessManagerBoot";
    public static final String EXTRA_REASON = "com.atv.launcher.systembridge.accessmanager.extra.REASON";

    private static final int JOB_ID = 0x29A;
    private static final int ALARM_REQUEST_RECURRING = 30;
    private static final int ALARM_REQUEST_WAKE_FAST = 31;
    private static final int ALARM_REQUEST_WAKE_MEDIUM = 32;
    private static final int ALARM_REQUEST_WAKE_SLOW = 33;
    private static final long ALARM_INTERVAL_MS = 9L * 60L * 1000L;
    private static final long JOB_INTERVAL_MS = 15L * 60L * 1000L;
    private static final long STARTUP_TRIGGER_THROTTLE_MS = 8000L;
    private static final long WAKE_FAST_DELAY_MS = 1500L;
    private static final long WAKE_MEDIUM_DELAY_MS = 15000L;
    private static final long WAKE_SLOW_DELAY_MS = 45000L;
    private static final long RUNTIME_TRIGGER_THROTTLE_MS = 4000L;
    private static final long WAKE_BACKSTOP_THROTTLE_MS = 15000L;
    private static final String RESULT_OK = "ok";
    private static final String RESULT_RESTORED = "restored";
    private static final String RESULT_GRANT_OK = "grant_ok";
    private static final String RESULT_REMOVE_OK = "remove_ok";
    private static final String RESULT_REPAIR_FAILED = "repair_failed";
    private static final String RESULT_MISSING_WSS = "missing_wss";

    private AccessibilityGrantCoordinator() {
    }

    public static void startGuardian(Context context, String reason) {
        Intent intent = new Intent(context, GuardianService.class);
        intent.putExtra(EXTRA_REASON, reason);
        Context appContext = context.getApplicationContext();
        try {
            Log.i(TAG, "startGuardian requested: " + reason);
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                appContext.startForegroundService(intent);
            } else {
                appContext.startService(intent);
            }
        } catch (Exception exception) {
            Log.w(TAG, "startGuardian failed for reason=" + reason, exception);
        }
    }

    public static ScanSnapshot loadSnapshot(Context context) {
        Context appContext = context.getApplicationContext();
        AccessibilityState state = readAccessibilityState(appContext);
        Set<String> managedPackages = AccessStateStore.getManagedPackageNames(appContext);
        List<AppEntry> apps = buildAppEntries(appContext, state, managedPackages);
        return new ScanSnapshot(
                apps,
                state.writeSecureSettingsGranted,
                state.accessibilityEnabled,
                managedPackages.size(),
                AccessStateStore.getLastVerifyResult(appContext),
                isAdbEnabled(appContext)
        );
    }

    public static ActionResult grantPackage(Context context, String packageName) {
        return applyPackageChange(context, packageName, true);
    }

    public static ActionResult removePackage(Context context, String packageName) {
        return applyPackageChange(context, packageName, false);
    }

    public static LocalGrantResult tryGrantWriteSecureSettingsWithLocalAdb(Context context) {
        Context appContext = context.getApplicationContext();
        if (hasPermission(appContext, Manifest.permission.WRITE_SECURE_SETTINGS)) {
            return new LocalGrantResult(true, appContext.getString(R.string.status_auto_grant_already_granted));
        }

        boolean adbEnabled = isAdbEnabled(appContext);
        String shellCommand = "pm grant " + appContext.getPackageName() + " " + Manifest.permission.WRITE_SECURE_SETTINGS;
        LocalAdbBridge.Result adbResult = LocalAdbBridge.executeShell(appContext, shellCommand);
        if (!adbResult.success) {
            String fallback = appContext.getString(
                    adbEnabled ? R.string.status_auto_grant_failed : R.string.status_auto_grant_adb_disabled
            );
            String detail = adbResult.detail;
            if (TextUtils.isEmpty(detail)) {
                return new LocalGrantResult(false, fallback);
            }
            if (!adbEnabled) {
                detail = appContext.getString(R.string.status_auto_grant_adb_disabled) + " " + detail;
            }
            return new LocalGrantResult(false, detail);
        }

        if (!hasPermission(appContext, Manifest.permission.WRITE_SECURE_SETTINGS)) {
            return new LocalGrantResult(false, appContext.getString(R.string.status_auto_grant_verify_failed));
        }

        return new LocalGrantResult(true, appContext.getString(R.string.status_auto_grant_success));
    }

    public static RecoveryResult ensureManagedAccessibility(Context context, String reason) {
        Context appContext = context.getApplicationContext();
        AccessibilityState beforeState = readAccessibilityState(appContext);
        LinkedHashSet<String> storedManagedServices = new LinkedHashSet<>(
                AccessStateStore.getManagedServiceIds(appContext)
        );
        LinkedHashSet<String> installedPackages = scanInstalledPackageNames(appContext);
        LinkedHashSet<String> managedPackages = AccessManagerLogic.pruneManagedPackages(
                AccessStateStore.getManagedPackageNames(appContext),
                installedPackages
        );
        LinkedHashSet<String> managedServiceIds = resolveManagedServices(beforeState.catalog, managedPackages);

        AccessStateStore.setManagedPackageNames(appContext, managedPackages);
        AccessStateStore.setManagedServiceIds(appContext, managedServiceIds);
        AccessStateStore.setLastRepairReason(appContext, reason);
        scheduleRecurringWork(appContext, reason);

        if (!beforeState.writeSecureSettingsGranted) {
            AccessStateStore.setLastVerifyResult(appContext, RESULT_MISSING_WSS);
            return new RecoveryResult(false, RESULT_MISSING_WSS);
        }

        if (managedServiceIds.isEmpty()) {
            LinkedHashSet<String> desiredEnabled = AccessManagerLogic.rebuildManagedEnabledSet(
                    beforeState.currentEnabledIds,
                    storedManagedServices,
                    managedPackages,
                    managedServiceIds
            );
            if (!desiredEnabled.equals(new LinkedHashSet<>(beforeState.currentEnabledIds))) {
                writeSecureString(appContext, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES, AccessManagerLogic.joinServiceIds(desiredEnabled));
                writeSecureInt(appContext, Settings.Secure.ACCESSIBILITY_ENABLED, desiredEnabled.isEmpty() ? 0 : 1);
                beforeState = readAccessibilityState(appContext);
            }
            AccessStateStore.setLastGoodSnapshot(appContext, new LinkedHashSet<>(beforeState.currentEnabledIds));
            AccessStateStore.setLastVerifyResult(appContext, RESULT_OK);
            AccessStateStore.setLastSuccessAt(appContext, System.currentTimeMillis());
            return new RecoveryResult(true, RESULT_OK);
        }

        LinkedHashSet<String> desiredEnabled = AccessManagerLogic.rebuildManagedEnabledSet(
                beforeState.currentEnabledIds,
                storedManagedServices,
                managedPackages,
                managedServiceIds
        );
        boolean needsWrite = !desiredEnabled.equals(new LinkedHashSet<>(beforeState.currentEnabledIds))
                || !beforeState.accessibilityEnabled;
        if (!needsWrite) {
            AccessStateStore.setLastGoodSnapshot(appContext, new LinkedHashSet<>(beforeState.currentEnabledIds));
            AccessStateStore.setLastVerifyResult(appContext, RESULT_OK);
            AccessStateStore.setLastSuccessAt(appContext, System.currentTimeMillis());
            return new RecoveryResult(true, RESULT_OK);
        }

        writeSecureString(appContext, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES, AccessManagerLogic.joinServiceIds(desiredEnabled));
        writeSecureInt(appContext, Settings.Secure.ACCESSIBILITY_ENABLED, 1);

        AccessibilityState afterState = readAccessibilityState(appContext);
        boolean verified = afterState.accessibilityEnabled
                && afterState.currentEnabledSet.containsAll(managedServiceIds);
        AccessStateStore.setLastVerifyResult(appContext, verified ? RESULT_RESTORED : RESULT_REPAIR_FAILED);
        if (verified) {
            AccessStateStore.setLastGoodSnapshot(appContext, new LinkedHashSet<>(afterState.currentEnabledIds));
            AccessStateStore.setLastSuccessAt(appContext, System.currentTimeMillis());
        }
        return new RecoveryResult(verified, verified ? RESULT_RESTORED : RESULT_REPAIR_FAILED);
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
        if (!isRuntimeWakeReason(normalizedReason)) {
            return true;
        }
        return tryAcquireEventWindow(context, "runtime_" + normalizedReason, RUNTIME_TRIGGER_THROTTLE_MS);
    }

    public static boolean shouldHandleStartupTrigger(Context context, String reason) {
        String triggerBucket = startupTriggerBucket(reason);
        if (TextUtils.isEmpty(triggerBucket)) {
            return true;
        }
        return tryAcquireEventWindow(context, "startup_" + triggerBucket, STARTUP_TRIGGER_THROTTLE_MS);
    }

    private static ActionResult applyPackageChange(Context context, String packageName, boolean grant) {
        Context appContext = context.getApplicationContext();
        AccessibilityState beforeState = readAccessibilityState(appContext);
        AccessStateStore.setLastRepairReason(appContext, (grant ? "manual_grant:" : "manual_remove:") + packageName);

        if (!beforeState.writeSecureSettingsGranted) {
            AccessStateStore.setLastVerifyResult(appContext, RESULT_MISSING_WSS);
            return new ActionResult(false, RESULT_MISSING_WSS, context.getString(R.string.status_missing_wss));
        }

        LinkedHashSet<String> managedPackages = new LinkedHashSet<>(AccessStateStore.getManagedPackageNames(appContext));
        LinkedHashSet<String> managedServiceIds = new LinkedHashSet<>(AccessStateStore.getManagedServiceIds(appContext));
        LinkedHashSet<String> packageServices = new LinkedHashSet<>(beforeState.catalog.servicesForPackage(packageName));

        if (grant && packageServices.isEmpty()) {
            AccessStateStore.setLastVerifyResult(appContext, RESULT_REPAIR_FAILED);
            return new ActionResult(false, RESULT_REPAIR_FAILED, context.getString(R.string.status_no_service));
        }

        LinkedHashSet<String> desiredEnabled = grant
                ? AccessManagerLogic.mergeGrant(
                        AccessManagerLogic.removePackageServices(beforeState.currentEnabledIds, managedServiceIds, packageName),
                        packageServices
                )
                : AccessManagerLogic.removePackageServices(beforeState.currentEnabledIds, managedServiceIds, packageName);

        writeSecureString(appContext, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES, AccessManagerLogic.joinServiceIds(desiredEnabled));
        writeSecureInt(appContext, Settings.Secure.ACCESSIBILITY_ENABLED, desiredEnabled.isEmpty() ? 0 : 1);

        AccessibilityState afterState = readAccessibilityState(appContext);
        boolean verified = verifyPackageChange(afterState, packageName, packageServices, desiredEnabled, grant);
        AccessStateStore.setLastVerifyResult(appContext, verified ? (grant ? RESULT_GRANT_OK : RESULT_REMOVE_OK) : RESULT_REPAIR_FAILED);

        if (verified) {
            if (grant) {
                managedPackages.add(packageName);
            } else {
                managedPackages.remove(packageName);
            }
            managedPackages = AccessManagerLogic.pruneManagedPackages(managedPackages, scanInstalledPackageNames(appContext));
            managedServiceIds = resolveManagedServices(afterState.catalog, managedPackages);
            AccessStateStore.setManagedPackageNames(appContext, managedPackages);
            AccessStateStore.setManagedServiceIds(appContext, managedServiceIds);
            AccessStateStore.setLastGoodSnapshot(appContext, new LinkedHashSet<>(afterState.currentEnabledIds));
            AccessStateStore.setLastSuccessAt(appContext, System.currentTimeMillis());
            startGuardian(appContext, grant ? "grant_applied" : "remove_applied");
            scheduleWakeBackstop(appContext, grant ? "grant_applied" : "remove_applied");
        }

        String successMessage = grant
                ? "Accessibility granted and verified."
                : "Accessibility removed and verified.";
        return new ActionResult(verified, AccessStateStore.getLastVerifyResult(appContext), verified ? successMessage : context.getString(R.string.status_apply_failed));
    }

    private static boolean verifyPackageChange(
            AccessibilityState afterState,
            String packageName,
            Collection<String> packageServices,
            Collection<String> desiredEnabled,
            boolean grant
    ) {
        boolean masterMatches = desiredEnabled.isEmpty() ? !afterState.accessibilityEnabled : afterState.accessibilityEnabled;
        if (grant) {
            if (!masterMatches || !afterState.currentEnabledSet.containsAll(packageServices)) {
                return false;
            }
            for (String currentService : afterState.currentEnabledIds) {
                String currentPackage = AccessManagerLogic.servicePackage(currentService);
                if (!packageName.equals(currentPackage)) {
                    continue;
                }
                if (!packageServices.contains(currentService)) {
                    return false;
                }
            }
            return true;
        }
        return masterMatches && !AccessManagerLogic.containsPackageService(afterState.currentEnabledIds, packageName);
    }

    private static List<AppEntry> buildAppEntries(
            Context context,
            AccessibilityState state,
            Set<String> managedPackages
    ) {
        PackageManager packageManager = context.getPackageManager();
        LinkedHashMap<String, PackageAccumulator> packages = new LinkedHashMap<>();
        collectLaunchablePackages(packageManager, packages);
        for (String servicePackage : state.catalog.servicePackages()) {
            PackageAccumulator accumulator = getOrCreateAccumulator(packages, servicePackage, packageManager);
            accumulator.serviceIds.addAll(state.catalog.servicesForPackage(servicePackage));
        }

        List<AppEntry> apps = new ArrayList<>();
        for (PackageAccumulator accumulator : packages.values()) {
            if (!accumulator.launchable && accumulator.serviceIds.isEmpty()) {
                continue;
            }
            boolean enabled = AccessManagerLogic.containsPackageService(state.currentEnabledIds, accumulator.packageName);
            boolean managed = managedPackages.contains(accumulator.packageName);
            apps.add(new AppEntry(
                    accumulator.packageName,
                    accumulator.label,
                    accumulator.systemApp,
                    accumulator.launchable,
                    !accumulator.serviceIds.isEmpty(),
                    enabled,
                    managed,
                    new ArrayList<>(accumulator.serviceIds),
                    accumulator.icon
            ));
        }

        Collections.sort(apps, APP_COMPARATOR);
        return apps;
    }

    private static void collectLaunchablePackages(
            PackageManager packageManager,
            Map<String, PackageAccumulator> packages
    ) {
        collectLaunchableByCategory(packageManager, packages, Intent.CATEGORY_LEANBACK_LAUNCHER);
        collectLaunchableByCategory(packageManager, packages, Intent.CATEGORY_LAUNCHER);
    }

    private static void collectLaunchableByCategory(
            PackageManager packageManager,
            Map<String, PackageAccumulator> packages,
            String category
    ) {
        Intent intent = new Intent(Intent.ACTION_MAIN);
        intent.addCategory(category);
        List<ResolveInfo> resolveInfos = packageManager.queryIntentActivities(intent, 0);
        if (resolveInfos == null) {
            return;
        }
        for (ResolveInfo resolveInfo : resolveInfos) {
            ActivityInfo activityInfo = resolveInfo.activityInfo;
            if (activityInfo == null || TextUtils.isEmpty(activityInfo.packageName)) {
                continue;
            }
            PackageAccumulator accumulator = getOrCreateAccumulator(packages, activityInfo.packageName, packageManager);
            accumulator.launchable = true;
        }
    }

    private static PackageAccumulator getOrCreateAccumulator(
            Map<String, PackageAccumulator> packages,
            String packageName,
            PackageManager packageManager
    ) {
        PackageAccumulator existing = packages.get(packageName);
        if (existing != null) {
            return existing;
        }
        PackageAccumulator created = PackageAccumulator.create(packageManager, packageName);
        packages.put(packageName, created);
        return created;
    }

    private static AccessibilityState readAccessibilityState(Context context) {
        AccessibilityCatalog catalog = AccessibilityCatalog.build(context);
        List<String> rawIds = AccessManagerLogic.splitServiceIds(readSecureString(context, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES));
        LinkedHashSet<String> normalizedIds = new LinkedHashSet<>();
        for (String rawId : rawIds) {
            String normalized = catalog.normalize(rawId);
            normalizedIds.add(TextUtils.isEmpty(normalized) ? rawId : normalized);
        }
        return new AccessibilityState(
                catalog,
                new ArrayList<>(normalizedIds),
                normalizedIds,
                readSecureInt(context, Settings.Secure.ACCESSIBILITY_ENABLED, 0) == 1,
                hasPermission(context, android.Manifest.permission.WRITE_SECURE_SETTINGS)
        );
    }

    private static LinkedHashSet<String> resolveManagedServices(
            AccessibilityCatalog catalog,
            Collection<String> managedPackages
    ) {
        LinkedHashSet<String> resolved = new LinkedHashSet<>();
        for (String managedPackage : managedPackages) {
            resolved.addAll(catalog.servicesForPackage(managedPackage));
        }
        return resolved;
    }

    private static LinkedHashSet<String> scanInstalledPackageNames(Context context) {
        LinkedHashSet<String> packages = new LinkedHashSet<>();
        List<ApplicationInfo> applications = context.getPackageManager().getInstalledApplications(0);
        if (applications == null) {
            return packages;
        }
        for (ApplicationInfo applicationInfo : applications) {
            if (applicationInfo != null && !TextUtils.isEmpty(applicationInfo.packageName)) {
                packages.add(applicationInfo.packageName);
            }
        }
        return packages;
    }

    private static boolean hasPermission(Context context, String permission) {
        return context.checkCallingOrSelfPermission(permission) == PackageManager.PERMISSION_GRANTED;
    }

    private static boolean isAdbEnabled(Context context) {
        try {
            return Settings.Global.getInt(context.getContentResolver(), Settings.Global.ADB_ENABLED, 0) == 1;
        } catch (Exception ignored) {
            return false;
        }
    }

    private static boolean writeSecureString(Context context, String key, String value) {
        try {
            Settings.Secure.putString(context.getContentResolver(), key, value);
        } catch (Exception ignored) {
        }
        return TextUtils.equals(readSecureString(context, key), value == null ? "" : value);
    }

    private static boolean writeSecureInt(Context context, String key, int value) {
        try {
            Settings.Secure.putInt(context.getContentResolver(), key, value);
        } catch (Exception ignored) {
        }
        return readSecureInt(context, key, Integer.MIN_VALUE) == value;
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

    private static void scheduleRecurringWork(Context context, String reason) {
        scheduleExactHeal(context, ALARM_INTERVAL_MS, "alarm_tick");
        scheduleGuardianJob(context, reason);
    }

    private static void scheduleExactHealInternal(Context context, long delayMs, String reason, int requestCode) {
        AlarmManager alarmManager = (AlarmManager) context.getApplicationContext().getSystemService(Context.ALARM_SERVICE);
        if (alarmManager == null) {
            return;
        }
        Intent intent = new Intent(context, GuardianAlarmReceiver.class);
        intent.putExtra(EXTRA_REASON, reason);
        PendingIntent pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        long triggerAt = System.currentTimeMillis() + Math.max(delayMs, 1500L);
        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent);
    }

    private static boolean shouldScheduleWakeBackstop(Context context, String reason) {
        String normalizedReason = normalizeReason(reason);
        if (!isRuntimeWakeReason(normalizedReason) && !normalizedReason.contains("package")) {
            return true;
        }
        return tryAcquireEventWindow(context, "backstop_" + normalizedReason, WAKE_BACKSTOP_THROTTLE_MS);
    }

    private static void scheduleGuardianJob(Context context, String reason) {
        Context appContext = context.getApplicationContext();
        JobScheduler scheduler = (JobScheduler) appContext.getSystemService(Context.JOB_SCHEDULER_SERVICE);
        if (scheduler == null) {
            return;
        }
        if (!supportsGuardianJobScheduling()) {
            scheduler.cancel(JOB_ID);
            return;
        }
        String normalizedReason = normalizeReason(reason);
        if (normalizedReason.contains("job_heartbeat")) {
            return;
        }
        if (isGuardianJobScheduled(scheduler)) {
            return;
        }
        JobInfo jobInfo = new JobInfo.Builder(
                JOB_ID,
                new ComponentName(appContext, GuardianJobService.class)
        )
                .setPersisted(true)
                .setPeriodic(JOB_INTERVAL_MS)
                .build();
        try {
            scheduler.schedule(jobInfo);
        } catch (Exception exception) {
            Log.w(TAG, "Unable to schedule guardian job", exception);
        }
    }

    private static boolean supportsGuardianJobScheduling() {
        // Xiaomi Android 9 repeatedly re-runs this persisted job every second after reschedule.
        // On that platform we rely on vendor boot broadcasts, core kicks, and exact alarms instead.
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q;
    }

    private static boolean isGuardianJobScheduled(JobScheduler scheduler) {
        try {
            for (JobInfo jobInfo : scheduler.getAllPendingJobs()) {
                if (jobInfo.getId() == JOB_ID) {
                    return true;
                }
            }
        } catch (Exception exception) {
            Log.w(TAG, "Unable to inspect guardian jobs", exception);
        }
        return false;
    }

    private static boolean tryAcquireEventWindow(Context context, String eventKey, long minIntervalMs) {
        long now = System.currentTimeMillis();
        long lastAt = AccessStateStore.getEventTimestamp(context.getApplicationContext(), eventKey);
        if (now - lastAt < minIntervalMs) {
            return false;
        }
        AccessStateStore.setEventTimestamp(context.getApplicationContext(), eventKey, now);
        return true;
    }

    private static boolean isRuntimeWakeReason(String normalizedReason) {
        return normalizedReason.contains("screen_on")
                || normalizedReason.contains("user_present")
                || normalizedReason.contains("user_unlocked")
                || normalizedReason.contains("dreaming_stopped")
                || normalizedReason.contains("boot_completed")
                || normalizedReason.contains("quickboot_poweron")
                || normalizedReason.contains("open_close_screen_saver");
    }

    private static String startupTriggerBucket(String reason) {
        String normalizedReason = normalizeReason(reason);
        if (normalizedReason.contains("boot_completed") || normalizedReason.contains("quickboot_poweron")) {
            return "boot";
        }
        if (normalizedReason.contains("my_package_replaced")) {
            return "self_replace";
        }
        if (normalizedReason.contains("screen_on")
                || normalizedReason.contains("user_present")
                || normalizedReason.contains("user_unlocked")
                || normalizedReason.contains("dreaming_stopped")
                || normalizedReason.contains("open_close_screen_saver")) {
            return "wake";
        }
        if (normalizedReason.contains("package")) {
            return "package";
        }
        if (normalizedReason.contains("core_kick")) {
            return normalizedReason.contains("boot") ? "boot" : "kick";
        }
        return null;
    }

    private static String normalizeReason(String reason) {
        if (TextUtils.isEmpty(reason)) {
            return "unknown";
        }
        return reason.trim().toLowerCase(Locale.US);
    }

    private static final Comparator<AppEntry> APP_COMPARATOR = (left, right) -> {
        int leftRank = left.accessibilityEnabled ? 0 : (left.hasAccessibilityService ? 1 : 2);
        int rightRank = right.accessibilityEnabled ? 0 : (right.hasAccessibilityService ? 1 : 2);
        if (leftRank != rightRank) {
            return Integer.compare(leftRank, rightRank);
        }
        return left.label.compareToIgnoreCase(right.label);
    };

    private static final class AccessibilityState {
        final AccessibilityCatalog catalog;
        final List<String> currentEnabledIds;
        final Set<String> currentEnabledSet;
        final boolean accessibilityEnabled;
        final boolean writeSecureSettingsGranted;

        AccessibilityState(
                AccessibilityCatalog catalog,
                List<String> currentEnabledIds,
                Set<String> currentEnabledSet,
                boolean accessibilityEnabled,
                boolean writeSecureSettingsGranted
        ) {
            this.catalog = catalog;
            this.currentEnabledIds = currentEnabledIds;
            this.currentEnabledSet = currentEnabledSet;
            this.accessibilityEnabled = accessibilityEnabled;
            this.writeSecureSettingsGranted = writeSecureSettingsGranted;
        }
    }

    private static final class PackageAccumulator {
        final String packageName;
        final String label;
        final boolean systemApp;
        final Drawable icon;
        boolean launchable;
        final LinkedHashSet<String> serviceIds = new LinkedHashSet<>();

        private PackageAccumulator(
                String packageName,
                String label,
                boolean systemApp,
                Drawable icon
        ) {
            this.packageName = packageName;
            this.label = label;
            this.systemApp = systemApp;
            this.icon = icon;
        }

        static PackageAccumulator create(PackageManager packageManager, String packageName) {
            try {
                ApplicationInfo applicationInfo = packageManager.getApplicationInfo(packageName, 0);
                String resolvedLabel = applicationInfo.loadLabel(packageManager).toString();
                Drawable resolvedIcon = applicationInfo.loadIcon(packageManager);
                boolean resolvedSystem = (applicationInfo.flags & (ApplicationInfo.FLAG_SYSTEM | ApplicationInfo.FLAG_UPDATED_SYSTEM_APP)) != 0;
                return new PackageAccumulator(packageName, resolvedLabel, resolvedSystem, resolvedIcon);
            } catch (Exception ignored) {
                return new PackageAccumulator(packageName, packageName, false, null);
            }
        }
    }

    private static final class AccessibilityCatalog {
        private final Map<String, String> aliases = new LinkedHashMap<>();
        private final Map<String, LinkedHashSet<String>> servicesByPackage = new LinkedHashMap<>();

        static AccessibilityCatalog build(Context context) {
            AccessibilityCatalog catalog = new AccessibilityCatalog();
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
            String canonical = AccessManagerLogic.canonicalServiceId(packageName, className);
            if (TextUtils.isEmpty(canonical)) {
                return;
            }
            LinkedHashSet<String> packageServices = servicesByPackage.get(packageName);
            if (packageServices == null) {
                packageServices = new LinkedHashSet<>();
                servicesByPackage.put(packageName, packageServices);
            }
            packageServices.add(canonical);
            addAlias(canonical, canonical);
            String classPart = canonical.substring(canonical.indexOf('/') + 1);
            ComponentName componentName = new ComponentName(packageName, classPart);
            addAlias(componentName.flattenToString(), canonical);
            addAlias(componentName.flattenToShortString(), canonical);
        }

        void addAlias(String rawId, String canonicalId) {
            if (TextUtils.isEmpty(rawId) || TextUtils.isEmpty(canonicalId)) {
                return;
            }
            aliases.put(rawId.trim(), canonicalId);
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
            String canonical = AccessManagerLogic.canonicalServiceId(
                    trimmed.substring(0, slashIndex),
                    trimmed.substring(slashIndex + 1)
            );
            if (TextUtils.isEmpty(canonical)) {
                return null;
            }
            List<String> services = servicesForPackage(trimmed.substring(0, slashIndex));
            return services.contains(canonical) ? canonical : null;
        }

        List<String> servicesForPackage(String packageName) {
            LinkedHashSet<String> services = servicesByPackage.get(packageName);
            if (services == null) {
                return Collections.emptyList();
            }
            return new ArrayList<>(services);
        }

        Set<String> servicePackages() {
            return new LinkedHashSet<>(servicesByPackage.keySet());
        }
    }

    public static final class ScanSnapshot {
        public final List<AppEntry> apps;
        public final boolean writeSecureSettingsGranted;
        public final boolean accessibilityMasterEnabled;
        public final int managedPackageCount;
        public final String lastVerifyResult;
        public final boolean adbEnabled;

        ScanSnapshot(
                List<AppEntry> apps,
                boolean writeSecureSettingsGranted,
                boolean accessibilityMasterEnabled,
                int managedPackageCount,
                String lastVerifyResult,
                boolean adbEnabled
        ) {
            this.apps = apps;
            this.writeSecureSettingsGranted = writeSecureSettingsGranted;
            this.accessibilityMasterEnabled = accessibilityMasterEnabled;
            this.managedPackageCount = managedPackageCount;
            this.lastVerifyResult = lastVerifyResult;
            this.adbEnabled = adbEnabled;
        }
    }

    public static final class ActionResult {
        public final boolean success;
        public final String verifyResult;
        public final String message;

        ActionResult(boolean success, String verifyResult, String message) {
            this.success = success;
            this.verifyResult = verifyResult;
            this.message = message;
        }
    }

    public static final class RecoveryResult {
        public final boolean success;
        public final String resultCode;

        RecoveryResult(boolean success, String resultCode) {
            this.success = success;
            this.resultCode = resultCode;
        }
    }

    public static final class LocalGrantResult {
        public final boolean success;
        public final String message;

        LocalGrantResult(boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }
}


