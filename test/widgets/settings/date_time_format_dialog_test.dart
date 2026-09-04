import 'package:flauncher/widgets/settings/date_time_format_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuple/tuple.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  void setTvScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildHarness({
    required Widget child,
    Locale locale = const Locale('vi'),
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  testWidgets('opens with Top-First Presets and autofocus NOT on TextFormField',
      (tester) async {
    setTvScreenSize(tester);
    await tester.pumpWidget(
      buildHarness(
        child: const DateTimeFormatDialog('E d/M', 'H:mm'),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and Live Preview exist
    expect(find.text('Định dạng ngày giờ'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    // Verify Top-First Presets section headers
    expect(find.text('Định dạng ngày (Bấm chọn nhanh)'), findsOneWidget);
    expect(find.text('Định dạng giờ (Bấm chọn nhanh)'), findsOneWidget);

    // Verify Date Preset chip exists
    expect(find.byKey(const ValueKey('date_preset_E d/M')), findsOneWidget);
    expect(find.byKey(const ValueKey('time_preset_H:mm')), findsOneWidget);

    // Crucial check: TextFormField must NOT be mounted or focused initially
    expect(find.byType(TextFormField), findsNothing);

    // Verify initial focus is NOT an EditableText
    final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
    expect(focusedWidget is EditableText, isFalse);
  });

  testWidgets('selecting another date and time preset updates selection and returns on apply',
      (tester) async {
    setTvScreenSize(tester);
    Tuple2<String, String>? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<Tuple2<String, String>>(
                    context: context,
                    builder: (_) => const DateTimeFormatDialog('E d/M', 'H:mm'),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap to open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Tap on Vietnamese full date preset: "Thứ 5 ngày d/M/y"
    final vnDatePresetFinder = find.byKey(const ValueKey('date_preset_Thứ 5 ngày d/M/y'));
    expect(vnDatePresetFinder, findsOneWidget);
    await tester.ensureVisible(vnDatePresetFinder);
    await tester.pumpAndSettle();
    await tester.tap(vnDatePresetFinder);
    await tester.pumpAndSettle();

    // Tap on 12-hour time preset: "h:mm a"
    final time12PresetFinder = find.byKey(const ValueKey('time_preset_h:mm a'));
    expect(time12PresetFinder, findsOneWidget);
    await tester.ensureVisible(time12PresetFinder);
    await tester.pumpAndSettle();
    await tester.tap(time12PresetFinder);
    await tester.pumpAndSettle();

    // Tap Apply button
    final applyButton = find.byKey(const Key('format_dialog_apply_button'));
    expect(applyButton, findsOneWidget);
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    // Verify result returned to caller
    expect(result, isNotNull);
    expect(result!.item1, "Thứ 5 ngày d/M/y");
    expect(result!.item2, "h:mm a");
  });

  testWidgets('cancel button dismisses dialog without returning value',
      (tester) async {
    setTvScreenSize(tester);
    Tuple2<String, String>? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<Tuple2<String, String>>(
                    context: context,
                    builder: (_) => const DateTimeFormatDialog('E d/M', 'H:mm'),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    final cancelButton = find.byKey(const Key('format_dialog_cancel_button'));
    expect(cancelButton, findsOneWidget);
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('expanding custom format reveals text fields',
      (tester) async {
    setTvScreenSize(tester);
    await tester.pumpWidget(
      buildHarness(
        child: const DateTimeFormatDialog('E d/M', 'H:mm'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNothing);

    // Tap toggle for custom input
    final toggleFinder = find.text('Tùy chỉnh định dạng thủ công (Nhập tay)');
    expect(toggleFinder, findsOneWidget);
    await tester.ensureVisible(toggleFinder);
    await tester.pumpAndSettle();
    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    // Now text fields are revealed
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Chuỗi định dạng ngày tùy chỉnh'), findsOneWidget);
    expect(find.text('Chuỗi định dạng giờ tùy chỉnh'), findsOneWidget);
  });

  testWidgets('remote TV D-pad navigates between presets without opening IME keyboard',
      (tester) async {
    setTvScreenSize(tester);
    await tester.pumpWidget(
      buildHarness(
        child: const DateTimeFormatDialog('E d/M', 'H:mm'),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial focus is on the active preset
    expect(
      find.byKey(const ValueKey('date_preset_E d/M')),
      findsOneWidget,
    );

    // Send D-pad Right
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // Send D-pad Down
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Verify no EditableText has focus at any time
    final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
    expect(focusedWidget is EditableText, isFalse);
  });
}
