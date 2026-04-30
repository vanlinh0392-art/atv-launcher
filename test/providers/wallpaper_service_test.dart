import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks.mocks.dart';

void main() {
  test('defers startup video warm-up until after the fast-start delay',
      () async {
    final settings = await _createSettingsService(<String, Object>{
      'wallpaper_mode': 'video',
      'wallpaper_asset_uri': 'content://video/1',
    });
    final channel = MockFLauncherChannel();
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 13);
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
      ),
    ).thenAnswer((_) async => <String, dynamic>{});

    final service = WallpaperService(channel, settings);

    verifyNever(channel.getVideoWallpaperTextureId());

    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(service.videoTextureId, 13);
    verify(channel.getVideoWallpaperTextureId()).called(1);
  });

  test('setGradient stores gradient mode and clears video state', () async {
    final settings = await _createSettingsService();
    final channel = MockFLauncherChannel();
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});
    final service = WallpaperService(channel, settings);

    await service.setGradient(FLauncherGradients.greatWhale);

    expect(settings.wallpaperMode, 'gradient');
    expect(service.wallpaper, isNull);
    expect(service.videoTextureId, isNull);
    verify(channel.setWallpaperMode('gradient')).called(1);
  });

  test('pickVideoWallpaperFilesSaf persists playlist selection', () async {
    final settings = await _createSettingsService();
    final channel = MockFLauncherChannel();
    when(channel.pickWallpaperFiles()).thenAnswer(
      (_) async => <String, dynamic>{
        'uris': ['content://video/1', 'content://video/2'],
        'primaryUri': 'content://video/1',
        'previewPath': 'C:/preview.jpg',
      },
    );
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 7);
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
      ),
    ).thenAnswer((_) async => <String, dynamic>{});
    final service = WallpaperService(channel, settings);

    await service.pickVideoWallpaperFilesSaf();

    expect(settings.wallpaperMode, 'video');
    expect(settings.videoWallpaperSourceType, 'multi_file_playlist');
    expect(
      settings.videoWallpaperUris,
      ['content://video/1', 'content://video/2'],
    );
    expect(settings.wallpaperAssetUri, 'content://video/1');
    expect(settings.wallpaperPreviewPath, 'C:/preview.jpg');
    expect(service.videoTextureId, 7);
  });

  test('applyLibrarySelection stores folder playlist metadata', () async {
    final settings = await _createSettingsService();
    final channel = MockFLauncherChannel();
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 5);
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
      ),
    ).thenAnswer((_) async => <String, dynamic>{});
    final service = WallpaperService(channel, settings);

    await service.applyLibrarySelection(
      uris: ['content://video/10', 'content://video/11'],
      sourceType: 'folder_playlist',
      folderBucketId: 'bucket-7',
      folderName: 'Trailers',
    );

    expect(settings.videoWallpaperSourceType, 'folder_playlist');
    expect(settings.videoWallpaperFolderBucketId, 'bucket-7');
    expect(settings.videoWallpaperFolderName, 'Trailers');
    expect(settings.videoWallpaperUris,
        ['content://video/10', 'content://video/11']);
    expect(service.videoTextureId, 5);
  });

  test('restoreFromSettings defers video warm-up for smooth mode', () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode': 'smooth',
      'wallpaper_mode': 'image',
      'wallpaper_asset_uri': 'content://image/1',
    });
    final channel = MockFLauncherChannel();
    when(channel.setWallpaperMode(any))
        .thenAnswer((_) async => <String, dynamic>{});
    when(channel.getVideoWallpaperTextureId()).thenAnswer((_) async => 11);
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
      ),
    ).thenAnswer((_) async => <String, dynamic>{});
    final service = WallpaperService(channel, settings);

    await settings.setWallpaperMode('video');
    await settings.setWallpaperAssetUri('content://video/restore');

    await service.restoreFromSettings();

    verify(channel.setWallpaperMode('video')).called(1);
    verifyNever(channel.getVideoWallpaperTextureId());

    await Future<void>.delayed(const Duration(milliseconds: 700));

    expect(service.videoTextureId, 11);
    verify(channel.getVideoWallpaperTextureId()).called(1);
  });

  test('setVideoRepeatCountPerItem persists and syncs repeat count', () async {
    final settings = await _createSettingsService();
    final channel = MockFLauncherChannel();
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
      ),
    ).thenAnswer((_) async => <String, dynamic>{});
    final service = WallpaperService(channel, settings);

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
      ),
    ).called(1);
  });

  test('settings playback suppression is ref-counted and only forwards edges',
      () async {
    final settings = await _createSettingsService();
    final channel = MockFLauncherChannel();
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

  test('pickVideoWallpaperFilesSaf defers warm-up for smooth mode', () async {
    final settings = await _createSettingsService(<String, Object>{
      'home_dock_performance_mode': 'smooth',
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
      ),
    ).thenAnswer((_) async => <String, dynamic>{});
    final service = WallpaperService(channel, settings);

    await service.pickVideoWallpaperFilesSaf();

    expect(settings.wallpaperMode, 'video');
    expect(service.videoTextureId, isNull);
    verifyNever(channel.getVideoWallpaperTextureId());

    await Future<void>.delayed(const Duration(milliseconds: 700));

    expect(service.videoTextureId, 19);
    verify(channel.getVideoWallpaperTextureId()).called(1);
  });
}

Future<SettingsService> _createSettingsService([
  Map<String, Object> values = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SettingsService(await SharedPreferences.getInstance());
}
