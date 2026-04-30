import 'package:flauncher/app_image_cache_invalidator.dart';
import 'package:flauncher/app_card_highlight_palette.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transparent_image/transparent_image.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  test('resolves configured app card highlight preset colors', () {
    expect(
      resolveAppCardHighlightPresetColor(
        SettingsService.appCardHighlightColorDefault,
      ),
      const Color(0xFF8ACBFF),
    );
    expect(
      resolveAppCardHighlightPresetColor(
        SettingsService.appCardHighlightColorMint,
      ),
      const Color(0xFF7BE0A5),
    );
  });

  testWidgets('reloads the image on the first cache invalidation event',
      (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    final application = fakeApp(
      packageName: 'cache.test.first.invalidation',
      name: 'Cache Test',
    );
    final category = fakeCategory()..applications.add(application);

    when(appsService.getAppBanner(application.packageName))
        .thenAnswer((_) async => Uint8List.fromList(kTransparentImage));
    when(appsService.addListener(any)).thenReturn(null);
    when(appsService.removeListener(any)).thenReturn(null);

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
            body: SizedBox(
              width: 320,
              child: AppCard(
                application: application,
                category: category,
                autofocus: true,
                onMove: (_, __) => false,
                onMoveEnd: (_, __) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    AppImageCacheInvalidator.instance.invalidate(application.packageName);
    await tester.pump();
    await tester.pumpAndSettle();

    verify(appsService.getAppBanner(application.packageName)).called(2);
  });

  testWidgets(
      'long press opens app management menu when home reorder mode is disabled',
      (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    final application = fakeApp(
      packageName: 'move.mode.commit',
      name: 'Move Mode',
    );
    final category = fakeCategory()..applications.add(application);
    when(appsService.getAppBanner(application.packageName))
        .thenAnswer((_) async => Uint8List.fromList(kTransparentImage));
    when(appsService.addListener(any)).thenReturn(null);
    when(appsService.removeListener(any)).thenReturn(null);
    when(appsService.launchApp(any)).thenAnswer((_) async {});

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
            body: SizedBox(
              width: 320,
              child: AppCard(
                application: application,
                category: category,
                autofocus: true,
                onMoveStart: (_) => true,
                onMove: (_, __) => true,
                onMoveEnd: (_, __) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(InkWell).first);
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outlined), findsOneWidget);
    verifyNever(appsService.launchApp(any));
  });

  testWidgets(
      'remote long press opens app management menu without launching app',
      (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    final application = fakeApp(
      packageName: 'move.mode.remote.longpress.menu',
      name: 'Remote Long Press Menu',
    );
    final category = fakeCategory()..applications.add(application);
    when(appsService.getAppBanner(application.packageName))
        .thenAnswer((_) async => Uint8List.fromList(kTransparentImage));
    when(appsService.addListener(any)).thenReturn(null);
    when(appsService.removeListener(any)).thenReturn(null);
    when(appsService.launchApp(any)).thenAnswer((_) async {});

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
            body: SizedBox(
              width: 320,
              child: AppCard(
                application: application,
                category: category,
                autofocus: true,
                onMoveStart: (_) => true,
                onMove: (_, __) => true,
                onMoveEnd: (_, __) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outlined), findsOneWidget);
    verifyNever(appsService.launchApp(any));
  });

  testWidgets('escape cancels move mode session', (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    final application = fakeApp(
      packageName: 'move.mode.cancel',
      name: 'Cancel Move',
    );
    final category = fakeCategory()..applications.add(application);
    bool? moveEndedCommitted;

    when(appsService.homeReorderModeEnabled).thenReturn(true);
    when(appsService.getAppBanner(application.packageName))
        .thenAnswer((_) async => Uint8List.fromList(kTransparentImage));
    when(appsService.addListener(any)).thenReturn(null);
    when(appsService.removeListener(any)).thenReturn(null);

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
            body: SizedBox(
              width: 320,
              child: AppCard(
                application: application,
                category: category,
                autofocus: true,
                onMoveStart: (_) => true,
                onMove: (_, __) => true,
                onMoveEnd: (_, committed) async {
                  moveEndedCommitted = committed;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(InkWell).first);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byIcon(Icons.keyboard_arrow_left), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 150));

    expect(moveEndedCommitted, isFalse);
    expect(find.byIcon(Icons.keyboard_arrow_left), findsNothing);
  });

  testWidgets(
      'enter starts move mode instead of launching app when home reorder mode is enabled',
      (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    final application = fakeApp(
      packageName: 'move.mode.armed',
      name: 'Armed Move',
    );
    final category = fakeCategory()..applications.add(application);
    var moveStarted = false;

    when(appsService.homeReorderModeEnabled).thenReturn(true);
    when(appsService.getAppBanner(application.packageName))
        .thenAnswer((_) async => Uint8List.fromList(kTransparentImage));
    when(appsService.addListener(any)).thenReturn(null);
    when(appsService.removeListener(any)).thenReturn(null);
    when(appsService.launchApp(any)).thenAnswer((_) async {});

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
            body: SizedBox(
              width: 320,
              child: AppCard(
                application: application,
                category: category,
                autofocus: true,
                onMoveStart: (_) {
                  moveStarted = true;
                  return true;
                },
                onMove: (_, __) => true,
                onMoveEnd: (_, __) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 150));

    expect(moveStarted, isTrue);
    expect(find.byIcon(Icons.keyboard_arrow_left), findsOneWidget);
    verifyNever(appsService.launchApp(any));
  });

  testWidgets('long press enters move mode when home reorder mode is enabled',
      (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    final application = fakeApp(
      packageName: 'move.mode.longpress.armed',
      name: 'Armed Long Press',
    );
    final category = fakeCategory()..applications.add(application);
    var moveStarted = false;

    when(appsService.homeReorderModeEnabled).thenReturn(true);
    when(appsService.getAppBanner(application.packageName))
        .thenAnswer((_) async => Uint8List.fromList(kTransparentImage));
    when(appsService.addListener(any)).thenReturn(null);
    when(appsService.removeListener(any)).thenReturn(null);

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
            body: SizedBox(
              width: 320,
              child: AppCard(
                application: application,
                category: category,
                autofocus: true,
                onMoveStart: (_) {
                  moveStarted = true;
                  return true;
                },
                onMove: (_, __) => true,
                onMoveEnd: (_, __) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(InkWell).first);
    await tester.pump(const Duration(milliseconds: 150));

    expect(moveStarted, isTrue);
    expect(find.byIcon(Icons.keyboard_arrow_left), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsNothing);
  });

  testWidgets(
      'remote long press enters move mode and key release does not auto confirm',
      (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    final application = fakeApp(
      packageName: 'move.mode.remote.longpress.armed',
      name: 'Remote Armed Long Press',
    );
    final category = fakeCategory()..applications.add(application);
    var moveStarted = false;
    bool? moveEndedCommitted;

    when(appsService.homeReorderModeEnabled).thenReturn(true);
    when(appsService.getAppBanner(application.packageName))
        .thenAnswer((_) async => Uint8List.fromList(kTransparentImage));
    when(appsService.addListener(any)).thenReturn(null);
    when(appsService.removeListener(any)).thenReturn(null);
    when(appsService.launchApp(any)).thenAnswer((_) async {});

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
            body: SizedBox(
              width: 320,
              child: AppCard(
                application: application,
                category: category,
                autofocus: true,
                onMoveStart: (_) {
                  moveStarted = true;
                  return true;
                },
                onMove: (_, __) => true,
                onMoveEnd: (_, committed) async {
                  moveEndedCommitted = committed;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 180));

    expect(moveStarted, isTrue);
    expect(find.byIcon(Icons.keyboard_arrow_left), findsOneWidget);
    expect(moveEndedCommitted, isNull);
    verifyNever(appsService.launchApp(any));
  });

  testWidgets(
      'move mode stays active across repeated directional key events until confirm',
      (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    final application = fakeApp(
      packageName: 'move.mode.repeat.direction',
      name: 'Repeat Direction',
    );
    final category = fakeCategory()..applications.add(application);
    final moves = <AxisDirection>[];
    bool? moveEndedCommitted;

    when(appsService.homeReorderModeEnabled).thenReturn(true);
    when(appsService.getAppBanner(application.packageName))
        .thenAnswer((_) async => Uint8List.fromList(kTransparentImage));
    when(appsService.addListener(any)).thenReturn(null);
    when(appsService.removeListener(any)).thenReturn(null);

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
            body: SizedBox(
              width: 320,
              child: AppCard(
                application: application,
                category: category,
                autofocus: true,
                onMoveStart: (_) => true,
                onMove: (_, direction) {
                  moves.add(direction);
                  return true;
                },
                onMoveEnd: (_, committed) async {
                  moveEndedCommitted = committed;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 120));

    expect(moves, [
      AxisDirection.right,
      AxisDirection.right,
      AxisDirection.right,
    ]);
    expect(moveEndedCommitted, isNull);
    expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 180));

    expect(moveEndedCommitted, isTrue);
    expect(find.byIcon(Icons.keyboard_arrow_right), findsNothing);
  });
}

Future<SettingsService> _createSettingsService() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return SettingsService(await SharedPreferences.getInstance());
}
