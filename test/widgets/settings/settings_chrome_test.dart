import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings transparency uses a stronger visible curve for TV values', () {
    final opaque = SettingsChromeSpec.fromTransparencyPercent(0);
    final low = SettingsChromeSpec.fromTransparencyPercent(15);
    final high = SettingsChromeSpec.fromTransparencyPercent(90);

    expect(low.effectiveTransparencyFraction, greaterThan(0.15));
    expect(
      low.panelSurfaceOpacity,
      lessThan(opaque.panelSurfaceOpacity - 0.18),
    );
    expect(
      low.dialogGradientOpacity,
      lessThan(opaque.dialogGradientOpacity - 0.2),
    );
    expect(high.panelSurfaceOpacity, lessThan(0.08));
    expect(high.dialogGradientOpacity, lessThan(0.12));
  });

  test('settings activate keys accept remote gameButtonA', () {
    expect(isSettingsActivateKey(LogicalKeyboardKey.gameButtonA), isTrue);
  });

  test(
      'settings focus hierarchy keeps detail frames lighter than action buttons',
      () {
    final spec = SettingsChromeSpec.fromTransparencyPercent(15);

    expect(
      spec.detailFocusFillOpacity,
      lessThan(spec.actionButtonSurfaceOpacity),
    );
    expect(
      spec.detailFocusBorderOpacity,
      lessThan(spec.actionButtonFocusBorderOpacity),
    );
    expect(
      spec.detailFocusGlowOpacity,
      lessThan(spec.actionButtonFocusGlowOpacity),
    );
  });

  test(
      'row-only focus visuals are clearer than detail frames but softer than options',
      () {
    final spec = SettingsChromeSpec.fromTransparencyPercent(15);
    final detail = spec.resolveFocusFrameVisuals(
      variant: SettingsFocusFrameVariant.detailPane,
      focused: true,
    );
    final rowOnly = spec.resolveFocusFrameVisuals(
      variant: SettingsFocusFrameVariant.rowOnly,
      focused: true,
    );
    final option = spec.resolveFocusFrameVisuals(
      variant: SettingsFocusFrameVariant.optionButton,
      focused: true,
    );
    final idleRowOnly = spec.resolveFocusFrameVisuals(
      variant: SettingsFocusFrameVariant.rowOnly,
      focused: false,
    );

    expect(rowOnly.borderWidth, greaterThan(detail.borderWidth));
    expect(rowOnly.glowBlurRadius, greaterThan(detail.glowBlurRadius));
    expect(
        rowOnly.fillColor.opacity, greaterThan(idleRowOnly.fillColor.opacity));
    expect(option.borderWidth, greaterThan(rowOnly.borderWidth));
    expect(option.glowColor.opacity, greaterThan(rowOnly.glowColor.opacity));
  });

  test('settings button variants keep distinct semantic accents', () {
    expect(
      SettingsButtonStyles.accentForVariant(SettingsButtonVariant.primary),
      isNot(
        SettingsButtonStyles.accentForVariant(SettingsButtonVariant.success),
      ),
    );
    expect(
      SettingsButtonStyles.accentForVariant(SettingsButtonVariant.success),
      isNot(
        SettingsButtonStyles.accentForVariant(SettingsButtonVariant.danger),
      ),
    );
  });

  testWidgets('rounded switch tiles use the shared row-only focus frame',
      (tester) async {
    await tester.pumpWidget(
      _settingsHarness(
        RoundedSwitchListTile(
          value: true,
          onChanged: (_) {},
          title: const Text('Launcher lock'),
          secondary: const Icon(Icons.lock_outline),
        ),
      ),
    );

    final frame =
        tester.widget<SettingsFocusFrame>(find.byType(SettingsFocusFrame));
    expect(frame.variant, SettingsFocusFrameVariant.rowOnly);
  });

  testWidgets('settings action cards use the shared row-only focus frame',
      (tester) async {
    await tester.pumpWidget(
      _settingsHarness(
        SettingsActionCard(
          title: 'Manage apps',
          subtitle: 'Open the row-only action card',
          icon: Icons.apps_outlined,
          onPressed: () async {},
        ),
      ),
    );

    final frame =
        tester.widget<SettingsFocusFrame>(find.byType(SettingsFocusFrame));
    expect(frame.variant, SettingsFocusFrameVariant.rowOnly);
  });

  testWidgets('settings metric tiles stay non-focusable compact summaries',
      (tester) async {
    final focusNode = FocusNode(debugLabel: 'metric_tile_focus');
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _settingsHarness(
        SettingsMetricTile(
          focusNode: focusNode,
          label: 'Permission health',
          value: 'Healthy',
          icon: Icons.verified_user_outlined,
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pumpAndSettle();

    final frame =
        tester.widget<SettingsFocusFrame>(find.byType(SettingsFocusFrame));
    expect(frame.variant, SettingsFocusFrameVariant.rowOnly);
    expect(frame.focused, isFalse);
    expect(focusNode.canRequestFocus, isFalse);
  });

  testWidgets(
      'settings metrics grid avoids a trailing single card for four summary tiles',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          color: Colors.black,
          child: Center(
            child: SizedBox(
              width: 620,
              child: SettingsMetricsGrid(
                children: List.generate(
                  4,
                  (index) => SettingsMetricTile(
                    label: 'Metric ${index + 1}',
                    value: 'Value ${index + 1}',
                    icon: Icons.info_outline,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final metric1 = tester.getTopLeft(find.text('Metric 1'));
    final metric2 = tester.getTopLeft(find.text('Metric 2'));
    final metric3 = tester.getTopLeft(find.text('Metric 3'));
    final metric4 = tester.getTopLeft(find.text('Metric 4'));

    expect(metric1.dy, equals(metric2.dy));
    expect(metric3.dy, greaterThan(metric2.dy));
    expect(metric3.dy, equals(metric4.dy));
  });

  testWidgets('explicit row-only focus binding produces a visible focus frame',
      (tester) async {
    await tester.pumpWidget(
      _settingsHarness(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SettingsFocusFrame(
              variant: SettingsFocusFrameVariant.rowOnly,
              focused: false,
              child: SizedBox(width: 160, height: 48),
            ),
            SizedBox(height: 12),
            SettingsFocusFrame(
              variant: SettingsFocusFrameVariant.rowOnly,
              focused: true,
              child: SizedBox(width: 160, height: 48),
            ),
          ],
        ),
      ),
    );

    final frames =
        tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
    final idleDecoration = frames.first.decoration! as BoxDecoration;
    final focusedDecoration = frames.last.decoration! as BoxDecoration;

    expect(
      focusedDecoration.border!.top.width,
      greaterThan(idleDecoration.border!.top.width),
    );
    expect(
      focusedDecoration.boxShadow!.length,
      greaterThan(idleDecoration.boxShadow!.length),
    );
    expect(
      focusedDecoration.border!.top.color.opacity,
      greaterThan(idleDecoration.border!.top.color.opacity),
    );
  });

  testWidgets(
      'choice rows keep the parent frame on the shared row-only variant',
      (tester) async {
    await tester.pumpWidget(
      _settingsHarness(
        SettingsChoiceCard<int>(
          title: 'Rows',
          subtitle: 'How many rows are visible',
          icon: Icons.view_stream_outlined,
          value: 3,
          options: const [
            SettingsChoiceOption<int>(value: 2, label: '2'),
            SettingsChoiceOption<int>(value: 3, label: '3'),
            SettingsChoiceOption<int>(value: 4, label: '4'),
          ],
          valueLabelBuilder: (value) => '$value rows',
          onChanged: (_) {},
        ),
      ),
    );

    final frame =
        tester.widget<SettingsFocusFrame>(find.byType(SettingsFocusFrame));
    expect(frame.variant, SettingsFocusFrameVariant.rowOnly);
  });
}

Widget _settingsHarness(Widget child) => MaterialApp(
      home: Material(
        color: Colors.black,
        child: Center(
          child: SizedBox(
            width: 680,
            child: child,
          ),
        ),
      ),
    );
