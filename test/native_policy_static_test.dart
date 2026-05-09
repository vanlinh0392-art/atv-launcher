import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Gradle declares Kotlin plugin before the Flutter app plugin', () {
    final settings = File('android/settings.gradle').readAsStringSync();
    final appBuild = File('android/app/build.gradle').readAsStringSync();

    expect(settings, contains('id "org.jetbrains.kotlin.android"'));
    expect(appBuild.indexOf('id "org.jetbrains.kotlin.android"'),
        lessThan(appBuild.indexOf('id "dev.flutter.flutter-gradle-plugin"')));
  });

  test('Android OS backup is disabled in favor of controlled app export', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
  });

  test('default ADB provisioning does not auto-whitelist battery optimization',
      () {
    final mainActivity = File(
      'android/app/src/main/java/com/atv/launcher/MainActivity.java',
    ).readAsStringSync();

    final checklist = _methodBody(
      mainActivity,
      'private Map<String, Object> buildProvisioningChecklist()',
      'private void applyProvisioningEvaluation(',
    );
    final grantBatch = _methodBody(
      mainActivity,
      'private List<String> buildProvisioningGrantCommands()',
      'private LocalAdbBridge.Result runLocalAdbGrantBatch(',
    );

    expect(checklist, isNot(contains('deviceidle whitelist')));
    expect(grantBatch, isNot(contains('deviceidle whitelist')));
    expect(
      checklist,
      contains('Only whitelist battery optimization on Android boxes'),
    );
    expect(mainActivity, contains('shouldRecommendBatteryOptimization()'));
    expect(mainActivity, contains('? "recommended" : "optional"'));
  });

  test('release logs do not print sensitive local ADB command details', () {
    final mainActivity = File(
      'android/app/src/main/java/com/atv/launcher/MainActivity.java',
    ).readAsStringSync();
    final densityController = File(
      'android/app/src/main/java/com/atv/launcher/systembridge/density/DensityController.java',
    ).readAsStringSync();

    expect(mainActivity, isNot(contains('Log.i(TAG, "local_adb_shell ')));
    expect(mainActivity, isNot(contains('Log.i(TAG, "local_adb_batch ')));
    expect(mainActivity, contains('logSensitiveInfo("local_adb_shell '));
    expect(mainActivity, contains('logSensitiveInfo("local_adb_batch '));
    expect(densityController, contains('ApplicationInfo.FLAG_DEBUGGABLE'));
    expect(densityController, isNot(contains('Log.i(TAG, "Shell attempt ')));
    expect(
        densityController, isNot(contains('Log.i(TAG, "Local ADB attempt ')));
  });

  test('legacy activity result flow has explicit deprecation suppression', () {
    final mainActivity = File(
      'android/app/src/main/java/com/atv/launcher/MainActivity.java',
    ).readAsStringSync();

    expect(mainActivity, contains('@SuppressWarnings("deprecation")'));
    expect(mainActivity,
        contains('public class MainActivity extends FlutterActivity'));
    expect(mainActivity, contains('protected void onActivityResult'));
    expect(mainActivity, contains('onRequestPermissionsResult'));
    expect(mainActivity, contains('startActivityForResult('));
    expect(mainActivity, contains('requestPermissions('));
  });

  test('video wake logs are gated behind debug builds', () {
    final controller = File(
      'android/app/src/main/java/com/atv/launcher/systembridge/wallpaper/VideoWallpaperController.java',
    ).readAsStringSync();

    expect(controller, contains('logWakeInfo("wallpaper_wake_rearm'));
    expect(controller, contains('isDebuggableBuild()'));
    expect(controller, isNot(contains('Log.i(TAG, "wallpaper_wake_rearm')));
  });

  test('launcher app query failures are logged instead of ignored', () {
    final mainActivity = File(
      'android/app/src/main/java/com/atv/launcher/MainActivity.java',
    ).readAsStringSync();

    expect(
      mainActivity,
      isNot(contains('InterruptedException | ExecutionException ignored')),
    );
    expect(mainActivity, contains('Thread.currentThread().interrupt()'));
    expect(mainActivity, contains('Failed to query launcher apps'));
    expect(mainActivity, contains('Failed to build launcher app entry'));
  });

  test('video wallpaper poster extraction scales and recycles native bitmaps',
      () {
    final mainActivity = File(
      'android/app/src/main/java/com/atv/launcher/MainActivity.java',
    ).readAsStringSync();
    final previewCode = _methodBody(
      mainActivity,
      'private String createWallpaperPreview(',
      'private Bitmap extractScaledVideoPreviewFrame(',
    );
    final extractorCode = _methodBody(
      mainActivity,
      'private Bitmap extractScaledVideoPreviewFrame(',
      'private Pair<Integer, Integer> resolveVideoPreviewFrameSize(',
    );

    expect(extractorCode, contains('getScaledFrameAtTime'));
    expect(previewCode, contains('normalizedBitmap.recycle()'));
    expect(previewCode, contains('sourceBitmap.recycle()'));
  });

  test('missing app banners use a bounded negative cache', () {
    final mainActivity = File(
      'android/app/src/main/java/com/atv/launcher/MainActivity.java',
    ).readAsStringSync();

    expect(mainActivity, contains('MAX_IMAGE_NEGATIVE_CACHE_ENTRIES = 24'));
    expect(mainActivity, contains('APP_IMAGE_NEGATIVE_CACHE'));
    expect(mainActivity, contains('isCachedAppImageMiss(cacheKey)'));
    expect(mainActivity, contains('putCachedAppImageMiss(cacheKey)'));
    expect(
      mainActivity,
      contains(
          'APP_IMAGE_NEGATIVE_CACHE.size() > MAX_IMAGE_NEGATIVE_CACHE_ENTRIES'),
    );
  });
}

String _methodBody(String source, String startToken, String endToken) {
  final start = source.indexOf(startToken);
  final end = source.indexOf(endToken, start);
  expect(start, greaterThanOrEqualTo(0),
      reason: 'Missing start token: $startToken');
  expect(end, greaterThanOrEqualTo(0), reason: 'Missing end token: $endToken');
  return source.substring(start, end);
}
