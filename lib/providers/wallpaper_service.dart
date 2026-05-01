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
import 'dart:io';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/home_performance_profile.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class WallpaperService extends ChangeNotifier with WidgetsBindingObserver {
  static const bool fastStartupEnabled = true;

  final FLauncherChannel _fLauncherChannel;
  final SettingsService _settingsService;

  ImageProvider? _wallpaper;
  int? _videoTextureId;
  bool _videoWarmUpScheduled = false;
  bool _videoWarmUpCompleted = false;
  int _settingsPlaybackSuppressionCount = 0;
  final int _bootstrapStartedAt = DateTime.now().millisecondsSinceEpoch;
  Timer? _pendingVideoWarmUpTimer;
  bool _homeVisibleAndUsable = false;
  late String _lastKnownPerformanceMode;

  ImageProvider? get wallpaper => _wallpaper;
  int? get videoTextureId => _videoTextureId;
  bool get isVideoMode => _settingsService.wallpaperMode == 'video';
  bool get videoAllowedByPerformanceMode =>
      _performanceProfile.allowVideoWallpaper;
  bool get videoBlockedByPerformanceMode => !videoAllowedByPerformanceMode;
  bool get settingsPlaybackSuppressed => _settingsPlaybackSuppressionCount > 0;
  String get wallpaperMode => _settingsService.wallpaperMode;
  String get wallpaperAssetUri => _settingsService.wallpaperAssetUri;
  String get wallpaperPreviewPath => _settingsService.wallpaperPreviewPath;
  String get videoSourceType => _settingsService.videoWallpaperSourceType;
  List<String> get videoUris => _settingsService.videoWallpaperUris;
  String get videoFolderUri => _settingsService.videoWallpaperFolderUri;
  String get videoFolderBucketId =>
      _settingsService.videoWallpaperFolderBucketId;
  String get videoFolderName => _settingsService.videoWallpaperFolderName;
  String get videoOrderMode => _settingsService.videoWallpaperOrderMode;
  String get videoAdvanceMode => _settingsService.videoWallpaperAdvanceMode;
  int get videoSwitchIntervalSeconds =>
      _settingsService.videoWallpaperSwitchIntervalSeconds;
  int get videoRepeatCountPerItem =>
      _settingsService.videoWallpaperRepeatCountPerItem;
  bool get videoPlaylistLoop => _settingsService.videoWallpaperPlaylistLoop;
  bool get videoLoop => _settingsService.videoWallpaperLoop;
  bool get videoMute => _settingsService.videoWallpaperMute;
  String get videoFit => _settingsService.videoWallpaperFit;
  int get videoDimPercent => _settingsService.videoWallpaperDimPercent;
  String get videoBlur => _settingsService.videoWallpaperBlur;
  bool get videoAutoResume => _settingsService.videoWallpaperAutoResume;

  FLauncherGradient get gradient => FLauncherGradients.all.firstWhere(
        (gradient) => gradient.uuid == _settingsService.gradientUuid,
        orElse: () => FLauncherGradients.greatWhale,
      );

  HomePerformanceProfile get _performanceProfile =>
      HomePerformanceProfile.resolve(_settingsService.homeDockPerformanceMode);

  Duration get _videoWarmUpDelay =>
      _performanceProfile.wallpaperVideoWarmUpDelay;

  bool get _disableAudioRendererWhenMuted =>
      _performanceProfile.disableAudioRendererWhenMuted;

  bool get _shouldDelayVideoUntilHomeSettles =>
      _performanceProfile.startVideoAfterHomeSettles;

  bool get _shouldReleasePlayerOnBackground =>
      _performanceProfile.releasePlayerOnBackground;

  bool get _canActivateVideoWallpaper =>
      isVideoMode && videoAllowedByPerformanceMode;

  bool get _hasStoredVideoSelection =>
      videoUris.isNotEmpty ||
      wallpaperAssetUri.isNotEmpty ||
      videoFolderUri.isNotEmpty ||
      videoFolderBucketId.isNotEmpty;

  bool get _shouldAutoRestoreVideoAfterOffFallback =>
      _settingsService.wallpaperVideoRestoreCandidatePending &&
      videoAllowedByPerformanceMode &&
      _settingsService.homeDockPerformanceMode !=
          SettingsService.homeDockPerformanceModeQuality &&
      _hasStoredVideoSelection;

  WallpaperService(this._fLauncherChannel, this._settingsService) {
    _lastKnownPerformanceMode = _settingsService.homeDockPerformanceMode;
    WidgetsBinding.instance.addObserver(this);
    _settingsService.addListener(_handleSettingsChanged);
    _init();
  }

  Future<void> _init() async {
    await _reloadPreviewImage();
    _logStartupMetric(
      'time_to_wallpaper_poster',
      DateTime.now().millisecondsSinceEpoch - _bootstrapStartedAt,
    );
    if (videoBlockedByPerformanceMode && isVideoMode) {
      await _fallbackFromVideoForPerformanceMode(autoRestoreEligible: true);
      return;
    }
    if (_shouldAutoRestoreVideoAfterOffFallback) {
      await _restoreVideoAfterOffFallback();
      return;
    }
    if (!_canActivateVideoWallpaper) {
      await _syncCurrentNonVideoModeToNative(
        clearRestoreCandidateForQuality: true,
      );
      return;
    }
    if (_shouldDelayVideoUntilHomeSettles) {
      await syncVideoOptionsToNative(notifyFlutter: false);
      return;
    }
    if (fastStartupEnabled) {
      _scheduleVideoWarmUp(allowDeferredStart: false);
    } else {
      await _warmUpVideoController();
    }
  }

  Future<void> restoreFromSettings() async {
    await _reloadPreviewImage();
    if (videoBlockedByPerformanceMode && isVideoMode) {
      await _fallbackFromVideoForPerformanceMode(autoRestoreEligible: true);
      return;
    }
    if (_shouldAutoRestoreVideoAfterOffFallback) {
      await _restoreVideoAfterOffFallback();
      return;
    }
    if (!_canActivateVideoWallpaper) {
      await _syncCurrentNonVideoModeToNative(
        clearRestoreCandidateForQuality: true,
      );
      _markVideoNeedsWarmUp(clearTexture: true);
      return;
    }
    await _fLauncherChannel.setWallpaperMode(wallpaperMode);
    if (_canActivateVideoWallpaper) {
      if (_shouldDelayVideoUntilHomeSettles) {
        _markVideoNeedsWarmUp(clearTexture: true);
        await syncVideoOptionsToNative(notifyFlutter: false);
        return;
      }
      await _warmUpVideoControllerForCurrentMode(allowDeferred: true);
    } else {
      _markVideoNeedsWarmUp(clearTexture: true);
    }
  }

  Future<bool> _reloadPreviewImage() async {
    final path = _settingsService.wallpaperPreviewPath;
    if (path.isNotEmpty && await File(path).exists()) {
      _wallpaper = FileImage(File(path));
      notifyListeners();
      return true;
    } else {
      _wallpaper = null;
    }
    notifyListeners();
    return false;
  }

  Future<void> _ensureVideoTextureId() async {
    final textureId = await _fLauncherChannel.getVideoWallpaperTextureId();
    _videoTextureId = textureId >= 0 ? textureId : null;
    notifyListeners();
  }

  void _scheduleVideoWarmUp({required bool allowDeferredStart}) {
    if (!_canActivateVideoWallpaper ||
        _videoWarmUpScheduled ||
        _videoWarmUpCompleted) {
      return;
    }
    if (_shouldDelayVideoUntilHomeSettles &&
        (!_homeVisibleAndUsable || settingsPlaybackSuppressed)) {
      return;
    }
    _pendingVideoWarmUpTimer?.cancel();
    _videoWarmUpScheduled = true;
    _pendingVideoWarmUpTimer = Timer(_videoWarmUpDelay, () async {
      _pendingVideoWarmUpTimer = null;
      _videoWarmUpScheduled = false;
      await _startVideoWarmUpIfEligible(allowDeferredStart: allowDeferredStart);
    });
  }

  Future<void> _warmUpVideoControllerForCurrentMode({
    required bool allowDeferred,
  }) async {
    if (allowDeferred &&
        fastStartupEnabled &&
        _shouldDelayVideoUntilHomeSettles) {
      scheduleHomeVisibleVideoStart();
      return;
    }
    await _warmUpVideoController();
  }

  Future<void> _startVideoWarmUpIfEligible({
    required bool allowDeferredStart,
  }) async {
    if (!_canActivateVideoWallpaper) {
      return;
    }
    if (_shouldDelayVideoUntilHomeSettles) {
      if (!allowDeferredStart ||
          !_homeVisibleAndUsable ||
          settingsPlaybackSuppressed) {
        return;
      }
    }
    await _warmUpVideoController();
  }

  Future<void> _warmUpVideoController() async {
    if (!_canActivateVideoWallpaper) {
      return;
    }
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    await _ensureVideoTextureId();
    await syncVideoOptionsToNative(notifyFlutter: false);
    _videoWarmUpCompleted = true;
    notifyListeners();
    _logStartupMetric(
      'time_to_video_ready_request',
      DateTime.now().millisecondsSinceEpoch - startedAt,
    );
  }

  Future<void> pickImageWallpaper() async {
    final result = await _fLauncherChannel.pickWallpaperAsset(kind: 'image');
    if (result['cancelled'] == true) {
      return;
    }
    await _settingsService
        .setWallpaperAssetUri(result['uri']?.toString() ?? '');
    await _settingsService
        .setWallpaperPreviewPath(result['previewPath']?.toString() ?? '');
    await _settingsService.setWallpaperMode('image');
    await _settingsService.setWallpaperVideoRestoreCandidatePending(false);
    await _fLauncherChannel.setWallpaperMode('image');
    cancelPendingHomeVideoStart(clearHomeVisible: true);
    _markVideoNeedsWarmUp(clearTexture: true, notify: false);
    await _reloadPreviewImage();
  }

  Future<void> pickVideoWallpaper() async {
    if (videoBlockedByPerformanceMode) {
      return;
    }
    final result = await _fLauncherChannel.pickWallpaperAsset(kind: 'video');
    if (result['cancelled'] == true) {
      return;
    }
    await _applyVideoSelection(
      sourceType: 'single_file',
      wallpaperAssetUri: result['uri']?.toString() ?? '',
      previewPath: result['previewPath']?.toString() ?? '',
      assetUris: [
        if ((result['uri']?.toString() ?? '').isNotEmpty)
          result['uri'].toString(),
      ],
    );
  }

  Future<void> pickVideoWallpaperFilesSaf() async {
    if (videoBlockedByPerformanceMode) {
      return;
    }
    final result = await _fLauncherChannel.pickWallpaperFiles();
    if (result['cancelled'] == true) {
      return;
    }
    final uris = ((result['uris'] as List?) ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    await _applyVideoSelection(
      sourceType: uris.length <= 1 ? 'single_file' : 'multi_file_playlist',
      wallpaperAssetUri:
          result['primaryUri']?.toString() ?? (uris.isEmpty ? '' : uris.first),
      previewPath: result['previewPath']?.toString() ?? '',
      assetUris: uris,
    );
  }

  Future<void> pickVideoWallpaperFolderSaf() async {
    if (videoBlockedByPerformanceMode) {
      return;
    }
    final result = await _fLauncherChannel.pickWallpaperFolder();
    if (result['cancelled'] == true) {
      return;
    }
    final uris = ((result['uris'] as List?) ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    await _applyVideoSelection(
      sourceType: 'folder_playlist',
      wallpaperAssetUri:
          result['primaryUri']?.toString() ?? (uris.isEmpty ? '' : uris.first),
      previewPath: result['previewPath']?.toString() ?? '',
      assetUris: uris,
      folderUri: result['folderUri']?.toString() ?? '',
      folderName: result['folderName']?.toString() ?? '',
    );
  }

  Future<Map<String, dynamic>> browseLocalVideoLibrary({String? bucketId}) =>
      _fLauncherChannel.browseLocalVideoLibrary(bucketId: bucketId);

  Future<void> applyLibrarySelection({
    required List<String> uris,
    required String sourceType,
    String previewPath = '',
    String folderBucketId = '',
    String folderName = '',
  }) async {
    if (videoBlockedByPerformanceMode) {
      return;
    }
    await _applyVideoSelection(
      sourceType: sourceType,
      wallpaperAssetUri: uris.isEmpty ? '' : uris.first,
      previewPath: previewPath,
      assetUris: uris,
      folderBucketId: folderBucketId,
      folderName: folderName,
    );
  }

  Future<void> _applyVideoSelection({
    required String sourceType,
    required String wallpaperAssetUri,
    required String previewPath,
    required List<String> assetUris,
    String folderUri = '',
    String folderBucketId = '',
    String folderName = '',
  }) async {
    if (videoBlockedByPerformanceMode) {
      return;
    }
    await _settingsService.setWallpaperAssetUri(wallpaperAssetUri);
    await _settingsService.setWallpaperPreviewPath(previewPath);
    await _settingsService.setWallpaperMode('video');
    await _settingsService.setWallpaperVideoRestoreCandidatePending(false);
    await _settingsService.setVideoWallpaperSourceType(sourceType);
    await _settingsService.setVideoWallpaperUris(assetUris);
    await _settingsService.setVideoWallpaperFolderUri(folderUri);
    await _settingsService.setVideoWallpaperFolderBucketId(folderBucketId);
    await _settingsService.setVideoWallpaperFolderName(folderName);
    await _fLauncherChannel.setWallpaperMode('video');
    await _reloadPreviewImage();
    _markVideoNeedsWarmUp(clearTexture: _shouldDelayVideoUntilHomeSettles);
    await _warmUpVideoControllerForCurrentMode(allowDeferred: true);
  }

  Future<void> setGradient(FLauncherGradient fLauncherGradient) async {
    await _settingsService.setGradientUuid(fLauncherGradient.uuid);
    await _settingsService.setWallpaperMode('gradient');
    await _settingsService.setWallpaperVideoRestoreCandidatePending(false);
    await _fLauncherChannel.setWallpaperMode('gradient');
    _wallpaper = null;
    cancelPendingHomeVideoStart(clearHomeVisible: true);
    _markVideoNeedsWarmUp(clearTexture: true, notify: false);
    notifyListeners();
  }

  Future<void> setVideoOrderMode(String value) async {
    await _settingsService.setVideoWallpaperOrderMode(value);
    await syncVideoOptionsToNative();
  }

  Future<void> setVideoAdvanceMode(String value) async {
    await _settingsService.setVideoWallpaperAdvanceMode(value);
    await syncVideoOptionsToNative();
  }

  Future<void> setVideoSwitchIntervalSeconds(int value) async {
    await _settingsService.setVideoWallpaperSwitchIntervalSeconds(value);
    await syncVideoOptionsToNative();
  }

  Future<void> setVideoRepeatCountPerItem(int value) async {
    await _settingsService.setVideoWallpaperRepeatCountPerItem(value);
    await syncVideoOptionsToNative();
  }

  Future<void> setVideoPlaylistLoop(bool value) async {
    await _settingsService.setVideoWallpaperPlaylistLoop(value);
    await syncVideoOptionsToNative();
  }

  Future<void> setVideoLoop(bool value) async {
    await _settingsService.setVideoWallpaperLoop(value);
    await syncVideoOptionsToNative();
  }

  Future<void> setVideoMute(bool value) async {
    await _settingsService.setVideoWallpaperMute(value);
    await syncVideoOptionsToNative();
  }

  Future<void> setVideoFit(String value) async {
    await _settingsService.setVideoWallpaperFit(value);
    await syncVideoOptionsToNative();
  }

  Future<void> setVideoDimPercent(int value) async {
    await _settingsService.setVideoWallpaperDimPercent(value);
    await syncVideoOptionsToNative();
  }

  Future<void> setVideoBlur(String value) async {
    await _settingsService.setVideoWallpaperBlur(value);
    await syncVideoOptionsToNative();
  }

  Future<void> setVideoAutoResume(bool value) async {
    await _settingsService.setVideoWallpaperAutoResume(value);
    await syncVideoOptionsToNative();
  }

  Future<void> setSettingsPlaybackSuppressed(bool suppressed) async {
    final previousSuppressed = settingsPlaybackSuppressed;
    if (suppressed) {
      _settingsPlaybackSuppressionCount += 1;
      cancelPendingHomeVideoStart();
      if (_shouldDelayVideoUntilHomeSettles) {
        _markVideoNeedsWarmUp(clearTexture: false);
      }
    } else if (_settingsPlaybackSuppressionCount > 0) {
      _settingsPlaybackSuppressionCount -= 1;
    }

    final nextSuppressed = settingsPlaybackSuppressed;
    if (previousSuppressed == nextSuppressed) {
      return;
    }

    await _fLauncherChannel.setVideoWallpaperPlaybackSuppressed(
      suppressed: nextSuppressed,
      reason: nextSuppressed ? 'settings_panel' : 'settings_panel_release',
    );
    if (!nextSuppressed && _shouldDelayVideoUntilHomeSettles) {
      scheduleHomeVisibleVideoStart();
    }
  }

  void notifyHomeVisibleAndUsable() {
    _homeVisibleAndUsable = true;
    if (!_canActivateVideoWallpaper || settingsPlaybackSuppressed) {
      return;
    }
    if (_shouldDelayVideoUntilHomeSettles) {
      scheduleHomeVisibleVideoStart();
    } else if (!_videoWarmUpCompleted && !_videoWarmUpScheduled) {
      if (fastStartupEnabled) {
        _scheduleVideoWarmUp(allowDeferredStart: false);
      } else {
        unawaited(_warmUpVideoController());
      }
    }
  }

  void cancelPendingHomeVideoStart({bool clearHomeVisible = false}) {
    _pendingVideoWarmUpTimer?.cancel();
    _pendingVideoWarmUpTimer = null;
    _videoWarmUpScheduled = false;
    if (clearHomeVisible) {
      _homeVisibleAndUsable = false;
    }
  }

  Future<void> syncVideoOptionsToNative({
    bool notifyFlutter = true,
  }) async {
    await _fLauncherChannel.setVideoWallpaperOptions(
      sourceType: videoSourceType,
      assetUris: videoUris.isNotEmpty
          ? videoUris
          : [
              if (wallpaperAssetUri.isNotEmpty) wallpaperAssetUri,
            ],
      folderUri: videoFolderUri,
      folderBucketId: videoFolderBucketId,
      folderName: videoFolderName,
      orderMode: videoOrderMode,
      advanceMode: videoAdvanceMode,
      switchIntervalSeconds: videoSwitchIntervalSeconds,
      repeatCountPerItem: videoRepeatCountPerItem,
      playlistLoop: videoPlaylistLoop,
      loop: videoLoop,
      mute: videoMute,
      fit: videoFit,
      dimPercent: videoDimPercent,
      blur: videoBlur,
      autoResume: videoAutoResume,
      videoAllowedByPerformanceMode: videoAllowedByPerformanceMode,
      disableAudioRendererWhenMuted: _disableAudioRendererWhenMuted,
      deferForegroundResume: _shouldDelayVideoUntilHomeSettles,
    );
    if (notifyFlutter) {
      notifyListeners();
    }
  }

  void _handleSettingsChanged() {
    final nextPerformanceMode = _settingsService.homeDockPerformanceMode;
    if (nextPerformanceMode == _lastKnownPerformanceMode) {
      return;
    }
    _lastKnownPerformanceMode = nextPerformanceMode;
    unawaited(_applyPerformanceModePolicyChange());
  }

  void scheduleHomeVisibleVideoStart() {
    if (!_shouldDelayVideoUntilHomeSettles ||
        !_canActivateVideoWallpaper ||
        settingsPlaybackSuppressed ||
        !_homeVisibleAndUsable ||
        _videoWarmUpCompleted ||
        _videoWarmUpScheduled) {
      return;
    }
    _scheduleVideoWarmUp(allowDeferredStart: true);
  }

  void _markVideoNeedsWarmUp({
    required bool clearTexture,
    bool notify = true,
  }) {
    cancelPendingHomeVideoStart();
    _videoWarmUpCompleted = false;
    if (clearTexture) {
      _videoTextureId = null;
    }
    if (notify) {
      notifyListeners();
    }
  }

  void _handleAppBackgrounded() {
    cancelPendingHomeVideoStart(clearHomeVisible: true);
    if (_shouldReleasePlayerOnBackground && _canActivateVideoWallpaper) {
      _markVideoNeedsWarmUp(clearTexture: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_canActivateVideoWallpaper || _shouldDelayVideoUntilHomeSettles) {
        return;
      }
      if (!_videoWarmUpCompleted && !_videoWarmUpScheduled) {
        if (fastStartupEnabled) {
          _scheduleVideoWarmUp(allowDeferredStart: false);
        } else {
          unawaited(_warmUpVideoController());
        }
      }
      return;
    }
    _handleAppBackgrounded();
  }

  @override
  void dispose() {
    cancelPendingHomeVideoStart(clearHomeVisible: true);
    _settingsService.removeListener(_handleSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _logStartupMetric(String label, int elapsedMs) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('FLauncherPerf $label elapsedMs=$elapsedMs');
  }

  Future<void> _applyPerformanceModePolicyChange() async {
    await syncVideoOptionsToNative(notifyFlutter: false);
    if (videoBlockedByPerformanceMode && isVideoMode) {
      await _fallbackFromVideoForPerformanceMode(autoRestoreEligible: true);
      return;
    }
    if (_shouldAutoRestoreVideoAfterOffFallback) {
      await _restoreVideoAfterOffFallback();
      return;
    }
    if (videoAllowedByPerformanceMode &&
        _settingsService.wallpaperVideoRestoreCandidatePending &&
        _settingsService.homeDockPerformanceMode ==
            SettingsService.homeDockPerformanceModeQuality) {
      await _settingsService.setWallpaperVideoRestoreCandidatePending(false);
    }
    if (!_canActivateVideoWallpaper) {
      notifyListeners();
      return;
    }
    if (_shouldDelayVideoUntilHomeSettles) {
      cancelPendingHomeVideoStart();
      if (_homeVisibleAndUsable && !settingsPlaybackSuppressed) {
        scheduleHomeVisibleVideoStart();
      }
      notifyListeners();
      return;
    }
    if (!_videoWarmUpCompleted && !_videoWarmUpScheduled) {
      if (fastStartupEnabled) {
        _scheduleVideoWarmUp(allowDeferredStart: false);
      } else {
        await _warmUpVideoController();
      }
    }
    notifyListeners();
  }

  Future<void> _fallbackFromVideoForPerformanceMode({
    required bool autoRestoreEligible,
  }) async {
    cancelPendingHomeVideoStart(clearHomeVisible: true);
    _markVideoNeedsWarmUp(clearTexture: true, notify: false);
    final hasPosterPreview = await _reloadPreviewImage();
    await _settingsService.setWallpaperVideoRestoreCandidatePending(
      autoRestoreEligible && _hasStoredVideoSelection,
    );
    if (hasPosterPreview) {
      await _settingsService.setWallpaperMode('image');
      await _fLauncherChannel.setWallpaperMode('image');
      await syncVideoOptionsToNative(notifyFlutter: false);
      notifyListeners();
      return;
    }
    await _settingsService.setWallpaperMode('gradient');
    await _fLauncherChannel.setWallpaperMode('gradient');
    _wallpaper = null;
    await syncVideoOptionsToNative(notifyFlutter: false);
    notifyListeners();
  }

  Future<void> _syncCurrentNonVideoModeToNative({
    required bool clearRestoreCandidateForQuality,
  }) async {
    if (isVideoMode) {
      return;
    }
    if (clearRestoreCandidateForQuality &&
        _settingsService.wallpaperVideoRestoreCandidatePending &&
        _settingsService.homeDockPerformanceMode ==
            SettingsService.homeDockPerformanceModeQuality) {
      await _settingsService.setWallpaperVideoRestoreCandidatePending(false);
    }
    await _fLauncherChannel.setWallpaperMode(wallpaperMode);
    await syncVideoOptionsToNative(notifyFlutter: false);
  }

  Future<void> _restoreVideoAfterOffFallback() async {
    await _settingsService.setWallpaperVideoRestoreCandidatePending(false);
    await _settingsService.setWallpaperMode('video');
    await _fLauncherChannel.setWallpaperMode('video');
    await _reloadPreviewImage();
    _markVideoNeedsWarmUp(
      clearTexture: _shouldDelayVideoUntilHomeSettles,
      notify: false,
    );
    await _warmUpVideoControllerForCurrentMode(allowDeferred: true);
    notifyListeners();
  }
}
