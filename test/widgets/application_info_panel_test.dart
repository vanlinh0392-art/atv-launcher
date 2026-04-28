import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/widgets/application_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('Open triggers launchApp', (tester) async {
    _prepareView(tester);
    final appsService = MockAppsService();
    final app = fakeApp();
    await _pumpPanel(tester, appsService, app, null);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    verify(appsService.launchApp(app)).called(1);
  });

  testWidgets('Hide triggers hideApplication for visible app', (tester) async {
    _prepareView(tester);
    final appsService = MockAppsService();
    final app = fakeApp(hidden: false);
    await _pumpPanel(tester, appsService, app, fakeCategory(name: 'Favorites'));

    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();

    verify(appsService.hideApplication(app)).called(1);
  });

  testWidgets('Show triggers showApplication for hidden app', (tester) async {
    _prepareView(tester);
    final appsService = MockAppsService();
    final app = fakeApp(hidden: true);
    await _pumpPanel(tester, appsService, app, fakeCategory(name: 'Favorites'));

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    verify(appsService.showApplication(app)).called(1);
  });

  testWidgets('Remove from category is available when category exists',
      (tester) async {
    _prepareView(tester);
    final appsService = MockAppsService();
    final app = fakeApp();
    final category = fakeCategory(name: 'Favorites');
    await _pumpPanel(tester, appsService, app, category);

    expect(find.textContaining('Remove from'), findsOneWidget);

    await tester.tap(find.textContaining('Remove from'));
    await tester.pumpAndSettle();

    verify(appsService.removeFromCategory(app, category)).called(1);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester,
  AppsService appsService,
  dynamic app,
  dynamic category,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppsService>.value(value: appsService),
        Provider<ProfileSecurityService?>.value(value: null),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Material(
          child: ApplicationInfoPanel(
            category: category,
            application: app,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _prepareView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
