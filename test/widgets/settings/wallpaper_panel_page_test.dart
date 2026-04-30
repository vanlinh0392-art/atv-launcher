import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('fixed interval mode shows switch interval stepper',
      (tester) async {
    _prepareView(tester);
    final wallpaperService =
        _mockWallpaperService(advanceMode: 'fixed_interval');
    final bridgeService = MockSystemBridgeService();
    when(bridgeService.fileAccessStatus)
        .thenReturn(const <String, dynamic>{'hasMediaPermission': true});

    await _pumpWidget(tester, wallpaperService, bridgeService);

    expect(find.textContaining('Switch interval'), findsOneWidget);
    expect(
      find.byKey(const Key('video_switch_interval_seconds_stepper')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('video_repeat_count_per_item_stepper')),
      findsNothing,
    );
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('fixed interval stepper is placed before loop playlist row',
      (tester) async {
    _prepareView(tester);
    final wallpaperService =
        _mockWallpaperService(advanceMode: 'fixed_interval');
    final bridgeService = MockSystemBridgeService();
    when(bridgeService.fileAccessStatus)
        .thenReturn(const <String, dynamic>{'hasMediaPermission': true});

    await _pumpWidget(tester, wallpaperService, bridgeService);

    final stepperTopLeft = tester.getTopLeft(
      find.byKey(const Key('video_switch_interval_seconds_stepper')),
    );
    final loopPlaylistTopLeft = tester.getTopLeft(find.text('Loop playlist'));

    expect(stepperTopLeft.dy, lessThan(loopPlaylistTopLeft.dy));
  });

  testWidgets('Pick folder falls back to TV storage when SAF is unavailable',
      (tester) async {
    _prepareView(tester);
    final wallpaperService = _mockWallpaperService();
    final bridgeService = MockSystemBridgeService();
    when(bridgeService.fileAccessStatus)
        .thenReturn(const <String, dynamic>{'hasMediaPermission': true});
    when(wallpaperService.pickVideoWallpaperFolderSaf()).thenThrow(
      PlatformException(code: 'picker_unavailable'),
    );
    when(wallpaperService.browseLocalVideoLibrary()).thenAnswer(
      (_) async => const <String, dynamic>{'hasMediaPermission': false},
    );

    await _pumpWidget(tester, wallpaperService, bridgeService);

    await tester.tap(find.text('Pick folder'));
    await tester.pumpAndSettle();

    verify(wallpaperService.pickVideoWallpaperFolderSaf()).called(1);
    verify(wallpaperService.browseLocalVideoLibrary()).called(1);
    expect(
      find.text(
        'This TV could not open the folder picker. Opening TV storage instead.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses TV-first selectors for wallpaper options', (tester) async {
    _prepareView(tester);
    final wallpaperService = _mockWallpaperService();
    final bridgeService = MockSystemBridgeService();
    when(bridgeService.fileAccessStatus)
        .thenReturn(const <String, dynamic>{'hasMediaPermission': true});

    await _pumpWidget(tester, wallpaperService, bridgeService);

    expect(
        find.byKey(const Key('wallpaper_order_mode_selector')), findsOneWidget);
    expect(
      find.byKey(const Key('wallpaper_advance_mode_selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('video_repeat_count_per_item_stepper')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('wallpaper_video_fit_selector')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
        find.byKey(const Key('wallpaper_video_fit_selector')), findsOneWidget);
    expect(
      find.byKey(const Key('wallpaper_video_blur_selector')),
      findsOneWidget,
    );
    expect(find.byType(ChoiceChip), findsNothing);
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
  when(wallpaperService.videoRepeatCountPerItem).thenReturn(3);
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
  when(wallpaperService.setVideoRepeatCountPerItem(any))
      .thenAnswer((_) async {});
  when(wallpaperService.browseLocalVideoLibrary()).thenAnswer(
    (_) async => const <String, dynamic>{'hasMediaPermission': false},
  );
  return wallpaperService;
}

void _prepareView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
