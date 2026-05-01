import 'dart:io';

import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('balanced startup waits for home usable signal before delayed warm-up',
      () async {
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

    verifyNever(channel.getVideoWallpaperTextureId());
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
        deferForegroundResume: true,
      ),
    ).called(1);

    await Future<void>.delayed(const Duration(milliseconds: 450));
    verifyNever(channel.getVideoWallpaperTextureId());

    service.notifyHomeVisibleAndUsable();
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(service.videoTextureId, 17);
    verify(channel.getVideoWallpaperTextureId()).called(1);
  });

  test('restoreFromSettings defers video warm-up until home becomes usable',
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

    await service.restoreFromSettings();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    verify(channel.setWallpaperMode('video')).called(1);
    verifyNever(channel.getVideoWallpaperTextureId());

    service.notifyHomeVisibleAndUsable();
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(service.videoTextureId, 11);
    verify(channel.getVideoWallpaperTextureId()).called(1);
  });

  test(
      'settings suppression cancels pending delayed start and reschedules once',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode':
          SettingsService.homeDockPerformanceModeBalanced,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/3',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 23);
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
    await Future<void>.delayed(const Duration(milliseconds: 50));

    service.notifyHomeVisibleAndUsable();
    await service.setSettingsPlaybackSuppressed(true);
    await Future<void>.delayed(const Duration(milliseconds: 450));

    verifyNever(channel.getVideoWallpaperTextureId());

    await service.setSettingsPlaybackSuppressed(false);
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(service.videoTextureId, 23);
    verify(channel.getVideoWallpaperTextureId()).called(1);
    verify(
      channel.setVideoWallpaperPlaybackSuppressed(
        suppressed: true,
        reason: 'settings_panel',
      ),
    ).called(1);
    verify(
      channel.setVideoWallpaperPlaybackSuppressed(
        suppressed: false,
        reason: 'settings_panel_release',
      ),
    ).called(1);
  });

  test('off startup falls back to poster image and preserves video restore',
      () async {
    final previewFile = await _createTempPreviewFile();
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode': SettingsService.homeDockPerformanceModeOff,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/off-1',
      'wallpaper_preview_path': previewFile.path,
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(settings.wallpaperMode, 'image');
    expect(settings.wallpaperVideoRestoreCandidatePending, isTrue);
    expect(service.wallpaper, isNotNull);
    verify(channel.setWallpaperMode('image')).called(1);
    verifyNever(channel.getVideoWallpaperTextureId());
  });

  test('off startup without a poster falls back to gradient', () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode': SettingsService.homeDockPerformanceModeOff,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/off-2',
      'wallpaper_preview_path': 'C:/missing/poster.jpg',
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(settings.wallpaperMode, 'gradient');
    expect(settings.wallpaperVideoRestoreCandidatePending, isTrue);
    expect(service.wallpaper, isNull);
    verify(channel.setWallpaperMode('gradient')).called(1);
    verifyNever(channel.getVideoWallpaperTextureId());
  });

  test('balanced restores saved video automatically after off fallback',
      () async {
    final previewFile = await _createTempPreviewFile();
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode': SettingsService.homeDockPerformanceModeOff,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/off-3',
      'wallpaper_preview_path': previewFile.path,
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 31);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(settings.wallpaperMode, 'image');

    await settings.setHomeDockPerformanceMode(
      SettingsService.homeDockPerformanceModeBalanced,
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(settings.wallpaperMode, 'video');
    expect(settings.wallpaperVideoRestoreCandidatePending, isFalse);
    verify(channel.setWallpaperMode('video')).called(1);
    verifyNever(channel.getVideoWallpaperTextureId());

    service.notifyHomeVisibleAndUsable();
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(service.videoTextureId, 31);
    verify(channel.getVideoWallpaperTextureId()).called(1);
  });

  test('quality does not auto-restore saved video after off fallback',
      () async {
    final previewFile = await _createTempPreviewFile();
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode': SettingsService.homeDockPerformanceModeOff,
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/off-4',
      'wallpaper_preview_path': previewFile.path,
    });
    final channel = MockFLauncherChannel();
    _stubVideoWallpaperOptions(channel);
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 37);

    final service = WallpaperService(channel, settings);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(settings.wallpaperMode, 'image');

    await settings.setHomeDockPerformanceMode(
      SettingsService.homeDockPerformanceModeQuality,
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(settings.wallpaperMode, 'image');
    expect(settings.wallpaperVideoRestoreCandidatePending, isFalse);

    service.notifyHomeVisibleAndUsable();
    await Future<void>.delayed(const Duration(milliseconds: 450));

    verifyNever(channel.getVideoWallpaperTextureId());
  });

  test('quality startup clears pending restore and keeps non-video wallpaper',
      () async {
    final previewFile = await _createTempPreviewFile();
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode': SettingsService.homeDockPerformanceModeQuality,
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
    await Future<void>.delayed(const Duration(milliseconds: 60));

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
    expect(service.videoTextureId, isNull);
    verifyNever(channel.getVideoWallpaperTextureId());

    service.notifyHomeVisibleAndUsable();
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(service.videoTextureId, 19);
    verify(channel.getVideoWallpaperTextureId()).called(1);
  });

  test(
      'applyLibrarySelection stores folder playlist metadata and waits for home',
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
    expect(service.videoTextureId, isNull);

    service.notifyHomeVisibleAndUsable();
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(service.videoTextureId, 5);
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
