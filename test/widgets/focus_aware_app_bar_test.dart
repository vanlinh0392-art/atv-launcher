import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/focus_aware_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.mocks.dart';

void main() {
  setUpAll(() {
    Provider.debugCheckInvalidValueType = null;
  });

  testWidgets('shows compact full RAM text without ellipsis in the status bar',
      (tester) async {
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = MockSettingsService();
    final apps = MockAppsService();
    final bridge = MockSystemBridgeService();

    when(settings.showRamInStatusBar).thenReturn(true);
    when(settings.autoHideAppBarEnabled).thenReturn(false);
    when(settings.homeDockGlassIntensityPercent).thenReturn(20);
    when(apps.homeReorderModeEnabled).thenReturn(false);
    when(bridge.status).thenReturn(<String, dynamic>{
      'memory': <String, dynamic>{
        'availBytes': 11811160064,
        'totalBytes': 137438953472,
        'lowMemory': false,
      },
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsService>.value(value: settings),
          Provider<AppsService>.value(value: apps),
          Provider<SystemBridgeService>.value(value: bridge),
        ],
        child: MediaQuery(
          data: const MediaQueryData(size: Size(960, 720)),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              appBar: FocusAwareAppBar(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('11G/128G'), findsOneWidget);
    expect(find.textContaining('...'), findsNothing);
  });

  testWidgets('shows status bar button tooltip when focused by keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = MockSettingsService();
    final apps = MockAppsService();
    final bridge = MockSystemBridgeService();

    when(settings.showRamInStatusBar).thenReturn(false);
    when(settings.autoHideAppBarEnabled).thenReturn(false);
    when(settings.homeDockGlassIntensityPercent).thenReturn(20);
    when(settings.showDateInStatusBar).thenReturn(false);
    when(settings.showTimeInStatusBar).thenReturn(false);
    when(settings.dateFormat).thenReturn('dd/MM');
    when(settings.timeFormat).thenReturn('HH:mm');
    when(settings.statusBarClockScalePercent).thenReturn(100);
    when(apps.homeReorderModeEnabled).thenReturn(false);
    when(bridge.status).thenReturn(const <String, dynamic>{});
    when(bridge.provisioningStatus).thenReturn(const <String, dynamic>{
      'health': 'healthy',
      'missingRequiredCount': 0,
      'missingRecommendedCount': 0,
      'requirements': <Map<String, dynamic>>[],
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsService>.value(value: settings),
          Provider<AppsService>.value(value: apps),
          Provider<SystemBridgeService>.value(value: bridge),
        ],
        child: MediaQuery(
          data: const MediaQueryData(size: Size(960, 720)),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              appBar: FocusAwareAppBar(),
              body: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(Scaffold));
    final localizations = AppLocalizations.of(context)!;

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(localizations.searchHint), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(localizations.searchHint), findsNothing);
    expect(find.text(localizations.reorder), findsOneWidget);
  });

  testWidgets('tapping the network badge opens Wi-Fi settings',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = MockSettingsService();
    final apps = MockAppsService();
    final bridge = MockSystemBridgeService();
    final channel = MockFLauncherChannel();

    when(settings.showRamInStatusBar).thenReturn(false);
    when(settings.autoHideAppBarEnabled).thenReturn(false);
    when(settings.homeDockGlassIntensityPercent).thenReturn(20);
    when(settings.showDateInStatusBar).thenReturn(false);
    when(settings.showTimeInStatusBar).thenReturn(false);
    when(settings.dateFormat).thenReturn('dd/MM');
    when(settings.timeFormat).thenReturn('HH:mm');
    when(settings.statusBarClockScalePercent).thenReturn(100);
    when(apps.homeReorderModeEnabled).thenReturn(false);
    when(bridge.status).thenReturn(const <String, dynamic>{});
    when(bridge.provisioningStatus).thenReturn(const <String, dynamic>{
      'health': 'healthy',
      'missingRequiredCount': 0,
      'missingRecommendedCount': 0,
      'requirements': <Map<String, dynamic>>[],
    });
    when(bridge.openSpecificSettingsPage('wifi'))
        .thenAnswer((_) async => true);
    when(channel.addNetworkChangedListener(any)).thenAnswer((_) {});
    when(channel.getActiveNetworkInformation()).thenAnswer(
      (_) async => <String, dynamic>{
        'networkType': 1,
        'internetAccess': true,
        'wirelessSignalLevel': 4,
      },
    );

    final networkService = NetworkService(channel);
    addTearDown(networkService.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsService>.value(value: settings),
          Provider<AppsService>.value(value: apps),
          Provider<SystemBridgeService>.value(value: bridge),
          ChangeNotifierProvider<NetworkService>.value(value: networkService),
        ],
        child: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 720)),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              appBar: FocusAwareAppBar(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.signal_wifi_4_bar));
    await tester.pumpAndSettle();

    verify(bridge.openSpecificSettingsPage('wifi')).called(1);
  });
}
