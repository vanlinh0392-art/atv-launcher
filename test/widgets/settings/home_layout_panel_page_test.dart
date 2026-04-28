import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/home_layout_panel_page.dart';
import 'package:flutter/material.dart';
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
      'shows language selector, dock collapse, row spacing, card size and icon size controls',
      (tester) async {
    final settings = await _createSettingsService();
    final appsService = MockAppsService();

    await _pumpPage(
      tester,
      settings: settings,
      appsService: appsService,
    );
    await _scrollToLocaleControl(tester);

    expect(find.text('App language'), findsAtLeastNWidgets(1));
    expect(find.text('Card size'), findsAtLeastNWidgets(1));
    expect(find.text('Icon size'), findsAtLeastNWidgets(1));
    expect(find.text('Dock glass intensity'), findsAtLeastNWidgets(1));
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
        find.byKey(const Key('app_card_layout_scale_selector')),
        findsOneWidget);
    expect(
        find.byKey(const Key('app_card_media_scale_stepper')),
        findsOneWidget);
    expect(find.byKey(const Key('home_dock_auto_collapse_delay_selector')),
        findsOneWidget);
    expect(find.byKey(const Key('home_dock_glass_intensity_selector')),
        findsOneWidget);
    expect(find.byKey(const Key('settings_ui_transparency_stepper')),
        findsOneWidget);
    expect(
        find.byKey(const Key('home_dock_row_spacing_stepper')),
        findsOneWidget);
    expect(find.text('90%'), findsAtLeastNWidgets(1));
    expect(find.text('110%'), findsAtLeastNWidgets(1));
    expect(find.text('24dp'), findsAtLeastNWidgets(1));
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

    final localeControl = tester.widget<SegmentedButton<String>>(
      find.byKey(const Key('app_locale_mode_selector')),
    );
    localeControl.onSelectionChanged?.call(
      <String>{SettingsService.appLocaleEnglish},
    );
    await tester.pumpAndSettle();

    expect(settings.appLocaleMode, SettingsService.appLocaleEnglish);

    final collapsedRowsControl = tester.widget<SegmentedButton<int>>(
      find.byKey(const Key('home_dock_collapsed_rows_selector')),
    );
    collapsedRowsControl.onSelectionChanged?.call(<int>{2});
    await tester.pumpAndSettle();

    expect(settings.homeDockCollapsedRowsPreset, 2);

    await _scrollToFinder(
      tester,
      find.byKey(const Key('icon_corner_radius_stepper')),
    );
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
      find.byKey(const ValueKey<String>('app_card_layout_scale_option_95')),
    );
    await tester.tap(find.byKey(const ValueKey<String>(
      'app_card_layout_scale_option_95',
    )));
    await tester.pumpAndSettle();

    expect(settings.appCardLayoutScalePercent, 95);

    await _scrollToFinder(
      tester,
      find.byKey(const Key('app_card_media_scale_stepper')),
    );
    await tester.tap(find.byKey(const ValueKey<String>(
      'app_card_media_scale_increase',
    )));
    await tester.pumpAndSettle();

    expect(settings.appCardMediaScalePercent, 115);
    expect(find.text('115%'), findsAtLeastNWidgets(1));

    await _scrollToFinder(
      tester,
      find.byKey(
        const ValueKey<String>('home_dock_auto_collapse_delay_option_30'),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>(
      'home_dock_auto_collapse_delay_option_30',
    )));
    await tester.pumpAndSettle();

    expect(settings.homeDockAutoCollapseDelaySeconds, 30);

    await _scrollToFinder(
      tester,
      find.byKey(
        const ValueKey<String>('home_dock_glass_intensity_option_40'),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>(
      'home_dock_glass_intensity_option_40',
    )));
    await tester.pumpAndSettle();

    expect(settings.homeDockGlassIntensityPercent, 40);

    await _scrollToFinder(
      tester,
      find.byKey(const Key('settings_ui_transparency_stepper')),
    );
    await tester.tap(find.byKey(const ValueKey<String>(
      'settings_ui_transparency_decrease',
    )));
    await tester.pumpAndSettle();

    expect(settings.settingsUiTransparencyPercent, 15);

    await _scrollToFinder(
      tester,
      find.byKey(const Key('home_dock_row_spacing_stepper')),
    );
    await tester.tap(find.byKey(const ValueKey<String>(
      'home_dock_row_spacing_decrease',
    )));
    await tester.pumpAndSettle();

    expect(settings.homeDockRowSpacing, 1);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SettingsService settings,
  required AppsService appsService,
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
        home: const Material(
          child: Scaffold(
            body: HomeLayoutPanelPage(),
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
