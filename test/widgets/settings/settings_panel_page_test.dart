import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/settings/permissions_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_panel_page.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks.mocks.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('shows master-detail settings shell', (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    expect(find.text('ATV Launcher Settings'), findsOneWidget);
    expect(find.text('Control Center'), findsOneWidget);
    expect(find.text('Home & Layout'), findsAtLeastNWidgets(1));
  });

  testWidgets('switches to Wallpaper & Media section from the rail',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await tester.tap(find.text('Wallpaper & Media').first);
    await tester.pumpAndSettle();

    expect(find.text('Source selection'), findsOneWidget);
    expect(find.text('Single video'), findsOneWidget);
  });

  testWidgets('switches to Permissions & Provisioning section from the rail',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permissions & Provisioning').first);
    await tester.pumpAndSettle();

    expect(find.text('Provisioning Wizard'), findsOneWidget);
    expect(find.text('Grant via local ADB'), findsOneWidget);
  });

  testWidgets('auto focuses Home & Layout detail pane on open',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    expect(find.text('App language'), findsAtLeastNWidgets(1));
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      isNot(contains('settings_rail_')),
    );
    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isTrue,
    );

    for (var index = 0; index < 4; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      final label = tester.binding.focusManager.primaryFocus?.debugLabel ?? '';
      if (label.contains('settings_rail_0')) {
        break;
      }
    }

    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('settings_rail_0'),
    );
    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isFalse,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.text('Source selection'), findsOneWidget);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      contains('settings_rail_1'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      isNot(contains('settings_rail_')),
    );
    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isTrue,
    );

    for (var index = 0; index < 4; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      final highlighted = tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted;
      if (!highlighted) {
        break;
      }
    }
    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isFalse,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(find.text('Home & Layout'), findsAtLeastNWidgets(1));
    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isFalse,
    );
  });

  testWidgets(
      'mounts only the current detail page and restores wallpaper scroll',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    expect(
      find.byType(WallpaperPanelPage, skipOffstage: false),
      findsNothing,
    );

    await tester.tap(find.text('Wallpaper & Media').first);
    await tester.pumpAndSettle();

    expect(
      find.byType(WallpaperPanelPage, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byType(PermissionsPanelPage, skipOffstage: false),
      findsNothing,
    );

    final wallpaperPageFinder = find.byKey(
      const PageStorageKey<String>(WallpaperPanelPage.routeName),
    );
    final wallpaperScrollableFinder = find.descendant(
      of: wallpaperPageFinder,
      matching: find.byType(Scrollable),
    );
    await tester.drag(wallpaperPageFinder, const Offset(0, -500));
    await tester.pumpAndSettle();
    final initialPixels = tester
        .state<ScrollableState>(wallpaperScrollableFinder)
        .position
        .pixels;

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permissions & Provisioning').first);
    await tester.pumpAndSettle();

    expect(
      find.byType(WallpaperPanelPage, skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byType(PermissionsPanelPage, skipOffstage: false),
      findsOneWidget,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallpaper & Media').first);
    await tester.pumpAndSettle();

    final restoredPixels = tester
        .state<ScrollableState>(wallpaperScrollableFinder)
        .position
        .pixels;
    expect(restoredPixels, closeTo(initialPixels, 0.1));

    expect(
      find.byType(WallpaperPanelPage, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byType(PermissionsPanelPage, skipOffstage: false),
      findsNothing,
    );
  });
}

Future<void> _pumpSettingsPanel(
  WidgetTester tester, {
  required SettingsService settings,
  required AppsService appsService,
  required WallpaperService wallpaperService,
  required SystemBridgeService bridgeService,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        ChangeNotifierProvider<AppsService>.value(value: appsService),
        ChangeNotifierProvider<WallpaperService>.value(value: wallpaperService),
        ChangeNotifierProvider<SystemBridgeService>.value(value: bridgeService),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Material(child: SettingsPanelPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MockWallpaperService _mockWallpaperService() {
  final wallpaperService = MockWallpaperService();
  when(wallpaperService.wallpaperMode).thenReturn('gradient');
  when(wallpaperService.videoSourceType).thenReturn('single_file');
  when(wallpaperService.videoUris).thenReturn(const <String>[]);
  when(wallpaperService.wallpaperAssetUri).thenReturn('');
  when(wallpaperService.videoFolderName).thenReturn('');
  when(wallpaperService.isVideoMode).thenReturn(false);
  when(wallpaperService.videoAdvanceMode).thenReturn('on_completion');
  when(wallpaperService.videoOrderMode).thenReturn('sequential');
  when(wallpaperService.videoSwitchIntervalSeconds).thenReturn(30);
  when(wallpaperService.videoPlaylistLoop).thenReturn(true);
  when(wallpaperService.videoLoop).thenReturn(true);
  when(wallpaperService.videoMute).thenReturn(true);
  when(wallpaperService.videoAutoResume).thenReturn(true);
  when(wallpaperService.videoFit).thenReturn('center-crop');
  when(wallpaperService.videoBlur).thenReturn('off');
  when(wallpaperService.videoDimPercent).thenReturn(15);
  when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
  return wallpaperService;
}

MockSystemBridgeService _mockBridgeService() {
  final bridgeService = MockSystemBridgeService();
  when(bridgeService.fileAccessStatus)
      .thenReturn(const <String, dynamic>{'hasMediaPermission': true});
  when(bridgeService.provisioningStatus).thenReturn(
    const <String, dynamic>{
      'requirements': <Map<String, dynamic>>[],
      'commands': <String>[],
      'wizardSteps': <String>['Enable developer options', 'Run local ADB'],
    },
  );
  return bridgeService;
}

Future<SettingsService> _createSettingsService() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return SettingsService(await SharedPreferences.getInstance());
}

void _prepareView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
