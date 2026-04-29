import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/status_bar_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('uses TV-first clock scale stepper instead of slider',
      (tester) async {
    final settings = await _createSettingsService();

    await _pumpWidget(tester, settings);

    expect(find.byKey(const Key('status_bar_clock_scale_stepper')),
        findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('clock scale can be changed from stepper buttons',
      (tester) async {
    final settings = await _createSettingsService();

    await _pumpWidget(tester, settings);
    await tester.scrollUntilVisible(
      find.byKey(const Key('status_bar_clock_scale_stepper')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final initial = settings.statusBarClockScalePercent;

    await tester.tap(
      find.byKey(const ValueKey<String>('status_bar_clock_scale_increase')),
    );
    await tester.pumpAndSettle();

    expect(
      settings.statusBarClockScalePercent,
      initial + SettingsService.statusBarClockScaleStep,
    );
  });
}

Future<void> _pumpWidget(
  WidgetTester tester,
  SettingsService settings,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsService>.value(
      value: settings,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: StatusBarPanelPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<SettingsService> _createSettingsService() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return SettingsService(await SharedPreferences.getInstance());
}
