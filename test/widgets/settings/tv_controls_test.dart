import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TvDrawerTokens contracts', () {
    test('standard tokens have expected dimensions and spacing', () {
      expect(TvDrawerTokens.cardMinHeight, 52.0);
      expect(TvDrawerTokens.cardMinHeightWithSubtitle, 64.0);
      expect(TvDrawerTokens.surfaceSpacing, 14.0);
      expect(TvDrawerTokens.rowSpacing, 10.0);
      expect(TvDrawerTokens.surfacePadding, const EdgeInsets.all(12.0));
      expect(
        TvDrawerTokens.cardPadding,
        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      );
    });
  });

  group('SettingsActionCard dimensions and padding', () {
    testWidgets(
        'single-line action card renders with minHeight >= 52dp and default cardPadding',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: SettingsActionCard(
                  title: 'Single Line Action',
                  icon: Icons.settings,
                  onPressed: () async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final actionCard = tester.widget<SettingsActionCard>(
        find.byType(SettingsActionCard),
      );
      expect(actionCard.contentPadding, TvDrawerTokens.cardPadding);

      final cardSize = tester.getSize(find.byType(SettingsActionCard));
      expect(cardSize.height, greaterThanOrEqualTo(52.0));
    });

    testWidgets('action card with subtitle renders with minHeight >= 64dp',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: SettingsActionCard(
                  title: 'Title with Subtitle',
                  subtitle: 'Detailed description underneath the title',
                  icon: Icons.info_outline,
                  onPressed: () async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardSize = tester.getSize(find.byType(SettingsActionCard));
      expect(cardSize.height, greaterThanOrEqualTo(64.0));
    });
  });

  group('SettingsControlButton visual swatch button dimensions', () {
    testWidgets('swatch button has 48x48 outer box and 36x36 inner circle',
        (tester) async {
      final focusNode = FocusNode(debugLabel: 'swatch_test_button');
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SettingsControlButton(
                focusNode: focusNode,
                isCircle: true,
                swatchColor: const Color(0xFF00E5FF),
                selected: false,
                onPressed: () {},
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final outerSizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(SettingsControlButton),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 48 && w.height == 48,
          ),
        ),
      );
      expect(outerSizedBox.width, 48.0);
      expect(outerSizedBox.height, 48.0);

      final innerContainer = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(SettingsControlButton),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final decoration = innerContainer.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, const Color(0xFF00E5FF));
      expect(innerContainer.constraints?.maxWidth, 36.0);
      expect(innerContainer.constraints?.maxHeight, 36.0);
    });

    testWidgets(
        'focused swatch button scales up while maintaining 48x48 outer bounds',
        (tester) async {
      final focusNode = FocusNode(debugLabel: 'swatch_focused_test');
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SettingsControlButton(
                focusNode: focusNode,
                isCircle: true,
                swatchColor: const Color(0xFFFFD700),
                selected: true,
                onPressed: () {},
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      final outerSize = tester.getSize(
        find.descendant(
          of: find.byType(SettingsControlButton),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 48 && w.height == 48,
          ),
        ),
      );
      expect(outerSize.width, 48.0);
      expect(outerSize.height, 48.0);

      final scaleWidget = tester.widget<AnimatedScale>(
        find.descendant(
          of: find.byType(SettingsControlButton),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(scaleWidget.scale, 1.15);
    });
  });
}
