import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/home_layout_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks.mocks.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets(
      'shows language selector, dock performance, row spacing, card size and icon size controls',
      (tester) async {
    final settings = await _createSettingsService();
    final appsService = MockAppsService();

    await _pumpPage(
      tester,
      settings: settings,
      appsService: appsService,
    );

    expect(find.text('App language'), findsAtLeastNWidgets(1));
    await _scrollToLocaleControl(tester);

    expect(find.text('Card size'), findsAtLeastNWidgets(1));
    expect(find.text('Icon size'), findsAtLeastNWidgets(1));
    expect(find.text('Dock glass intensity'), findsAtLeastNWidgets(1));
    expect(find.text('Home performance mode'), findsAtLeastNWidgets(1));
    expect(find.text('Settings transparency'), findsAtLeastNWidgets(1));
    expect(find.text('Collapsed dock rows'), findsAtLeastNWidgets(1));
    expect(find.text('Row spacing'), findsAtLeastNWidgets(1));
    expect(find.text('Auto collapse dock'), findsAtLeastNWidgets(1));
    expect(find.text('Auto collapse delay'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('app_locale_mode_selector')), findsOneWidget);
    expect(
      find.byKey(const Key('home_dock_collapsed_rows_selector')),
      findsOneWidget,
    );
    expect(
        find.byKey(const Key('app_card_layout_scale_stepper')), findsOneWidget);
    expect(
        find.byKey(const Key('app_card_media_scale_stepper')), findsOneWidget);
    expect(find.byKey(const Key('home_dock_auto_collapse_delay_selector')),
        findsOneWidget);
    expect(find.byKey(const Key('home_dock_glass_intensity_selector')),
        findsOneWidget);
    expect(find.byKey(const Key('home_dock_performance_mode_selector')),
        findsOneWidget);
    expect(find.byKey(const Key('settings_ui_transparency_stepper')),
        findsOneWidget);
    expect(
        find.byKey(const Key('home_dock_row_spacing_stepper')), findsOneWidget);
    await _scrollToFinder(
      tester,
      find.byKey(
        const ValueKey<String>('home_layout_quick_tile_app_locale'),
      ),
    );
    expect(
      find.byKey(
        const ValueKey<String>('home_layout_quick_tile_app_locale'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('home_layout_quick_tile_card_size'),
      ),
      findsOneWidget,
    );

    final quickTileFrame = tester.widget<SettingsFocusFrame>(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('home_layout_quick_tile_app_locale'),
        ),
        matching: find.byType(SettingsFocusFrame),
      ),
    );
    expect(quickTileFrame.variant, SettingsFocusFrameVariant.rowOnly);
  });

  testWidgets('updates locale mode and icon scale from controls',
      (tester) async {
    final settings = await _createSettingsService();
    final appsService = MockAppsService();

    await _pumpPage(
      tester,
      settings: settings,
      appsService: appsService,
    );
    await _scrollToLocaleControl(tester);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('app_locale_mode_selector')),
        matching: find.text('English'),
      ),
    );
    await tester.pumpAndSettle();

    expect(settings.appLocaleMode, SettingsService.appLocaleEnglish);

    await _scrollToFinder(
      tester,
      find.byKey(
        const ValueKey<String>('home_layout_quick_tile_collapsed_rows'),
      ),
    );
    await tester.tap(find.byKey(
      const ValueKey<String>('home_layout_quick_tile_collapsed_rows'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('home_dock_collapsed_rows_option_2'),
      ),
    );
    await tester.pumpAndSettle();

    expect(settings.homeDockCollapsedRowsPreset, 2);

    await _scrollToFinder(
      tester,
      find.byKey(
        const ValueKey<String>('home_layout_quick_tile_corner_radius'),
      ),
    );
    await tester.tap(find.byKey(
      const ValueKey<String>('home_layout_quick_tile_corner_radius'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>(
      'icon_corner_radius_increase',
    )));
    await tester.pumpAndSettle();

    expect(
      settings.appCardCornerRadius,
      SettingsService.appCardCornerRadiusDefault + 1,
    );

    await _scrollToFinder(
      tester,
      find.byKey(
        const ValueKey<String>('home_layout_quick_tile_card_size'),
      ),
    );
    final initialCardSize = settings.appCardLayoutScalePercent;
    await tester.tap(find.byKey(
      const ValueKey<String>('home_layout_quick_tile_card_size'),
    ));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      settings.appCardLayoutScalePercent,
      (initialCardSize + 10).clamp(70, 115),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(settings.appCardMediaScalePercent, 115);
    expect(find.text('115%'), findsAtLeastNWidgets(1));

    await _scrollToFinder(
      tester,
      find.byKey(
        const ValueKey<String>('home_layout_quick_tile_collapse_delay'),
      ),
    );
    await tester.tap(find.byKey(
      const ValueKey<String>('home_layout_quick_tile_collapse_delay'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>(
      'home_dock_auto_collapse_delay_option_30',
    )));
    await tester.pumpAndSettle();

    expect(settings.homeDockAutoCollapseDelaySeconds, 30);

    await _scrollToFinder(
      tester,
      find.byKey(
        const ValueKey<String>('home_layout_quick_tile_glass_intensity'),
      ),
    );
    await tester.tap(find.byKey(
      const ValueKey<String>('home_layout_quick_tile_glass_intensity'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>(
      'home_dock_glass_intensity_option_40',
    )));
    await tester.pumpAndSettle();

    expect(settings.homeDockGlassIntensityPercent, 40);

    await _scrollToFinder(
      tester,
      find.byKey(
        const ValueKey<String>('home_layout_quick_tile_performance_mode'),
      ),
    );
    await tester.tap(find.byKey(
      const ValueKey<String>('home_layout_quick_tile_performance_mode'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>(
      'home_dock_performance_mode_option_smooth',
    )));
    await tester.pumpAndSettle();

    expect(
      settings.homeDockPerformanceMode,
      SettingsService.homeDockPerformanceModeSmooth,
    );

    await _scrollToFinder(
      tester,
      find.byKey(
        const ValueKey<String>('home_layout_quick_tile_settings_transparency'),
      ),
    );
    await tester.tap(find.byKey(
      const ValueKey<String>('home_layout_quick_tile_settings_transparency'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>(
      'settings_ui_transparency_decrease',
    )));
    await tester.pumpAndSettle();

    expect(settings.settingsUiTransparencyPercent, 15);

    await _scrollToFinder(
      tester,
      find.byKey(
        const ValueKey<String>('home_layout_quick_tile_row_spacing'),
      ),
    );
    await tester.tap(find.byKey(
      const ValueKey<String>('home_layout_quick_tile_row_spacing'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>(
      'home_dock_row_spacing_decrease',
    )));
    await tester.pumpAndSettle();

    expect(settings.homeDockRowSpacing, 1);
  });

  testWidgets(
      'autofocuses app language option, moves rows with DOWN, and changes only after OK activation',
      (tester) async {
    final settings = await _createSettingsService();
    final appsService = MockAppsService();

    await _pumpPage(
      tester,
      settings: settings,
      appsService: appsService,
    );

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_appLocale_option_2'),
    );
    expect(settings.appLocaleMode, SettingsService.appLocaleVietnamese);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_dockRows_option_1'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(settings.appLocaleMode, SettingsService.appLocaleVietnamese);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_appLocale_option_2'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(settings.appLocaleMode, SettingsService.appLocaleVietnamese);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_appLocale_option_1'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(settings.appLocaleMode, SettingsService.appLocaleEnglish);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_appLocale_option_1'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(settings.appLocaleMode, SettingsService.appLocaleEnglish);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_appLocale_option_0'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(settings.appLocaleMode, SettingsService.appLocaleSystem);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'home_layout_target_appLocale',
    );
  });

  testWidgets(
      'stepper uses LEFT RIGHT for focus only and OK for changing value',
      (tester) async {
    final settings = await _createSettingsService();
    final appsService = MockAppsService();

    await _pumpPage(
      tester,
      settings: settings,
      appsService: appsService,
    );

    await _scrollToFinder(
      tester,
      find.byKey(
        const ValueKey<String>('home_layout_quick_tile_row_spacing'),
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey<String>('home_layout_quick_tile_row_spacing'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_rowSpacing_decrease'),
    );

    final initialSpacing = settings.homeDockRowSpacing;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(settings.homeDockRowSpacing, initialSpacing);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_rowSpacing_increase'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(settings.homeDockRowSpacing, initialSpacing);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_rowSpacing_decrease'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(settings.homeDockRowSpacing, initialSpacing);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'home_layout_target_rowSpacing',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(settings.homeDockRowSpacing, initialSpacing + 1);
  });

  testWidgets('quick summary tile jumps focus to matching setting card',
      (tester) async {
    final settings = await _createSettingsService();
    final appsService = MockAppsService();

    await _pumpPage(
      tester,
      settings: settings,
      appsService: appsService,
    );

    await _scrollToFinder(
      tester,
      find.byKey(
        const ValueKey<String>('home_layout_quick_tile_card_size'),
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey<String>('home_layout_quick_tile_card_size'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_cardSize'),
    );
  });

  testWidgets('keeps focused deep settings rows inside the visible detail band',
      (tester) async {
    final settings = await _createSettingsService();
    final appsService = MockAppsService();

    await _pumpPage(
      tester,
      settings: settings,
      appsService: appsService,
      viewportHeight: 360,
    );

    for (var index = 0; index < 10; index += 1) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }

    final scrollableRect = tester.getRect(
      find
          .descendant(
            of: find.byType(HomeLayoutPanelPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final focusedRowRect = tester.getRect(
      find.byKey(const Key('app_card_layout_scale_stepper')),
    );

    expect(
      focusedRowRect.top,
      greaterThan(scrollableRect.top + 20),
    );
    expect(
      focusedRowRect.bottom,
      lessThan(scrollableRect.bottom - 20),
    );
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SettingsService settings,
  required AppsService appsService,
  double viewportHeight = 720,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        ChangeNotifierProvider<AppsService>.value(value: appsService),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Material(
          child: Scaffold(
            body: Center(
              child: SizedBox(
                height: viewportHeight,
                child: const HomeLayoutPanelPage(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollToLocaleControl(WidgetTester tester) async {
  await _scrollToFinder(
    tester,
    find.byKey(const Key('app_locale_mode_selector')),
  );
}

Future<void> _scrollToFinder(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find
        .descendant(
          of: find.byType(HomeLayoutPanelPage),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<SettingsService> _createSettingsService() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return SettingsService(await SharedPreferences.getInstance());
}
