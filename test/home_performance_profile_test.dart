import 'package:flauncher/home_performance_profile.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quality, balanced, smooth and off keep a stable cost hierarchy', () {
    final quality = HomePerformanceProfile.resolve(
      SettingsService.homeDockPerformanceModeQuality,
    );
    final balanced = HomePerformanceProfile.resolve(
      SettingsService.homeDockPerformanceModeBalanced,
    );
    final smooth = HomePerformanceProfile.resolve(
      SettingsService.homeDockPerformanceModeSmooth,
    );
    final off = HomePerformanceProfile.resolve(
      SettingsService.homeDockPerformanceModeOff,
    );

    expect(
      quality.dockStaticMaxBlurSigma,
      greaterThan(balanced.dockStaticMaxBlurSigma),
    );
    expect(
      balanced.dockStaticMaxBlurSigma,
      greaterThan(smooth.dockStaticMaxBlurSigma),
    );
    expect(
        smooth.dockStaticMaxBlurSigma, greaterThan(off.dockStaticMaxBlurSigma));

    expect(
        quality.appCardFocusedScale, greaterThan(balanced.appCardFocusedScale));
    expect(
        balanced.appCardFocusedScale, greaterThan(smooth.appCardFocusedScale));
    expect(smooth.appCardFocusedScale,
        greaterThanOrEqualTo(off.appCardFocusedScale));

    expect(
      quality.wallpaperVideoWarmUpDelay,
      lessThan(balanced.wallpaperVideoWarmUpDelay),
    );
    expect(
      balanced.wallpaperVideoWarmUpDelay,
      lessThan(smooth.wallpaperVideoWarmUpDelay),
    );
    expect(
      smooth.wallpaperVideoWarmUpDelay,
      lessThan(off.wallpaperVideoWarmUpDelay),
    );
  });

  test('smooth and off clamp expensive video blur while quality keeps it', () {
    final quality = HomePerformanceProfile.resolve(
      SettingsService.homeDockPerformanceModeQuality,
    );
    final balanced = HomePerformanceProfile.resolve(
      SettingsService.homeDockPerformanceModeBalanced,
    );
    final smooth = HomePerformanceProfile.resolve(
      SettingsService.homeDockPerformanceModeSmooth,
    );
    final off = HomePerformanceProfile.resolve(
      SettingsService.homeDockPerformanceModeOff,
    );

    expect(quality.capWallpaperVideoBlurSigma(9), 9);
    expect(balanced.capWallpaperVideoBlurSigma(9), 5);
    expect(smooth.capWallpaperVideoBlurSigma(9), 0);
    expect(off.capWallpaperVideoBlurSigma(9), 0);
  });

  test('smooth mode uses lighter sampling and static app focus treatment', () {
    final quality = HomePerformanceProfile.resolve(
      SettingsService.homeDockPerformanceModeQuality,
    );
    final smooth = HomePerformanceProfile.resolve(
      SettingsService.homeDockPerformanceModeSmooth,
    );

    expect(quality.appCardHighlightPulseEnabled, isTrue);
    expect(smooth.appCardHighlightPulseEnabled, isFalse);
    expect(quality.wallpaperFilterQuality, FilterQuality.low);
    expect(smooth.wallpaperFilterQuality, FilterQuality.none);
    expect(smooth.appCardFilterQuality, FilterQuality.none);
  });
}
