import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/providers/search_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/right_panel_dialog.dart';
import 'package:flauncher/widgets/settings/home_layout_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flauncher/widgets/settings/settings_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks.mocks.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('SettingsPanel renders 520dp Side Sheet drawer when useSideSheetSettings is true',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setUseSideSheetSettings(true);
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    when(wallpaperService.setSettingsPlaybackSuppressed(any))
        .thenAnswer((_) async {});
    final bridgeService = MockSystemBridgeService();
    final securityService =
        ProfileSecurityService(await SharedPreferences.getInstance());
    final searchService = SearchService(
      await SharedPreferences.getInstance(),
      MockFLauncherChannel(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<AppsService>.value(value: appsService),
          ChangeNotifierProvider<WallpaperService>.value(value: wallpaperService),
          ChangeNotifierProvider<SystemBridgeService>.value(value: bridgeService),
          ChangeNotifierProvider<ProfileSecurityService>.value(
            value: securityService,
          ),
          ChangeNotifierProvider<SearchService>.value(value: searchService),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPanel(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dialogFinder = find.byType(RightPanelDialog);
    expect(dialogFinder, findsOneWidget);
    final dialog = tester.widget<RightPanelDialog>(dialogFinder);
    expect(dialog.width, TvDrawerTokens.drawerWidth);
    expect(dialog.width, 520.0);

    expect(find.byType(SettingsPanelPage), findsOneWidget);
    expect(find.text('ATV Launcher Settings'), findsOneWidget);
  });

  testWidgets('SettingsPanel drills down into sub-panel and navigates back',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setUseSideSheetSettings(true);
    final appsService = MockAppsService();
    when(appsService.applications).thenReturn(const []);
    final wallpaperService = MockWallpaperService();
    when(wallpaperService.wallpaperMode).thenReturn('gradient');
    when(wallpaperService.setSettingsPlaybackSuppressed(any))
        .thenAnswer((_) async {});
    final bridgeService = MockSystemBridgeService();
    final securityService =
        ProfileSecurityService(await SharedPreferences.getInstance());
    final searchService = SearchService(
      await SharedPreferences.getInstance(),
      MockFLauncherChannel(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<AppsService>.value(value: appsService),
          ChangeNotifierProvider<WallpaperService>.value(value: wallpaperService),
          ChangeNotifierProvider<SystemBridgeService>.value(value: bridgeService),
          ChangeNotifierProvider<ProfileSecurityService>.value(
            value: securityService,
          ),
          ChangeNotifierProvider<SearchService>.value(value: searchService),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPanel(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home & Layout').first);
    await tester.pumpAndSettle();

    expect(find.byType(HomeLayoutPanelPage), findsOneWidget);
    final backButtonFinder = find.byIcon(Icons.arrow_back);
    expect(backButtonFinder, findsOneWidget);

    await tester.tap(backButtonFinder);
    await tester.pumpAndSettle();

    expect(find.byType(HomeLayoutPanelPage), findsNothing);
    expect(find.byType(SettingsPanelPage), findsOneWidget);
  });

  testWidgets('SettingsPanel renders 1360 width when useSideSheetSettings is false',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setUseSideSheetSettings(false);
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    when(wallpaperService.setSettingsPlaybackSuppressed(any))
        .thenAnswer((_) async {});
    final bridgeService = MockSystemBridgeService();
    final securityService =
        ProfileSecurityService(await SharedPreferences.getInstance());
    final searchService = SearchService(
      await SharedPreferences.getInstance(),
      MockFLauncherChannel(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<AppsService>.value(value: appsService),
          ChangeNotifierProvider<WallpaperService>.value(value: wallpaperService),
          ChangeNotifierProvider<SystemBridgeService>.value(value: bridgeService),
          ChangeNotifierProvider<ProfileSecurityService>.value(
            value: securityService,
          ),
          ChangeNotifierProvider<SearchService>.value(value: searchService),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPanel(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dialogFinder = find.byType(RightPanelDialog);
    expect(dialogFinder, findsOneWidget);
    final dialog = tester.widget<RightPanelDialog>(dialogFinder);
    expect(dialog.width, 1360.0);
  });

  testWidgets('RightPanelDialog renders default backdrop theme gradient colors',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setUseSideSheetSettings(true);

    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    when(wallpaperService.setSettingsPlaybackSuppressed(any))
        .thenAnswer((_) async {});
    final bridgeService = MockSystemBridgeService();
    final securityService =
        ProfileSecurityService(await SharedPreferences.getInstance());
    final searchService = SearchService(
      await SharedPreferences.getInstance(),
      MockFLauncherChannel(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<AppsService>.value(value: appsService),
          ChangeNotifierProvider<WallpaperService>.value(value: wallpaperService),
          ChangeNotifierProvider<SystemBridgeService>.value(value: bridgeService),
          ChangeNotifierProvider<ProfileSecurityService>.value(
            value: securityService,
          ),
          ChangeNotifierProvider<SearchService>.value(value: searchService),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPanel(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final decoratedBoxFinder = find.descendant(
      of: find.byType(RightPanelDialog),
      matching: find.byType(DecoratedBox),
    );
    expect(decoratedBoxFinder, findsAtLeastNWidgets(1));

    final decoratedBox = tester.widget<DecoratedBox>(decoratedBoxFinder.first);
    final decoration = decoratedBox.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;

    final defaultSpec = SettingsChromeSpec.fromTransparencyPercent(
      settings.settingsUiTransparencyPercent,
      backdropTheme: TvSettingsBackdropTheme.deepSlate,
    );
    expect(gradient.colors, defaultSpec.dialogGradientColors);
  });

  testWidgets('RightPanelDialog updates gradient colors immediately on theme change without remount',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setUseSideSheetSettings(true);

    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    when(wallpaperService.setSettingsPlaybackSuppressed(any))
        .thenAnswer((_) async {});
    final bridgeService = MockSystemBridgeService();
    final securityService =
        ProfileSecurityService(await SharedPreferences.getInstance());
    final searchService = SearchService(
      await SharedPreferences.getInstance(),
      MockFLauncherChannel(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<AppsService>.value(value: appsService),
          ChangeNotifierProvider<WallpaperService>.value(value: wallpaperService),
          ChangeNotifierProvider<SystemBridgeService>.value(value: bridgeService),
          ChangeNotifierProvider<ProfileSecurityService>.value(
            value: securityService,
          ),
          ChangeNotifierProvider<SearchService>.value(value: searchService),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPanel(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await settings.setSettingsBackdropTheme(TvSettingsBackdropTheme.oceanNavy);
    await tester.pumpAndSettle();

    var decoratedBoxFinder = find.descendant(
      of: find.byType(RightPanelDialog),
      matching: find.byType(DecoratedBox),
    );
    var decoratedBox = tester.widget<DecoratedBox>(decoratedBoxFinder.first);
    var decoration = decoratedBox.decoration as BoxDecoration;
    var gradient = decoration.gradient as LinearGradient;

    var oceanSpec = SettingsChromeSpec.fromTransparencyPercent(
      settings.settingsUiTransparencyPercent,
      backdropTheme: TvSettingsBackdropTheme.oceanNavy,
    );
    expect(gradient.colors, oceanSpec.dialogGradientColors);

    await settings.setSettingsBackdropTheme(TvSettingsBackdropTheme.smokyAmethyst);
    await tester.pumpAndSettle();

    decoratedBox = tester.widget<DecoratedBox>(decoratedBoxFinder.first);
    decoration = decoratedBox.decoration as BoxDecoration;
    gradient = decoration.gradient as LinearGradient;

    var smokySpec = SettingsChromeSpec.fromTransparencyPercent(
      settings.settingsUiTransparencyPercent,
      backdropTheme: TvSettingsBackdropTheme.smokyAmethyst,
    );
    expect(gradient.colors, smokySpec.dialogGradientColors);
  });

  testWidgets('RightPanelDialog applies dialogGradientOpacity correctly to new palette colors',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setUseSideSheetSettings(true);
    await settings.setSettingsBackdropTheme(TvSettingsBackdropTheme.warmEspresso);
    await settings.setSettingsUiTransparencyPercent(50);

    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    when(wallpaperService.setSettingsPlaybackSuppressed(any))
        .thenAnswer((_) async {});
    final bridgeService = MockSystemBridgeService();
    final securityService =
        ProfileSecurityService(await SharedPreferences.getInstance());
    final searchService = SearchService(
      await SharedPreferences.getInstance(),
      MockFLauncherChannel(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<AppsService>.value(value: appsService),
          ChangeNotifierProvider<WallpaperService>.value(value: wallpaperService),
          ChangeNotifierProvider<SystemBridgeService>.value(value: bridgeService),
          ChangeNotifierProvider<ProfileSecurityService>.value(
            value: securityService,
          ),
          ChangeNotifierProvider<SearchService>.value(value: searchService),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPanel(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final decoratedBoxFinder = find.descendant(
      of: find.byType(RightPanelDialog),
      matching: find.byType(DecoratedBox),
    );
    final decoratedBox = tester.widget<DecoratedBox>(decoratedBoxFinder.first);
    final decoration = decoratedBox.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;

    final spec = SettingsChromeSpec.fromTransparencyPercent(
      50,
      backdropTheme: TvSettingsBackdropTheme.warmEspresso,
    );
    expect(gradient.colors, spec.dialogGradientColors);
    expect(gradient.colors.first.opacity, closeTo(spec.dialogGradientOpacity, 0.001));
  });
}
