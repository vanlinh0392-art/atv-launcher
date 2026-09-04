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
    expect(find.text('Highlight color'), findsAtLeastNWidgets(1));
    expect(find.text('Dock glass intensity'), findsAtLeastNWidgets(1));
    expect(find.text('Home performance mode'), findsAtLeastNWidgets(1));
    expect(find.text('Settings transparency'), findsAtLeastNWidgets(1));
    expect(find.text('Settings backdrop theme'), findsAtLeastNWidgets(1));
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
    expect(
      find.byKey(const Key('app_card_highlight_color_selector')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home_dock_auto_collapse_delay_selector')),
        findsOneWidget);
    expect(find.byKey(const Key('home_dock_glass_intensity_selector')),
        findsOneWidget);
    expect(find.byKey(const Key('home_dock_performance_mode_selector')),
        findsOneWidget);
    expect(find.byKey(const Key('settings_ui_transparency_stepper')),
        findsOneWidget);
    expect(find.byKey(const Key('settings_background_color_selector')),
        findsOneWidget);
    expect(
        find.byKey(const Key('home_dock_row_spacing_stepper')), findsOneWidget);
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
        const Key('home_dock_collapsed_rows_selector'),
      ),
    );
    await _focusControl(tester, const Key('home_dock_collapsed_rows_selector'));
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
        const Key('icon_corner_radius_stepper'),
      ),
    );
    await _focusControl(tester, const Key('icon_corner_radius_stepper'));
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
        const Key('app_card_layout_scale_stepper'),
      ),
    );
    final initialCardSize = settings.appCardLayoutScalePercent;
    await _focusControl(tester, const Key('app_card_layout_scale_stepper'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      settings.appCardLayoutScalePercent,
      (initialCardSize + 5).clamp(70, 115),
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
        const Key('home_dock_auto_collapse_delay_selector'),
      ),
    );
    await _focusControl(tester, const Key('home_dock_auto_collapse_delay_selector'));
    await tester.tap(find.byKey(const ValueKey<String>(
      'home_dock_auto_collapse_delay_option_30',
    )));
    await tester.pumpAndSettle();

    expect(settings.homeDockAutoCollapseDelaySeconds, 30);

    await _scrollToFinder(
      tester,
      find.byKey(
        const Key('home_dock_glass_intensity_selector'),
      ),
    );
    await _focusControl(tester, const Key('home_dock_glass_intensity_selector'));
    await tester.tap(find.byKey(const ValueKey<String>(
      'home_dock_glass_intensity_option_40',
    )));
    await tester.pumpAndSettle();

    expect(settings.homeDockGlassIntensityPercent, 40);

    await _scrollToFinder(
      tester,
      find.byKey(
        const Key('home_dock_performance_mode_selector'),
      ),
    );
    await _focusControl(tester, const Key('home_dock_performance_mode_selector'));
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
        const Key('settings_ui_transparency_stepper'),
      ),
    );
    await _focusControl(tester, const Key('settings_ui_transparency_stepper'));
    await tester.tap(find.byKey(const ValueKey<String>(
      'settings_ui_transparency_decrease',
    )));
    await tester.pumpAndSettle();

    expect(settings.settingsUiTransparencyPercent, 15);

    await _scrollToFinder(
      tester,
      find.byKey(
        const Key('home_dock_row_spacing_stepper'),
      ),
    );
    await _focusControl(tester, const Key('home_dock_row_spacing_stepper'));
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

    // Verify only 2 language options exist: Vietnamese (option_0) and English (option_1)
    expect(
      find.byKey(const ValueKey<String>('app_locale_mode_option_system')),
      findsNothing,
    );
    expect(find.text('System'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('app_locale_mode_option_vi')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('app_locale_mode_option_en')),
      findsOneWidget,
    );

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_appLocale_option_0'),
    );
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      isNot(contains('home_layout_target_appLocale_option_2')),
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
      contains('home_layout_target_appLocale_option_0'),
    );

    // D-pad Right from option_0 (vi) to option_1 (en)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(settings.appLocaleMode, SettingsService.appLocaleVietnamese);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_appLocale_option_1'),
    );

    // Activate option_1 (en)
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(settings.appLocaleMode, SettingsService.appLocaleEnglish);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_appLocale_option_1'),
    );

    // D-pad Left from option_1 (en) back to option_0 (vi)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(settings.appLocaleMode, SettingsService.appLocaleEnglish);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_appLocale_option_0'),
    );

    // Activate option_0 (vi)
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(settings.appLocaleMode, SettingsService.appLocaleVietnamese);

    // D-pad Left from option_0 moves focus to the row card container
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
        const Key('home_dock_row_spacing_stepper'),
      ),
    );
    await _focusControl(tester, const Key('home_dock_row_spacing_stepper'));

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

  testWidgets(
      'settings backdrop theme selector displays swatches, supports D-Pad navigation, and updates on Enter/Select',
      (tester) async {
    final settings = await _createSettingsService();
    final appsService = MockAppsService();

    await _pumpPage(
      tester,
      settings: settings,
      appsService: appsService,
    );

    final selectorFinder =
        find.byKey(const Key('settings_background_color_selector'));
    expect(selectorFinder, findsOneWidget);
    await _scrollToFinder(tester, selectorFinder);

    await _focusControl(
      tester,
      const Key('settings_background_color_selector'),
    );

    expect(
      find.byKey(const ValueKey<String>(
        'settings_backdrop_theme_option_TvSettingsBackdropTheme.deepSlate',
      )),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>(
        'settings_backdrop_theme_option_TvSettingsBackdropTheme.obsidianOled',
      )),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>(
        'settings_backdrop_theme_option_TvSettingsBackdropTheme.oceanNavy',
      )),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>(
        'settings_backdrop_theme_option_TvSettingsBackdropTheme.smokyAmethyst',
      )),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>(
        'settings_backdrop_theme_option_TvSettingsBackdropTheme.forestMoss',
      )),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>(
        'settings_backdrop_theme_option_TvSettingsBackdropTheme.warmEspresso',
      )),
      findsOneWidget,
    );

    expect(settings.settingsBackdropTheme, TvSettingsBackdropTheme.deepSlate);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_settingsBackdropTheme_option_0'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_settingsBackdropTheme_option_1'),
    );
    expect(settings.settingsBackdropTheme, TvSettingsBackdropTheme.deepSlate);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_settingsBackdropTheme_option_2'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_settingsBackdropTheme_option_1'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(settings.settingsBackdropTheme, TvSettingsBackdropTheme.obsidianOled);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('home_layout_target_settingsBackdropTheme_option_4'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(settings.settingsBackdropTheme, TvSettingsBackdropTheme.forestMoss);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      anyOf(
        contains('cardSize'),
        contains('app_card_layout_scale'),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('settingsBackdropTheme'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      anyOf(
        contains('settingsTransparency'),
        contains('settings_ui_transparency'),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('settingsBackdropTheme'),
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

Future<void> _focusControl(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  final FocusNode? focusNode = tester.widget<Focus>(
    find.ancestor(
      of: finder,
      matching: find.byType(Focus),
    ).first,
  ).focusNode;
  focusNode?.requestFocus();
  await tester.pumpAndSettle();
}
