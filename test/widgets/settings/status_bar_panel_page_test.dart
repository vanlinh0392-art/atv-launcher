import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/status_bar_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final primaryFocusNode = FocusNode(debugLabel: 'status_bar_primary_toggle');
    addTearDown(primaryFocusNode.dispose);

    await _pumpWidget(
      tester,
      settings,
      primaryFocusNode: primaryFocusNode,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('status_bar_clock_scale_stepper')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    primaryFocusNode.requestFocus();
    await tester.pumpAndSettle();

    for (var index = 0; index < 4; index += 1) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }

    expect(
      FocusManager.instance.primaryFocus?.debugLabel ?? '',
      contains('status_bar_clock_scale_increase'),
    );

    final initial = settings.statusBarClockScalePercent;

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      settings.statusBarClockScalePercent,
      initial + SettingsService.statusBarClockScaleStep,
    );
  });
}

Future<void> _pumpWidget(
  WidgetTester tester,
  SettingsService settings, {
  FocusNode? primaryFocusNode,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsService>.value(
      value: settings,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatusBarPanelPage(primaryFocusNode: primaryFocusNode),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<SettingsService> _createSettingsService() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return SettingsService(await SharedPreferences.getInstance());
}
