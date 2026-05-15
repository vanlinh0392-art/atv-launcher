import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/painting.dart';

class HomePerformanceProfile {
  final double dockStaticMaxBlurSigma;
  final double dockVideoMaxBlurSigma;
  final double dockStaticShadowBlurRadius;
  final double dockVideoShadowBlurRadius;
  final double dockStaticShadowOpacity;
  final double dockVideoShadowOpacity;
  final double dockVideoFakeGlassBoost;
  final bool dockBackdropBlurEnabled;
  final bool dockVideoBackdropBlurEnabled;
  final int dockCacheRowsAhead;
  final int dockMinimumCacheRows;
  final double dockScrollJumpThreshold;
  final Duration dockHeightAnimationDuration;
  final Duration dockShortScrollDuration;
  final Duration dockLongScrollDuration;
  final double wallpaperVideoBlurSigmaCap;
  final bool allowVideoWallpaper;
  final bool disableAudioRendererWhenMuted;
  final bool startVideoAfterHomeSettles;
  final bool releasePlayerOnBackground;
  final FilterQuality wallpaperFilterQuality;
  final FilterQuality appCardFilterQuality;
  final Duration wallpaperVideoWarmUpDelay;
  final bool appCardHighlightPulseEnabled;
  final Duration appCardHighlightPulseDuration;
  final Duration appCardTransformDuration;
  final double appCardFocusedScale;
  final double appCardFocusedElevation;
  final double appCardHighlightBorderWidth;
  final double appCardHighlightBorderBaseOpacity;
  final double appCardHighlightBorderPulseOpacityDelta;
  final double appCardHighlightGlowBaseOpacity;
  final double appCardHighlightGlowPulseOpacityDelta;
  final double appCardHighlightGlowBaseBlur;
  final double appCardHighlightGlowPulseBlurDelta;
  final double appCardHighlightGlowBaseSpread;
  final double appCardHighlightGlowPulseSpreadDelta;

  const HomePerformanceProfile({
    required this.dockStaticMaxBlurSigma,
    required this.dockVideoMaxBlurSigma,
    required this.dockStaticShadowBlurRadius,
    required this.dockVideoShadowBlurRadius,
    required this.dockStaticShadowOpacity,
    required this.dockVideoShadowOpacity,
    required this.dockVideoFakeGlassBoost,
    required this.dockBackdropBlurEnabled,
    required this.dockVideoBackdropBlurEnabled,
    required this.dockCacheRowsAhead,
    required this.dockMinimumCacheRows,
    required this.dockScrollJumpThreshold,
    required this.dockHeightAnimationDuration,
    required this.dockShortScrollDuration,
    required this.dockLongScrollDuration,
    required this.wallpaperVideoBlurSigmaCap,
    required this.allowVideoWallpaper,
    required this.disableAudioRendererWhenMuted,
    required this.startVideoAfterHomeSettles,
    required this.releasePlayerOnBackground,
    required this.wallpaperFilterQuality,
    required this.appCardFilterQuality,
    required this.wallpaperVideoWarmUpDelay,
    required this.appCardHighlightPulseEnabled,
    required this.appCardHighlightPulseDuration,
    required this.appCardTransformDuration,
    required this.appCardFocusedScale,
    required this.appCardFocusedElevation,
    required this.appCardHighlightBorderWidth,
    required this.appCardHighlightBorderBaseOpacity,
    required this.appCardHighlightBorderPulseOpacityDelta,
    required this.appCardHighlightGlowBaseOpacity,
    required this.appCardHighlightGlowPulseOpacityDelta,
    required this.appCardHighlightGlowBaseBlur,
    required this.appCardHighlightGlowPulseBlurDelta,
    required this.appCardHighlightGlowBaseSpread,
    required this.appCardHighlightGlowPulseSpreadDelta,
  });

  static HomePerformanceProfile resolve(String mode) {
    switch (mode) {
      case SettingsService.homeDockPerformanceModeQuality:
        return const HomePerformanceProfile(
          dockStaticMaxBlurSigma: 16,
          dockVideoMaxBlurSigma: 6,
          dockStaticShadowBlurRadius: 30,
          dockVideoShadowBlurRadius: 22,
          dockStaticShadowOpacity: 0.27,
          dockVideoShadowOpacity: 0.20,
          dockVideoFakeGlassBoost: 1.1,
          dockBackdropBlurEnabled: true,
          dockVideoBackdropBlurEnabled: true,
          dockCacheRowsAhead: 3,
          dockMinimumCacheRows: 5,
          dockScrollJumpThreshold: 10,
          dockHeightAnimationDuration: Duration(milliseconds: 340),
          dockShortScrollDuration: Duration(milliseconds: 96),
          dockLongScrollDuration: Duration(milliseconds: 132),
          wallpaperVideoBlurSigmaCap: 9,
          allowVideoWallpaper: true,
          disableAudioRendererWhenMuted: true,
          startVideoAfterHomeSettles: false,
          releasePlayerOnBackground: false,
          wallpaperFilterQuality: FilterQuality.low,
          appCardFilterQuality: FilterQuality.medium,
          wallpaperVideoWarmUpDelay: Duration(milliseconds: 320),
          appCardHighlightPulseEnabled: true,
          appCardHighlightPulseDuration: Duration(milliseconds: 520),
          appCardTransformDuration: Duration(milliseconds: 100),
          appCardFocusedScale: 1.05,
          appCardFocusedElevation: 16,
          appCardHighlightBorderWidth: 3,
          appCardHighlightBorderBaseOpacity: 0.34,
          appCardHighlightBorderPulseOpacityDelta: 0.66,
          appCardHighlightGlowBaseOpacity: 0.10,
          appCardHighlightGlowPulseOpacityDelta: 0.16,
          appCardHighlightGlowBaseBlur: 18,
          appCardHighlightGlowPulseBlurDelta: 8,
          appCardHighlightGlowBaseSpread: 0.5,
          appCardHighlightGlowPulseSpreadDelta: 0.8,
        );
      case SettingsService.homeDockPerformanceModeSmooth:
        return const HomePerformanceProfile(
          dockStaticMaxBlurSigma: 6,
          dockVideoMaxBlurSigma: 0,
          dockStaticShadowBlurRadius: 16,
          dockVideoShadowBlurRadius: 10,
          dockStaticShadowOpacity: 0.16,
          dockVideoShadowOpacity: 0.12,
          dockVideoFakeGlassBoost: 1.3,
          dockBackdropBlurEnabled: false,
          dockVideoBackdropBlurEnabled: false,
          dockCacheRowsAhead: 1,
          dockMinimumCacheRows: 3,
          dockScrollJumpThreshold: 18,
          dockHeightAnimationDuration: Duration(milliseconds: 250),
          dockShortScrollDuration: Duration(milliseconds: 68),
          dockLongScrollDuration: Duration(milliseconds: 88),
          wallpaperVideoBlurSigmaCap: 0,
          allowVideoWallpaper: true,
          disableAudioRendererWhenMuted: true,
          startVideoAfterHomeSettles: true,
          releasePlayerOnBackground: true,
          wallpaperFilterQuality: FilterQuality.none,
          appCardFilterQuality: FilterQuality.low,
          wallpaperVideoWarmUpDelay: Duration(milliseconds: 650),
          appCardHighlightPulseEnabled: false,
          appCardHighlightPulseDuration: Duration(milliseconds: 420),
          appCardTransformDuration: Duration(milliseconds: 72),
          appCardFocusedScale: 1.02,
          appCardFocusedElevation: 8,
          appCardHighlightBorderWidth: 2.4,
          appCardHighlightBorderBaseOpacity: 0.64,
          appCardHighlightBorderPulseOpacityDelta: 0.0,
          appCardHighlightGlowBaseOpacity: 0.08,
          appCardHighlightGlowPulseOpacityDelta: 0.0,
          appCardHighlightGlowBaseBlur: 14,
          appCardHighlightGlowPulseBlurDelta: 0.0,
          appCardHighlightGlowBaseSpread: 0.24,
          appCardHighlightGlowPulseSpreadDelta: 0.0,
        );
      case SettingsService.homeDockPerformanceModeOff:
        return const HomePerformanceProfile(
          dockStaticMaxBlurSigma: 0,
          dockVideoMaxBlurSigma: 0,
          dockStaticShadowBlurRadius: 10,
          dockVideoShadowBlurRadius: 8,
          dockStaticShadowOpacity: 0.12,
          dockVideoShadowOpacity: 0.10,
          dockVideoFakeGlassBoost: 1.35,
          dockBackdropBlurEnabled: false,
          dockVideoBackdropBlurEnabled: false,
          dockCacheRowsAhead: 1,
          dockMinimumCacheRows: 2,
          dockScrollJumpThreshold: 24,
          dockHeightAnimationDuration: Duration(milliseconds: 220),
          dockShortScrollDuration: Duration(milliseconds: 58),
          dockLongScrollDuration: Duration(milliseconds: 74),
          wallpaperVideoBlurSigmaCap: 0,
          allowVideoWallpaper: false,
          disableAudioRendererWhenMuted: true,
          startVideoAfterHomeSettles: true,
          releasePlayerOnBackground: true,
          wallpaperFilterQuality: FilterQuality.none,
          appCardFilterQuality: FilterQuality.none,
          wallpaperVideoWarmUpDelay: Duration(milliseconds: 850),
          appCardHighlightPulseEnabled: false,
          appCardHighlightPulseDuration: Duration(milliseconds: 360),
          appCardTransformDuration: Duration(milliseconds: 64),
          appCardFocusedScale: 1.0,
          appCardFocusedElevation: 2,
          appCardHighlightBorderWidth: 2.0,
          appCardHighlightBorderBaseOpacity: 0.42,
          appCardHighlightBorderPulseOpacityDelta: 0.0,
          appCardHighlightGlowBaseOpacity: 0.0,
          appCardHighlightGlowPulseOpacityDelta: 0.0,
          appCardHighlightGlowBaseBlur: 0.0,
          appCardHighlightGlowPulseBlurDelta: 0.0,
          appCardHighlightGlowBaseSpread: 0.0,
          appCardHighlightGlowPulseSpreadDelta: 0.0,
        );
      case SettingsService.homeDockPerformanceModeBalanced:
      default:
        return const HomePerformanceProfile(
          dockStaticMaxBlurSigma: 10,
          dockVideoMaxBlurSigma: 0,
          dockStaticShadowBlurRadius: 24,
          dockVideoShadowBlurRadius: 16,
          dockStaticShadowOpacity: 0.24,
          dockVideoShadowOpacity: 0.18,
          dockVideoFakeGlassBoost: 1.25,
          dockBackdropBlurEnabled: false,
          dockVideoBackdropBlurEnabled: false,
          dockCacheRowsAhead: 1,
          dockMinimumCacheRows: 2,
          dockScrollJumpThreshold: 14,
          dockHeightAnimationDuration: Duration(milliseconds: 300),
          dockShortScrollDuration: Duration(milliseconds: 78),
          dockLongScrollDuration: Duration(milliseconds: 102),
          wallpaperVideoBlurSigmaCap: 0,
          allowVideoWallpaper: true,
          disableAudioRendererWhenMuted: true,
          startVideoAfterHomeSettles: true,
          releasePlayerOnBackground: true,
          wallpaperFilterQuality: FilterQuality.none,
          appCardFilterQuality: FilterQuality.low,
          wallpaperVideoWarmUpDelay: Duration(milliseconds: 400),
          appCardHighlightPulseEnabled: true,
          appCardHighlightPulseDuration: Duration(milliseconds: 460),
          appCardTransformDuration: Duration(milliseconds: 90),
          appCardFocusedScale: 1.04,
          appCardFocusedElevation: 12,
          appCardHighlightBorderWidth: 2.8,
          appCardHighlightBorderBaseOpacity: 0.32,
          appCardHighlightBorderPulseOpacityDelta: 0.44,
          appCardHighlightGlowBaseOpacity: 0.08,
          appCardHighlightGlowPulseOpacityDelta: 0.10,
          appCardHighlightGlowBaseBlur: 16,
          appCardHighlightGlowPulseBlurDelta: 6,
          appCardHighlightGlowBaseSpread: 0.34,
          appCardHighlightGlowPulseSpreadDelta: 0.5,
        );
    }
  }

  Duration dockScrollDuration(double delta, double viewportExtent) {
    if (delta < (viewportExtent * 0.35)) {
      return dockShortScrollDuration;
    }
    return dockLongScrollDuration;
  }

  double capWallpaperVideoBlurSigma(double sigma) {
    return sigma.clamp(0.0, wallpaperVideoBlurSigmaCap).toDouble();
  }
}
