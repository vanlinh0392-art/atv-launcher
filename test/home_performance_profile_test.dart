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
    expect(quality.dockBackdropBlurEnabled, isTrue);
    expect(balanced.dockBackdropBlurEnabled, isFalse);
    expect(smooth.dockBackdropBlurEnabled, isFalse);
    expect(off.dockBackdropBlurEnabled, isFalse);
  });

  test(
      'balanced, smooth and off clamp expensive video blur for CPU-first modes',
      () {
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
    expect(balanced.capWallpaperVideoBlurSigma(9), 0);
    expect(smooth.capWallpaperVideoBlurSigma(9), 0);
    expect(off.capWallpaperVideoBlurSigma(9), 0);
    expect(balanced.wallpaperFilterQuality, FilterQuality.none);
    expect(quality.startVideoAfterHomeSettles, isFalse);
    expect(quality.releasePlayerOnBackground, isFalse);
    expect(quality.allowVideoWallpaper, isTrue);
    expect(quality.disableAudioRendererWhenMuted, isTrue);
    expect(balanced.startVideoAfterHomeSettles, isTrue);
    expect(balanced.releasePlayerOnBackground, isTrue);
    expect(balanced.allowVideoWallpaper, isTrue);
    expect(balanced.disableAudioRendererWhenMuted, isTrue);
    expect(smooth.startVideoAfterHomeSettles, isTrue);
    expect(smooth.allowVideoWallpaper, isTrue);
    expect(smooth.disableAudioRendererWhenMuted, isTrue);
    expect(off.startVideoAfterHomeSettles, isTrue);
    expect(off.allowVideoWallpaper, isFalse);
    expect(off.disableAudioRendererWhenMuted, isTrue);
  });

  test('smooth mode keeps light sampling while sharpening app cards', () {
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
    expect(quality.appCardFilterQuality, FilterQuality.medium);
    expect(smooth.appCardFilterQuality, FilterQuality.low);
  });

  test('balanced mode keeps reduced dock prebuild limits for RAM savings', () {
    final balanced = HomePerformanceProfile.resolve(
      SettingsService.homeDockPerformanceModeBalanced,
    );
    final quality = HomePerformanceProfile.resolve(
      SettingsService.homeDockPerformanceModeQuality,
    );
    final smooth = HomePerformanceProfile.resolve(
      SettingsService.homeDockPerformanceModeSmooth,
    );
    final off = HomePerformanceProfile.resolve(
      SettingsService.homeDockPerformanceModeOff,
    );

    expect(balanced.dockCacheRowsAhead, 1);
    expect(balanced.dockMinimumCacheRows, 2);
    expect(quality.dockCacheRowsAhead, 3);
    expect(quality.dockMinimumCacheRows, 5);
    expect(smooth.dockCacheRowsAhead, 1);
    expect(smooth.dockMinimumCacheRows, 3);
    expect(off.dockCacheRowsAhead, 1);
    expect(off.dockMinimumCacheRows, 2);
  });
}
