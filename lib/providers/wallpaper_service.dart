/*
 * FLauncher
 * Copyright (C) 2021  Etienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:io';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class WallpaperService extends ChangeNotifier {
  static const bool fastStartupEnabled = true;
  static const Duration _videoWarmUpDelay = Duration(milliseconds: 400);

  final FLauncherChannel _fLauncherChannel;
  final SettingsService _settingsService;

  ImageProvider? _wallpaper;
  int? _videoTextureId;
  bool _videoWarmUpScheduled = false;
  bool _videoWarmUpCompleted = false;
  int _settingsPlaybackSuppressionCount = 0;
  final int _bootstrapStartedAt = DateTime.now().millisecondsSinceEpoch;

  ImageProvider? get wallpaper => _wallpaper;
  int? get videoTextureId => _videoTextureId;
  bool get isVideoMode => _settingsService.wallpaperMode == 'video';
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

  WallpaperService(this._fLauncherChannel, this._settingsService) {
    _init();
  }

  Future<void> _init() async {
    await _reloadPreviewImage();
    _logStartupMetric(
      'time_to_wallpaper_poster',
      DateTime.now().millisecondsSinceEpoch - _bootstrapStartedAt,
    );
    if (!isVideoMode) {
      return;
    }
    if (fastStartupEnabled) {
      _scheduleVideoWarmUp();
    } else {
      await _warmUpVideoController();
    }
  }

  Future<void> restoreFromSettings() async {
    await _reloadPreviewImage();
    await _fLauncherChannel.setWallpaperMode(wallpaperMode);
    if (isVideoMode) {
      await _warmUpVideoController();
    } else {
      _videoWarmUpCompleted = false;
      _videoTextureId = null;
      notifyListeners();
    }
  }

  Future<void> _reloadPreviewImage() async {
    final path = _settingsService.wallpaperPreviewPath;
    if (path.isNotEmpty && await File(path).exists()) {
      _wallpaper = FileImage(File(path));
    } else {
      _wallpaper = null;
    }
    notifyListeners();
  }

  Future<void> _ensureVideoTextureId() async {
    final textureId = await _fLauncherChannel.getVideoWallpaperTextureId();
    _videoTextureId = textureId >= 0 ? textureId : null;
    notifyListeners();
  }

  void _scheduleVideoWarmUp() {
    if (!isVideoMode || _videoWarmUpScheduled || _videoWarmUpCompleted) {
      return;
    }
    _videoWarmUpScheduled = true;
    Future<void>.delayed(_videoWarmUpDelay, () async {
      _videoWarmUpScheduled = false;
      if (!isVideoMode) {
        return;
      }
      await _warmUpVideoController();
    });
  }

  Future<void> _warmUpVideoController() async {
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    await _ensureVideoTextureId();
    await syncVideoOptionsToNative();
    _videoWarmUpCompleted = true;
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
    await _fLauncherChannel.setWallpaperMode('image');
    _videoWarmUpCompleted = false;
    _videoTextureId = null;
    await _reloadPreviewImage();
  }

  Future<void> pickVideoWallpaper() async {
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
    await _settingsService.setWallpaperAssetUri(wallpaperAssetUri);
    await _settingsService.setWallpaperPreviewPath(previewPath);
    await _settingsService.setWallpaperMode('video');
    await _settingsService.setVideoWallpaperSourceType(sourceType);
    await _settingsService.setVideoWallpaperUris(assetUris);
    await _settingsService.setVideoWallpaperFolderUri(folderUri);
    await _settingsService.setVideoWallpaperFolderBucketId(folderBucketId);
    await _settingsService.setVideoWallpaperFolderName(folderName);
    await _fLauncherChannel.setWallpaperMode('video');
    await _reloadPreviewImage();
    _videoWarmUpCompleted = false;
    await _warmUpVideoController();
  }

  Future<void> setGradient(FLauncherGradient fLauncherGradient) async {
    await _settingsService.setGradientUuid(fLauncherGradient.uuid);
    await _settingsService.setWallpaperMode('gradient');
    await _fLauncherChannel.setWallpaperMode('gradient');
    _wallpaper = null;
    _videoWarmUpCompleted = false;
    _videoTextureId = null;
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
  }

  Future<void> syncVideoOptionsToNative() async {
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
    );
    notifyListeners();
  }

  void _logStartupMetric(String label, int elapsedMs) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('FLauncherPerf $label elapsedMs=$elapsedMs');
  }
}
