import 'package:flauncher/flauncher.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/providers/search_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/apps_grid.dart';
import 'package:flauncher/widgets/category_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transparent_image/transparent_image.dart';

import 'mocks.dart';
import 'mocks.mocks.dart';
import 'package:flauncher/models/category.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('renders row and grid launcher sections inside the dock',
      (tester) async {
    _prepareView(tester);
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final bridgeService = MockSystemBridgeService();
    final channel = MockFLauncherChannel();
    final settingsService = await _createSettingsService();
    final favorites =
        fakeCategory(name: 'Favorites', order: 0, type: CategoryType.row);
    favorites.applications
        .add(fakeApp(packageName: 'row.app', name: 'Row App'));
    final applications =
        fakeCategory(name: 'Applications', order: 1, type: CategoryType.grid);
    applications.applications
        .add(fakeApp(packageName: 'grid.app', name: 'Grid App'));
    when(appsService.initialized).thenReturn(true);
    when(appsService.launcherSections).thenReturn([favorites, applications]);
    when(appsService.getAppBanner(any))
        .thenAnswer((_) async => kTransparentImage);
    when(appsService.getAppIcon(any))
        .thenAnswer((_) async => kTransparentImage);
    when(wallpaperService.wallpaperMode).thenReturn('gradient');
    when(wallpaperService.wallpaper).thenReturn(null);
    when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
    when(wallpaperService.isVideoMode).thenReturn(false);
    when(wallpaperService.videoTextureId).thenReturn(null);
    when(bridgeService.wallpaperStatus).thenReturn(const <String, dynamic>{});
    when(bridgeService.provisioningStatus).thenReturn(const <String, dynamic>{
      'health': 'healthy',
      'requirements': <Map<String, dynamic>>[],
      'missingRequiredCount': 0,
      'missingRecommendedCount': 0,
    });
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});
    await settingsService.setHomeDockAutoCollapseEnabled(false);
    await settingsService.setHomeDockRowsPreset(4);

    await _pumpLauncher(
      tester,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
      channel: channel,
      settingsService: settingsService,
    );

    expect(find.text('Favorites'), findsOneWidget);
    expect(find.byType(CategoryRow), findsOneWidget);
    expect(find.byType(AppsGrid), findsOneWidget);
    expect(find.byKey(const Key('row.app')), findsOneWidget);
    expect(find.byKey(const Key('grid.app')), findsOneWidget);
    expect(find.byKey(const Key('home_bottom_dock')), findsOneWidget);
  });

  testWidgets('status bar reorder button toggles home reorder mode',
      (tester) async {
    _prepareView(tester);
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final bridgeService = MockSystemBridgeService();
    final channel = MockFLauncherChannel();
    final settingsService = await _createSettingsService();
    final favorites =
        fakeCategory(name: 'Favorites', order: 0, type: CategoryType.row);
    favorites.applications
        .add(fakeApp(packageName: 'row.app', name: 'Row App'));
    when(appsService.initialized).thenReturn(true);
    when(appsService.launcherSections).thenReturn([favorites]);
    when(appsService.homeReorderModeEnabled).thenReturn(false);
    when(appsService.getAppBanner(any))
        .thenAnswer((_) async => kTransparentImage);
    when(appsService.getAppIcon(any))
        .thenAnswer((_) async => kTransparentImage);
    when(wallpaperService.wallpaperMode).thenReturn('gradient');
    when(wallpaperService.wallpaper).thenReturn(null);
    when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
    when(wallpaperService.isVideoMode).thenReturn(false);
    when(wallpaperService.videoTextureId).thenReturn(null);
    when(bridgeService.wallpaperStatus).thenReturn(const <String, dynamic>{});
    when(bridgeService.provisioningStatus).thenReturn(const <String, dynamic>{
      'health': 'healthy',
      'requirements': <Map<String, dynamic>>[],
      'missingRequiredCount': 0,
      'missingRecommendedCount': 0,
    });
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});

    await _pumpLauncher(
      tester,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
      channel: channel,
      settingsService: settingsService,
    );

    await tester.tap(find.byIcon(Icons.drive_file_move_outline));
    await tester.pump();

    verify(appsService.toggleHomeReorderMode()).called(1);
  });

  testWidgets('shows image wallpaper when image mode is active',
      (tester) async {
    _prepareView(tester);
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final bridgeService = MockSystemBridgeService();
    final channel = MockFLauncherChannel();
    when(appsService.initialized).thenReturn(true);
    when(appsService.launcherSections).thenReturn(const <LauncherSection>[]);
    when(wallpaperService.wallpaperMode).thenReturn('image');
    when(wallpaperService.wallpaper)
        .thenReturn(MemoryImage(Uint8List.fromList(kTransparentImage)));
    when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
    when(wallpaperService.isVideoMode).thenReturn(false);
    when(wallpaperService.videoTextureId).thenReturn(null);
    when(bridgeService.wallpaperStatus).thenReturn(const <String, dynamic>{});
    when(bridgeService.provisioningStatus).thenReturn(const <String, dynamic>{
      'health': 'healthy',
      'requirements': <Map<String, dynamic>>[],
      'missingRequiredCount': 0,
      'missingRecommendedCount': 0,
    });
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});

    await _pumpLauncher(
      tester,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
      channel: channel,
    );

    expect(
      tester.widget(find.byKey(const Key('background'))),
      isA<Image>(),
    );
  });

  testWidgets(
      'dock height presets scale by visible rows when auto collapse is off',
      (tester) async {
    _prepareView(tester);
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final bridgeService = MockSystemBridgeService();
    final channel = MockFLauncherChannel();
    final settingsService = await _createSettingsService();

    when(appsService.initialized).thenReturn(true);
    when(appsService.launcherSections).thenReturn(const <LauncherSection>[]);
    when(wallpaperService.wallpaperMode).thenReturn('gradient');
    when(wallpaperService.wallpaper).thenReturn(null);
    when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
    when(wallpaperService.isVideoMode).thenReturn(false);
    when(wallpaperService.videoTextureId).thenReturn(null);
    when(bridgeService.wallpaperStatus).thenReturn(const <String, dynamic>{});
    when(bridgeService.provisioningStatus).thenReturn(const <String, dynamic>{
      'health': 'healthy',
      'requirements': <Map<String, dynamic>>[],
      'missingRequiredCount': 0,
      'missingRecommendedCount': 0,
    });
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});

    Future<double> pumpDock({
      required int rows,
      required bool showTitles,
    }) async {
      await settingsService.setHomeDockAutoCollapseEnabled(false);
      await settingsService.setHomeDockRowsPreset(rows);
      await settingsService.setShowCategoryTitles(showTitles);
      await _pumpLauncher(
        tester,
        appsService: appsService,
        wallpaperService: wallpaperService,
        bridgeService: bridgeService,
        channel: channel,
        settingsService: settingsService,
      );
      return tester.getSize(find.byKey(const Key('home_bottom_dock'))).height;
    }

    final height2Rows = await pumpDock(rows: 2, showTitles: true);
    final height3Rows = await pumpDock(rows: 3, showTitles: true);
    final height4Rows = await pumpDock(rows: 4, showTitles: true);
    final height3RowsNoTitle = await pumpDock(rows: 3, showTitles: false);

    expect(height3Rows, greaterThan(height2Rows));
    expect(height4Rows, greaterThan(height3Rows));
    expect(height3Rows - height2Rows, greaterThanOrEqualTo(100));
    expect(height4Rows - height3Rows, greaterThanOrEqualTo(100));
    expect((height3Rows - height3RowsNoTitle).abs(), lessThanOrEqualTo(0.1));
  });

  testWidgets('collapsed dock height honors collapsed rows and row spacing',
      (tester) async {
    _prepareView(tester);
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final bridgeService = MockSystemBridgeService();
    final channel = MockFLauncherChannel();
    final settingsService = await _createSettingsService();

    when(appsService.initialized).thenReturn(true);
    when(appsService.launcherSections).thenReturn(const <LauncherSection>[]);
    when(wallpaperService.wallpaperMode).thenReturn('gradient');
    when(wallpaperService.wallpaper).thenReturn(null);
    when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
    when(wallpaperService.isVideoMode).thenReturn(false);
    when(wallpaperService.videoTextureId).thenReturn(null);
    when(bridgeService.wallpaperStatus).thenReturn(const <String, dynamic>{});
    when(bridgeService.provisioningStatus).thenReturn(const <String, dynamic>{
      'health': 'healthy',
      'requirements': <Map<String, dynamic>>[],
      'missingRequiredCount': 0,
      'missingRecommendedCount': 0,
    });
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});

    Future<double> pumpCollapsedDock({
      required int collapsedRows,
      required int rowSpacing,
    }) async {
      await settingsService.setHomeDockRowsPreset(4);
      await settingsService.setHomeDockCollapsedRowsPreset(collapsedRows);
      await settingsService.setHomeDockRowSpacing(rowSpacing);
      await settingsService.setHomeDockAutoCollapseEnabled(true);
      await _pumpLauncher(
        tester,
        appsService: appsService,
        wallpaperService: wallpaperService,
        bridgeService: bridgeService,
        channel: channel,
        settingsService: settingsService,
      );
      return tester.getSize(find.byKey(const Key('home_bottom_dock'))).height;
    }

    final height1Row =
        await pumpCollapsedDock(collapsedRows: 1, rowSpacing: 12);
    final height2Rows =
        await pumpCollapsedDock(collapsedRows: 2, rowSpacing: 12);
    final height2RowsTight =
        await pumpCollapsedDock(collapsedRows: 2, rowSpacing: 4);

    expect(height2Rows, greaterThan(height1Row));
    expect(height2RowsTight, lessThan(height2Rows));
  });

  testWidgets('dock stays anchored while its inner content scrolls',
      (tester) async {
    _prepareView(tester);
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final bridgeService = MockSystemBridgeService();
    final channel = MockFLauncherChannel();
    final settingsService = await _createSettingsService();
    final sections = List<LauncherSection>.generate(8, (index) {
      final category = fakeCategory(
        name: 'Category $index',
        order: index,
        type: CategoryType.row,
      );
      category.applications.add(
        fakeApp(
          packageName: 'row.app.$index',
          name: 'Row App $index',
        ),
      );
      return category;
    });

    when(appsService.initialized).thenReturn(true);
    when(appsService.launcherSections).thenReturn(sections);
    when(appsService.getAppBanner(any))
        .thenAnswer((_) async => kTransparentImage);
    when(appsService.getAppIcon(any))
        .thenAnswer((_) async => kTransparentImage);
    when(wallpaperService.wallpaperMode).thenReturn('gradient');
    when(wallpaperService.wallpaper).thenReturn(null);
    when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
    when(wallpaperService.isVideoMode).thenReturn(false);
    when(wallpaperService.videoTextureId).thenReturn(null);
    when(bridgeService.wallpaperStatus).thenReturn(const <String, dynamic>{});
    when(bridgeService.provisioningStatus).thenReturn(const <String, dynamic>{
      'health': 'healthy',
      'requirements': <Map<String, dynamic>>[],
      'missingRequiredCount': 0,
      'missingRecommendedCount': 0,
    });
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});

    await settingsService.setHomeDockRowsPreset(3);
    await settingsService.setShowCategoryTitles(true);
    await _pumpLauncher(
      tester,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
      channel: channel,
      settingsService: settingsService,
    );

    final dockFinder = find.byKey(const Key('home_bottom_dock'));
    final scrollFinder = find.byKey(const Key('home_bottom_dock_scroll'));
    final firstSectionFinder = find.byType(CategoryRow).first;

    final initialDockTop = tester.getTopLeft(dockFinder);
    final initialSectionTop = tester.getTopLeft(firstSectionFinder);

    await tester.drag(scrollFinder, const Offset(0, -280));
    await tester.pumpAndSettle();

    final scrolledDockTop = tester.getTopLeft(dockFinder);
    final scrolledSectionTop = tester.getTopLeft(firstSectionFinder);

    expect(scrolledDockTop.dy, initialDockTop.dy);
    expect(scrolledSectionTop.dy, lessThan(initialSectionTop.dy));
  });

  testWidgets('collapsed dock can move focus to the next category with DPAD',
      (tester) async {
    _prepareView(tester);
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final bridgeService = MockSystemBridgeService();
    final channel = MockFLauncherChannel();
    final settingsService = await _createSettingsService();
    final sections = List<LauncherSection>.generate(3, (index) {
      final category = fakeCategory(
        name: 'Category $index',
        order: index,
        type: CategoryType.row,
      );
      category.applications.add(
        fakeApp(
          packageName: 'focus.app.$index',
          name: 'Focus App $index',
        ),
      );
      return category;
    });

    when(appsService.initialized).thenReturn(true);
    when(appsService.launcherSections).thenReturn(sections);
    when(appsService.getAppBanner(any))
        .thenAnswer((_) async => kTransparentImage);
    when(appsService.getAppIcon(any))
        .thenAnswer((_) async => kTransparentImage);
    when(wallpaperService.wallpaperMode).thenReturn('gradient');
    when(wallpaperService.wallpaper).thenReturn(null);
    when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
    when(wallpaperService.isVideoMode).thenReturn(false);
    when(wallpaperService.videoTextureId).thenReturn(null);
    when(bridgeService.wallpaperStatus).thenReturn(const <String, dynamic>{});
    when(bridgeService.provisioningStatus).thenReturn(const <String, dynamic>{
      'health': 'healthy',
      'requirements': <Map<String, dynamic>>[],
      'missingRequiredCount': 0,
      'missingRecommendedCount': 0,
    });
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});

    await settingsService.setShowCategoryTitles(true);
    await settingsService.setHomeDockRowsPreset(3);
    await settingsService.setHomeDockAutoCollapseEnabled(true);

    await _pumpLauncher(
      tester,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
      channel: channel,
      settingsService: settingsService,
    );

    expect(find.text('Category 0'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));

    expect(find.text('Category 1'), findsOneWidget);
  });

  testWidgets('dock collapse resets scroll to top and focus back to first app',
      (tester) async {
    _prepareView(tester);
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final bridgeService = MockSystemBridgeService();
    final channel = MockFLauncherChannel();
    final settingsService = await _createSettingsService();
    final sections = List<LauncherSection>.generate(6, (index) {
      final category = fakeCategory(
        name: 'Reset $index',
        order: index,
        type: CategoryType.row,
      );
      category.applications.add(
        fakeApp(
          packageName: 'reset.app.$index',
          name: 'Reset App $index',
        ),
      );
      return category;
    });

    when(appsService.initialized).thenReturn(true);
    when(appsService.launcherSections).thenReturn(sections);
    when(appsService.getAppBanner(any))
        .thenAnswer((_) async => kTransparentImage);
    when(appsService.getAppIcon(any))
        .thenAnswer((_) async => kTransparentImage);
    when(wallpaperService.wallpaperMode).thenReturn('gradient');
    when(wallpaperService.wallpaper).thenReturn(null);
    when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
    when(wallpaperService.isVideoMode).thenReturn(false);
    when(wallpaperService.videoTextureId).thenReturn(null);
    when(bridgeService.wallpaperStatus).thenReturn(const <String, dynamic>{});
    when(bridgeService.provisioningStatus).thenReturn(const <String, dynamic>{
      'health': 'healthy',
      'requirements': <Map<String, dynamic>>[],
      'missingRequiredCount': 0,
      'missingRecommendedCount': 0,
    });
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});

    await settingsService.setShowCategoryTitles(true);
    await settingsService.setHomeDockRowsPreset(3);
    await settingsService.setHomeDockCollapsedRowsPreset(1);
    await settingsService.setHomeDockAutoCollapseEnabled(true);
    await settingsService.setHomeDockAutoCollapseDelaySeconds(5);

    await _pumpLauncher(
      tester,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
      channel: channel,
      settingsService: settingsService,
    );

    final firstSectionFinder = find.byType(CategoryRow).first;
    final initialSectionTop = tester.getTopLeft(firstSectionFinder).dy;

    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 420));
    }

    final scrolledSectionTop = tester.getTopLeft(firstSectionFinder).dy;
    expect(scrolledSectionTop, lessThan(initialSectionTop));
    expect(find.text('Reset 3'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));

    final resetSectionTop = tester.getTopLeft(firstSectionFinder).dy;
    expect(resetSectionTop, greaterThan(scrolledSectionTop));
    expect((resetSectionTop - initialSectionTop).abs(), lessThanOrEqualTo(1.0));
    expect(find.text('Reset 0'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));

    expect(find.text('Reset 1'), findsOneWidget);
  });

  testWidgets(
      'dock keeps vertical focus inside categories before reaching app bar',
      (tester) async {
    _prepareView(tester);
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final bridgeService = MockSystemBridgeService();
    final channel = MockFLauncherChannel();
    final settingsService = await _createSettingsService();
    final sections = List<LauncherSection>.generate(3, (index) {
      final category = fakeCategory(
        name: 'Vertical $index',
        order: index,
        type: CategoryType.row,
      );
      category.applications.add(
        fakeApp(
          packageName: 'vertical.app.$index',
          name: 'Vertical App $index',
        ),
      );
      return category;
    });

    when(appsService.initialized).thenReturn(true);
    when(appsService.launcherSections).thenReturn(sections);
    when(appsService.getAppBanner(any))
        .thenAnswer((_) async => kTransparentImage);
    when(appsService.getAppIcon(any))
        .thenAnswer((_) async => kTransparentImage);
    when(wallpaperService.wallpaperMode).thenReturn('gradient');
    when(wallpaperService.wallpaper).thenReturn(null);
    when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
    when(wallpaperService.isVideoMode).thenReturn(false);
    when(wallpaperService.videoTextureId).thenReturn(null);
    when(bridgeService.wallpaperStatus).thenReturn(const <String, dynamic>{});
    when(bridgeService.provisioningStatus).thenReturn(const <String, dynamic>{
      'health': 'healthy',
      'requirements': <Map<String, dynamic>>[],
      'missingRequiredCount': 0,
      'missingRecommendedCount': 0,
    });
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});

    await settingsService.setShowCategoryTitles(true);
    await settingsService.setHomeDockRowsPreset(3);
    await settingsService.setHomeDockAutoCollapseEnabled(false);

    await _pumpLauncher(
      tester,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
      channel: channel,
      settingsService: settingsService,
    );

    expect(find.text('Vertical 0'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    expect(find.text('Vertical 1'), findsOneWidget);
    _expectCardNearDockCenter(tester, const Key('vertical.app.1'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    expect(find.text('Vertical 2'), findsOneWidget);
    _expectCardNearDockCenter(tester, const Key('vertical.app.2'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    expect(find.text('Vertical 1'), findsOneWidget);
    _expectCardNearDockCenter(tester, const Key('vertical.app.1'));
  });

  testWidgets(
      'long press on home opens app management menu when reorder mode is off',
      (tester) async {
    _prepareView(tester);
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final bridgeService = MockSystemBridgeService();
    final channel = MockFLauncherChannel();
    final settingsService = await _createSettingsService();
    final category = fakeCategory(
      name: 'Reorder',
      order: 0,
      type: CategoryType.row,
    );
    category.applications.addAll([
      fakeApp(packageName: 'reorder.app.0', name: 'Reorder App 0'),
      fakeApp(packageName: 'reorder.app.1', name: 'Reorder App 1'),
    ]);
    final fillerSections = List<LauncherSection>.generate(4, (index) {
      final filler = fakeCategory(
        name: 'Filler $index',
        order: index + 1,
        type: CategoryType.row,
      );
      filler.applications.add(
        fakeApp(
          packageName: 'filler.app.$index',
          name: 'Filler App $index',
        ),
      );
      return filler;
    });

    when(appsService.initialized).thenReturn(true);
    when(appsService.launcherSections)
        .thenReturn([category, ...fillerSections]);
    when(appsService.beginApplicationReorderSession(any)).thenReturn(true);
    when(appsService.getAppBanner(any))
        .thenAnswer((_) async => kTransparentImage);
    when(appsService.getAppIcon(any))
        .thenAnswer((_) async => kTransparentImage);
    when(wallpaperService.wallpaperMode).thenReturn('gradient');
    when(wallpaperService.wallpaper).thenReturn(null);
    when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
    when(wallpaperService.isVideoMode).thenReturn(false);
    when(wallpaperService.videoTextureId).thenReturn(null);
    when(bridgeService.wallpaperStatus).thenReturn(const <String, dynamic>{});
    when(bridgeService.provisioningStatus).thenReturn(const <String, dynamic>{
      'health': 'healthy',
      'requirements': <Map<String, dynamic>>[],
      'missingRequiredCount': 0,
      'missingRecommendedCount': 0,
    });
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});

    await settingsService.setHomeDockRowsPreset(3);
    await settingsService.setHomeDockCollapsedRowsPreset(1);
    await settingsService.setHomeDockAutoCollapseEnabled(true);

    await _pumpLauncher(
      tester,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
      channel: channel,
      settingsService: settingsService,
    );

    final dockFinder = find.byKey(const Key('home_bottom_dock'));
    final collapsedHeight = tester.getSize(dockFinder).height;

    await tester.longPress(
      find.descendant(
        of: find.byKey(const Key('reorder.app.0')),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));

    final currentHeight = tester.getSize(dockFinder).height;
    expect(currentHeight, greaterThanOrEqualTo(collapsedHeight));
    verifyNever(appsService.beginApplicationReorderSession(any));
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets(
      'row reorder keeps move mode active across multiple DPAD moves until OK',
      (tester) async {
    _prepareView(tester);
    final appsService = MockAppsService();
    final settingsService = await _createSettingsService();
    final category = fakeCategory(
      name: 'Row Reorder',
      order: 0,
      type: CategoryType.row,
      columnsCount: 4,
    );
    category.applications.addAll([
      fakeApp(packageName: 'move.row.0', name: 'Move Row 0'),
      fakeApp(packageName: 'move.row.1', name: 'Move Row 1'),
      fakeApp(packageName: 'move.row.2', name: 'Move Row 2'),
    ]);

    late void Function() rebuild;
    when(appsService.homeReorderModeEnabled).thenReturn(true);
    when(appsService.beginApplicationReorderSession(any)).thenReturn(true);
    when(appsService.commitApplicationReorderSession(any))
        .thenAnswer((_) async {});
    when(appsService.cancelApplicationReorderSession(any))
        .thenAnswer((_) async {});
    when(appsService.getAppBanner(any))
        .thenAnswer((_) async => kTransparentImage);
    when(appsService.getAppIcon(any))
        .thenAnswer((_) async => kTransparentImage);
    when(appsService.addListener(any)).thenReturn(null);
    when(appsService.removeListener(any)).thenReturn(null);
    when(appsService.reorderApplication(any, any, any))
        .thenAnswer((invocation) {
      final targetCategory = invocation.positionalArguments[0] as Category;
      final oldIndex = invocation.positionalArguments[1] as int;
      final newIndex = invocation.positionalArguments[2] as int;
      final moved = targetCategory.applications.removeAt(oldIndex);
      targetCategory.applications.insert(newIndex, moved);
      rebuild();
      return true;
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProfileSecurityService?>.value(value: null),
          ListenableProvider<AppsService>.value(value: appsService),
          ChangeNotifierProvider<SettingsService>.value(value: settingsService),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = () => setState(() {});
                return SizedBox(
                  width: 1280,
                  child: CategoryRow(
                    category: category,
                    applications: category.applications,
                    autofocusFirstItem: true,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
    expect(category.applications[1].packageName, 'move.row.0');
    verifyNever(appsService.commitApplicationReorderSession(any));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
    expect(category.applications[2].packageName, 'move.row.0');
    verifyNever(appsService.commitApplicationReorderSession(any));

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 180));

    verify(appsService.commitApplicationReorderSession(any)).called(1);
    verifyNever(appsService.setHomeReorderModeEnabled(false));
    expect(find.byIcon(Icons.keyboard_arrow_right), findsNothing);
  });

  testWidgets(
      'grid reorder keeps move mode active across vertical and horizontal DPAD moves until OK',
      (tester) async {
    _prepareView(tester);
    final appsService = MockAppsService();
    final settingsService = await _createSettingsService();
    final category = fakeCategory(
      name: 'Grid Reorder',
      order: 0,
      type: CategoryType.grid,
      columnsCount: 2,
    );
    category.applications.addAll([
      fakeApp(packageName: 'move.grid.0', name: 'Move Grid 0'),
      fakeApp(packageName: 'move.grid.1', name: 'Move Grid 1'),
      fakeApp(packageName: 'move.grid.2', name: 'Move Grid 2'),
      fakeApp(packageName: 'move.grid.3', name: 'Move Grid 3'),
    ]);

    late void Function() rebuild;
    when(appsService.homeReorderModeEnabled).thenReturn(true);
    when(appsService.beginApplicationReorderSession(any)).thenReturn(true);
    when(appsService.commitApplicationReorderSession(any))
        .thenAnswer((_) async {});
    when(appsService.cancelApplicationReorderSession(any))
        .thenAnswer((_) async {});
    when(appsService.getAppBanner(any))
        .thenAnswer((_) async => kTransparentImage);
    when(appsService.getAppIcon(any))
        .thenAnswer((_) async => kTransparentImage);
    when(appsService.addListener(any)).thenReturn(null);
    when(appsService.removeListener(any)).thenReturn(null);
    when(appsService.reorderApplication(any, any, any))
        .thenAnswer((invocation) {
      final targetCategory = invocation.positionalArguments[0] as Category;
      final oldIndex = invocation.positionalArguments[1] as int;
      final newIndex = invocation.positionalArguments[2] as int;
      final moved = targetCategory.applications.removeAt(oldIndex);
      targetCategory.applications.insert(newIndex, moved);
      rebuild();
      return true;
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProfileSecurityService?>.value(value: null),
          ListenableProvider<AppsService>.value(value: appsService),
          ChangeNotifierProvider<SettingsService>.value(value: settingsService),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = () => setState(() {});
                return SizedBox(
                  width: 1280,
                  child: AppsGrid(
                    category: category,
                    applications: category.applications,
                    autofocusFirstItem: true,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(category.applications[2].packageName, 'move.grid.0');
    verifyNever(appsService.commitApplicationReorderSession(any));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
    expect(category.applications[3].packageName, 'move.grid.0');
    verifyNever(appsService.commitApplicationReorderSession(any));

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 180));

    verify(appsService.commitApplicationReorderSession(any)).called(1);
    verifyNever(appsService.setHomeReorderModeEnabled(false));
    expect(find.byIcon(Icons.keyboard_arrow_right), findsNothing);
  });
}

void _expectCardNearDockCenter(WidgetTester tester, Key appKey) {
  final dockRect = tester.getRect(find.byKey(const Key('home_bottom_dock')));
  final cardRect = tester.getRect(find.byKey(appKey));
  final distanceFromCenter = (cardRect.center.dy - dockRect.center.dy).abs();
  expect(
    distanceFromCenter,
    lessThanOrEqualTo(cardRect.height + 40),
  );
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required AppsService appsService,
  required WallpaperService wallpaperService,
  required SystemBridgeService bridgeService,
  required FLauncherChannel channel,
  SettingsService? settingsService,
}) async {
  final resolvedSettings = settingsService ?? await _createSettingsService();
  if (bridgeService is MockSystemBridgeService) {
    when(bridgeService.status).thenReturn(const <String, dynamic>{
      'memory': <String, dynamic>{},
      'provisioning': <String, dynamic>{},
    });
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WallpaperService>.value(value: wallpaperService),
        ChangeNotifierProvider<AppsService>.value(value: appsService),
        ChangeNotifierProvider<SettingsService>.value(value: resolvedSettings),
        ChangeNotifierProvider<ProfileSecurityService>.value(
          value: await _createProfileSecurityService(),
        ),
        ChangeNotifierProvider<SystemBridgeService>.value(value: bridgeService),
        ChangeNotifierProvider<SearchService>.value(
          value: await _createSearchService(channel),
        ),
        ChangeNotifierProvider(create: (_) => LauncherState()),
        ChangeNotifierProvider(create: (_) => NetworkService(channel)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const FLauncher(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<SettingsService> _createSettingsService() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return SettingsService(await SharedPreferences.getInstance());
}

Future<ProfileSecurityService> _createProfileSecurityService() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return ProfileSecurityService(await SharedPreferences.getInstance());
}

void _stubWallpaperService(
  MockWallpaperService wallpaperService, {
  String wallpaperMode = 'gradient',
  ImageProvider<Object>? wallpaper,
  FLauncherGradient? gradient,
  bool isVideoMode = false,
  int? videoTextureId,
  String videoFit = 'center-crop',
  String videoBlur = 'off',
  int videoDimPercent = 15,
}) {
  when(wallpaperService.wallpaperMode).thenReturn(wallpaperMode);
  when(wallpaperService.wallpaper).thenReturn(wallpaper);
  when(wallpaperService.gradient)
      .thenReturn(gradient ?? FLauncherGradients.greatWhale);
  when(wallpaperService.isVideoMode).thenReturn(isVideoMode);
  when(wallpaperService.videoTextureId).thenReturn(videoTextureId);
  when(wallpaperService.videoFit).thenReturn(videoFit);
  when(wallpaperService.videoBlur).thenReturn(videoBlur);
  when(wallpaperService.videoDimPercent).thenReturn(videoDimPercent);
}

Future<SearchService> _createSearchService(FLauncherChannel channel) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return SearchService(await SharedPreferences.getInstance(), channel);
}

void _prepareView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
