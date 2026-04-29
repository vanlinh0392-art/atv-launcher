import 'package:flauncher/widgets/settings/settings_chrome.dart';
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

  test('settings focus hierarchy keeps detail frames lighter than action buttons',
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
}
