import 'package:flauncher/widgets/date_time_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  testWidgets('updates the formatted text when the app locale changes',
      (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        locale: const Locale('en'),
        child: const DateTimeWidget(
          'MMMM',
          key: ValueKey<String>('date_time_widget'),
          updateInterval: Duration(days: 1),
        ),
      ),
    );

    final englishValue = _textValue(tester);

    await tester.pumpWidget(
      _buildHarness(
        locale: const Locale('vi'),
        child: const DateTimeWidget(
          'MMMM',
          key: ValueKey<String>('date_time_widget'),
          updateInterval: Duration(days: 1),
        ),
      ),
    );
    await tester.pump();

    final vietnameseValue = _textValue(tester);
    expect(vietnameseValue, isNot(equals(englishValue)));
  });

  testWidgets('updates the formatted text when the format changes',
      (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        locale: const Locale('en'),
        child: const DateTimeWidget(
          'MMMM',
          key: ValueKey<String>('date_time_widget'),
          updateInterval: Duration(days: 1),
        ),
      ),
    );

    final monthValue = _textValue(tester);

    await tester.pumpWidget(
      _buildHarness(
        locale: const Locale('en'),
        child: const DateTimeWidget(
          'yyyy',
          key: ValueKey<String>('date_time_widget'),
          updateInterval: Duration(days: 1),
        ),
      ),
    );
    await tester.pump();

    final yearValue = _textValue(tester);
    expect(yearValue, isNot(equals(monthValue)));
  });
}

Widget _buildHarness({
  required Locale locale,
  required Widget child,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const <Locale>[
      Locale('en'),
      Locale('vi'),
    ],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

String _textValue(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).data ?? '';
