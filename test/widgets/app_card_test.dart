import 'package:flauncher/app_image_cache_invalidator.dart';
import 'package:flauncher/app_card_highlight_palette.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flauncher/widgets/category_row.dart';
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
    _stubAppsServiceDefaults(appsService);
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
      'evicted resolved app images are fetched again after cache pressure',
      (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    _stubAppsServiceDefaults(appsService);
    final applications = List.generate(
      30,
      (index) => fakeApp(
        packageName: 'cache.trim.$index',
        name: 'Cache Trim $index',
      ),
    );
    final category = fakeCategory()..applications.addAll(applications);

    when(appsService.getAppBanner(any))
        .thenAnswer((_) async => Uint8List.fromList(kTransparentImage));
    when(appsService.addListener(any)).thenReturn(null);
    when(appsService.removeListener(any)).thenReturn(null);

    Future<void> pumpCardForApp(App application) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProfileSecurityService?>.value(value: null),
            ListenableProvider<AppsService>.value(value: appsService),
            ChangeNotifierProvider<SettingsService>.value(
              value: settingsService,
            ),
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
    }

    for (final application in applications) {
      await pumpCardForApp(application);
    }

    await pumpCardForApp(applications.first);

    verify(appsService.getAppBanner(applications.first.packageName)).called(2);
  });

  testWidgets('app images request decode size for displayed card bounds',
      (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    _stubAppsServiceDefaults(appsService);
    final application = fakeApp(
      packageName: 'decode.size.banner',
      name: 'Decode Size Banner',
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
            body: Center(
              child: SizedBox(
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
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image).first);
    expect(image.image, isA<ResizeImage>());
    final resizedProvider = image.image as ResizeImage;
    expect(resizedProvider.width, isNotNull);
    expect(resizedProvider.height, isNotNull);
    expect(resizedProvider.width, greaterThan(0));
    expect(resizedProvider.height, greaterThan(0));
  });

  testWidgets(
      'non-autofocus cards defer image loading until shared delay elapses',
      (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    _stubAppsServiceDefaults(appsService);
    final applications = [
      fakeApp(
        packageName: 'deferred.load.first',
        name: 'Deferred First',
      ),
      fakeApp(
        packageName: 'deferred.load.second',
        name: 'Deferred Second',
      ),
    ];
    final category = fakeCategory()..applications.addAll(applications);

    when(appsService.getAppBanner(any))
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
            body: Row(
              children: applications
                  .map(
                    (application) => Expanded(
                      child: AppCard(
                        application: application,
                        category: category,
                        autofocus: false,
                        onMove: (_, __) => false,
                        onMoveEnd: (_, __) async {},
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );

    verifyNever(appsService.getAppBanner(any));

    await tester.pump(const Duration(milliseconds: 899));
    verifyNever(appsService.getAppBanner(any));

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    verify(appsService.getAppBanner('deferred.load.first')).called(1);
    verify(appsService.getAppBanner('deferred.load.second')).called(1);
  });

  testWidgets('home recovery warmup loads built non-eager cards immediately',
      (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    _stubAppsServiceDefaults(appsService);
    final application = fakeApp(
      packageName: 'wake.non.eager.retry',
      name: 'Wake Non Eager Retry',
    );
    final category = fakeCategory()..applications.add(application);

    when(appsService.getAppBanner(application.packageName))
        .thenAnswer((_) async => Uint8List.fromList(kTransparentImage));
    when(appsService.addListener(any)).thenReturn(null);
    when(appsService.removeListener(any)).thenReturn(null);

    Future<void> pumpCard(int imageWarmupSequence) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProfileSecurityService?>.value(value: null),
            ListenableProvider<AppsService>.value(value: appsService),
            ChangeNotifierProvider<SettingsService>.value(
              value: settingsService,
            ),
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
                  autofocus: false,
                  eagerImageLoad: false,
                  imageWarmupSequence: imageWarmupSequence,
                  onMove: (_, __) => false,
                  onMoveEnd: (_, __) async {},
                ),
              ),
            ),
          ),
        ),
      );
    }

    await pumpCard(0);
    await tester.pump(const Duration(milliseconds: 100));

    verifyNever(appsService.getAppBanner(application.packageName));

    await pumpCard(9);
    await tester.pump();
    await tester.pumpAndSettle();

    verify(appsService.getAppBanner(application.packageName)).called(1);
  });

  testWidgets('disposing a deferred app card cancels its pending image load',
      (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    _stubAppsServiceDefaults(appsService);
    final application = fakeApp(
      packageName: 'deferred.dispose.cancel',
      name: 'Deferred Dispose',
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
                autofocus: false,
                onMove: (_, __) => false,
                onMoveEnd: (_, __) async {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1000));

    verifyNever(appsService.getAppBanner(application.packageName));
  });

  testWidgets(
      'long press opens app management menu when home reorder mode is disabled',
      (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    _stubAppsServiceDefaults(appsService);
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
    _stubAppsServiceDefaults(appsService);
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
    _stubAppsServiceDefaults(appsService);
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
    _stubAppsServiceDefaults(appsService);
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
    _stubAppsServiceDefaults(appsService);
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
    _stubAppsServiceDefaults(appsService);
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
    _stubAppsServiceDefaults(appsService);
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

  testWidgets('category row navigates within the row by index before fallback',
      (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    _stubAppsServiceDefaults(appsService);
    final applications = [
      fakeApp(packageName: 'dpad.index.first', name: 'Dpad First'),
      fakeApp(packageName: 'dpad.index.second', name: 'Dpad Second'),
    ];
    final category = fakeCategory(columnsCount: 2, type: CategoryType.row)
      ..applications.addAll(applications);

    when(appsService.getAppBanner(any))
        .thenAnswer((_) async => Uint8List.fromList(kTransparentImage));

    await _pumpCategoryRowHarness(
      tester,
      settingsService: settingsService,
      appsService: appsService,
      category: category,
      autofocusFirstItem: true,
    );
    await tester.pumpAndSettle();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('dpad.index.first'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('dpad.index.second'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('dpad.index.first'),
    );
  });

  testWidgets('category row prefetches neighbor images around focused card',
      (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    _stubAppsServiceDefaults(appsService);
    final applications = [
      fakeApp(packageName: 'focus.prefetch.first', name: 'Prefetch First'),
      fakeApp(packageName: 'focus.prefetch.second', name: 'Prefetch Second'),
      fakeApp(packageName: 'focus.prefetch.third', name: 'Prefetch Third'),
    ];
    final category = fakeCategory(columnsCount: 2, type: CategoryType.row)
      ..applications.addAll(applications);

    when(appsService.getAppBanner(any))
        .thenAnswer((_) async => Uint8List.fromList(kTransparentImage));

    await _pumpCategoryRowHarness(
      tester,
      settingsService: settingsService,
      appsService: appsService,
      category: category,
      autofocusFirstItem: true,
    );
    await tester.pumpAndSettle();

    verify(appsService.getAppBanner('focus.prefetch.first')).called(1);
    verify(appsService.getAppBanner('focus.prefetch.second')).called(1);
    verify(appsService.getAppBanner('focus.prefetch.third')).called(1);
  });
}

Future<SettingsService> _createSettingsService() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return SettingsService(await SharedPreferences.getInstance());
}

void _stubAppsServiceDefaults(MockAppsService appsService) {
  when(appsService.homeReorderModeEnabled).thenReturn(false);
}

Future<void> _pumpCategoryRowHarness(
  WidgetTester tester, {
  required SettingsService settingsService,
  required MockAppsService appsService,
  required Category category,
  required bool autofocusFirstItem,
}) async {
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
            width: 480,
            child: CategoryRow(
              category: category,
              applications: category.applications,
              autofocusFirstItem: autofocusFirstItem,
            ),
          ),
        ),
      ),
    ),
  );
}
