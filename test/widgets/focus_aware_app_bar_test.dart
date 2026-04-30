import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/focus_aware_app_bar.dart';
import 'package:flutter/material.dart';
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
        'availBytes': 1181116006,
        'totalBytes': 3758096384,
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

    expect(find.text('1.1G/3.5G'), findsOneWidget);
    expect(find.textContaining('...'), findsNothing);
  });
}
