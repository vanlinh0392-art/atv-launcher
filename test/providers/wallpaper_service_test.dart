import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks.mocks.dart';

void main() {
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
    expect(settings.videoWallpaperUris, ['content://video/10', 'content://video/11']);
    expect(service.videoTextureId, 5);
  });
}

Future<SettingsService> _createSettingsService([
  Map<String, Object> values = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SettingsService(await SharedPreferences.getInstance());
}
