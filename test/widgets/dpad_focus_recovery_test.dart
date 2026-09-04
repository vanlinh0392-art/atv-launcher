import 'dart:async';

import 'package:flauncher/flauncher.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/providers/search_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flauncher/widgets/right_panel_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transparent_image/transparent_image.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('D-pad Focus Recovery Tests', () {
    testWidgets(
        'recovers focus to dock item when primaryFocus is null or lost after closing dialog',
        (tester) async {
      _prepareView(tester);
      final appsService = MockAppsService();
      final wallpaperService = MockWallpaperService();
      final channel = MockFLauncherChannel();
      final bridgeService = _MutableSystemBridgeService(channel, {
        'navigation': {'homeSequence': 0, 'reason': 'startup'},
      });
      final settingsService = await _createSettingsService();
      await settingsService.setHomeDockAutoCollapseEnabled(false);
      await settingsService.setHomeDockRowsPreset(4);

      final favorites = fakeCategory(name: 'Favorites', order: 0, type: CategoryType.row);
      favorites.applications.add(fakeApp(packageName: 'row.app.1', name: 'App One'));
      favorites.applications.add(fakeApp(packageName: 'row.app.2', name: 'App Two'));

      when(appsService.initialized).thenReturn(true);
      when(appsService.launcherSections).thenReturn([favorites]);
      when(appsService.getAppBanner(any)).thenAnswer((_) async => kTransparentImage);
      when(appsService.getAppIcon(any)).thenAnswer((_) async => kTransparentImage);
      when(channel.addNetworkChangedListener(any)).thenReturn(null);
      when(channel.getActiveNetworkInformation()).thenAnswer((_) async => <String, dynamic>{});
      _stubWallpaperService(wallpaperService);

      await _pumpLauncher(
        tester,
        appsService: appsService,
        wallpaperService: wallpaperService,
        bridgeService: bridgeService,
        channel: channel,
        settingsService: settingsService,
      );

      // Verify dock AppCard initially receives focus
      expect(find.byKey(const Key('row.app.1')), findsOneWidget);
      expect(_primaryFocusIsDescendantOf(tester, find.byKey(const Key('row.app.1'))), isTrue);

      // Open a dialog
      late BuildContext dialogContext;
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(FLauncher)),
          builder: (ctx) {
            dialogContext = ctx;
            return const AlertDialog(
              content: Text('Test Dialog Content'),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Dialog Content'), findsOneWidget);

      // Close the dialog
      Navigator.of(dialogContext).pop();
      await tester.pumpAndSettle();

      expect(find.text('Test Dialog Content'), findsNothing);

      // Verify that after dialog close, focus is automatically restored to a dock item
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(_primaryFocusIsDescendantOf(tester, find.byType(AppCard)), isTrue);
    });

    testWidgets(
        'focus watchdog automatically restores focus to dock when primaryFocus becomes null',
        (tester) async {
      _prepareView(tester);
      final appsService = MockAppsService();
      final wallpaperService = MockWallpaperService();
      final channel = MockFLauncherChannel();
      final bridgeService = _MutableSystemBridgeService(channel, {
        'navigation': {'homeSequence': 0, 'reason': 'startup'},
      });
      final settingsService = await _createSettingsService();
      await settingsService.setHomeDockAutoCollapseEnabled(false);

      final favorites = fakeCategory(name: 'Favorites', order: 0, type: CategoryType.row);
      favorites.applications.add(fakeApp(packageName: 'row.app.1', name: 'App One'));

      when(appsService.initialized).thenReturn(true);
      when(appsService.launcherSections).thenReturn([favorites]);
      when(appsService.getAppBanner(any)).thenAnswer((_) async => kTransparentImage);
      when(appsService.getAppIcon(any)).thenAnswer((_) async => kTransparentImage);
      when(channel.addNetworkChangedListener(any)).thenReturn(null);
      when(channel.getActiveNetworkInformation()).thenAnswer((_) async => <String, dynamic>{});
      _stubWallpaperService(wallpaperService);

      await _pumpLauncher(
        tester,
        appsService: appsService,
        wallpaperService: wallpaperService,
        bridgeService: bridgeService,
        channel: channel,
        settingsService: settingsService,
      );

      expect(_primaryFocusIsDescendantOf(tester, find.byKey(const Key('row.app.1'))), isTrue);

      // Simulate an orphan focus node that is not part of the widget tree
      final orphanNode = FocusNode(debugLabel: 'orphan_node');
      orphanNode.requestFocus();
      await tester.pump();

      // Pump to let the watchdog detect orphan and recover
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Focus should be restored to the AppCard in the dock
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(_primaryFocusIsDescendantOf(tester, find.byKey(const Key('row.app.1'))), isTrue);
      orphanNode.dispose();
    });

    testWidgets(
        'ensures focus is restored on valid AppCard upon screen_wake event',
        (tester) async {
      _prepareView(tester);
      final appsService = MockAppsService();
      final wallpaperService = MockWallpaperService();
      final channel = MockFLauncherChannel();
      final bridgeService = _MutableSystemBridgeService(channel, {
        'navigation': {'homeSequence': 0, 'reason': 'startup'},
      });
      final settingsService = await _createSettingsService();
      await settingsService.setHomeDockAutoCollapseEnabled(false);

      final favorites = fakeCategory(name: 'Favorites', order: 0, type: CategoryType.row);
      favorites.applications.add(fakeApp(packageName: 'row.app.1', name: 'App One'));
      favorites.applications.add(fakeApp(packageName: 'row.app.2', name: 'App Two'));

      when(appsService.initialized).thenReturn(true);
      when(appsService.launcherSections).thenReturn([favorites]);
      when(appsService.getAppBanner(any)).thenAnswer((_) async => kTransparentImage);
      when(appsService.getAppIcon(any)).thenAnswer((_) async => kTransparentImage);
      when(channel.addNetworkChangedListener(any)).thenReturn(null);
      when(channel.getActiveNetworkInformation()).thenAnswer((_) async => <String, dynamic>{});
      _stubWallpaperService(wallpaperService);

      await _pumpLauncher(
        tester,
        appsService: appsService,
        wallpaperService: wallpaperService,
        bridgeService: bridgeService,
        channel: channel,
        settingsService: settingsService,
      );

      // Clear focus or move away
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Send screen_wake navigation event
      bridgeService.setNavigationStatus({
        'homeSequence': 1,
        'reason': 'screen_wake',
      });
      await tester.pumpAndSettle();

      // Focus must be guaranteed on the valid AppCard
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(_primaryFocusIsDescendantOf(tester, find.byKey(const Key('row.app.1'))), isTrue);
    });

    testWidgets(
        'ensures focus is restored on valid AppCard upon home_reentry event',
        (tester) async {
      _prepareView(tester);
      final appsService = MockAppsService();
      final wallpaperService = MockWallpaperService();
      final channel = MockFLauncherChannel();
      final bridgeService = _MutableSystemBridgeService(channel, {
        'navigation': {'homeSequence': 0, 'reason': 'startup'},
      });
      final settingsService = await _createSettingsService();
      await settingsService.setHomeDockAutoCollapseEnabled(false);

      final favorites = fakeCategory(name: 'Favorites', order: 0, type: CategoryType.row);
      favorites.applications.add(fakeApp(packageName: 'row.app.1', name: 'App One'));
      favorites.applications.add(fakeApp(packageName: 'row.app.2', name: 'App Two'));

      when(appsService.initialized).thenReturn(true);
      when(appsService.launcherSections).thenReturn([favorites]);
      when(appsService.getAppBanner(any)).thenAnswer((_) async => kTransparentImage);
      when(appsService.getAppIcon(any)).thenAnswer((_) async => kTransparentImage);
      when(channel.addNetworkChangedListener(any)).thenReturn(null);
      when(channel.getActiveNetworkInformation()).thenAnswer((_) async => <String, dynamic>{});
      _stubWallpaperService(wallpaperService);

      await _pumpLauncher(
        tester,
        appsService: appsService,
        wallpaperService: wallpaperService,
        bridgeService: bridgeService,
        channel: channel,
        settingsService: settingsService,
      );

      // Clear focus
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Send home_reentry navigation event
      bridgeService.setNavigationStatus({
        'homeSequence': 2,
        'reason': 'home_reentry',
      });
      await tester.pumpAndSettle();

      // Focus must be guaranteed on the valid AppCard
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(_primaryFocusIsDescendantOf(tester, find.byKey(const Key('row.app.1'))), isTrue);
    });

    testWidgets(
        'recovers focus after opening and closing RightPanelDialog',
        (tester) async {
      _prepareView(tester);
      final appsService = MockAppsService();
      final wallpaperService = MockWallpaperService();
      final channel = MockFLauncherChannel();
      final bridgeService = _MutableSystemBridgeService(channel, {
        'navigation': {'homeSequence': 0, 'reason': 'startup'},
      });
      final settingsService = await _createSettingsService();
      await settingsService.setHomeDockAutoCollapseEnabled(false);

      final favorites = fakeCategory(name: 'Favorites', order: 0, type: CategoryType.row);
      favorites.applications.add(fakeApp(packageName: 'row.app.1', name: 'App One'));

      when(appsService.initialized).thenReturn(true);
      when(appsService.launcherSections).thenReturn([favorites]);
      when(appsService.getAppBanner(any)).thenAnswer((_) async => kTransparentImage);
      when(appsService.getAppIcon(any)).thenAnswer((_) async => kTransparentImage);
      when(channel.addNetworkChangedListener(any)).thenReturn(null);
      when(channel.getActiveNetworkInformation()).thenAnswer((_) async => <String, dynamic>{});
      _stubWallpaperService(wallpaperService);

      await _pumpLauncher(
        tester,
        appsService: appsService,
        wallpaperService: wallpaperService,
        bridgeService: bridgeService,
        channel: channel,
        settingsService: settingsService,
      );

      expect(_primaryFocusIsDescendantOf(tester, find.byKey(const Key('row.app.1'))), isTrue);

      // Open RightPanelDialog
      late BuildContext drawerContext;
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(FLauncher)),
          builder: (ctx) {
            drawerContext = ctx;
            return const RightPanelDialog(
              child: Text('Settings Drawer Panel'),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings Drawer Panel'), findsOneWidget);

      // Dismiss dialog
      Navigator.of(drawerContext).pop();
      await tester.pumpAndSettle();

      expect(find.text('Settings Drawer Panel'), findsNothing);

      // Focus should be restored safely to dock item
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(_primaryFocusIsDescendantOf(tester, find.byKey(const Key('row.app.1'))), isTrue);
    });
  });
}

bool _primaryFocusIsDescendantOf(WidgetTester tester, Finder finder) {
  final elements = tester.elementList(finder);
  if (elements.isEmpty) {
    return false;
  }
  final targetElement = elements.first;
  final focusedContext = tester.binding.focusManager.primaryFocus?.context;
  if (focusedContext == null) {
    return false;
  }
  if (focusedContext == targetElement) {
    return true;
  }
  var found = false;
  focusedContext.visitAncestorElements((element) {
    if (element == targetElement) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required AppsService appsService,
  required WallpaperService wallpaperService,
  required SystemBridgeService bridgeService,
  required FLauncherChannel channel,
  SettingsService? settingsService,
  Map<String, dynamic> navigationStatus = const <String, dynamic>{},
}) async {
  final resolvedSettings = settingsService ?? await _createSettingsService();
  if (appsService is MockAppsService) {
    when(appsService.homeReorderModeEnabled).thenReturn(false);
  }
  if (bridgeService is MockSystemBridgeService) {
    when(bridgeService.status).thenReturn(const <String, dynamic>{
      'memory': <String, dynamic>{},
      'provisioning': <String, dynamic>{},
    });
    when(bridgeService.navigationStatus).thenReturn(navigationStatus);
    when(bridgeService.memoryStatus).thenReturn(const <String, dynamic>{});
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
        navigatorObservers: [homeRouteObserver],
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
}) {
  when(wallpaperService.wallpaperMode).thenReturn(wallpaperMode);
  when(wallpaperService.wallpaper).thenReturn(null);
  when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
  when(wallpaperService.isVideoMode).thenReturn(false);
  when(wallpaperService.videoBlockedByPerformanceMode).thenReturn(false);
  when(wallpaperService.videoTextureId).thenReturn(null);
  when(wallpaperService.videoFit).thenReturn('center-crop');
  when(wallpaperService.videoBlur).thenReturn('off');
  when(wallpaperService.videoDimPercent).thenReturn(15);
  when(wallpaperService.recoverVideoPlaybackAfterHomeFrame(
    reason: anyNamed('reason'),
  )).thenAnswer((_) async {});
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

class _MutableSystemBridgeService extends SystemBridgeService {
  _MutableSystemBridgeService(
    FLauncherChannel channel,
    Map<String, dynamic> initialStatus,
  )   : _status = Map<String, dynamic>.from(initialStatus),
        super(channel);

  Map<String, dynamic> _status;

  @override
  bool get initialized => true;

  @override
  Map<String, dynamic> get status => _status;

  @override
  Map<String, dynamic> get navigationStatus => _nestedStatus('navigation');

  @override
  Map<String, dynamic> get provisioningStatus => _nestedStatus('provisioning');

  @override
  Map<String, dynamic> get wallpaperStatus => _nestedStatus('wallpaper');

  @override
  Map<String, dynamic> get memoryStatus => _nestedStatus('memory');

  void setNavigationStatus(Map<String, dynamic> navigation) {
    _status = <String, dynamic>{
      ..._status,
      'navigation': Map<String, dynamic>.from(navigation),
    };
    notifyListeners();
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> refreshLite() async {}

  @override
  Future<void> refreshFull() async {}

  Map<String, dynamic> _nestedStatus(String key) {
    final value = _status[key];
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return const <String, dynamic>{};
  }
}
