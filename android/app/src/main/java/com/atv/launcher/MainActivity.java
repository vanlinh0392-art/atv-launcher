/*
 * FLauncher
 * Copyright (C) 2021  Oscar Rojas
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

package com.atv.launcher;

import android.Manifest;
import android.app.Activity;
import android.app.ActivityManager;
import android.app.admin.DevicePolicyManager;
import android.content.ClipData;
import android.content.ComponentName;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ActivityInfo;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.media.tv.TvContract;
import android.media.tv.TvInputInfo;
import android.media.tv.TvInputManager;
import android.media.MediaMetadataRetriever;
import android.net.ConnectivityManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.provider.OpenableColumns;
import android.provider.Settings;
import android.speech.RecognizerIntent;
import android.text.TextUtils;
import android.util.Log;
import android.util.Pair;

import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;

import com.atv.launcher.systembridge.accessmanager.model.AppEntry;
import com.atv.launcher.systembridge.accessmanager.adb.LocalAdbBridge;
import com.atv.launcher.systembridge.accessmanager.service.AccessibilityGrantCoordinator;
import com.atv.launcher.systembridge.accessmanager.state.AccessStateStore;
import com.atv.launcher.systembridge.density.DensityBridge;
import com.atv.launcher.systembridge.dns.PrivateDnsController;
import com.atv.launcher.systembridge.shared.service.SystemBridgeCoordinator;
import com.atv.launcher.systembridge.shared.state.BridgeStateStore;
import com.atv.launcher.systembridge.shared.voice.VoiceSearchLauncher;
import com.atv.launcher.systembridge.wallpaper.VideoLibraryController;
import com.atv.launcher.systembridge.wallpaper.VideoWallpaperController;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.Serializable;
import java.nio.charset.StandardCharsets;
import java.text.DateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CompletionService;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorCompletionService;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
    private static final String TAG = "FLauncherPerf";
    private static final boolean FAST_STARTUP_ENABLED = true;
    private static final String METHOD_CHANNEL = "com.atv.launcher/method";
    private static final String APPS_EVENT_CHANNEL = "com.atv.launcher/event_apps";
    private static final String NETWORK_EVENT_CHANNEL = "com.atv.launcher/event_network";
    private static final String SYSTEM_EVENT_CHANNEL = "com.atv.launcher/event_system";
    private static final String DEBUG_BENCHMARK_ACTION = "com.atv.launcher.DEBUG_BENCHMARK";
    private static final long SYSTEM_EVENT_INTERVAL_MS = 3000L;
    private static final long INITIAL_SYSTEM_SNAPSHOT_DELAY_MS = 180L;
    private static final long APPLICATIONS_CACHE_TTL_MS = 20_000L;
    private static final int MAX_IMAGE_CACHE_ENTRIES = 128;
    private static final int MAX_IMAGE_CACHE_BYTES = 16 * 1024 * 1024;
    private static final int MAX_BANNER_WIDTH = 640;
    private static final int MAX_BANNER_HEIGHT = 360;
    private static final int MAX_ICON_WIDTH = 256;
    private static final int MAX_ICON_HEIGHT = 256;
    private static final String PRIVATE_DNS_SETTINGS_ACTION = "android.settings.PRIVATE_DNS_SETTINGS";
    private static final String FLUTTER_SHARED_PREFERENCES_NAME = "FlutterSharedPreferences";
    private static final String FLUTTER_PREFS_KEY_VIDEO_WALLPAPER_URIS = "flutter.video_wallpaper_uris";
    private static final String FLUTTER_PREFS_KEY_SEARCH_RECENT_QUERIES = "flutter.search_recent_queries";
    private static final String FLUTTER_PREFS_KEY_SEARCH_RECENT_SELECTION_IDS = "flutter.search_recent_selection_ids";
    private static final String ADB_WIFI_KEY = "adb_wifi_enabled";
    private static final int REQUEST_PICK_WALLPAPER_ASSET = 4101;
    private static final int REQUEST_PICK_WALLPAPER_FILES = 4102;
    private static final int REQUEST_PICK_WALLPAPER_FOLDER = 4103;
    private static final int REQUEST_EXPORT_BACKUP = 4104;
    private static final int REQUEST_IMPORT_BACKUP = 4105;
    private static final int REQUEST_MEDIA_PERMISSION = 4106;
    private static final int REQUEST_SPEECH_RECOGNIZER = 4107;

    private static final Object FLUTTER_ENGINE_LOCK = new Object();
    private static final Object APPLICATIONS_CACHE_LOCK = new Object();
    private static final Handler SHARED_SYSTEM_EVENT_HANDLER = new Handler(Looper.getMainLooper());
    private static final LinkedHashMap<String, byte[]> APP_IMAGE_CACHE = new LinkedHashMap<>(16, 0.75f, true);
    private static FlutterEngine sharedFlutterEngine;
    private static EventChannel.EventSink sharedSystemEventSink;
    private static VideoWallpaperController sharedVideoWallpaperController;
    private static MainActivity activeActivity;
    private static boolean sharedChannelsBound;
    private static boolean sharedDartStarted;
    private static List<Map<String, Serializable>> cachedApplications;
    private static long cachedApplicationsAtElapsedMs;
    private static int appImageCacheBytes = 0;
    private static long homeNavigationSequence;
    private static String lastNavigationReason = "";
    private static long benchmarkCommandSequence;
    private static String lastBenchmarkAction = "";
    private static String lastBenchmarkRoute = "";
    private static String lastBenchmarkSessionId = "";
    private static boolean lastBenchmarkAutoFocusDetail;
    private static boolean lastBenchmarkBypassSettingsSecurity;
    private static boolean firstBridgeSnapshotLogged;
    private static boolean firstLiteBridgeStatusLogged;
    private static boolean firstFullBridgeStatusLogged;
    private static final Runnable sharedInitialSystemSnapshotRunnable =
            MainActivity::emitInitialSystemSnapshotForActiveActivity;
    private static final Runnable sharedSystemEventRunnable = new Runnable() {
        @Override
        public void run() {
            if (sharedSystemEventSink == null) {
                return;
            }
            MainActivity activity = activeActivity;
            if (activity != null) {
                sharedSystemEventSink.success(activity.buildSystemBridgeStatusLite());
            }
            SHARED_SYSTEM_EVENT_HANDLER.postDelayed(this, SYSTEM_EVENT_INTERVAL_MS);
        }
    };

    private final long activityBootstrapStartedAtNanos = System.nanoTime();
    private MethodChannel.Result pendingWallpaperAssetResult;
    private MethodChannel.Result pendingWallpaperFilesResult;
    private MethodChannel.Result pendingWallpaperFolderResult;
    private MethodChannel.Result pendingBackupExportResult;
    private MethodChannel.Result pendingBackupImportResult;
    private MethodChannel.Result pendingMediaPermissionResult;
    private MethodChannel.Result pendingSpeechRecognizerResult;
    private String pendingWallpaperAssetKind = "mixed";
    private String pendingBackupExportContent = "";
    private String pendingBackupExportFileName = "atv-launcher-backup.json";
    private String pendingBackupImportMode = "import";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        if (recordBenchmarkCommand(getIntent())) {
            // Keep benchmark state so Flutter can consume it from the first lite snapshot.
        }
        if (shouldRedirectNonHomeEntry(getIntent())
                && moveExistingLauncherTaskToFront("onCreate")) {
            finish();
            return;
        }
        super.onCreate(savedInstanceState);
    }

    @Override
    public FlutterEngine provideFlutterEngine(@NonNull Context context) {
        synchronized (FLUTTER_ENGINE_LOCK) {
            if (sharedFlutterEngine == null) {
                sharedFlutterEngine = new FlutterEngine(context.getApplicationContext());
            }
            return sharedFlutterEngine;
        }
    }

    @Override
    public boolean shouldDestroyEngineWithHost() {
        return false;
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        activeActivity = this;
        synchronized (FLUTTER_ENGINE_LOCK) {
            if (sharedVideoWallpaperController == null) {
                sharedVideoWallpaperController = new VideoWallpaperController(
                        getApplicationContext(),
                        flutterEngine.getRenderer()
                );
            }
            bindSharedFlutterChannels(flutterEngine);
            if (!sharedDartStarted && !flutterEngine.getDartExecutor().isExecutingDart()) {
                GeneratedPluginRegistrant.registerWith(flutterEngine);
                flutterEngine.getDartExecutor().executeDartEntrypoint(
                        DartExecutor.DartEntrypoint.createDefault()
                );
            }
            sharedDartStarted = true;
        }
    }

    private void bindSharedFlutterChannels(@NonNull FlutterEngine flutterEngine) {
        if (sharedChannelsBound) {
            return;
        }

        BinaryMessenger messenger = flutterEngine.getDartExecutor().getBinaryMessenger();

        new MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler((call, result) -> {
            MainActivity activity = activeActivity;
            if (activity == null) {
                result.error("activity_unavailable", "Launcher activity is not attached", null);
                return;
            }
            try {
                activity.handleMethodCall(call, result);
            } catch (Exception exception) {
                result.error("native_error", exception.toString(), null);
            }
        });

        new EventChannel(messenger, APPS_EVENT_CHANNEL).setStreamHandler(
                new LauncherAppsEventStreamHandler(getApplicationContext()));

        new EventChannel(messenger, NETWORK_EVENT_CHANNEL).setStreamHandler(
                new NetworkEventStreamHandler(getApplicationContext()));

        new EventChannel(messenger, SYSTEM_EVENT_CHANNEL).setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                sharedSystemEventSink = events;
                SHARED_SYSTEM_EVENT_HANDLER.removeCallbacks(sharedInitialSystemSnapshotRunnable);
                SHARED_SYSTEM_EVENT_HANDLER.removeCallbacks(sharedSystemEventRunnable);
                SHARED_SYSTEM_EVENT_HANDLER.postDelayed(
                        sharedInitialSystemSnapshotRunnable,
                        INITIAL_SYSTEM_SNAPSHOT_DELAY_MS
                );
                SHARED_SYSTEM_EVENT_HANDLER.postDelayed(
                        sharedSystemEventRunnable,
                        SYSTEM_EVENT_INTERVAL_MS
                );
            }

            @Override
            public void onCancel(Object arguments) {
                sharedSystemEventSink = null;
                SHARED_SYSTEM_EVENT_HANDLER.removeCallbacks(sharedInitialSystemSnapshotRunnable);
                SHARED_SYSTEM_EVENT_HANDLER.removeCallbacks(sharedSystemEventRunnable);
            }
        });

        sharedChannelsBound = true;
    }

    @Override
    protected void onStart() {
        super.onStart();
        activeActivity = this;
        if (sharedVideoWallpaperController != null) {
            sharedVideoWallpaperController.onStart();
        }
        SystemBridgeCoordinator.startCore(getApplicationContext(), "activity_start");
    }

    @Override
    protected void onResume() {
        super.onResume();
        activeActivity = this;
        if (sharedVideoWallpaperController != null) {
            sharedVideoWallpaperController.onStart();
        }
        pruneBackgroundLauncherTasks("onResume");
        SystemBridgeCoordinator.startCore(getApplicationContext(), "activity_resume");
    }

    @Override
    protected void onStop() {
        if (sharedVideoWallpaperController != null) {
            sharedVideoWallpaperController.onStop();
        }
        super.onStop();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        if (recordBenchmarkCommand(intent)) {
            return;
        }
        if (shouldRedirectNonHomeEntry(intent)) {
            recordHomeNavigation("launcher_reentry");
            return;
        }
        if (isHomeIntent(intent)) {
            recordHomeNavigation("home_reentry");
        }
    }

    @Override
    protected void onDestroy() {
        if (activeActivity == this) {
            activeActivity = null;
        }
        super.onDestroy();
    }

    @Override
    @Deprecated
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQUEST_PICK_WALLPAPER_ASSET) {
            handleWallpaperPickerResult(resultCode == Activity.RESULT_OK && data != null ? data.getData() : null);
            return;
        }
        if (requestCode == REQUEST_PICK_WALLPAPER_FILES) {
            handleWallpaperFilesPickerResult(resultCode == Activity.RESULT_OK ? extractUris(data) : new ArrayList<>());
            return;
        }
        if (requestCode == REQUEST_PICK_WALLPAPER_FOLDER) {
            handleWallpaperFolderPickerResult(resultCode == Activity.RESULT_OK && data != null ? data.getData() : null);
            return;
        }
        if (requestCode == REQUEST_EXPORT_BACKUP) {
            handleBackupExportResult(resultCode == Activity.RESULT_OK && data != null ? data.getData() : null);
            return;
        }
        if (requestCode == REQUEST_IMPORT_BACKUP) {
            handleBackupImportResult(resultCode == Activity.RESULT_OK && data != null ? data.getData() : null);
            return;
        }
        if (requestCode == REQUEST_SPEECH_RECOGNIZER) {
            handleSpeechRecognizerResult(resultCode, data);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_MEDIA_PERMISSION) {
            boolean granted = grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED;
            handleMediaPermissionResult(granted);
        }
    }

    private void handleMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "getApplications" -> result.success(getApplications());
            case "getApplicationBanner" -> result.success(getApplicationBanner((String) call.arguments));
            case "getApplicationIcon" -> result.success(getApplicationIcon((String) call.arguments));
            case "applicationExists" -> result.success(applicationExists((String) call.arguments));
            case "launchActivityFromAction" -> result.success(launchActivityFromAction((String) call.arguments));
            case "launchApp" -> result.success(launchApp((String) call.arguments));
            case "openSettings" -> result.success(openSettings());
            case "openAppInfo" -> result.success(openAppInfo((String) call.arguments));
            case "uninstallApp" -> result.success(uninstallApp((String) call.arguments));
            case "isDefaultLauncher" -> result.success(isDefaultLauncher());
            case "checkForGetContentAvailability" -> result.success(checkForGetContentAvailability());
            case "startAmbientMode" -> result.success(startAmbientMode());
            case "getActiveNetworkInformation" -> result.success(getActiveNetworkInformation());
            case "getSystemBridgeStatusLite" -> result.success(buildSystemBridgeStatusLite());
            case "getSystemBridgeStatus" -> result.success(buildSystemBridgeStatus());
            case "getProvisioningChecklist" -> result.success(buildProvisioningChecklist());
            case "getAdbAutomationStatus" -> result.success(SystemBridgeCoordinator.buildAdbAutomationStatus(this));
            case "getAccessibilityManagerSnapshot" -> result.success(buildAccessibilityManagerSnapshot());
            case "setVoiceMode" -> result.success(setVoiceMode(call));
            case "setVoiceInterceptEnabled" -> result.success(setVoiceInterceptEnabled(call));
            case "startKeyLearning" -> result.success(startKeyLearning());
            case "resetVoiceMapping" -> result.success(resetVoiceMapping());
            case "testVoiceSearch" -> result.success(testVoiceSearch());
            case "openAccessibilitySettings" -> result.success(openSpecificSettingsPage("accessibility"));
            case "openSpecificAndroidSettingsPage" -> result.success(openSpecificSettingsPage((String) call.arguments));
            case "repairAccessibility" -> result.success(repairAccessibility());
            case "grantWriteSecureSettingsWithLocalAdb" -> result.success(grantWriteSecureSettingsWithLocalAdb());
            case "setAdbAutomationPolicy" -> result.success(setAdbAutomationPolicy(call));
            case "setAdbEnabledNow" -> result.success(setAdbEnabledNow(call));
            case "runProvisioningAction" -> result.success(runProvisioningAction(call));
            case "setManagedAccessibility" -> result.success(setManagedAccessibility(call));
            case "getDensityStatus" -> result.success(DensityBridge.getStatus(this));
            case "applyDensity" -> result.success(applyDensity(call));
            case "resetDensity" -> result.success(DensityBridge.resetDensity(this));
            case "getPrivateDnsStatus" -> result.success(PrivateDnsController.getStatus(this));
            case "applyPrivateDns" -> result.success(applyPrivateDns(call));
            case "resetPrivateDns" -> result.success(PrivateDnsController.reset(this));
            case "getFileAccessStatus" -> result.success(VideoLibraryController.getFileAccessStatus(this));
            case "requestMediaReadPermission" -> requestMediaReadPermission(result);
            case "prepareLauncherUpdateInstall" -> result.success(prepareLauncherUpdateInstall());
            case "installDownloadedApk" -> result.success(installDownloadedApk(call));
            case "browseLocalVideoLibrary" -> result.success(browseLocalVideoLibrary(call));
            case "getTvInputs" -> result.success(getTvInputs());
            case "launchTvInput" -> result.success(launchTvInput(call));
            case "querySearchableMedia" -> result.success(querySearchableMedia());
            case "launchMediaUri" -> result.success(launchMediaUri(call));
            case "startSpeechRecognizer" -> startSpeechRecognizer(result);
            case "pickWallpaperAsset" -> pickWallpaperAsset(call, result);
            case "pickWallpaperFiles" -> pickWallpaperFiles(result);
            case "pickWallpaperFolder" -> pickWallpaperFolder(result);
            case "setWallpaperMode" -> result.success(setWallpaperMode((String) call.arguments));
            case "setVideoWallpaperOptions" -> result.success(setVideoWallpaperOptions(call));
            case "setVideoWallpaperPlaybackSuppressed" -> result.success(setVideoWallpaperPlaybackSuppressed(call));
            case "exportSettingsBackup" -> exportSettingsBackup(call, result);
            case "importSettingsBackup" -> importSettingsBackup(result, "import");
            case "previewBackup" -> importSettingsBackup(result, "preview");
            case "recordBackupRestoreResult" -> result.success(recordBackupRestoreResult(call));
            case "getVideoWallpaperTextureId" -> result.success(
                    sharedVideoWallpaperController == null
                            ? -1L
                            : sharedVideoWallpaperController.ensureTextureId());
            case "getDiagnosticsReport" -> result.success(SystemBridgeCoordinator.buildStatusReport(this));
            case "repairSharedPreferences" -> result.success(repairSharedPreferences());
            case "clearLauncherSharedPreferences" -> result.success(clearLauncherSharedPreferences());
            default -> throw new IllegalArgumentException("Unsupported method: " + call.method);
        }
    }

    private Map<String, Serializable> repairSharedPreferences() {
        SharedPreferences sharedPreferences =
                getSharedPreferences(FLUTTER_SHARED_PREFERENCES_NAME, MODE_PRIVATE);
        SharedPreferences.Editor editor = sharedPreferences.edit();
        List<String> removedKeys = new ArrayList<>();
        for (String key : Arrays.asList(
                FLUTTER_PREFS_KEY_VIDEO_WALLPAPER_URIS,
                FLUTTER_PREFS_KEY_SEARCH_RECENT_QUERIES,
                FLUTTER_PREFS_KEY_SEARCH_RECENT_SELECTION_IDS)) {
            if (sharedPreferences.contains(key)) {
                editor.remove(key);
                removedKeys.add(key);
            }
        }
        boolean committed = editor.commit();
        Map<String, Serializable> result = new HashMap<>();
        result.put("repaired", committed);
        result.put("removedKeys", new ArrayList<>(removedKeys));
        return result;
    }

    private boolean clearLauncherSharedPreferences() {
        return getSharedPreferences(FLUTTER_SHARED_PREFERENCES_NAME, MODE_PRIVATE)
                .edit()
                .clear()
                .commit();
    }

    private List<Map<String, Serializable>> getApplications() {
        long startedAt = System.nanoTime();
        List<Map<String, Serializable>> cached = getCachedApplications();
        if (cached != null) {
            logPerf("getApplications cacheHit count=" + cached.size(), startedAt);
            return cached;
        }

        ExecutorService executor = Executors.newFixedThreadPool(4);
        CompletionService<Pair<Boolean, List<ResolveInfo>>> queryIntentActivitiesCompletionService =
                new ExecutorCompletionService<>(executor);
        queryIntentActivitiesCompletionService.submit(() ->
                Pair.create(false, queryIntentActivities(false)));
        queryIntentActivitiesCompletionService.submit(() ->
                Pair.create(true, queryIntentActivities(true)));
        List<ResolveInfo> tvActivitiesInfo = null;
        List<ResolveInfo> nonTvActivitiesInfo = null;

        int completed = 0;
        while (completed < 2) {
            try {
                Pair<Boolean, List<ResolveInfo>> activitiesInfo = queryIntentActivitiesCompletionService.take().get();
                if (!activitiesInfo.first) {
                    tvActivitiesInfo = activitiesInfo.second;
                } else {
                    nonTvActivitiesInfo = activitiesInfo.second;
                }
            } catch (InterruptedException | ExecutionException ignored) {
            } finally {
                completed += 1;
            }
        }

        CompletionService<Map<String, Serializable>> completionService = new ExecutorCompletionService<>(executor);
        List<Map<String, Serializable>> applications = new ArrayList<>(
                tvActivitiesInfo.size() + nonTvActivitiesInfo.size());

        boolean settingsPresent = false;
        int appCount = 0;
        for (ResolveInfo tvActivityInfo : tvActivitiesInfo) {
            if (!settingsPresent) {
                settingsPresent = tvActivityInfo.activityInfo.packageName.equals("com.android.tv.settings");
            }
            completionService.submit(() -> buildAppMap(tvActivityInfo.activityInfo, false, null));
            appCount += 1;
        }

        for (ResolveInfo nonTvActivityInfo : nonTvActivitiesInfo) {
            boolean nonDuplicate = true;
            if (!settingsPresent) {
                settingsPresent = nonTvActivityInfo.activityInfo.packageName.equals("com.android.settings");
            }
            for (ResolveInfo tvActivityInfo : tvActivitiesInfo) {
                if (tvActivityInfo.activityInfo.packageName.equals(nonTvActivityInfo.activityInfo.packageName)) {
                    nonDuplicate = false;
                    break;
                }
            }
            if (nonDuplicate) {
                appCount += 1;
                completionService.submit(() -> buildAppMap(nonTvActivityInfo.activityInfo, true, null));
            }
        }

        while (appCount > 0) {
            try {
                Future<Map<String, Serializable>> appMap = completionService.take();
                applications.add(appMap.get());
            } catch (InterruptedException | ExecutionException ignored) {
            } finally {
                appCount -= 1;
            }
        }

        executor.shutdown();

        if (!settingsPresent) {
            PackageManager packageManager = getPackageManager();
            Intent settingsIntent = new Intent(Settings.ACTION_SETTINGS);
            ActivityInfo activityInfo = settingsIntent.resolveActivityInfo(packageManager, 0);
            if (activityInfo != null) {
                applications.add(buildAppMap(activityInfo, false, Settings.ACTION_SETTINGS));
            }
        }

        putCachedApplications(applications);
        logPerf("getApplications count=" + applications.size(), startedAt);
        return cloneApplications(applications);
    }

    private byte[] getApplicationBanner(String packageName) {
        long startedAt = System.nanoTime();
        String cacheKey = buildAppImageCacheKey("banner", packageName);
        byte[] cachedImageBytes = getCachedAppImage(cacheKey);
        if (cachedImageBytes != null) {
            logPerf("getApplicationBanner cacheHit package=" + packageName + " bytes=" + cachedImageBytes.length, startedAt);
            return cachedImageBytes;
        }

        byte[] imageBytes = new byte[0];
        PackageManager packageManager = getPackageManager();
        try {
            ApplicationInfo info = packageManager.getApplicationInfo(packageName, 0);
            Drawable drawable = info.loadBanner(packageManager);
            if (drawable != null) {
                imageBytes = drawableToByteArray(drawable, MAX_BANNER_WIDTH, MAX_BANNER_HEIGHT, true);
            }
        } catch (PackageManager.NameNotFoundException ignored) {
        }
        putCachedAppImage(cacheKey, imageBytes);
        logPerf("getApplicationBanner package=" + packageName + " bytes=" + imageBytes.length, startedAt);
        return imageBytes;
    }

    private byte[] getApplicationIcon(String packageName) {
        long startedAt = System.nanoTime();
        String cacheKey = buildAppImageCacheKey("icon", packageName);
        byte[] cachedImageBytes = getCachedAppImage(cacheKey);
        if (cachedImageBytes != null) {
            logPerf("getApplicationIcon cacheHit package=" + packageName + " bytes=" + cachedImageBytes.length, startedAt);
            return cachedImageBytes;
        }

        byte[] imageBytes = new byte[0];
        PackageManager packageManager = getPackageManager();
        try {
            ApplicationInfo info = packageManager.getApplicationInfo(packageName, 0);
            Drawable drawable = info.loadIcon(packageManager);
            if (drawable != null) {
                imageBytes = drawableToByteArray(drawable, MAX_ICON_WIDTH, MAX_ICON_HEIGHT, false);
            }
        } catch (PackageManager.NameNotFoundException ignored) {
        }
        putCachedAppImage(cacheKey, imageBytes);
        logPerf("getApplicationIcon package=" + packageName + " bytes=" + imageBytes.length, startedAt);
        return imageBytes;
    }

    static void clearAppImageCacheForPackage(String packageName) {
        invalidateApplicationsCacheStatic();
        synchronized (APP_IMAGE_CACHE) {
            List<String> keysToRemove = new ArrayList<>();
            for (String key : APP_IMAGE_CACHE.keySet()) {
                if (key.startsWith("banner:" + packageName + ":") || key.startsWith("icon:" + packageName + ":")) {
                    keysToRemove.add(key);
                }
            }
            for (String key : keysToRemove) {
                byte[] bytes = APP_IMAGE_CACHE.remove(key);
                if (bytes != null) {
                    appImageCacheBytes -= bytes.length;
                }
            }
        }
    }

    void clearAppImageCache(String packageName) {
        clearAppImageCacheForPackage(packageName);
    }

    private String buildAppImageCacheKey(String type, String packageName) {
        PackageManager packageManager = getPackageManager();
        try {
            PackageInfo packageInfo = packageManager.getPackageInfo(packageName, 0);
            long versionCode = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
                    ? packageInfo.getLongVersionCode()
                    : packageInfo.versionCode;
            return type + ":" + packageName + ":" + versionCode + ":" + packageInfo.lastUpdateTime;
        } catch (PackageManager.NameNotFoundException ignored) {
            return type + ":" + packageName + ":missing";
        }
    }

    private byte[] getCachedAppImage(String cacheKey) {
        synchronized (APP_IMAGE_CACHE) {
            return APP_IMAGE_CACHE.get(cacheKey);
        }
    }

    private void putCachedAppImage(String cacheKey, byte[] imageBytes) {
        if (imageBytes.length > MAX_IMAGE_CACHE_BYTES / 2) {
            return;
        }
        synchronized (APP_IMAGE_CACHE) {
            byte[] previous = APP_IMAGE_CACHE.put(cacheKey, imageBytes);
            if (previous != null) {
                appImageCacheBytes -= previous.length;
            }
            appImageCacheBytes += imageBytes.length;
            trimAppImageCache();
        }
    }

    private void trimAppImageCache() {
        while (APP_IMAGE_CACHE.size() > MAX_IMAGE_CACHE_ENTRIES || appImageCacheBytes > MAX_IMAGE_CACHE_BYTES) {
            String eldestKey = APP_IMAGE_CACHE.keySet().iterator().next();
            byte[] eldest = APP_IMAGE_CACHE.remove(eldestKey);
            if (eldest != null) {
                appImageCacheBytes -= eldest.length;
            }
        }
    }

    private static void invalidateApplicationsCacheStatic() {
        synchronized (APPLICATIONS_CACHE_LOCK) {
            cachedApplications = null;
            cachedApplicationsAtElapsedMs = 0L;
        }
    }

    private void invalidateApplicationsCache() {
        invalidateApplicationsCacheStatic();
    }

    private List<Map<String, Serializable>> getCachedApplications() {
        synchronized (APPLICATIONS_CACHE_LOCK) {
            if (cachedApplications == null) {
                return null;
            }
            if (SystemClock.elapsedRealtime() - cachedApplicationsAtElapsedMs > APPLICATIONS_CACHE_TTL_MS) {
                cachedApplications = null;
                cachedApplicationsAtElapsedMs = 0L;
                return null;
            }
            return cloneApplications(cachedApplications);
        }
    }

    private void putCachedApplications(List<Map<String, Serializable>> applications) {
        synchronized (APPLICATIONS_CACHE_LOCK) {
            cachedApplications = cloneApplications(applications);
            cachedApplicationsAtElapsedMs = SystemClock.elapsedRealtime();
        }
    }

    private List<Map<String, Serializable>> cloneApplications(List<Map<String, Serializable>> applications) {
        List<Map<String, Serializable>> copy = new ArrayList<>(applications.size());
        for (Map<String, Serializable> application : applications) {
            copy.add(new LinkedHashMap<>(application));
        }
        return copy;
    }

    private void logPerf(String label, long startedAtNanos) {
        if ((getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) == 0) {
            return;
        }
        long elapsedMs = (System.nanoTime() - startedAtNanos) / 1_000_000L;
        Log.d(TAG, label + " elapsedMs=" + elapsedMs);
    }

    private boolean applicationExists(String packageName) {
        int flags = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N
                ? PackageManager.MATCH_UNINSTALLED_PACKAGES
                : PackageManager.GET_UNINSTALLED_PACKAGES;
        try {
            getPackageManager().getApplicationInfo(packageName, flags);
            return true;
        } catch (PackageManager.NameNotFoundException ignored) {
            return false;
        }
    }

    private static List<ResolveInfo> queryIntentActivities(Context context, boolean sideloaded) {
        String category = sideloaded ? Intent.CATEGORY_LAUNCHER : Intent.CATEGORY_LEANBACK_LAUNCHER;
        Intent intent = new Intent(Intent.ACTION_MAIN).addCategory(category);
        return context.getPackageManager().queryIntentActivities(intent, 0);
    }

    private List<ResolveInfo> queryIntentActivities(boolean sideloaded) {
        return queryIntentActivities(this, sideloaded);
    }

    private static Map<String, Serializable> buildAppMap(
            Context context,
            ActivityInfo activityInfo,
            boolean sideloaded,
            String action
    ) {
        PackageManager packageManager = context.getPackageManager();
        String applicationName = activityInfo.loadLabel(packageManager).toString();
        String applicationVersionName = "";
        try {
            applicationVersionName = packageManager.getPackageInfo(activityInfo.packageName, 0).versionName;
        } catch (PackageManager.NameNotFoundException ignored) {
        }

        Map<String, Serializable> appMap = new HashMap<>();
        appMap.put("name", applicationName);
        appMap.put("packageName", activityInfo.packageName);
        appMap.put("version", applicationVersionName);
        appMap.put("sideloaded", sideloaded);
        if (action != null) {
            appMap.put("action", action);
        }
        return appMap;
    }

    private Map<String, Serializable> buildAppMap(ActivityInfo activityInfo, boolean sideloaded, String action) {
        return buildAppMap(this, activityInfo, sideloaded, action);
    }

    static Map<String, Serializable> getApplicationForPackage(Context context, String packageName) {
        for (ResolveInfo resolveInfo : queryIntentActivities(context, false)) {
            if (TextUtils.equals(resolveInfo.activityInfo.packageName, packageName)) {
                return buildAppMap(context, resolveInfo.activityInfo, false, null);
            }
        }
        for (ResolveInfo resolveInfo : queryIntentActivities(context, true)) {
            if (TextUtils.equals(resolveInfo.activityInfo.packageName, packageName)) {
                return buildAppMap(context, resolveInfo.activityInfo, true, null);
            }
        }
        return new HashMap<>();
    }

    Map<String, Serializable> getApplication(String packageName) {
        return getApplicationForPackage(this, packageName);
    }

    private boolean launchActivityFromAction(String action) {
        return tryStartActivity(new Intent(action));
    }

    private boolean launchApp(String packageName) {
        PackageManager packageManager = getPackageManager();
        Intent intent = packageManager.getLeanbackLaunchIntentForPackage(packageName);
        if (intent == null) {
            intent = packageManager.getLaunchIntentForPackage(packageName);
        }
        return tryStartActivity(intent);
    }

    private boolean openSettings() {
        return launchActivityFromAction(Settings.ACTION_SETTINGS);
    }

    private boolean openAppInfo(String packageName) {
        Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", packageName, null));
        return tryStartActivity(intent);
    }

    private boolean uninstallApp(String packageName) {
        Intent intent = new Intent(Intent.ACTION_DELETE)
                .setData(Uri.fromParts("package", packageName, null));
        return tryStartActivity(intent);
    }

    private boolean checkForGetContentAvailability() {
        List<ResolveInfo> intentActivities = getPackageManager().queryIntentActivities(
                new Intent(Intent.ACTION_GET_CONTENT, null).setTypeAndNormalize("image/*"),
                0);
        return !intentActivities.isEmpty();
    }

    private boolean isDefaultLauncher() {
        Intent intent = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
        ResolveInfo defaultLauncher = getPackageManager().resolveActivity(intent, 0);
        return defaultLauncher != null
                && defaultLauncher.activityInfo != null
                && defaultLauncher.activityInfo.packageName.equals(getPackageName());
    }

    private boolean startAmbientMode() {
        Intent intent = new Intent(Intent.ACTION_MAIN)
                .setClassName("com.android.systemui", "com.android.systemui.Somnambulator");
        return tryStartActivity(intent);
    }

    private Map<String, Object> getActiveNetworkInformation() {
        ConnectivityManager connectivityManager = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return NetworkUtils.getNetworkInformation(this, connectivityManager.getActiveNetwork());
        }
        return NetworkUtils.getNetworkInformation(this, connectivityManager.getActiveNetworkInfo());
    }

    private Map<String, Object> buildSystemBridgeStatusLite() {
        long startedAt = System.nanoTime();
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("snapshotKind", "lite");
        map.put("navigation", buildNavigationStatus());
        if (isDebuggableBuild()) {
            map.put("benchmarkCommand", buildBenchmarkCommandStatus());
        }
        map.put("voice", buildVoiceStatus());
        map.put("systemCore", buildSystemCoreStatus());
        map.put("adbAutomation", SystemBridgeCoordinator.buildAdbAutomationStatus(this));
        map.put("homeGuard", SystemBridgeCoordinator.buildHomeGuardStatus(this));
        map.put("density", DensityBridge.getStatus(this));
        map.put("privateDns", PrivateDnsController.getStatus(this));
        map.put(
                "wallpaper",
                sharedVideoWallpaperController != null
                        ? sharedVideoWallpaperController.getStatus()
                        : new LinkedHashMap<>()
        );
        map.put("provisioning", buildProvisioningSummary());
        map.put("updates", buildUpdateStatus());
        map.put("memory", buildMemoryStatus());
        map.put("fileAccess", VideoLibraryController.getFileAccessStatus(this));
        map.put("backup", buildBackupStatus());
        if (!firstLiteBridgeStatusLogged) {
            firstLiteBridgeStatusLogged = true;
            logPerf("time_to_lite_bridge_status", startedAt);
        }
        return map;
    }

    private Map<String, Object> buildSystemBridgeStatus() {
        long startedAt = System.nanoTime();
        Map<String, Object> map = buildSystemBridgeStatusLite();
        map.put("snapshotKind", "full");
        map.put("provisioning", buildProvisioningChecklist());
        map.put("diagnosticsReport", SystemBridgeCoordinator.buildStatusReport(this));
        if (!firstFullBridgeStatusLogged) {
            firstFullBridgeStatusLogged = true;
            logPerf("time_to_full_bridge_status", startedAt);
        }
        return map;
    }

    private Map<String, Object> buildVoiceStatus() {
        Map<String, Object> voice = new LinkedHashMap<>();
        String ownServiceId = SystemBridgeCoordinator.ownAccessibilityServiceId(this);
        Set<String> enabledServices = readEnabledAccessibilityServices();
        int mode = BridgeStateStore.getMode(this);
        voice.put("mode", mode);
        voice.put("modeLabel", SystemBridgeCoordinator.modeLabel(this, mode));
        voice.put("keyCode", BridgeStateStore.getKeyCode(this));
        voice.put("defaultKeySummary", BridgeStateStore.defaultVoiceKeySummary());
        voice.put("learningMode", BridgeStateStore.isLearningMode(this));
        voice.put("interceptEnabled", BridgeStateStore.isVoiceInterceptEnabled(this));
        voice.put("accessibilityEnabled", enabledServices.contains(ownServiceId));
        voice.put("serviceId", ownServiceId);
        voice.put("lastRepairResult", BridgeStateStore.getLastAccessibilityRepairResult(this));
        voice.put("missingServices", new ArrayList<>(BridgeStateStore.getLastMissingServiceIds(this)));
        voice.put("writeSecureSettingsGranted", hasPermission(android.Manifest.permission.WRITE_SECURE_SETTINGS));
        voice.put("health", deriveAccessibilityHealth(enabledServices.contains(ownServiceId)));
        return voice;
    }

    private Map<String, Object> buildSystemCoreStatus() {
        Map<String, Object> system = new LinkedHashMap<>();
        boolean ownAccessibilityEnabled = readEnabledAccessibilityServices()
                .contains(SystemBridgeCoordinator.ownAccessibilityServiceId(this));
        system.put("adbEnabled", readGlobalInt(Settings.Global.ADB_ENABLED, 0) == 1);
        system.put("adbWifiEnabled", readGlobalInt(ADB_WIFI_KEY, 0) == 1);
        system.put("batteryOptimizationIgnored", SystemBridgeCoordinator.isIgnoringBatteryOptimizations(this));
        system.put("deviceOwner", isDeviceOwner());
        system.put("accessibilityMasterEnabled", readSecureInt(Settings.Secure.ACCESSIBILITY_ENABLED, 0) == 1);
        system.put("coreServiceHealth", deriveAccessibilityHealth(ownAccessibilityEnabled));
        system.put("lastRecoveryReason", BridgeStateStore.getLastRecoveryReason(this));
        system.put("lastSuccessAt", BridgeStateStore.getLastSuccessAt(this));
        system.put("lastSuccessAtText", formatTime(BridgeStateStore.getLastSuccessAt(this)));
        system.put("lastRestoreAtText", formatTime(BridgeStateStore.getLastAccessibilityRestoreAt(this)));
        system.put("lastProvisioningVerifyAtText", formatTime(BridgeStateStore.getLastProvisioningVerifyAt(this)));
        system.put("lastRepairResult", BridgeStateStore.getLastAccessibilityRepairResult(this));
        system.put("missingServices", new ArrayList<>(BridgeStateStore.getLastMissingServiceIds(this)));
        system.put("managedAccessibilityPackages", AccessStateStore.getManagedPackageNames(this).size());
        system.put("accessManagerVerifyResult", AccessStateStore.getLastVerifyResult(this));
        system.put("adbPolicy", BridgeStateStore.getAdbAutomationPolicy(this));
        system.put("adbDisableOnSleep", BridgeStateStore.isAdbDisableOnSleepEnabled(this));
        system.put("adbLastAppliedAtText", formatTime(BridgeStateStore.getLastAdbPolicyAppliedAt(this)));
        system.put("adbLastReason", BridgeStateStore.getLastAdbPolicyReason(this));
        system.put("adbLastState", BridgeStateStore.getLastAdbPolicyState(this));
        return system;
    }

    private Map<String, Object> buildBackupStatus() {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("lastExportName", BridgeStateStore.getLastBackupExportName(this));
        map.put("lastImportName", BridgeStateStore.getLastBackupImportName(this));
        map.put("lastRestoreSummary", BridgeStateStore.getLastBackupRestoreSummary(this));
        map.put("lastRestoreAt", BridgeStateStore.getLastBackupRestoreAt(this));
        map.put("lastRestoreAtText", formatTime(BridgeStateStore.getLastBackupRestoreAt(this)));
        return map;
    }

    private Map<String, Object> buildMemoryStatus() {
        Map<String, Object> memory = new LinkedHashMap<>();
        ActivityManager activityManager = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
        ActivityManager.MemoryInfo info = new ActivityManager.MemoryInfo();
        if (activityManager != null) {
            activityManager.getMemoryInfo(info);
        }
        long totalBytes = Math.max(info.totalMem, 0L);
        long availableBytes = Math.max(info.availMem, 0L);
        double usedPercent = totalBytes <= 0L
                ? 0d
                : ((double) (totalBytes - availableBytes) * 100d) / (double) totalBytes;
        memory.put("availBytes", availableBytes);
        memory.put("totalBytes", totalBytes);
        memory.put("usedPercent", usedPercent);
        memory.put("lowMemory", info.lowMemory);
        return memory;
    }

    private Map<String, Object> buildAccessibilityManagerSnapshot() {
        AccessibilityGrantCoordinator.ScanSnapshot snapshot = AccessibilityGrantCoordinator.loadSnapshot(this);
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("writeSecureSettingsGranted", snapshot.writeSecureSettingsGranted);
        map.put("accessibilityMasterEnabled", snapshot.accessibilityMasterEnabled);
        map.put("managedPackageCount", snapshot.managedPackageCount);
        map.put("lastVerifyResult", snapshot.lastVerifyResult);
        map.put("adbEnabled", snapshot.adbEnabled);
        List<Map<String, Object>> apps = new ArrayList<>();
        for (AppEntry app : snapshot.apps) {
            Map<String, Object> appMap = new LinkedHashMap<>();
            appMap.put("packageName", app.packageName);
            appMap.put("label", app.label);
            appMap.put("systemApp", app.systemApp);
            appMap.put("launchable", app.launchable);
            appMap.put("hasAccessibilityService", app.hasAccessibilityService);
            appMap.put("accessibilityEnabled", app.accessibilityEnabled);
            appMap.put("managed", app.managed);
            appMap.put("serviceIds", app.serviceIds);
            apps.add(appMap);
        }
        map.put("apps", apps);
        return map;
    }

    private ProvisioningEvaluation evaluateProvisioning() {
        List<Map<String, Object>> requirements = new ArrayList<>();
        requirements.add(buildPermissionItem(android.Manifest.permission.WRITE_SECURE_SETTINGS,
                isDeclaredPermission(android.Manifest.permission.WRITE_SECURE_SETTINGS),
                hasPermission(android.Manifest.permission.WRITE_SECURE_SETTINGS),
                "ADB one-time grant or device owner",
                "required"));
        requirements.add(buildPermissionItem(android.Manifest.permission.WRITE_SETTINGS,
                isDeclaredPermission(android.Manifest.permission.WRITE_SETTINGS),
                Settings.System.canWrite(this),
                "Open write settings page if missing",
                "recommended"));
        requirements.add(buildPermissionItem(android.Manifest.permission.SYSTEM_ALERT_WINDOW,
                isDeclaredPermission(android.Manifest.permission.SYSTEM_ALERT_WINDOW),
                Settings.canDrawOverlays(this),
                "Optional for future overlay tools",
                "optional"));
        requirements.add(buildPermissionItem("ignore_battery_optimizations",
                isDeclaredPermission(android.Manifest.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS),
                SystemBridgeCoordinator.isIgnoringBatteryOptimizations(this),
                "Recommended for Xiaomi stability",
                "recommended"));
        requirements.add(buildPermissionItem("post_notifications",
                isDeclaredPermission(android.Manifest.permission.POST_NOTIFICATIONS),
                !requiresNotificationRuntimePermission() || areNotificationsEnabled(),
                "Foreground service notification visibility",
                "recommended"));
        requirements.add(buildPermissionItem("device_owner",
                true,
                isDeviceOwner(),
                "Optional enhancement path for fresh/reset devices",
                "optional"));
        requirements.add(buildPermissionItem("adb_enabled",
                true,
                readGlobalInt(Settings.Global.ADB_ENABLED, 0) == 1,
                "Needed for one-time local ADB fallback",
                "optional"));
        requirements.add(buildPermissionItem("adb_wifi_enabled",
                true,
                readGlobalInt(ADB_WIFI_KEY, 0) == 1,
                "Useful for local ADB density/DNS fallback",
                "optional"));
        requirements.add(buildPermissionItem("request_install_packages",
                isDeclaredPermission(android.Manifest.permission.REQUEST_INSTALL_PACKAGES),
                canInstallPackageUpdates(),
                "Allow installs from this launcher or use local ADB fallback",
                "recommended"));
        requirements.add(buildPermissionItem(mediaReadPermissionName(),
                isDeclaredPermission(mediaReadPermissionName()),
                hasPermission(mediaReadPermissionName()),
                "Use the in-app prompt, local ADB wizard or PC ADB grant",
                "required"));

        int missingRequiredCount = 0;
        int missingRecommendedCount = 0;
        int missingOptionalCount = 0;
        for (Map<String, Object> requirement : requirements) {
            boolean granted = Boolean.TRUE.equals(requirement.get("granted"));
            if (granted) {
                continue;
            }
            String importance = requirement.get("importance") == null
                    ? "required"
                    : requirement.get("importance").toString();
            switch (importance) {
                case "recommended" -> missingRecommendedCount += 1;
                case "optional" -> missingOptionalCount += 1;
                default -> missingRequiredCount += 1;
            }
        }
        String health = missingRequiredCount > 0
                ? "missing_required"
                : (missingRecommendedCount > 0 ? "recommended_missing" : "healthy");
        return new ProvisioningEvaluation(
                requirements,
                missingRequiredCount,
                missingRecommendedCount,
                missingOptionalCount,
                health
        );
    }

    private Map<String, Object> buildProvisioningSummary() {
        ProvisioningEvaluation evaluation = evaluateProvisioning();
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("packageName", getPackageName());
        map.put("recommendedPolicy", BridgeStateStore.ADB_POLICY_ADB_AND_WIFI);
        applyProvisioningEvaluation(map, evaluation);
        return map;
    }

    private Map<String, Object> buildProvisioningChecklist() {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("packageName", getPackageName());
        List<String> commands = new ArrayList<>();
        commands.add("adb install -r atv-launcher-armeabi-v7a.apk");
        commands.add("adb shell pm grant " + getPackageName() + " " + Manifest.permission.WRITE_SECURE_SETTINGS);
        commands.add("adb shell pm grant " + getPackageName() + " " + mediaReadPermissionName());
        if (requiresNotificationRuntimePermission()) {
            commands.add("adb shell pm grant " + getPackageName() + " " + Manifest.permission.POST_NOTIFICATIONS);
        }
        commands.add("adb shell appops set " + getPackageName() + " REQUEST_INSTALL_PACKAGES allow");
        commands.add("adb shell appops set " + getPackageName() + " SYSTEM_ALERT_WINDOW allow");
        commands.add("adb shell appops set " + getPackageName() + " WRITE_SETTINGS allow");
        commands.add("adb shell dumpsys deviceidle whitelist +" + getPackageName());
        commands.add("adb shell settings put global adb_enabled 1");
        commands.add("adb shell settings put global adb_wifi_enabled 1");
        map.put("commands", commands);
        map.put("recommendedPolicy", BridgeStateStore.ADB_POLICY_ADB_AND_WIFI);
        map.put("wizardSteps", Arrays.asList(
                "Open developer options if ADB is disabled.",
                "Grant WRITE_SECURE_SETTINGS using local ADB or PC ADB.",
                "Grant video library access so the launcher can browse TV storage directly.",
                "Allow overlay and WRITE_SETTINGS if your firmware requires it.",
                "Whitelist battery optimization for Xiaomi TVs.",
                "Select the long-term ADB automation policy."
        ));
        ProvisioningEvaluation evaluation = evaluateProvisioning();
        applyProvisioningEvaluation(map, evaluation);
        return map;
    }

    private void applyProvisioningEvaluation(
            Map<String, Object> map,
            ProvisioningEvaluation evaluation
    ) {
        map.put("requirements", evaluation.requirements);
        map.put("missingRequiredCount", evaluation.missingRequiredCount);
        map.put("missingRecommendedCount", evaluation.missingRecommendedCount);
        map.put("missingOptionalCount", evaluation.missingOptionalCount);
        map.put("health", evaluation.health);
    }

    private boolean hasActionableProvisioningGaps(ProvisioningEvaluation evaluation) {
        return evaluation.missingRequiredCount > 0 || evaluation.missingRecommendedCount > 0;
    }

    private Map<String, Object> buildUpdateStatus() {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("packageName", getPackageName());
        map.put("requestInstallPackagesDeclared",
                isDeclaredPermission(android.Manifest.permission.REQUEST_INSTALL_PACKAGES));
        map.put("canRequestPackageInstalls", canInstallPackageUpdates());
        map.put("adbEnabled", readGlobalInt(Settings.Global.ADB_ENABLED, 0) == 1);
        map.put("adbWifiEnabled", readGlobalInt(ADB_WIFI_KEY, 0) == 1);
        return map;
    }

    private Map<String, Object> prepareLauncherUpdateInstall() {
        Map<String, Object> map = new LinkedHashMap<>(buildUpdateStatus());
        List<String> log = new ArrayList<>();
        boolean success = false;
        String message;
        if (readGlobalInt(Settings.Global.ADB_ENABLED, 0) != 1) {
            message = "ADB is disabled. Enable Developer options first.";
        } else {
            log.add(runLocalAdbBestEffort("appops set " + getPackageName() + " REQUEST_INSTALL_PACKAGES allow"));
            success = canInstallPackageUpdates();
            message = success
                    ? "Install permission granted for this launcher."
                    : "Install permission still needs user approval from Android settings.";
        }
        map.put("success", success);
        map.put("message", message);
        map.put("log", log);
        emitSystemSnapshot();
        return map;
    }

    private Map<String, Object> buildPermissionItem(
            String name,
            boolean declared,
            boolean granted,
            String guidance,
            String importance
    ) {
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("name", name);
        item.put("declared", declared);
        item.put("granted", granted);
        item.put("guidance", guidance);
        item.put("importance", importance);
        return item;
    }

    private static final class ProvisioningEvaluation {
        final List<Map<String, Object>> requirements;
        final int missingRequiredCount;
        final int missingRecommendedCount;
        final int missingOptionalCount;
        final String health;

        ProvisioningEvaluation(
                List<Map<String, Object>> requirements,
                int missingRequiredCount,
                int missingRecommendedCount,
                int missingOptionalCount,
                String health
        ) {
            this.requirements = requirements;
            this.missingRequiredCount = missingRequiredCount;
            this.missingRecommendedCount = missingRecommendedCount;
            this.missingOptionalCount = missingOptionalCount;
            this.health = health;
        }
    }

    private Map<String, Object> setVoiceMode(MethodCall call) {
        Integer mode = call.argument("mode");
        Integer keyCode = call.argument("keyCode");
        Boolean interceptEnabled = call.argument("interceptEnabled");
        if (mode != null) {
            BridgeStateStore.setMode(this, mode);
        }
        if (keyCode != null) {
            BridgeStateStore.setKeyCode(this, keyCode);
        }
        if (interceptEnabled != null) {
            BridgeStateStore.setVoiceInterceptEnabled(this, interceptEnabled);
        }
        BridgeStateStore.setLearningMode(this, false);
        SystemBridgeCoordinator.startCore(this, "manual_voice_config");
        emitSystemSnapshot();
        return buildVoiceStatus();
    }

    private Map<String, Object> setVoiceInterceptEnabled(MethodCall call) {
        Boolean enabled = call.argument("enabled");
        BridgeStateStore.setVoiceInterceptEnabled(this, enabled == null || enabled);
        emitSystemSnapshot();
        return buildVoiceStatus();
    }

    private Map<String, Object> startKeyLearning() {
        BridgeStateStore.setLearningMode(this, true);
        emitSystemSnapshot();
        return buildVoiceStatus();
    }

    private Map<String, Object> resetVoiceMapping() {
        BridgeStateStore.resetDefaultMapping(this);
        emitSystemSnapshot();
        return buildVoiceStatus();
    }

    private Map<String, Object> testVoiceSearch() {
        boolean success = VoiceSearchLauncher.launch(this);
        Map<String, Object> map = buildVoiceStatus();
        map.put("success", success);
        map.put("message", success ? "Voice search launched." : "Voice search fallback chain failed.");
        return map;
    }

    private Map<String, Object> repairAccessibility() {
        SystemBridgeCoordinator.ensureSystemState(this, "manual_repair", false);
        AccessibilityGrantCoordinator.ensureManagedAccessibility(this, "manual_repair");
        BridgeStateStore.setLastProvisioningVerifyAt(this, System.currentTimeMillis());
        emitSystemSnapshot();
        return buildSystemBridgeStatus();
    }

    private Map<String, Object> grantWriteSecureSettingsWithLocalAdb() {
        AccessibilityGrantCoordinator.LocalGrantResult grantResult =
                AccessibilityGrantCoordinator.tryGrantWriteSecureSettingsWithLocalAdb(this);
        if (grantResult.success) {
            BridgeStateStore.setLastProvisioningVerifyAt(this, System.currentTimeMillis());
        }
        Map<String, Object> map = buildProvisioningChecklist();
        map.put("success", grantResult.success);
        map.put("message", grantResult.message);
        emitSystemSnapshot();
        return map;
    }

    private Map<String, Object> setAdbAutomationPolicy(MethodCall call) {
        String policy = call.argument("policy");
        Boolean disableOnSleep = call.argument("disableOnSleep");
        Map<String, Object> map = SystemBridgeCoordinator.setAdbAutomationPolicy(
                this,
                policy,
                disableOnSleep != null && disableOnSleep
        );
        emitSystemSnapshot();
        return map;
    }

    private Map<String, Object> setAdbEnabledNow(MethodCall call) {
        Boolean enabled = call.argument("enabled");
        Map<String, Object> map = SystemBridgeCoordinator.setAdbEnabledNow(this, enabled == null || enabled);
        emitSystemSnapshot();
        return map;
    }

    private Map<String, Object> runProvisioningAction(MethodCall call) {
        String action = call.argument("action");
        String suggestedPolicy = call.argument("suggestedPolicy");
        String normalizedAction = action == null ? "" : action.trim().toLowerCase(Locale.US);
        Map<String, Object> map = buildProvisioningChecklist();
        List<String> log = new ArrayList<>();
        boolean success = false;
        String message = "Unsupported provisioning action.";

        if (TextUtils.equals(normalizedAction, "verify")) {
            success = true;
            message = "Provisioning state refreshed.";
        } else if (TextUtils.equals(normalizedAction, "grant_all_local_adb")) {
            ProvisioningEvaluation beforeEvaluation = evaluateProvisioning();
            boolean hadActionableGaps = hasActionableProvisioningGaps(beforeEvaluation);
            boolean adbEnabledBefore = readGlobalInt(Settings.Global.ADB_ENABLED, 0) == 1;
            AccessibilityGrantCoordinator.LocalGrantResult grantResult =
                    AccessibilityGrantCoordinator.tryGrantWriteSecureSettingsWithLocalAdb(this);
            log.add(grantResult.message);
            if (grantResult.success) {
                if (adbEnabledBefore) {
                    log.add(runLocalAdbBestEffort("pm grant " + getPackageName() + " " + mediaReadPermissionName()));
                    if (requiresNotificationRuntimePermission()) {
                        log.add(runLocalAdbBestEffort("pm grant " + getPackageName() + " " + Manifest.permission.POST_NOTIFICATIONS));
                    }
                    log.add(runLocalAdbBestEffort("appops set " + getPackageName() + " REQUEST_INSTALL_PACKAGES allow"));
                    log.add(runLocalAdbBestEffort("appops set " + getPackageName() + " SYSTEM_ALERT_WINDOW allow"));
                    log.add(runLocalAdbBestEffort("appops set " + getPackageName() + " WRITE_SETTINGS allow"));
                    log.add(runLocalAdbBestEffort("cmd deviceidle whitelist +" + getPackageName()));
                    if (!TextUtils.isEmpty(suggestedPolicy)) {
                        Map<String, Object> policyResult = SystemBridgeCoordinator.setAdbAutomationPolicy(
                                this,
                                suggestedPolicy,
                                false
                        );
                        log.add(policyResult.get("message") == null ? "" : policyResult.get("message").toString());
                    }
                } else if (hadActionableGaps) {
                    log.add("Local ADB commands skipped because ADB is still disabled.");
                }
            }
            ProvisioningEvaluation afterEvaluation = evaluateProvisioning();
            boolean hasActionableGapsAfter = hasActionableProvisioningGaps(afterEvaluation);
            boolean requiresAdbSetup = !adbEnabledBefore && hasActionableGapsAfter;
            BridgeStateStore.setLastProvisioningVerifyAt(this, System.currentTimeMillis());
            map = buildProvisioningChecklist();
            map.put("requiresAdbSetup", requiresAdbSetup);
            map.put("remainingRequiredCount", afterEvaluation.missingRequiredCount);
            map.put("remainingRecommendedCount", afterEvaluation.missingRecommendedCount);
            if (!hadActionableGaps && !hasActionableGapsAfter) {
                success = true;
                message = "Provisioning already verified.";
            } else if (!hasActionableGapsAfter) {
                success = true;
                message = "Local ADB provisioning completed and verified.";
            } else if (requiresAdbSetup) {
                success = false;
                message = "ADB is disabled. Enable Developer options and retry the local ADB grant.";
            } else if (afterEvaluation.missingRequiredCount > 0) {
                success = false;
                message = "Local ADB grant finished, but required permissions are still missing.";
            } else {
                success = false;
                message = "Local ADB grant finished, but some recommended permissions still need approval.";
            }
        } else if (TextUtils.equals(normalizedAction, "grant_update_install_local_adb")) {
            if (readGlobalInt(Settings.Global.ADB_ENABLED, 0) != 1) {
                success = false;
                message = "ADB is disabled. Enable Developer options first.";
            } else {
                log.add(runLocalAdbBestEffort("appops set " + getPackageName() + " REQUEST_INSTALL_PACKAGES allow"));
                success = canInstallPackageUpdates();
                message = success
                        ? "Install permission granted for this launcher."
                        : "Install permission still needs user approval from Android settings.";
            }
        } else if (TextUtils.equals(normalizedAction, "open_development")) {
            success = openSpecificSettingsPage("development");
            message = success ? "Developer options opened." : "Developer options could not be opened.";
        }

        map.put("success", success);
        map.put("message", message);
        map.put("log", log);
        emitSystemSnapshot();
        return map;
    }

    private Map<String, Object> setManagedAccessibility(MethodCall call) {
        String packageName = call.argument("packageName");
        Boolean enabled = call.argument("enabled");
        AccessibilityGrantCoordinator.ActionResult actionResult =
                enabled != null && enabled
                        ? AccessibilityGrantCoordinator.grantPackage(this, packageName)
                        : AccessibilityGrantCoordinator.removePackage(this, packageName);
        Map<String, Object> map = buildAccessibilityManagerSnapshot();
        map.put("success", actionResult.success);
        map.put("message", actionResult.message);
        map.put("verifyResult", actionResult.verifyResult);
        emitSystemSnapshot();
        return map;
    }

    private Map<String, Object> applyDensity(MethodCall call) {
        Integer density = call.argument("density");
        Map<String, Object> result = DensityBridge.applyDensity(this, density == null ? 320 : density);
        emitSystemSnapshot();
        return result;
    }

    private Map<String, Object> applyPrivateDns(MethodCall call) {
        String mode = call.argument("mode");
        String host = call.argument("host");
        Map<String, Object> result = PrivateDnsController.apply(this, mode, host);
        emitSystemSnapshot();
        return result;
    }

    private Map<String, Object> browseLocalVideoLibrary(MethodCall call) {
        String bucketId = call.argument("bucketId");
        return VideoLibraryController.browseLocalVideoLibrary(this, bucketId);
    }

    private Map<String, Object> getTvInputs() {
        Map<String, Object> map = new LinkedHashMap<>();
        List<Map<String, Object>> inputs = new ArrayList<>();
        try {
            TvInputManager manager = (TvInputManager) getSystemService(Context.TV_INPUT_SERVICE);
            if (manager != null) {
                for (TvInputInfo info : manager.getTvInputList()) {
                    if (info == null || TextUtils.isEmpty(info.getId())) {
                        continue;
                    }
                    Map<String, Object> inputMap = new LinkedHashMap<>();
                    int state = manager.getInputState(info.getId());
                    CharSequence label = info.loadLabel(this);
                    inputMap.put("inputId", info.getId());
                    inputMap.put("label", label == null ? "TV Input" : label.toString());
                    inputMap.put("packageName",
                            info.getServiceInfo() == null ? "" : info.getServiceInfo().packageName);
                    inputMap.put("state", state);
                    inputMap.put("stateLabel", switch (state) {
                        case TvInputManager.INPUT_STATE_CONNECTED -> "connected";
                        case TvInputManager.INPUT_STATE_CONNECTED_STANDBY -> "standby";
                        default -> "disconnected";
                    });
                    inputMap.put("passthrough", info.isPassthroughInput());
                    inputs.add(inputMap);
                }
            }
        } catch (Exception exception) {
            map.put("message", exception.toString());
        }
        map.put("inputs", inputs);
        return map;
    }

    private boolean launchTvInput(MethodCall call) {
        String inputId = call.argument("inputId");
        if (TextUtils.isEmpty(inputId)) {
            return false;
        }
        Intent intent = new Intent(Intent.ACTION_VIEW, TvContract.buildChannelUriForPassthroughInput(inputId))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        return tryStartActivity(intent);
    }

    private Map<String, Object> querySearchableMedia() {
        return VideoLibraryController.browseLocalVideoLibrary(this, null);
    }

    private boolean launchMediaUri(MethodCall call) {
        String uri = call.argument("uri");
        if (TextUtils.isEmpty(uri)) {
            return false;
        }
        Intent intent = new Intent(Intent.ACTION_VIEW)
                .setDataAndType(Uri.parse(uri), "video/*")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_GRANT_READ_URI_PERMISSION);
        return tryStartActivity(intent);
    }

    private void startSpeechRecognizer(MethodChannel.Result result) {
        if (pendingSpeechRecognizerResult != null) {
            result.error("speech_busy", "Speech recognition is already active.", null);
            return;
        }
        Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                .putExtra(RecognizerIntent.EXTRA_PROMPT, "Speak now");
        try {
            pendingSpeechRecognizerResult = result;
            startActivityForResult(intent, REQUEST_SPEECH_RECOGNIZER);
        } catch (Exception exception) {
            pendingSpeechRecognizerResult = null;
            boolean fallbackLaunched = VoiceSearchLauncher.launch(this);
            Map<String, Object> map = new LinkedHashMap<>();
            map.put("success", false);
            map.put("cancelled", false);
            map.put("text", "");
            map.put("launchedExternalVoice", fallbackLaunched);
            map.put("message", fallbackLaunched
                    ? "Speech recognizer unavailable, launched external voice search instead."
                    : exception.toString());
            result.success(map);
        }
    }

    private void requestMediaReadPermission(MethodChannel.Result result) {
        if (pendingMediaPermissionResult != null) {
            result.error("permission_busy", "A permission request is already active.", null);
            return;
        }
        if (hasPermission(mediaReadPermissionName())) {
            result.success(buildMediaPermissionResult(true));
            return;
        }
        pendingMediaPermissionResult = result;
        requestPermissions(new String[]{mediaReadPermissionName()}, REQUEST_MEDIA_PERMISSION);
    }

    private void pickWallpaperAsset(MethodCall call, MethodChannel.Result result) {
        if (pendingWallpaperAssetResult != null) {
            result.error("picker_busy", "Wallpaper picker is already active.", null);
            return;
        }
        String kind = call.argument("kind");
        pendingWallpaperAssetKind = TextUtils.isEmpty(kind) ? "mixed" : kind;
        pendingWallpaperAssetResult = result;
        String[] mimeTypes = switch (pendingWallpaperAssetKind) {
            case "video" -> new String[]{"video/*"};
            case "image" -> new String[]{"image/*"};
            default -> new String[]{"image/*", "video/*"};
        };
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        if (mimeTypes.length == 1) {
            intent.setType(mimeTypes[0]);
        } else {
            intent.setType("*/*");
            intent.putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes);
        }
        try {
            startActivityForResult(intent, REQUEST_PICK_WALLPAPER_ASSET);
        } catch (Exception exception) {
            pendingWallpaperAssetResult = null;
            result.error("picker_unavailable", exception.toString(), null);
        }
    }

    private void pickWallpaperFiles(MethodChannel.Result result) {
        if (pendingWallpaperFilesResult != null) {
            result.error("picker_busy", "Wallpaper multi-picker is already active.", null);
            return;
        }
        pendingWallpaperFilesResult = result;
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("video/*");
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
        try {
            startActivityForResult(intent, REQUEST_PICK_WALLPAPER_FILES);
        } catch (Exception exception) {
            pendingWallpaperFilesResult = null;
            result.error("picker_unavailable", exception.toString(), null);
        }
    }

    private void pickWallpaperFolder(MethodChannel.Result result) {
        if (pendingWallpaperFolderResult != null) {
            result.error("picker_busy", "Wallpaper folder picker is already active.", null);
            return;
        }
        pendingWallpaperFolderResult = result;
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        try {
            startActivityForResult(intent, REQUEST_PICK_WALLPAPER_FOLDER);
        } catch (Exception exception) {
            pendingWallpaperFolderResult = null;
            result.error("picker_unavailable", exception.toString(), null);
        }
    }

    private Map<String, Object> setWallpaperMode(String mode) {
        BridgeStateStore.setWallpaperMode(this, TextUtils.isEmpty(mode) ? "gradient" : mode);
        if (sharedVideoWallpaperController != null) {
            sharedVideoWallpaperController.onWallpaperModeChanged();
        }
        emitSystemSnapshot();
        return sharedVideoWallpaperController != null
                ? sharedVideoWallpaperController.getStatus()
                : new LinkedHashMap<>();
    }

    private Map<String, Object> setVideoWallpaperOptions(MethodCall call) {
        String sourceType = call.argument("sourceType");
        List<String> assetUris = call.argument("assetUris");
        String folderUri = call.argument("folderUri");
        String folderBucketId = call.argument("folderBucketId");
        String folderName = call.argument("folderName");
        String orderMode = call.argument("orderMode");
        String advanceMode = call.argument("advanceMode");
        Integer switchIntervalSeconds = call.argument("switchIntervalSeconds");
        Integer repeatCountPerItem = call.argument("repeatCountPerItem");
        Boolean playlistLoop = call.argument("playlistLoop");
        Boolean loop = call.argument("loop");
        Boolean mute = call.argument("mute");
        String fit = call.argument("fit");
        Integer dimPercent = call.argument("dimPercent");
        String blur = call.argument("blur");
        Boolean autoResume = call.argument("autoResume");

        if (!TextUtils.isEmpty(sourceType)) {
            BridgeStateStore.setWallpaperVideoSourceType(this, sourceType);
        }
        if (assetUris != null) {
            BridgeStateStore.setWallpaperVideoAssetUris(this, assetUris);
            if (!assetUris.isEmpty() && TextUtils.isEmpty(BridgeStateStore.getWallpaperPreviewPath(this))) {
                try {
                    BridgeStateStore.setWallpaperPreviewPath(
                            this,
                            createWallpaperPreview(Uri.parse(assetUris.get(0)), "video")
                    );
                } catch (Exception ignored) {
                }
            }
        }
        if (folderUri != null) {
            BridgeStateStore.setWallpaperVideoFolderUri(this, folderUri);
        }
        if (folderBucketId != null) {
            BridgeStateStore.setWallpaperVideoFolderBucketId(this, folderBucketId);
        }
        if (folderName != null) {
            BridgeStateStore.setWallpaperVideoFolderName(this, folderName);
        }
        if (!TextUtils.isEmpty(orderMode)) {
            BridgeStateStore.setWallpaperVideoOrderMode(this, orderMode);
        }
        if (!TextUtils.isEmpty(advanceMode)) {
            BridgeStateStore.setWallpaperVideoAdvanceMode(this, advanceMode);
        }
        if (switchIntervalSeconds != null) {
            BridgeStateStore.setWallpaperVideoSwitchIntervalSeconds(this, switchIntervalSeconds);
        }
        if (repeatCountPerItem != null) {
            BridgeStateStore.setWallpaperVideoRepeatCountPerItem(this, repeatCountPerItem);
        }
        if (playlistLoop != null) {
            BridgeStateStore.setWallpaperVideoPlaylistLoopEnabled(this, playlistLoop);
        }
        if (loop != null) {
            BridgeStateStore.setWallpaperVideoLoopEnabled(this, loop);
        }
        if (mute != null) {
            BridgeStateStore.setWallpaperVideoMuted(this, mute);
        }
        if (!TextUtils.isEmpty(fit)) {
            BridgeStateStore.setWallpaperVideoFit(this, fit);
        }
        if (dimPercent != null) {
            BridgeStateStore.setWallpaperVideoDimPercent(this, Math.max(0, Math.min(100, dimPercent)));
        }
        if (!TextUtils.isEmpty(blur)) {
            BridgeStateStore.setWallpaperVideoBlur(this, blur);
        }
        if (autoResume != null) {
            BridgeStateStore.setWallpaperVideoAutoResumeEnabled(this, autoResume);
        }
        if (sharedVideoWallpaperController != null) {
            sharedVideoWallpaperController.onVideoConfigChanged();
        }
        emitSystemSnapshot();
        return sharedVideoWallpaperController != null
                ? sharedVideoWallpaperController.getStatus()
                : new LinkedHashMap<>();
    }

    private Map<String, Object> setVideoWallpaperPlaybackSuppressed(MethodCall call) {
        boolean suppressed = Boolean.TRUE.equals(call.argument("suppressed"));
        String reason = call.argument("reason");
        if (sharedVideoWallpaperController != null) {
            sharedVideoWallpaperController.setPlaybackSuppressed(suppressed, reason);
        }
        return sharedVideoWallpaperController != null
                ? sharedVideoWallpaperController.getStatus()
                : new LinkedHashMap<>();
    }

    private void handleWallpaperPickerResult(Uri uri) {
        if (pendingWallpaperAssetResult == null) {
            return;
        }
        MethodChannel.Result result = pendingWallpaperAssetResult;
        pendingWallpaperAssetResult = null;

        if (uri == null) {
            result.success(buildCancelledResult());
            return;
        }

        try {
            grantPersistableReadPermission(uri);

            String mimeType = getContentResolver().getType(uri);
            String resolvedKind = resolveAssetKind(mimeType, pendingWallpaperAssetKind);
            String previewPath = createWallpaperPreview(uri, resolvedKind);
            BridgeStateStore.setWallpaperAssetUri(this, uri.toString());
            BridgeStateStore.setWallpaperPreviewPath(this, previewPath);
            if (TextUtils.equals("video", resolvedKind) && sharedVideoWallpaperController != null) {
                sharedVideoWallpaperController.onWallpaperModeChanged();
            }

            Map<String, Object> map = new LinkedHashMap<>();
            map.put("cancelled", false);
            map.put("kind", resolvedKind);
            map.put("uri", uri.toString());
            map.put("mimeType", mimeType == null ? "" : mimeType);
            map.put("displayName", queryDisplayName(uri));
            map.put("previewPath", previewPath);
            emitSystemSnapshot();
            result.success(map);
        } catch (Exception exception) {
            result.error("picker_failed", exception.toString(), null);
        }
    }

    private void handleWallpaperFilesPickerResult(List<Uri> uris) {
        if (pendingWallpaperFilesResult == null) {
            return;
        }
        MethodChannel.Result result = pendingWallpaperFilesResult;
        pendingWallpaperFilesResult = null;

        if (uris == null || uris.isEmpty()) {
            result.success(buildCancelledResult());
            return;
        }

        try {
            List<String> uriStrings = new ArrayList<>();
            for (Uri uri : uris) {
                grantPersistableReadPermission(uri);
                uriStrings.add(uri.toString());
            }
            String previewPath = createWallpaperPreview(uris.get(0), "video");
            BridgeStateStore.setWallpaperVideoSourceType(
                    this,
                    uris.size() <= 1
                            ? BridgeStateStore.WALLPAPER_SOURCE_SINGLE_FILE
                            : BridgeStateStore.WALLPAPER_SOURCE_MULTI_FILE
            );
            BridgeStateStore.setWallpaperVideoAssetUris(this, uriStrings);
            BridgeStateStore.setWallpaperVideoFolderUri(this, "");
            BridgeStateStore.setWallpaperVideoFolderBucketId(this, "");
            BridgeStateStore.setWallpaperVideoFolderName(this, "");
            BridgeStateStore.setWallpaperPreviewPath(this, previewPath);

            Map<String, Object> map = new LinkedHashMap<>();
            map.put("cancelled", false);
            map.put("sourceType", uris.size() <= 1
                    ? BridgeStateStore.WALLPAPER_SOURCE_SINGLE_FILE
                    : BridgeStateStore.WALLPAPER_SOURCE_MULTI_FILE);
            map.put("uris", uriStrings);
            map.put("primaryUri", uriStrings.get(0));
            map.put("previewPath", previewPath);
            emitSystemSnapshot();
            result.success(map);
        } catch (Exception exception) {
            result.error("picker_failed", exception.toString(), null);
        }
    }

    private void handleWallpaperFolderPickerResult(Uri uri) {
        if (pendingWallpaperFolderResult == null) {
            return;
        }
        MethodChannel.Result result = pendingWallpaperFolderResult;
        pendingWallpaperFolderResult = null;

        if (uri == null) {
            result.success(buildCancelledResult());
            return;
        }

        try {
            grantPersistableReadPermission(uri);
            Map<String, Object> folder = VideoLibraryController.browseTreeFolder(this, uri.toString());
            List<String> uris = new ArrayList<>();
            Object rawUris = folder.get("uris");
            if (rawUris instanceof List<?>) {
                for (Object rawUri : (List<?>) rawUris) {
                    if (rawUri != null && !TextUtils.isEmpty(rawUri.toString())) {
                        uris.add(rawUri.toString());
                    }
                }
            }
            String primaryUri = folder.get("primaryUri") == null ? "" : folder.get("primaryUri").toString();
            String previewPath = TextUtils.isEmpty(primaryUri)
                    ? BridgeStateStore.getWallpaperPreviewPath(this)
                    : createWallpaperPreview(Uri.parse(primaryUri), "video");

            BridgeStateStore.setWallpaperVideoSourceType(this, BridgeStateStore.WALLPAPER_SOURCE_FOLDER);
            BridgeStateStore.setWallpaperVideoAssetUris(this, uris);
            BridgeStateStore.setWallpaperVideoFolderUri(this, uri.toString());
            BridgeStateStore.setWallpaperVideoFolderBucketId(this, "");
            BridgeStateStore.setWallpaperVideoFolderName(
                    this,
                    folder.get("folderName") == null ? "" : folder.get("folderName").toString()
            );
            BridgeStateStore.setWallpaperPreviewPath(this, previewPath);

            Map<String, Object> map = new LinkedHashMap<>(folder);
            map.put("cancelled", false);
            map.put("previewPath", previewPath);
            emitSystemSnapshot();
            result.success(map);
        } catch (Exception exception) {
            result.error("picker_failed", exception.toString(), null);
        }
    }

    private void exportSettingsBackup(MethodCall call, MethodChannel.Result result) {
        String fileName = call.argument("fileName");
        String content = call.argument("content");
        try {
            result.success(writeBackupToLocalFile(fileName, content));
        } catch (Exception exception) {
            result.error("backup_export_failed", exception.toString(), null);
        }
    }

    private void importSettingsBackup(MethodChannel.Result result, String mode) {
        if (pendingBackupImportResult != null) {
            result.error("backup_busy", "A backup import is already active.", null);
            return;
        }
        pendingBackupImportResult = result;
        pendingBackupImportMode = mode == null ? "import" : mode;
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"application/json", "text/plain"});
        try {
            startActivityForResult(intent, REQUEST_IMPORT_BACKUP);
        } catch (Exception exception) {
            pendingBackupImportResult = null;
            result.error("backup_import_unavailable", exception.toString(), null);
        }
    }

    private void handleBackupExportResult(Uri uri) {
        if (pendingBackupExportResult == null) {
            return;
        }
        MethodChannel.Result result = pendingBackupExportResult;
        pendingBackupExportResult = null;

        if (uri == null) {
            result.success(buildCancelledResult());
            return;
        }

        try (OutputStream outputStream = getContentResolver().openOutputStream(uri, "wt")) {
            if (outputStream == null) {
                throw new IllegalStateException("Could not open backup destination.");
            }
            outputStream.write(pendingBackupExportContent.getBytes(StandardCharsets.UTF_8));
            String displayName = queryDisplayName(uri);
            BridgeStateStore.setLastBackupExportName(this, displayName);
            Map<String, Object> map = new LinkedHashMap<>();
            map.put("cancelled", false);
            map.put("uri", uri.toString());
            map.put("displayName", displayName);
            emitSystemSnapshot();
            result.success(map);
        } catch (Exception exception) {
            result.error("backup_export_failed", exception.toString(), null);
        }
    }

    private Map<String, Object> writeBackupToLocalFile(String fileName, String content) throws Exception {
        String resolvedFileName = sanitizeBackupFileName(fileName);
        File directory = getExternalFilesDir("backups");
        if (directory == null) {
            directory = new File(getFilesDir(), "backups");
        }
        if (!directory.isDirectory() && !directory.mkdirs()) {
            throw new IllegalStateException("Could not create backup directory.");
        }

        File backupFile = new File(directory, resolvedFileName);
        try (OutputStream outputStream = new FileOutputStream(backupFile, false)) {
            outputStream.write((content == null ? "" : content).getBytes(StandardCharsets.UTF_8));
            outputStream.flush();
        }

        String displayName = backupFile.getName();
        BridgeStateStore.setLastBackupExportName(this, displayName);
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("cancelled", false);
        map.put("uri", Uri.fromFile(backupFile).toString());
        map.put("displayName", displayName);
        map.put("path", backupFile.getAbsolutePath());
        map.put("storage", "local_app_backup");
        emitSystemSnapshot();
        return map;
    }

    private void handleBackupImportResult(Uri uri) {
        if (pendingBackupImportResult == null) {
            return;
        }
        MethodChannel.Result result = pendingBackupImportResult;
        pendingBackupImportResult = null;

        if (uri == null) {
            result.success(buildCancelledResult());
            return;
        }

        try {
            grantPersistableReadPermission(uri);
            String content = readTextFromUri(uri);
            String displayName = queryDisplayName(uri);
            Map<String, Object> map = new LinkedHashMap<>();
            map.put("cancelled", false);
            map.put("mode", pendingBackupImportMode);
            map.put("uri", uri.toString());
            map.put("displayName", displayName);
            map.put("content", content);
            if (TextUtils.equals("import", pendingBackupImportMode)) {
                BridgeStateStore.setLastBackupImportName(this, displayName);
            }
            emitSystemSnapshot();
            result.success(map);
        } catch (Exception exception) {
            result.error("backup_import_failed", exception.toString(), null);
        }
    }

    private void handleMediaPermissionResult(Boolean granted) {
        if (pendingMediaPermissionResult == null) {
            return;
        }
        MethodChannel.Result result = pendingMediaPermissionResult;
        pendingMediaPermissionResult = null;
        result.success(buildMediaPermissionResult(granted != null && granted));
        emitSystemSnapshot();
    }

    private void handleSpeechRecognizerResult(int resultCode, Intent data) {
        if (pendingSpeechRecognizerResult == null) {
            return;
        }
        MethodChannel.Result result = pendingSpeechRecognizerResult;
        pendingSpeechRecognizerResult = null;

        Map<String, Object> map = new LinkedHashMap<>();
        map.put("cancelled", resultCode != Activity.RESULT_OK);
        map.put("success", false);
        map.put("text", "");
        map.put("launchedExternalVoice", false);

        if (resultCode == Activity.RESULT_OK && data != null) {
            ArrayList<String> matches = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS);
            String text = (matches == null || matches.isEmpty()) ? "" : matches.get(0);
            map.put("text", text == null ? "" : text);
            map.put("success", !TextUtils.isEmpty(text));
            map.put("message", TextUtils.isEmpty(text)
                    ? "No speech was recognized."
                    : "Speech recognized.");
        } else {
            map.put("message", "Speech recognition was cancelled.");
        }
        result.success(map);
    }

    private Map<String, Object> recordBackupRestoreResult(MethodCall call) {
        String importName = call.argument("importName");
        String summary = call.argument("summary");
        Number restoredAt = call.argument("restoredAt");
        if (!TextUtils.isEmpty(importName)) {
            BridgeStateStore.setLastBackupImportName(this, importName);
        }
        BridgeStateStore.setLastBackupRestoreSummary(this, summary == null ? "" : summary);
        BridgeStateStore.setLastBackupRestoreAt(
                this,
                restoredAt == null ? System.currentTimeMillis() : restoredAt.longValue()
        );
        emitSystemSnapshot();
        return buildBackupStatus();
    }

    private String createWallpaperPreview(Uri uri, String kind) throws Exception {
        File directory = new File(getFilesDir(), "wallpaper_assets");
        if (!directory.isDirectory() && !directory.mkdirs()) {
            throw new IllegalStateException("Could not create wallpaper asset directory.");
        }

        if (TextUtils.equals("video", kind)) {
            File previewFile = new File(directory, "video_preview.jpg");
            MediaMetadataRetriever retriever = new MediaMetadataRetriever();
            try {
                retriever.setDataSource(this, uri);
                Bitmap bitmap = retriever.getFrameAtTime(0);
                if (bitmap != null) {
                    try (FileOutputStream outputStream = new FileOutputStream(previewFile, false)) {
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 88, outputStream);
                    }
                    return previewFile.getAbsolutePath();
                }
            } finally {
                try {
                    retriever.release();
                } catch (Exception ignored) {
                }
            }
            return BridgeStateStore.getWallpaperPreviewPath(this);
        }

        File imageFile = new File(directory, "image_wallpaper");
        try (InputStream inputStream = getContentResolver().openInputStream(uri);
             OutputStream outputStream = new FileOutputStream(imageFile, false)) {
            if (inputStream == null) {
                throw new IllegalStateException("Could not open selected asset.");
            }
            byte[] buffer = new byte[8192];
            int read;
            while ((read = inputStream.read(buffer)) > 0) {
                outputStream.write(buffer, 0, read);
            }
        }
        return imageFile.getAbsolutePath();
    }

    private String resolveAssetKind(String mimeType, String requestedKind) {
        if (TextUtils.equals("video", requestedKind) || (mimeType != null && mimeType.startsWith("video/"))) {
            return "video";
        }
        return "image";
    }

    private Map<String, Object> buildCancelledResult() {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("cancelled", true);
        return map;
    }

    private String sanitizeBackupFileName(String fileName) {
        String resolvedName = TextUtils.isEmpty(fileName)
                ? "atv-launcher-backup.json"
                : new File(fileName).getName();
        if (!resolvedName.endsWith(".json")) {
            resolvedName = resolvedName + ".json";
        }
        return resolvedName;
    }

    private Map<String, Object> buildMediaPermissionResult(boolean granted) {
        Map<String, Object> map = new LinkedHashMap<>(VideoLibraryController.getFileAccessStatus(this));
        map.put("permission", mediaReadPermissionName());
        map.put("granted", granted && hasPermission(mediaReadPermissionName()));
        map.put("message", granted
                ? "Video library permission granted."
                : "Video library permission was not granted.");
        return map;
    }

    private void grantPersistableReadPermission(Uri uri) {
        if (uri == null) {
            return;
        }
        try {
            final int flags = Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION;
            getContentResolver().takePersistableUriPermission(uri, flags);
        } catch (Exception ignored) {
        }
    }

    private String readTextFromUri(Uri uri) throws Exception {
        try (InputStream inputStream = getContentResolver().openInputStream(uri)) {
            if (inputStream == null) {
                throw new IllegalStateException("Could not open the selected backup.");
            }
            byte[] buffer = new byte[8192];
            StringBuilder builder = new StringBuilder();
            int read;
            while ((read = inputStream.read(buffer)) > 0) {
                builder.append(new String(buffer, 0, read, StandardCharsets.UTF_8));
            }
            return builder.toString();
        }
    }

    private String queryDisplayName(Uri uri) {
        ContentResolver contentResolver = getContentResolver();
        try (Cursor cursor = contentResolver.query(uri, null, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                int displayNameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (displayNameIndex >= 0) {
                    return cursor.getString(displayNameIndex);
                }
            }
        } catch (Exception ignored) {
        }
        return uri.getLastPathSegment() == null ? "" : uri.getLastPathSegment();
    }

    private List<Uri> extractUris(Intent data) {
        List<Uri> uris = new ArrayList<>();
        if (data == null) {
            return uris;
        }
        Uri singleUri = data.getData();
        if (singleUri != null) {
            uris.add(singleUri);
        }
        ClipData clipData = data.getClipData();
        if (clipData == null) {
            return uris;
        }
        for (int index = 0; index < clipData.getItemCount(); index += 1) {
            Uri uri = clipData.getItemAt(index).getUri();
            if (uri != null && !uris.contains(uri)) {
                uris.add(uri);
            }
        }
        return uris;
    }

    private String runLocalAdbBestEffort(String shellCommand) {
        LocalAdbBridge.Result result = LocalAdbBridge.executeShell(this, shellCommand);
        if (result.success) {
            return shellCommand + " -> ok";
        }
        return shellCommand + " -> " + (TextUtils.isEmpty(result.detail) ? "failed" : result.detail);
    }

    private Map<String, Object> installDownloadedApk(MethodCall call) {
        String filePath = call.argument("filePath");
        Map<String, Object> map = new LinkedHashMap<>(buildUpdateStatus());
        if (TextUtils.isEmpty(filePath)) {
            map.put("success", false);
            map.put("message", "Downloaded APK path is missing.");
            return map;
        }
        File apkFile = new File(filePath);
        if (!apkFile.exists() || !apkFile.isFile()) {
            map.put("success", false);
            map.put("message", "Downloaded APK file could not be found.");
            return map;
        }
        if (!canInstallPackageUpdates()) {
            map.put("success", false);
            map.put("needsPermission", true);
            map.put("message", "Allow installs from this launcher before installing the update.");
            return map;
        }
        try {
            Uri apkUri = FileProvider.getUriForFile(
                    this,
                    getPackageName() + ".fileprovider",
                    apkFile
            );
            Intent intent = new Intent(Intent.ACTION_VIEW)
                    .setDataAndType(apkUri, "application/vnd.android.package-archive")
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_GRANT_READ_URI_PERMISSION);
            boolean success = tryStartActivity(intent);
            map.put("success", success);
            map.put("message", success
                    ? "Package installer opened for the downloaded update."
                    : "Package installer could not be opened.");
            return map;
        } catch (Exception exception) {
            map.put("success", false);
            map.put("message", exception.toString());
            return map;
        }
    }

    private boolean openSpecificSettingsPage(String page) {
        Intent intent;
        String normalized = page == null ? "" : page.trim().toLowerCase(Locale.US);
        switch (normalized) {
            case "accessibility" -> intent = new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS);
            case "write_settings" -> intent = new Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS)
                    .setData(Uri.parse("package:" + getPackageName()));
            case "overlay" -> intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                    .setData(Uri.parse("package:" + getPackageName()));
            case "install_unknown_apps" -> intent = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                    ? new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                    .setData(Uri.parse("package:" + getPackageName()))
                    : new Intent(Settings.ACTION_SECURITY_SETTINGS);
            case "battery" -> intent = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
            case "app_details" -> intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:" + getPackageName()));
            case "private_dns" -> intent = new Intent(PRIVATE_DNS_SETTINGS_ACTION);
            case "notifications" -> intent = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, getPackageName());
            case "development" -> intent = new Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS);
            default -> intent = new Intent(Settings.ACTION_SETTINGS);
        }
        return tryStartActivity(intent);
    }

    private boolean tryStartActivity(Intent intent) {
        boolean success = true;
        try {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        } catch (Exception ignored) {
            success = false;
        }
        return success;
    }

    private boolean shouldRedirectNonHomeEntry(Intent intent) {
        if (intent == null) {
            return false;
        }
        if (isDebugBenchmarkIntent(intent)) {
            return false;
        }
        return !isHomeIntent(intent);
    }

    private boolean moveExistingLauncherTaskToFront(String source) {
        ActivityManager activityManager = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
        if (activityManager == null) {
            return false;
        }
        List<ActivityManager.AppTask> appTasks = activityManager.getAppTasks();
        if (appTasks == null || appTasks.isEmpty()) {
            return false;
        }
        ActivityManager.AppTask preferredTask = null;
        ActivityManager.RecentTaskInfo preferredTaskInfo = null;
        ActivityManager.AppTask fallbackTask = null;
        ActivityManager.RecentTaskInfo fallbackTaskInfo = null;
        for (ActivityManager.AppTask appTask : appTasks) {
            ActivityManager.RecentTaskInfo taskInfo = appTask.getTaskInfo();
            if (taskInfo == null || taskInfo.id == getTaskId()) {
                continue;
            }
            if (!isOwnLauncherTask(taskInfo)) {
                continue;
            }
            if (isHomeLauncherTask(taskInfo)) {
                preferredTask = appTask;
                preferredTaskInfo = taskInfo;
                break;
            }
            if (fallbackTask == null) {
                fallbackTask = appTask;
                fallbackTaskInfo = taskInfo;
            }
        }
        ActivityManager.AppTask targetTask = preferredTask != null ? preferredTask : fallbackTask;
        ActivityManager.RecentTaskInfo targetInfo = preferredTaskInfo != null ? preferredTaskInfo : fallbackTaskInfo;
        if (targetTask == null || targetInfo == null) {
            return false;
        }
        try {
            targetTask.moveToFront();
            Log.i(
                    TAG,
                    "Reused existing launcher task via " + source + " taskId=" + targetInfo.id
            );
            return true;
        } catch (Exception exception) {
            Log.w(TAG, "Failed to move existing launcher task via " + source, exception);
            return false;
        }
    }

    private void pruneBackgroundLauncherTasks(String source) {
        if (!isHomeIntent(getIntent())) {
            return;
        }
        ActivityManager activityManager = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
        if (activityManager == null) {
            return;
        }
        List<ActivityManager.AppTask> appTasks = activityManager.getAppTasks();
        if (appTasks == null || appTasks.isEmpty()) {
            return;
        }
        for (ActivityManager.AppTask appTask : appTasks) {
            ActivityManager.RecentTaskInfo taskInfo = appTask.getTaskInfo();
            if (taskInfo == null || taskInfo.id == getTaskId()) {
                continue;
            }
            if (!isOwnLauncherTask(taskInfo)) {
                continue;
            }
            try {
                appTask.finishAndRemoveTask();
                Log.i(TAG, "Pruned stale launcher task via " + source + " taskId=" + taskInfo.id);
            } catch (Exception exception) {
                Log.w(TAG, "Failed to prune stale launcher task via " + source, exception);
            }
        }
    }

    private boolean isOwnLauncherTask(ActivityManager.RecentTaskInfo taskInfo) {
        ComponentName baseActivity = taskInfo.baseActivity;
        ComponentName topActivity = taskInfo.topActivity;
        boolean ownsBase = baseActivity != null
                && TextUtils.equals(baseActivity.getPackageName(), getPackageName());
        boolean ownsTop = topActivity != null
                && TextUtils.equals(topActivity.getPackageName(), getPackageName());
        return ownsBase || ownsTop;
    }

    private boolean isHomeLauncherTask(ActivityManager.RecentTaskInfo taskInfo) {
        Intent baseIntent = taskInfo.baseIntent;
        if (baseIntent == null) {
            return false;
        }
        Set<String> categories = baseIntent.getCategories();
        return categories != null && categories.contains(Intent.CATEGORY_HOME);
    }

    private byte[] drawableToByteArray(Drawable drawable, int maxWidth, int maxHeight, boolean opaqueBackground) {
        if (drawable.getIntrinsicWidth() <= 0 || drawable.getIntrinsicHeight() <= 0) {
            return new byte[0];
        }
        Bitmap bitmap = drawableToBitmap(drawable, maxWidth, maxHeight, opaqueBackground);
        ByteArrayOutputStream stream = new ByteArrayOutputStream();
        Bitmap.CompressFormat format = opaqueBackground ? Bitmap.CompressFormat.JPEG : Bitmap.CompressFormat.PNG;
        int quality = opaqueBackground ? 86 : 100;
        bitmap.compress(format, quality, stream);
        return stream.toByteArray();
    }

    private Bitmap drawableToBitmap(Drawable drawable, int maxWidth, int maxHeight, boolean opaqueBackground) {
        int sourceWidth = drawable.getIntrinsicWidth();
        int sourceHeight = drawable.getIntrinsicHeight();
        float scale = Math.min(1f, Math.min(maxWidth / (float) sourceWidth, maxHeight / (float) sourceHeight));
        int targetWidth = Math.max(1, Math.round(sourceWidth * scale));
        int targetHeight = Math.max(1, Math.round(sourceHeight * scale));
        Bitmap bitmap;
        if (drawable instanceof BitmapDrawable bitmapDrawable) {
            Bitmap sourceBitmap = bitmapDrawable.getBitmap();
            if (!opaqueBackground && sourceBitmap.getWidth() == targetWidth && sourceBitmap.getHeight() == targetHeight) {
                return sourceBitmap;
            }
        }
        bitmap = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        if (opaqueBackground) {
            canvas.drawColor(Color.BLACK);
        }
        drawable.setBounds(0, 0, targetWidth, targetHeight);
        drawable.draw(canvas);
        return bitmap;
    }

    private void emitSystemSnapshot() {
        if (sharedSystemEventSink != null) {
            sharedSystemEventSink.success(buildSystemBridgeStatusLite());
        }
    }

    private void emitSystemSnapshotDelta(Map<String, Object> delta) {
        if (sharedSystemEventSink != null) {
            sharedSystemEventSink.success(delta);
        }
    }

    private void emitWallpaperStatusDelta() {
        Map<String, Object> delta = new LinkedHashMap<>();
        delta.put(
                "wallpaper",
                sharedVideoWallpaperController != null
                        ? sharedVideoWallpaperController.getStatus()
                        : new LinkedHashMap<>()
        );
        emitSystemSnapshotDelta(delta);
    }

    private static void emitInitialSystemSnapshotForActiveActivity() {
        MainActivity activity = activeActivity;
        if (activity != null) {
            activity.emitInitialSystemSnapshot();
        }
    }

    private void emitInitialSystemSnapshot() {
        emitSystemSnapshot();
        if (!firstBridgeSnapshotLogged) {
            firstBridgeSnapshotLogged = true;
            logPerf(
                    "time_to_first_bridge_snapshot",
                    activityBootstrapStartedAtNanos
            );
        }
    }

    private void scheduleStartupSystemSnapshot() {
        if (!FAST_STARTUP_ENABLED) {
            emitSystemSnapshot();
            return;
        }
        SHARED_SYSTEM_EVENT_HANDLER.removeCallbacks(sharedInitialSystemSnapshotRunnable);
        SHARED_SYSTEM_EVENT_HANDLER.postDelayed(
                sharedInitialSystemSnapshotRunnable,
                INITIAL_SYSTEM_SNAPSHOT_DELAY_MS
        );
    }

    private Map<String, Object> buildNavigationStatus() {
        Map<String, Object> navigation = new LinkedHashMap<>();
        navigation.put("homeSequence", homeNavigationSequence);
        navigation.put("reason", lastNavigationReason);
        return navigation;
    }

    private Map<String, Object> buildBenchmarkCommandStatus() {
        Map<String, Object> benchmark = new LinkedHashMap<>();
        benchmark.put("sequence", benchmarkCommandSequence);
        benchmark.put("action", lastBenchmarkAction);
        benchmark.put("route", lastBenchmarkRoute);
        benchmark.put("sessionId", lastBenchmarkSessionId);
        benchmark.put("autoFocusDetail", lastBenchmarkAutoFocusDetail);
        benchmark.put("bypassSettingsSecurity", lastBenchmarkBypassSettingsSecurity);
        return benchmark;
    }

    private void recordHomeNavigation(String reason) {
        homeNavigationSequence += 1L;
        lastNavigationReason = TextUtils.isEmpty(reason) ? "" : reason;
        Map<String, Object> delta = new LinkedHashMap<>();
        delta.put("navigation", buildNavigationStatus());
        emitSystemSnapshotDelta(delta);
    }

    private boolean isDebugBenchmarkIntent(Intent intent) {
        return isDebuggableBuild()
                && intent != null
                && TextUtils.equals(DEBUG_BENCHMARK_ACTION, intent.getAction());
    }

    private boolean recordBenchmarkCommand(Intent intent) {
        if (!isDebugBenchmarkIntent(intent)) {
            return false;
        }
        String action = intent.getStringExtra("action");
        if (!TextUtils.equals("open_launcher_settings", action)
                && !TextUtils.equals("close_launcher_settings", action)) {
            return false;
        }
        benchmarkCommandSequence += 1L;
        lastBenchmarkAction = action;
        lastBenchmarkRoute = intent.getStringExtra("route") != null
                ? intent.getStringExtra("route")
                : "";
        lastBenchmarkSessionId = intent.getStringExtra("sessionId") != null
                ? intent.getStringExtra("sessionId")
                : "";
        lastBenchmarkAutoFocusDetail = intent.getBooleanExtra("autoFocusDetail", false);
        lastBenchmarkBypassSettingsSecurity = intent.getBooleanExtra(
                "bypassSettingsSecurity",
                false
        );
        Map<String, Object> delta = new LinkedHashMap<>();
        delta.put("benchmarkCommand", buildBenchmarkCommandStatus());
        emitSystemSnapshotDelta(delta);
        return true;
    }

    private boolean isHomeIntent(Intent intent) {
        if (intent == null) {
            return false;
        }
        if (!TextUtils.equals(Intent.ACTION_MAIN, intent.getAction())) {
            return false;
        }
        Set<String> categories = intent.getCategories();
        if (categories == null) {
            return false;
        }
        return categories.contains(Intent.CATEGORY_HOME);
    }

    private boolean isDebuggableBuild() {
        return (getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
    }

    private Set<String> readEnabledAccessibilityServices() {
        String raw = Settings.Secure.getString(getContentResolver(), Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
        LinkedHashSet<String> services = new LinkedHashSet<>();
        if (TextUtils.isEmpty(raw)) {
            return services;
        }
        for (String part : raw.split(":")) {
            if (!TextUtils.isEmpty(part)) {
                services.add(part.trim());
            }
        }
        return services;
    }

    private String deriveAccessibilityHealth(boolean ownAccessibilityEnabled) {
        boolean wss = hasPermission(android.Manifest.permission.WRITE_SECURE_SETTINGS);
        if (!wss) {
            return "missing_wss";
        }
        return ownAccessibilityEnabled ? "healthy" : "degraded";
    }

    private boolean hasPermission(String permission) {
        return checkCallingOrSelfPermission(permission) == PackageManager.PERMISSION_GRANTED;
    }

    private boolean isDeclaredPermission(String permission) {
        try {
            PackageInfo packageInfo = getPackageManager().getPackageInfo(getPackageName(), PackageManager.GET_PERMISSIONS);
            String[] requested = packageInfo.requestedPermissions;
            if (requested == null) {
                return false;
            }
            for (String value : requested) {
                if (TextUtils.equals(value, permission)) {
                    return true;
                }
            }
        } catch (Exception ignored) {
        }
        return false;
    }

    private boolean isDeviceOwner() {
        DevicePolicyManager dpm = (DevicePolicyManager) getSystemService(Context.DEVICE_POLICY_SERVICE);
        return dpm != null && dpm.isDeviceOwnerApp(getPackageName());
    }

    private boolean requiresNotificationRuntimePermission() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU;
    }

    private boolean areNotificationsEnabled() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return true;
        }
        android.app.NotificationManager notificationManager =
                (android.app.NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        return notificationManager == null || notificationManager.areNotificationsEnabled();
    }

    private boolean canInstallPackageUpdates() {
        if (!isDeclaredPermission(Manifest.permission.REQUEST_INSTALL_PACKAGES)) {
            return false;
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return true;
        }
        return getPackageManager().canRequestPackageInstalls();
    }

    private String mediaReadPermissionName() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                ? Manifest.permission.READ_MEDIA_VIDEO
                : Manifest.permission.READ_EXTERNAL_STORAGE;
    }

    private int readGlobalInt(String key, int fallback) {
        try {
            return Settings.Global.getInt(getContentResolver(), key);
        } catch (Settings.SettingNotFoundException ignored) {
            return fallback;
        }
    }

    private int readSecureInt(String key, int fallback) {
        try {
            return Settings.Secure.getInt(getContentResolver(), key);
        } catch (Settings.SettingNotFoundException ignored) {
            return fallback;
        }
    }

    private String formatTime(long epochMillis) {
        if (epochMillis <= 0L) {
            return "-";
        }
        DateFormat format = DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.MEDIUM);
        return format.format(new Date(epochMillis));
    }
}
