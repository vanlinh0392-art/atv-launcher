import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/profiles_security_panel_page.dart';
import 'package:flutter/material.dart';
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

  testWidgets('renders app security page in the detail pane without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final sharedPreferences = await SharedPreferences.getInstance();
    final security = ProfileSecurityService(sharedPreferences);
    final appsService = MockAppsService();
    when(appsService.applications).thenReturn(<App>[
      App(
        packageName: 'com.example.video',
        name: 'Video',
        version: '1.0',
        hidden: false,
      ),
      App(
        packageName: 'com.example.hidden',
        name: 'Hidden',
        version: '1.0',
        hidden: true,
      ),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfileSecurityService>.value(value: security),
          ChangeNotifierProvider<AppsService>.value(value: appsService),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Material(
            child: Center(
              child: SizedBox(
                width: 860,
                height: 560,
                child: ProfilesSecurityPanelPage(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('App Security'), findsOneWidget);
    expect(find.text('Manage hidden apps'), findsOneWidget);
    expect(find.text('Manage locked apps'), findsOneWidget);
    expect(find.text('Set owner PIN'), findsOneWidget);
    expect(find.text('Clear owner PIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app manager dialog does not autofocus filter input',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final sharedPreferences = await SharedPreferences.getInstance();
    final security = ProfileSecurityService(sharedPreferences);
    final appsService = MockAppsService();
    when(appsService.applications).thenReturn(<App>[
      App(
        packageName: 'com.example.video',
        name: 'Video',
        version: '1.0',
        hidden: false,
      ),
      App(
        packageName: 'com.example.hidden',
        name: 'Hidden',
        version: '1.0',
        hidden: true,
      ),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfileSecurityService>.value(value: security),
          ChangeNotifierProvider<AppsService>.value(value: appsService),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Material(
            child: Scaffold(
              body: ProfilesSecurityPanelPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manage hidden apps'));
    await tester.pumpAndSettle();

    final dialogFinder = find.byType(Dialog);
    final filterField = tester.widget<TextField>(
      find.descendant(of: dialogFinder, matching: find.byType(TextField)),
    );
    final dialogTiles = tester
        .widgetList<RoundedSwitchListTile>(
          find.descendant(
            of: dialogFinder,
            matching: find.byType(RoundedSwitchListTile),
          ),
        )
        .toList(growable: false);

    expect(filterField.autofocus, isFalse);
    expect(dialogTiles, isNotEmpty);
    expect(dialogTiles.first.autofocus, isTrue);
  });
}
