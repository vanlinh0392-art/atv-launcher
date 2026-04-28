import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../../mocks.mocks.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('shows media access warning when permission is missing',
      (tester) async {
    _prepareView(tester);
    final wallpaperService = _mockWallpaperService();
    final bridgeService = MockSystemBridgeService();
    when(bridgeService.fileAccessStatus)
        .thenReturn(const <String, dynamic>{'hasMediaPermission': false});

    await _pumpWidget(tester, wallpaperService, bridgeService);

    expect(find.text('Grant access'), findsOneWidget);
  });

  testWidgets('Single video action calls pickVideoWallpaper', (tester) async {
    _prepareView(tester);
    final wallpaperService = _mockWallpaperService();
    final bridgeService = MockSystemBridgeService();
    when(bridgeService.fileAccessStatus)
        .thenReturn(const <String, dynamic>{'hasMediaPermission': true});
    when(wallpaperService.pickVideoWallpaper()).thenAnswer((_) async {});

    await _pumpWidget(tester, wallpaperService, bridgeService);

    await tester.tap(find.text('Single video'));
    await tester.pumpAndSettle();

    verify(wallpaperService.pickVideoWallpaper()).called(1);
  });

  testWidgets('fixed interval mode shows switch interval slider',
      (tester) async {
    _prepareView(tester);
    final wallpaperService =
        _mockWallpaperService(advanceMode: 'fixed_interval');
    final bridgeService = MockSystemBridgeService();
    when(bridgeService.fileAccessStatus)
        .thenReturn(const <String, dynamic>{'hasMediaPermission': true});

    await _pumpWidget(tester, wallpaperService, bridgeService);

    expect(find.textContaining('Switch interval'), findsOneWidget);
  });
}

Future<void> _pumpWidget(
  WidgetTester tester,
  WallpaperService wallpaperService,
  SystemBridgeService bridgeService,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WallpaperService>.value(value: wallpaperService),
        ChangeNotifierProvider<SystemBridgeService>.value(value: bridgeService),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: WallpaperPanelPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MockWallpaperService _mockWallpaperService(
    {String advanceMode = 'on_completion'}) {
  final wallpaperService = MockWallpaperService();
  when(wallpaperService.wallpaperMode).thenReturn('video');
  when(wallpaperService.videoSourceType).thenReturn('single_file');
  when(wallpaperService.videoUris)
      .thenReturn(const <String>['content://video/1']);
  when(wallpaperService.wallpaperAssetUri).thenReturn('content://video/1');
  when(wallpaperService.videoFolderName).thenReturn('');
  when(wallpaperService.isVideoMode).thenReturn(true);
  when(wallpaperService.videoAdvanceMode).thenReturn(advanceMode);
  when(wallpaperService.videoOrderMode).thenReturn('sequential');
  when(wallpaperService.videoSwitchIntervalSeconds).thenReturn(45);
  when(wallpaperService.videoPlaylistLoop).thenReturn(true);
  when(wallpaperService.videoLoop).thenReturn(true);
  when(wallpaperService.videoMute).thenReturn(true);
  when(wallpaperService.videoAutoResume).thenReturn(true);
  when(wallpaperService.videoFit).thenReturn('center-crop');
  when(wallpaperService.videoBlur).thenReturn('off');
  when(wallpaperService.videoDimPercent).thenReturn(15);
  when(wallpaperService.pickVideoWallpaperFilesSaf()).thenAnswer((_) async {});
  when(wallpaperService.pickVideoWallpaperFolderSaf()).thenAnswer((_) async {});
  when(wallpaperService.pickImageWallpaper()).thenAnswer((_) async {});
  return wallpaperService;
}

void _prepareView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
