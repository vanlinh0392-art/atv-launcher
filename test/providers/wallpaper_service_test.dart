import 'dart:io';

import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('quality startup warms up video after fast-start delay', () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeQuality,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/1',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 13);

    final service = WallpaperService(channel, settings);

    verifyNever(channel.getVideoWallpaperTextureId());

    await Future<void>.delayed(const Duration(milliseconds: 550));

    expect(service.videoTextureId, 13);
    verify(channel.getVideoWallpaperTextureId()).called(1);
    verify(
      channel.setVideoWallpaperOptions(
        sourceType: anyNamed('sourceType'),
        assetUris: anyNamed('assetUris'),
        folderUri: anyNamed('folderUri'),
        folderBucketId: anyNamed('folderBucketId'),
        folderName: anyNamed('folderName'),
        orderMode: anyNamed('orderMode'),
        advanceMode: anyNamed('advanceMode'),
        switchIntervalSeconds: anyNamed('switchIntervalSeconds'),
        repeatCountPerItem: anyNamed('repeatCountPerItem'),
        playlistLoop: anyNamed('playlistLoop'),
        loop: anyNamed('loop'),
        mute: anyNamed('mute'),
        fit: anyNamed('fit'),
        dimPercent: anyNamed('dimPercent'),
        blur: anyNamed('blur'),
        autoResume: anyNamed('autoResume'),
        videoAllowedByPerformanceMode: anyNamed(
          'videoAllowedByPerformanceMode',
        ),
        disableAudioRendererWhenMuted: anyNamed(
          'disableAudioRendererWhenMuted',
        ),
        deferForegroundResume: false,
      ),
    ).called(1);
  });

  test('balanced startup warms up video instantly on startup', () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeBalanced,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/2',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 17);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(service.videoTextureId, 17);
    verify(channel.getVideoWallpaperTextureId()).called(1);
    verify(
      channel.setVideoWallpaperOptions(
        sourceType: anyNamed('sourceType'),
        assetUris: anyNamed('assetUris'),
        folderUri: anyNamed('folderUri'),
        folderBucketId: anyNamed('folderBucketId'),
        folderName: anyNamed('folderName'),
        orderMode: anyNamed('orderMode'),
        advanceMode: anyNamed('advanceMode'),
        switchIntervalSeconds: anyNamed('switchIntervalSeconds'),
        repeatCountPerItem: anyNamed('repeatCountPerItem'),
        playlistLoop: anyNamed('playlistLoop'),
        loop: anyNamed('loop'),
        mute: anyNamed('mute'),
        fit: anyNamed('fit'),
        dimPercent: anyNamed('dimPercent'),
        blur: anyNamed('blur'),
        autoResume: anyNamed('autoResume'),
        videoAllowedByPerformanceMode: true,
        disableAudioRendererWhenMuted: true,
        deferForegroundResume: false,
      ),
    ).called(1);
  });

  test('balanced home warm-up syncs native video mode before texture request',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeBalanced,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/native-drift',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 18);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(service.videoTextureId, 18);
    verifyInOrder([
      channel.setWallpaperMode('video'),
      channel.getVideoWallpaperTextureId(),
      channel.setVideoWallpaperOptions(
        sourceType: anyNamed('sourceType'),
        assetUris: anyNamed('assetUris'),
        folderUri: anyNamed('folderUri'),
        folderBucketId: anyNamed('folderBucketId'),
        folderName: anyNamed('folderName'),
        orderMode: anyNamed('orderMode'),
        advanceMode: anyNamed('advanceMode'),
        switchIntervalSeconds: anyNamed('switchIntervalSeconds'),
        repeatCountPerItem: anyNamed('repeatCountPerItem'),
        playlistLoop: anyNamed('playlistLoop'),
        loop: anyNamed('loop'),
        mute: anyNamed('mute'),
        fit: anyNamed('fit'),
        dimPercent: anyNamed('dimPercent'),
        blur: anyNamed('blur'),
        autoResume: anyNamed('autoResume'),
        videoAllowedByPerformanceMode: anyNamed(
          'videoAllowedByPerformanceMode',
        ),
        disableAudioRendererWhenMuted: anyNamed(
          'disableAudioRendererWhenMuted',
        ),
        deferForegroundResume: false,
      ),
    ]);
  });

  test('restoreFromSettings warms up video immediately for active video mode',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeBalanced,
      'wallpaper_mode': 'image',
      'wallpaper_asset_uri': 'content://image/1',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 11);
    final service = WallpaperService(channel, settings);

    await settings.setWallpaperMode('video');
    await settings.setWallpaperAssetUri('content://video/restore');

    clearInteractions(channel);
    await service.restoreFromSettings();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(service.videoTextureId, 11);
    verify(channel.setWallpaperMode('video')).called(greaterThanOrEqualTo(1));
    verify(channel.getVideoWallpaperTextureId())
        .called(greaterThanOrEqualTo(1));
  });

  test('smooth settings suppression reschedules video after release', () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeSmooth,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/3',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 23);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(service.videoTextureId, 23);

    await service.setSettingsPlaybackSuppressed(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(service.settingsPlaybackSuppressed, isTrue);
    verify(
      channel.setVideoWallpaperPlaybackSuppressed(
        suppressed: true,
        reason: 'settings_panel',
      ),
    ).called(1);

    await service.setSettingsPlaybackSuppressed(false);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(service.settingsPlaybackSuppressed, isFalse);
    verify(
      channel.setVideoWallpaperPlaybackSuppressed(
        suppressed: false,
        reason: 'settings_panel_release',
      ),
    ).called(1);
  });

  test('balanced retains warmed video texture across settings suppression',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeBalanced,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/31',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 31);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(service.videoTextureId, 31);
    verify(channel.getVideoWallpaperTextureId()).called(1);
    clearInteractions(channel);

    await service.setSettingsPlaybackSuppressed(true);
    await service.setSettingsPlaybackSuppressed(false);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(service.videoTextureId, 31);
    verify(channel.setVideoWallpaperPlaybackSuppressed(
      suppressed: true,
      reason: 'settings_panel',
    )).called(1);
    verify(channel.setVideoWallpaperPlaybackSuppressed(
      suppressed: false,
      reason: 'settings_panel_release',
    )).called(1);
  });

  test('balanced home recovery is safe no-op retaining video state',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeBalanced,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/recovery',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 32);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(service.videoTextureId, 32);
    clearInteractions(channel);

    await service.recoverVideoPlaybackAfterHomeFrame(
      reason: 'activity_resume',
    );

    expect(service.videoTextureId, 32);
  });

  test('balanced starts video immediately on library selection', () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeBalanced,
      'wallpaper_mode': 'image',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 29);

    final service = WallpaperService(channel, settings);

    await service.applyLibrarySelection(
      uris: ['content://video/91'],
      sourceType: 'single_file',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(settings.wallpaperMode, 'video');
    expect(service.videoTextureId, 29);
    verify(channel.getVideoWallpaperTextureId()).called(1);
  });

  test('balanced explicitly rearms video after app resumes from background',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeBalanced,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/41',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 41);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    service.notifyHomeVisibleAndUsable();
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(service.videoTextureId, 41);
    verify(channel.getVideoWallpaperTextureId()).called(1);
    clearInteractions(channel);

    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(service.videoTextureId, 41);

    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(service.videoTextureId, 41);
    verify(
      channel.setVideoWallpaperOptions(
        sourceType: anyNamed('sourceType'),
        assetUris: anyNamed('assetUris'),
        folderUri: anyNamed('folderUri'),
        folderBucketId: anyNamed('folderBucketId'),
        folderName: anyNamed('folderName'),
        orderMode: anyNamed('orderMode'),
        advanceMode: anyNamed('advanceMode'),
        switchIntervalSeconds: anyNamed('switchIntervalSeconds'),
        repeatCountPerItem: anyNamed('repeatCountPerItem'),
        playlistLoop: anyNamed('playlistLoop'),
        loop: anyNamed('loop'),
        mute: anyNamed('mute'),
        fit: anyNamed('fit'),
        dimPercent: anyNamed('dimPercent'),
        blur: anyNamed('blur'),
        autoResume: anyNamed('autoResume'),
        videoAllowedByPerformanceMode: anyNamed(
          'videoAllowedByPerformanceMode',
        ),
        disableAudioRendererWhenMuted: anyNamed(
          'disableAudioRendererWhenMuted',
        ),
        deferForegroundResume: anyNamed('deferForegroundResume'),
      ),
    ).called(1);
  });

  test('smooth restores video after app resumes', () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeSmooth,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/47',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 47);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(service.videoTextureId, 47);
    verify(channel.getVideoWallpaperTextureId()).called(1);
    clearInteractions(channel);

    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(service.videoTextureId, 47);

    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(service.videoTextureId, 47);
  });

  test('wake auto-resume restores video immediately when app resumes from sleep',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeSmooth,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/wake-test',
      'wallpaper_video_auto_resume': true,
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 99);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(service.videoTextureId, 99);
    clearInteractions(channel);

    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(service.videoTextureId, 99);
    verify(
      channel.setVideoWallpaperOptions(
        sourceType: anyNamed('sourceType'),
        assetUris: anyNamed('assetUris'),
        folderUri: anyNamed('folderUri'),
        folderBucketId: anyNamed('folderBucketId'),
        folderName: anyNamed('folderName'),
        orderMode: anyNamed('orderMode'),
        advanceMode: anyNamed('advanceMode'),
        switchIntervalSeconds: anyNamed('switchIntervalSeconds'),
        repeatCountPerItem: anyNamed('repeatCountPerItem'),
        playlistLoop: anyNamed('playlistLoop'),
        loop: anyNamed('loop'),
        mute: anyNamed('mute'),
        fit: anyNamed('fit'),
        dimPercent: anyNamed('dimPercent'),
        blur: anyNamed('blur'),
        autoResume: true,
        videoAllowedByPerformanceMode: anyNamed(
          'videoAllowedByPerformanceMode',
        ),
        disableAudioRendererWhenMuted: anyNamed(
          'disableAudioRendererWhenMuted',
        ),
        deferForegroundResume: anyNamed('deferForegroundResume'),
      ),
    ).called(1);
  });

  test(
      'TC-WPS-01: switching between quality, smooth, and off preserves video mode without fallback',
      () async {
    final previewFile = await _createTempPreviewFile();
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeQuality,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/persistent-1',
      'wallpaper_preview_path': previewFile.path,
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 44);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(settings.wallpaperMode, 'video');
    expect(service.videoTextureId, 44);

    // Switch to smooth mode: must remain video mode
    await settings.setHomeDockPerformanceMode(
      SettingsService.homeDockPerformanceModeSmooth,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(settings.wallpaperMode, 'video');

    // Switch to off mode: must remain video mode, no fallback to image or gradient
    await settings.setHomeDockPerformanceMode(
      SettingsService.homeDockPerformanceModeOff,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(settings.wallpaperMode, 'video');

    // Switch back to balanced mode
    await settings.setHomeDockPerformanceMode(
      SettingsService.homeDockPerformanceModeBalanced,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(settings.wallpaperMode, 'video');

    verifyNever(channel.setWallpaperMode('image'));
    verifyNever(channel.setWallpaperMode('gradient'));
  });

  test(
      'TC-WPS-02: videoTextureId is preserved across performance mode transitions',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeQuality,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/texture-preserve',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 77);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(service.videoTextureId, 77);

    // Switching to off mode must NOT clear videoTextureId
    await settings.setHomeDockPerformanceMode(
      SettingsService.homeDockPerformanceModeOff,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(service.videoTextureId, 77);

    // Switching to smooth mode must NOT clear videoTextureId
    await settings.setHomeDockPerformanceMode(
      SettingsService.homeDockPerformanceModeSmooth,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(service.videoTextureId, 77);
  });

  test(
      'TC-WPS-03: video picker functions operate normally without being blocked in any mode',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode': SettingsService.homeDockPerformanceModeOff,
      'wallpaper_mode': 'gradient',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 88);
    when(channel.pickWallpaperAsset(kind: 'video')).thenAnswer(
      (_) async => <String, dynamic>{
        'cancelled': false,
        'uri': 'content://video/picked-in-off',
        'previewPath': 'C:/preview/off.jpg',
      },
    );

    final service = WallpaperService(channel, settings);
    await service.pickVideoWallpaper();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(settings.wallpaperMode, 'video');
    expect(settings.wallpaperAssetUri, 'content://video/picked-in-off');
    expect(service.videoTextureId, 88);
    verify(channel.pickWallpaperAsset(kind: 'video')).called(1);
  });

  test('quality startup clears pending restore and keeps non-video wallpaper',
      () async {
    final previewFile = await _createTempPreviewFile();
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeQuality,
      'wallpaper_mode': 'image',
      'wallpaper_asset_uri': 'content://video/off-5',
      'wallpaper_preview_path': previewFile.path,
      'wallpaper_video_restore_candidate_pending': true,
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(settings.wallpaperMode, 'image');
    expect(settings.wallpaperVideoRestoreCandidatePending, isFalse);
    expect(service.wallpaper, isNotNull);
    verify(channel.setWallpaperMode('image')).called(1);
    verifyNever(channel.getVideoWallpaperTextureId());
  });

  test('setGradient stores gradient mode and clears video state', () async {
    final settings = await _createSettingsService();
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    clearInteractions(channel);

    await service.setGradient(FLauncherGradients.greatWhale);

    expect(settings.wallpaperMode, 'gradient');
    expect(service.wallpaper, isNull);
    expect(service.videoTextureId, isNull);
    verify(channel.setWallpaperMode('gradient')).called(1);
  });

  test(
      'pickVideoWallpaperFilesSaf persists playlist selection and waits for home',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeBalanced,
    });
    final channel = MockFLauncherChannel();
    when(channel.pickWallpaperFiles()).thenAnswer(
      (_) async => <String, dynamic>{
        'uris': ['content://video/21', 'content://video/22'],
        'primaryUri': 'content://video/21',
        'previewPath': 'C:/preview2.jpg',
      },
    );
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 19);
    _stubVideoWallpaperOptions(channel);
    final service = WallpaperService(channel, settings);

    await service.pickVideoWallpaperFilesSaf();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(settings.wallpaperMode, 'video');
    expect(settings.videoWallpaperSourceType, 'multi_file_playlist');
    expect(
      settings.videoWallpaperUris,
      ['content://video/21', 'content://video/22'],
    );
    expect(service.videoTextureId, 19);
    verify(channel.getVideoWallpaperTextureId()).called(1);
  });

  test(
      'applyLibrarySelection stores folder playlist metadata and starts video',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeBalanced,
    });
    final channel = MockFLauncherChannel();
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 5);
    _stubVideoWallpaperOptions(channel);
    final service = WallpaperService(channel, settings);

    await service.applyLibrarySelection(
      uris: ['content://video/10', 'content://video/11'],
      sourceType: 'folder_playlist',
      folderBucketId: 'bucket-7',
      folderName: 'Trailers',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(settings.videoWallpaperSourceType, 'folder_playlist');
    expect(settings.videoWallpaperFolderBucketId, 'bucket-7');
    expect(settings.videoWallpaperFolderName, 'Trailers');
    expect(settings.videoWallpaperUris,
        ['content://video/10', 'content://video/11']);
    expect(service.videoTextureId, 5);
    verify(channel.getVideoWallpaperTextureId()).called(1);
  });

  test('setVideoRepeatCountPerItem persists and syncs repeat count', () async {
    final settings = await _createSettingsService();
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    clearInteractions(channel);

    await service.setVideoRepeatCountPerItem(5);

    expect(settings.videoWallpaperRepeatCountPerItem, 5);
    verify(
      channel.setVideoWallpaperOptions(
        sourceType: anyNamed('sourceType'),
        assetUris: anyNamed('assetUris'),
        folderUri: anyNamed('folderUri'),
        folderBucketId: anyNamed('folderBucketId'),
        folderName: anyNamed('folderName'),
        orderMode: anyNamed('orderMode'),
        advanceMode: anyNamed('advanceMode'),
        switchIntervalSeconds: anyNamed('switchIntervalSeconds'),
        repeatCountPerItem: 5,
        playlistLoop: anyNamed('playlistLoop'),
        loop: anyNamed('loop'),
        mute: anyNamed('mute'),
        fit: anyNamed('fit'),
        dimPercent: anyNamed('dimPercent'),
        blur: anyNamed('blur'),
        autoResume: anyNamed('autoResume'),
        videoAllowedByPerformanceMode: anyNamed(
          'videoAllowedByPerformanceMode',
        ),
        disableAudioRendererWhenMuted: anyNamed(
          'disableAudioRendererWhenMuted',
        ),
        deferForegroundResume: anyNamed('deferForegroundResume'),
      ),
    ).called(1);
  });

  test('settings playback suppression remains ref-counted at edge transitions',
      () async {
    final settings = await _createSettingsService();
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(
      channel.setVideoWallpaperPlaybackSuppressed(
        suppressed: true,
        reason: anyNamed('reason'),
      ),
    ).thenAnswer((_) async => <String, dynamic>{});
    when(
      channel.setVideoWallpaperPlaybackSuppressed(
        suppressed: false,
        reason: anyNamed('reason'),
      ),
    ).thenAnswer((_) async => <String, dynamic>{});
    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    clearInteractions(channel);

    await service.setSettingsPlaybackSuppressed(true);
    await service.setSettingsPlaybackSuppressed(true);

    expect(service.settingsPlaybackSuppressed, isTrue);
    verify(
      channel.setVideoWallpaperPlaybackSuppressed(
        suppressed: true,
        reason: 'settings_panel',
      ),
    ).called(1);

    await service.setSettingsPlaybackSuppressed(false);

    expect(service.settingsPlaybackSuppressed, isTrue);
    verifyNever(
      channel.setVideoWallpaperPlaybackSuppressed(
        suppressed: false,
        reason: 'settings_panel_release',
      ),
    );

    await service.setSettingsPlaybackSuppressed(false);

    expect(service.settingsPlaybackSuppressed, isFalse);
    verify(
      channel.setVideoWallpaperPlaybackSuppressed(
        suppressed: false,
        reason: 'settings_panel_release',
      ),
    ).called(1);
  });

  test('pickVideoWallpaper applies single video selection and warms up video',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeQuality,
    });
    final channel = MockFLauncherChannel();
    when(channel.pickWallpaperAsset(kind: 'video')).thenAnswer(
      (_) async => <String, dynamic>{
        'uri': 'content://video/single_sample',
        'previewPath': 'C:/preview_single.jpg',
      },
    );
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 55);
    _stubVideoWallpaperOptions(channel);
    final service = WallpaperService(channel, settings);

    await service.pickVideoWallpaper();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(settings.wallpaperMode, 'video');
    expect(settings.videoWallpaperSourceType, 'single_file');
    expect(settings.wallpaperAssetUri, 'content://video/single_sample');
    expect(settings.videoWallpaperUris, ['content://video/single_sample']);
    expect(service.videoTextureId, 55);
    verify(channel.getVideoWallpaperTextureId()).called(1);
  });

  test('pickVideoWallpaperFolderSaf applies folder selection and stores metadata',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeBalanced,
    });
    final channel = MockFLauncherChannel();
    when(channel.pickWallpaperFolder()).thenAnswer(
      (_) async => <String, dynamic>{
        'uris': ['content://video/f1', 'content://video/f2'],
        'primaryUri': 'content://video/f1',
        'previewPath': 'C:/preview_folder.jpg',
        'folderUri': 'content://folder/1',
        'folderName': 'Movies',
      },
    );
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 88);
    _stubVideoWallpaperOptions(channel);
    final service = WallpaperService(channel, settings);

    await service.pickVideoWallpaperFolderSaf();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(settings.wallpaperMode, 'video');
    expect(settings.videoWallpaperSourceType, 'folder_playlist');
    expect(settings.videoWallpaperFolderName, 'Movies');
    expect(settings.videoWallpaperFolderUri, 'content://folder/1');
    expect(settings.videoWallpaperUris,
        ['content://video/f1', 'content://video/f2']);
    expect(service.videoTextureId, 88);
    verify(channel.getVideoWallpaperTextureId()).called(1);
  });

  test('recoverVideoPlaybackAfterHomeFrame is safe no-op', () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeBalanced,
      'wallpaper_mode': 'image',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);

    final service = WallpaperService(channel, settings);
    await service.recoverVideoPlaybackAfterHomeFrame(
      reason: 'boot_recovery',
    );
    expect(service.videoTextureId, isNull);
  });

  test(
      'TC-WPS-04: direct startup in off mode with existing video activates player immediately without fallback',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode': SettingsService.homeDockPerformanceModeOff,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/instant_off',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 88);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(settings.wallpaperMode, 'video');
    expect(service.videoTextureId, 88);
    verify(channel.setWallpaperMode('video')).called(1);
    verify(channel.getVideoWallpaperTextureId()).called(1);
    verifyNever(channel.setWallpaperMode('image'));
    verifyNever(channel.setWallpaperMode('gradient'));
  });

  test(
      'TC-WPS-WAKE-01: rapid sleep and wake cycle (paused -> resumed -> paused -> resumed) cleanly rearms video',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeBalanced,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/rapid-wake',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 50);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(service.videoTextureId, 50);
    clearInteractions(channel);

    // Cycle 1: Pause then immediate Resume
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(service.videoTextureId, 50);
    verify(channel.setVideoWallpaperOptions(
      sourceType: anyNamed('sourceType'),
      assetUris: anyNamed('assetUris'),
      folderUri: anyNamed('folderUri'),
      folderBucketId: anyNamed('folderBucketId'),
      folderName: anyNamed('folderName'),
      orderMode: anyNamed('orderMode'),
      advanceMode: anyNamed('advanceMode'),
      switchIntervalSeconds: anyNamed('switchIntervalSeconds'),
      repeatCountPerItem: anyNamed('repeatCountPerItem'),
      playlistLoop: anyNamed('playlistLoop'),
      loop: anyNamed('loop'),
      mute: anyNamed('mute'),
      fit: anyNamed('fit'),
      dimPercent: anyNamed('dimPercent'),
      blur: anyNamed('blur'),
      autoResume: anyNamed('autoResume'),
      videoAllowedByPerformanceMode: anyNamed('videoAllowedByPerformanceMode'),
      disableAudioRendererWhenMuted: anyNamed('disableAudioRendererWhenMuted'),
      deferForegroundResume: anyNamed('deferForegroundResume'),
    )).called(1);

    clearInteractions(channel);

    // Cycle 2: Immediate Pause then immediate Resume again
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(service.videoTextureId, 50);
    verify(channel.setVideoWallpaperOptions(
      sourceType: anyNamed('sourceType'),
      assetUris: anyNamed('assetUris'),
      folderUri: anyNamed('folderUri'),
      folderBucketId: anyNamed('folderBucketId'),
      folderName: anyNamed('folderName'),
      orderMode: anyNamed('orderMode'),
      advanceMode: anyNamed('advanceMode'),
      switchIntervalSeconds: anyNamed('switchIntervalSeconds'),
      repeatCountPerItem: anyNamed('repeatCountPerItem'),
      playlistLoop: anyNamed('playlistLoop'),
      loop: anyNamed('loop'),
      mute: anyNamed('mute'),
      fit: anyNamed('fit'),
      dimPercent: anyNamed('dimPercent'),
      blur: anyNamed('blur'),
      autoResume: anyNamed('autoResume'),
      videoAllowedByPerformanceMode: anyNamed('videoAllowedByPerformanceMode'),
      disableAudioRendererWhenMuted: anyNamed('disableAudioRendererWhenMuted'),
      deferForegroundResume: anyNamed('deferForegroundResume'),
    )).called(1);
  });

  test(
      'TC-WPS-WAKE-02: wake during active settings suppression does not trigger instant video rearm until released',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeBalanced,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/wake-suppressed',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 60);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(service.videoTextureId, 60);

    // Open settings (suppress playback)
    await service.setSettingsPlaybackSuppressed(true);
    expect(service.settingsPlaybackSuppressed, isTrue);
    clearInteractions(channel);

    // Sleep then Wake while settings is still open
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Must NOT call setVideoWallpaperOptions because settingsPlaybackSuppressed is true
    verifyNever(channel.setVideoWallpaperOptions(
      sourceType: anyNamed('sourceType'),
      assetUris: anyNamed('assetUris'),
      folderUri: anyNamed('folderUri'),
      folderBucketId: anyNamed('folderBucketId'),
      folderName: anyNamed('folderName'),
      orderMode: anyNamed('orderMode'),
      advanceMode: anyNamed('advanceMode'),
      switchIntervalSeconds: anyNamed('switchIntervalSeconds'),
      repeatCountPerItem: anyNamed('repeatCountPerItem'),
      playlistLoop: anyNamed('playlistLoop'),
      loop: anyNamed('loop'),
      mute: anyNamed('mute'),
      fit: anyNamed('fit'),
      dimPercent: anyNamed('dimPercent'),
      blur: anyNamed('blur'),
      autoResume: anyNamed('autoResume'),
      videoAllowedByPerformanceMode: anyNamed('videoAllowedByPerformanceMode'),
      disableAudioRendererWhenMuted: anyNamed('disableAudioRendererWhenMuted'),
      deferForegroundResume: anyNamed('deferForegroundResume'),
    ));

    // Now close settings: playback suppression released
    await service.setSettingsPlaybackSuppressed(false);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(service.settingsPlaybackSuppressed, isFalse);
    expect(service.videoTextureId, 60);
  });

  test(
      'TC-WPS-WAKE-03: wake when videoTextureId is null re-acquires texture from native channel',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeBalanced,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/wake-reacquire',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 72);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(service.videoTextureId, 72);

    // Switch temporarily to gradient which clears videoTextureId
    await service.setGradient(FLauncherGradients.greatWhale);
    expect(service.videoTextureId, isNull);

    // Switch back to video via settings
    await settings.setWallpaperMode('video');
    clearInteractions(channel);

    // Trigger wake (resumed)
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    // Verify channel was queried to acquire the texture ID
    verify(channel.getVideoWallpaperTextureId()).called(1);
    expect(service.videoTextureId, 72);
  });

  test(
      'TC-WPS-WAKE-04: wake in non-video modes (image and gradient) safely ignores video rearm',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeBalanced,
      'wallpaper_mode': 'gradient',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(service.videoTextureId, isNull);
    clearInteractions(channel);

    // Send sleep and wake
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Must NOT call video options or texture ID
    verifyNever(channel.getVideoWallpaperTextureId());
    verifyNever(channel.setVideoWallpaperOptions(
      sourceType: anyNamed('sourceType'),
      assetUris: anyNamed('assetUris'),
      folderUri: anyNamed('folderUri'),
      folderBucketId: anyNamed('folderBucketId'),
      folderName: anyNamed('folderName'),
      orderMode: anyNamed('orderMode'),
      advanceMode: anyNamed('advanceMode'),
      switchIntervalSeconds: anyNamed('switchIntervalSeconds'),
      repeatCountPerItem: anyNamed('repeatCountPerItem'),
      playlistLoop: anyNamed('playlistLoop'),
      loop: anyNamed('loop'),
      mute: anyNamed('mute'),
      fit: anyNamed('fit'),
      dimPercent: anyNamed('dimPercent'),
      blur: anyNamed('blur'),
      autoResume: anyNamed('autoResume'),
      videoAllowedByPerformanceMode: anyNamed('videoAllowedByPerformanceMode'),
      disableAudioRendererWhenMuted: anyNamed('disableAudioRendererWhenMuted'),
      deferForegroundResume: anyNamed('deferForegroundResume'),
    ));
    expect(service.videoTextureId, isNull);
  });

  test(
      'TC-WPS-WAKE-05: wake in effects-off mode maintains video playback and texture without fallback',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode': SettingsService.homeDockPerformanceModeOff,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/wake-off',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 82);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(service.videoTextureId, 82);
    clearInteractions(channel);

    // Sleep and wake in Off mode
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(settings.wallpaperMode, 'video');
    expect(service.videoTextureId, 82);
    verify(channel.setVideoWallpaperOptions(
      sourceType: anyNamed('sourceType'),
      assetUris: anyNamed('assetUris'),
      folderUri: anyNamed('folderUri'),
      folderBucketId: anyNamed('folderBucketId'),
      folderName: anyNamed('folderName'),
      orderMode: anyNamed('orderMode'),
      advanceMode: anyNamed('advanceMode'),
      switchIntervalSeconds: anyNamed('switchIntervalSeconds'),
      repeatCountPerItem: anyNamed('repeatCountPerItem'),
      playlistLoop: anyNamed('playlistLoop'),
      loop: anyNamed('loop'),
      mute: anyNamed('mute'),
      fit: anyNamed('fit'),
      dimPercent: anyNamed('dimPercent'),
      blur: anyNamed('blur'),
      autoResume: anyNamed('autoResume'),
      videoAllowedByPerformanceMode: true,
      disableAudioRendererWhenMuted: anyNamed('disableAudioRendererWhenMuted'),
      deferForegroundResume: anyNamed('deferForegroundResume'),
    )).called(1);
    verifyNever(channel.setWallpaperMode('image'));
    verifyNever(channel.setWallpaperMode('gradient'));
  });
}

Future<SettingsService> _createSettingsService([
  Map<String, Object> values = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SettingsService(await SharedPreferences.getInstance());
}

void _stubVideoWallpaperOptions(MockFLauncherChannel channel) {
  when(channel.setWallpaperMode(any))
      .thenAnswer((_) async => <String, dynamic>{});
  when(
    channel.setVideoWallpaperPlaybackSuppressed(
      suppressed: anyNamed('suppressed'),
      reason: anyNamed('reason'),
    ),
  ).thenAnswer((_) async => <String, dynamic>{});
  when(
    channel.setVideoWallpaperOptions(
      sourceType: anyNamed('sourceType'),
      assetUris: anyNamed('assetUris'),
      folderUri: anyNamed('folderUri'),
      folderBucketId: anyNamed('folderBucketId'),
      folderName: anyNamed('folderName'),
      orderMode: anyNamed('orderMode'),
      advanceMode: anyNamed('advanceMode'),
      switchIntervalSeconds: anyNamed('switchIntervalSeconds'),
      repeatCountPerItem: anyNamed('repeatCountPerItem'),
      playlistLoop: anyNamed('playlistLoop'),
      loop: anyNamed('loop'),
      mute: anyNamed('mute'),
      fit: anyNamed('fit'),
      dimPercent: anyNamed('dimPercent'),
      blur: anyNamed('blur'),
      autoResume: anyNamed('autoResume'),
      videoAllowedByPerformanceMode: anyNamed(
        'videoAllowedByPerformanceMode',
      ),
      disableAudioRendererWhenMuted: anyNamed(
        'disableAudioRendererWhenMuted',
      ),
      deferForegroundResume: anyNamed('deferForegroundResume'),
    ),
  ).thenAnswer((_) async => <String, dynamic>{});
}

Future<File> _createTempPreviewFile() async {
  final directory = await Directory.systemTemp.createTemp(
    'flauncher_wallpaper_test_',
  );
  final file = File('${directory.path}${Platform.pathSeparator}poster.jpg');
  await file.writeAsBytes(const <int>[0, 1, 2, 3]);
  return file;
}
