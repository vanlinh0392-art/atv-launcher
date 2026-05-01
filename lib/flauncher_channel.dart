/*
 * FLauncher
 * Copyright (C) 2021  Etienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:async';

import 'package:flutter/services.dart';

class FLauncherChannel {
  static const _methodChannel = MethodChannel('com.atv.launcher/method');
  static const _appsEventChannel = EventChannel('com.atv.launcher/event_apps');
  static const _networkEventChannel =
      EventChannel('com.atv.launcher/event_network');
  static const _systemEventChannel =
      EventChannel('com.atv.launcher/event_system');

  Future<List<Map<dynamic, dynamic>>> getApplications() async {
    final applications = await _methodChannel
        .invokeListMethod<Map<dynamic, dynamic>>('getApplications');
    return applications ?? const [];
  }

  Future<Uint8List> getApplicationBanner(String packageName) async =>
      await _methodChannel.invokeMethod('getApplicationBanner', packageName);

  Future<Uint8List> getApplicationIcon(String packageName) async =>
      await _methodChannel.invokeMethod('getApplicationIcon', packageName);

  Future<bool> applicationExists(String packageName) async =>
      await _methodChannel.invokeMethod('applicationExists', packageName);

  Future<void> launchActivityFromAction(String action) async =>
      await _methodChannel.invokeMethod('launchActivityFromAction', action);

  Future<void> launchApp(String packageName) async =>
      await _methodChannel.invokeMethod('launchApp', packageName);

  Future<void> openSettings() async =>
      await _methodChannel.invokeMethod('openSettings');

  Future<void> openAppInfo(String packageName) async =>
      await _methodChannel.invokeMethod('openAppInfo', packageName);

  Future<void> uninstallApp(String packageName) async =>
      await _methodChannel.invokeMethod('uninstallApp', packageName);

  Future<bool> isDefaultLauncher() async =>
      await _methodChannel.invokeMethod('isDefaultLauncher');

  Future<bool> checkForGetContentAvailability() async =>
      await _methodChannel.invokeMethod('checkForGetContentAvailability');

  Future<Map<String, dynamic>> getActiveNetworkInformation() async {
    final map = await _methodChannel
        .invokeMapMethod<dynamic, dynamic>('getActiveNetworkInformation');
    return (map ?? const {}).cast<String, dynamic>();
  }

  Future<void> startAmbientMode() async =>
      await _methodChannel.invokeMethod('startAmbientMode');

  Future<Map<String, dynamic>> getSystemBridgeStatus() async =>
      _invokeMapMethod('getSystemBridgeStatus');

  Future<Map<String, dynamic>> getSystemBridgeStatusLite() async =>
      _invokeMapMethod('getSystemBridgeStatusLite');

  Future<List<String>> getSupportedAbis() async {
    final abis = await _methodChannel.invokeListMethod<dynamic>(
      'getSupportedAbis',
    );
    return (abis ?? const <dynamic>[])
        .map((value) => _normalizeSupportedAbi(value?.toString() ?? ''))
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> getProvisioningChecklist() async =>
      _invokeMapMethod('getProvisioningChecklist');

  Future<Map<String, dynamic>> getAdbAutomationStatus() async =>
      _invokeMapMethod('getAdbAutomationStatus');

  Future<Map<String, dynamic>> getAccessibilityManagerSnapshot() async =>
      _invokeMapMethod('getAccessibilityManagerSnapshot');

  Future<Map<String, dynamic>> setVoiceMode({
    int? mode,
    int? keyCode,
    bool? interceptEnabled,
  }) async =>
      _invokeMapMethod('setVoiceMode', {
        'mode': mode,
        'keyCode': keyCode,
        'interceptEnabled': interceptEnabled,
      });

  Future<Map<String, dynamic>> setVoiceInterceptEnabled(bool enabled) async =>
      _invokeMapMethod('setVoiceInterceptEnabled', {'enabled': enabled});

  Future<Map<String, dynamic>> startKeyLearning() async =>
      _invokeMapMethod('startKeyLearning');

  Future<Map<String, dynamic>> resetVoiceMapping() async =>
      _invokeMapMethod('resetVoiceMapping');

  Future<Map<String, dynamic>> testVoiceSearch() async =>
      _invokeMapMethod('testVoiceSearch');

  Future<void> openAccessibilitySettings() async =>
      await _methodChannel.invokeMethod('openAccessibilitySettings');

  Future<bool> openSpecificAndroidSettingsPage(String page) async =>
      await _methodChannel.invokeMethod(
          'openSpecificAndroidSettingsPage', page);

  Future<Map<String, dynamic>> repairAccessibility() async =>
      _invokeMapMethod('repairAccessibility');

  Future<Map<String, dynamic>> grantWriteSecureSettingsWithLocalAdb() async =>
      _invokeMapMethod('grantWriteSecureSettingsWithLocalAdb');

  Future<Map<String, dynamic>> setAdbAutomationPolicy({
    required String policy,
    required bool disableOnSleep,
  }) async =>
      _invokeMapMethod('setAdbAutomationPolicy', {
        'policy': policy,
        'disableOnSleep': disableOnSleep,
      });

  Future<Map<String, dynamic>> setAdbEnabledNow(bool enabled) async =>
      _invokeMapMethod('setAdbEnabledNow', {'enabled': enabled});

  Future<Map<String, dynamic>> runProvisioningAction({
    required String action,
    String? suggestedPolicy,
  }) async =>
      _invokeMapMethod('runProvisioningAction', {
        'action': action,
        'suggestedPolicy': suggestedPolicy,
      });

  Future<Map<String, dynamic>> setManagedAccessibility(
          String packageName, bool enabled) async =>
      _invokeMapMethod('setManagedAccessibility', {
        'packageName': packageName,
        'enabled': enabled,
      });

  Future<Map<String, dynamic>> getDensityStatus() async =>
      _invokeMapMethod('getDensityStatus');

  Future<Map<String, dynamic>> applyDensity(int density) async =>
      _invokeMapMethod('applyDensity', {'density': density});

  Future<Map<String, dynamic>> resetDensity() async =>
      _invokeMapMethod('resetDensity');

  Future<Map<String, dynamic>> getPrivateDnsStatus() async =>
      _invokeMapMethod('getPrivateDnsStatus');

  Future<Map<String, dynamic>> applyPrivateDns({
    required String mode,
    String? host,
  }) async =>
      _invokeMapMethod('applyPrivateDns', {'mode': mode, 'host': host});

  Future<Map<String, dynamic>> resetPrivateDns() async =>
      _invokeMapMethod('resetPrivateDns');

  Future<Map<String, dynamic>> getFileAccessStatus() async =>
      _invokeMapMethod('getFileAccessStatus');

  Future<Map<String, dynamic>> requestMediaReadPermission() async =>
      _invokeMapMethod('requestMediaReadPermission');

  Future<Map<String, dynamic>> prepareLauncherUpdateInstall() async =>
      _invokeMapMethod('prepareLauncherUpdateInstall');

  Future<Map<String, dynamic>> installDownloadedApk(String filePath) async =>
      _invokeMapMethod('installDownloadedApk', {'filePath': filePath});

  Future<Map<String, dynamic>> browseLocalVideoLibrary({
    String? bucketId,
  }) async =>
      _invokeMapMethod('browseLocalVideoLibrary', {
        'bucketId': bucketId,
      });

  Future<Map<String, dynamic>> getTvInputs() async =>
      _invokeMapMethod('getTvInputs');

  Future<bool> launchTvInput(String inputId) async =>
      await _methodChannel.invokeMethod('launchTvInput', {'inputId': inputId});

  Future<Map<String, dynamic>> querySearchableMedia() async =>
      _invokeMapMethod('querySearchableMedia');

  Future<bool> launchMediaUri(String uri) async =>
      await _methodChannel.invokeMethod('launchMediaUri', {'uri': uri});

  Future<Map<String, dynamic>> startSpeechRecognizer() async =>
      _invokeMapMethod('startSpeechRecognizer');

  Future<Map<String, dynamic>> pickWallpaperAsset(
          {String kind = 'mixed'}) async =>
      _invokeMapMethod('pickWallpaperAsset', {'kind': kind});

  Future<Map<String, dynamic>> pickWallpaperFiles() async =>
      _invokeMapMethod('pickWallpaperFiles');

  Future<Map<String, dynamic>> pickWallpaperFolder() async =>
      _invokeMapMethod('pickWallpaperFolder');

  Future<Map<String, dynamic>> setWallpaperMode(String mode) async =>
      _invokeMapMethod('setWallpaperMode', mode);

  Future<Map<String, dynamic>> setVideoWallpaperOptions({
    String? sourceType,
    List<String>? assetUris,
    String? folderUri,
    String? folderBucketId,
    String? folderName,
    String? orderMode,
    String? advanceMode,
    int? switchIntervalSeconds,
    int? repeatCountPerItem,
    bool? playlistLoop,
    bool? loop,
    bool? mute,
    String? fit,
    int? dimPercent,
    String? blur,
    bool? autoResume,
    bool? videoAllowedByPerformanceMode,
    bool? disableAudioRendererWhenMuted,
    bool? deferForegroundResume,
  }) async =>
      _invokeMapMethod('setVideoWallpaperOptions', {
        'sourceType': sourceType,
        'assetUris': assetUris,
        'folderUri': folderUri,
        'folderBucketId': folderBucketId,
        'folderName': folderName,
        'orderMode': orderMode,
        'advanceMode': advanceMode,
        'switchIntervalSeconds': switchIntervalSeconds,
        'repeatCountPerItem': repeatCountPerItem,
        'playlistLoop': playlistLoop,
        'loop': loop,
        'mute': mute,
        'fit': fit,
        'dimPercent': dimPercent,
        'blur': blur,
        'autoResume': autoResume,
        'videoAllowedByPerformanceMode': videoAllowedByPerformanceMode,
        'disableAudioRendererWhenMuted': disableAudioRendererWhenMuted,
        'deferForegroundResume': deferForegroundResume,
      });

  Future<Map<String, dynamic>> setVideoWallpaperPlaybackSuppressed({
    required bool suppressed,
    String? reason,
  }) =>
      _invokeMapMethod('setVideoWallpaperPlaybackSuppressed', {
        'suppressed': suppressed,
        'reason': reason,
      });

  Future<Map<String, dynamic>> exportSettingsBackup({
    required String fileName,
    required String content,
  }) async =>
      _invokeMapMethod('exportSettingsBackup', {
        'fileName': fileName,
        'content': content,
      });

  Future<Map<String, dynamic>> importSettingsBackup() async =>
      _invokeMapMethod('importSettingsBackup');

  Future<Map<String, dynamic>> previewBackup() async =>
      _invokeMapMethod('previewBackup');

  Future<Map<String, dynamic>> recordBackupRestoreResult({
    required String importName,
    required String summary,
    required int restoredAt,
  }) async =>
      _invokeMapMethod('recordBackupRestoreResult', {
        'importName': importName,
        'summary': summary,
        'restoredAt': restoredAt,
      });

  Future<int> getVideoWallpaperTextureId() async =>
      await _methodChannel.invokeMethod<int>('getVideoWallpaperTextureId') ??
      -1;

  Future<String> getDiagnosticsReport() async =>
      await _methodChannel.invokeMethod<String>('getDiagnosticsReport') ?? '';

  void addAppsChangedListener(void Function(Map<String, dynamic>) listener) =>
      _appsEventChannel.receiveBroadcastStream().listen((event) {
        final eventMap = (event as Map).cast<String, dynamic>();
        listener(eventMap);
      });

  void addNetworkChangedListener(
          void Function(Map<String, dynamic>) listener) =>
      _networkEventChannel.receiveBroadcastStream().listen((event) {
        final eventMap = (event as Map).cast<String, dynamic>();
        listener(eventMap);
      });

  StreamSubscription<dynamic> addSystemChangedListener(
    void Function(Map<String, dynamic>) listener,
  ) =>
      _systemEventChannel.receiveBroadcastStream().listen((event) {
        final eventMap = (event as Map).cast<String, dynamic>();
        listener(eventMap);
      });

  Future<Map<String, dynamic>> _invokeMapMethod(String method,
      [Object? arguments]) async {
    final map = await _methodChannel.invokeMapMethod<dynamic, dynamic>(
        method, arguments);
    return (map ?? const {}).cast<String, dynamic>();
  }

  String _normalizeSupportedAbi(String rawAbi) {
    final normalized = rawAbi.trim().toLowerCase().replaceAll('_', '-');
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized.contains('arm64') || normalized.contains('aarch64')) {
      return 'arm64-v8a';
    }
    if (normalized.contains('armeabi-v7a') ||
        normalized == 'armeabi' ||
        normalized.contains('armv7')) {
      return 'armeabi-v7a';
    }
    return normalized;
  }
}
