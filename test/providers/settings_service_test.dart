/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

//import 'dart:html';

import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

//import '../mocks.mocks.dart';

void main() async {
  SharedPreferencesStorePlatform.instance =
      InMemorySharedPreferencesStore.empty();
  final sharedPreferences = await SharedPreferences.getInstance();
  final settingsService = SettingsService(sharedPreferences);

  setUp(() async {
    await sharedPreferences.clear();
  });

  test("setUse24HourTimeFormat", () async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final settingsService = SettingsService(sharedPreferences);
    final expected = "XYZ";

    await settingsService.setDateTimeFormat("", expected);

    expect(settingsService.timeFormat, expected);
  });

  test("setGradientUuid", () async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final settingsService = SettingsService(sharedPreferences);

    await settingsService
        .setGradientUuid("4730aa2d-1a90-49a6-9942-ffe82f470e26");

    expect(sharedPreferences.getString("gradient_uuid"),
        "4730aa2d-1a90-49a6-9942-ffe82f470e26");
  });

  group("getGradientUuid", () {
    test("without uuid from shared preferences", () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      await sharedPreferences.clear();
      final settingsService = SettingsService(sharedPreferences);

      final gradientUuid = settingsService.gradientUuid;

      expect(gradientUuid, null);
    });

    test("with uuid from shared preferences", () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      await sharedPreferences.clear();
      sharedPreferences.setString(
          "gradient_uuid", "4730aa2d-1a90-49a6-9942-ffe82f470e26");
      final settingsService = SettingsService(sharedPreferences);

      final gradientUuid = settingsService.gradientUuid;

      expect(gradientUuid, "4730aa2d-1a90-49a6-9942-ffe82f470e26");
    });
  });

  group("getDateFormat", () {
    test("with default", () async {
      expect(settingsService.dateFormat, SettingsService.defaultDateFormat);
    });

    test("with value set", () async {
      final expected = "XYZ";

      settingsService.setDateTimeFormat(expected, "");

      expect(settingsService.dateFormat, expected);
    });
  });

  group("home dock settings", () {
    test("use defaults when nothing is stored", () async {
      expect(settingsService.homeDockRowsPreset, 3);
      expect(
        settingsService.homeDockCollapsedRowsPreset,
        SettingsService.homeDockCollapsedRowsDefault,
      );
      expect(settingsService.homeDockAutoCollapseEnabled, true);
      expect(
        settingsService.homeDockAutoCollapseDelaySeconds,
        SettingsService.homeDockAutoCollapseDelayDefault,
      );
      expect(settingsService.homeDockBlurEnabled, true);
      expect(
        settingsService.homeDockGlassIntensityPercent,
        SettingsService.homeDockGlassIntensityDefault,
      );
      expect(
        settingsService.homeDockPerformanceMode,
        SettingsService.homeDockPerformanceModeOff,
      );
      expect(
        settingsService.homeDockRowSpacing,
        SettingsService.homeDockRowSpacingDefault,
      );
      expect(settingsService.appLocaleMode, SettingsService.appLocaleDefault);
      expect(
        settingsService.settingsUiTransparencyPercent,
        SettingsService.settingsUiTransparencyDefault,
      );
      expect(
        settingsService.appCardCornerRadius,
        SettingsService.appCardCornerRadiusDefault,
      );
      expect(
        settingsService.appCardLayoutScalePercent,
        SettingsService.appCardLayoutScaleDefault,
      );
      expect(
        settingsService.appHighlightAnimationColorPreset,
        SettingsService.appCardHighlightColorDefault,
      );
      expect(
        settingsService.appCardMediaScalePercent,
        SettingsService.appCardMediaScaleDefault,
      );
      expect(
        settingsService.videoWallpaperRepeatCountPerItem,
        SettingsService.videoWallpaperRepeatCountPerItemDefault,
      );
      expect(
        settingsService.showRamInStatusBar,
        SettingsService.showRamInStatusBarDefault,
      );
      expect(
        settingsService.statusBarClockScalePercent,
        SettingsService.statusBarClockScaleDefault,
      );
      expect(
        settingsService.settingsBackdropTheme,
        TvSettingsBackdropTheme.deepSlate,
      );
    });

    test("backup and restore include dock and status bar fields", () async {
      await settingsService.applyBackupMap(const <String, dynamic>{
        'homeDockRowsPreset': 4,
        'homeDockCollapsedRowsPreset': 2,
        'homeDockAutoCollapseEnabled': false,
        'homeDockAutoCollapseDelaySeconds': 25,
        'homeDockGlassIntensityPercent': 65,
        'homeDockPerformanceMode': 'smooth',
        'homeDockRowSpacing': 8,
        'appLocaleMode': 'vi',
        'settingsUiTransparencyPercent': 70,
        'settingsBackdropTheme': 'ocean_navy',
        'appCardCornerRadius': 18,
        'appCardLayoutScalePercent': 95,
        'appHighlightAnimationColorPreset':
            SettingsService.appCardHighlightColorMint,
        'appCardMediaScalePercent': 125,
        'showRamInStatusBar': true,
        'statusBarClockScalePercent': 150,
      });

      final backup = settingsService.toBackupMap();

      expect(settingsService.homeDockRowsPreset, 4);
      expect(settingsService.homeDockCollapsedRowsPreset, 2);
      expect(settingsService.homeDockAutoCollapseEnabled, false);
      expect(settingsService.homeDockAutoCollapseDelaySeconds, 25);
      expect(settingsService.homeDockBlurEnabled, true);
      expect(settingsService.homeDockGlassIntensityPercent, 65);
      expect(
        settingsService.homeDockPerformanceMode,
        SettingsService.homeDockPerformanceModeSmooth,
      );
      expect(settingsService.homeDockRowSpacing, 8);
      expect(
          settingsService.appLocaleMode, SettingsService.appLocaleVietnamese);
      expect(settingsService.settingsUiTransparencyPercent, 70);
      expect(
        settingsService.settingsBackdropTheme,
        TvSettingsBackdropTheme.oceanNavy,
      );
      expect(settingsService.appCardCornerRadius, 18);
      expect(settingsService.appCardLayoutScalePercent, 95);
      expect(
        settingsService.appHighlightAnimationColorPreset,
        SettingsService.appCardHighlightColorMint,
      );
      expect(settingsService.appCardMediaScalePercent, 125);
      expect(settingsService.showRamInStatusBar, true);
      expect(settingsService.statusBarClockScalePercent, 150);
      expect(backup['homeDockRowsPreset'], 4);
      expect(backup['homeDockCollapsedRowsPreset'], 2);
      expect(backup['homeDockAutoCollapseEnabled'], false);
      expect(backup['homeDockAutoCollapseDelaySeconds'], 25);
      expect(backup['homeDockBlurEnabled'], true);
      expect(backup['homeDockGlassIntensityPercent'], 65);
      expect(
        backup['homeDockPerformanceMode'],
        SettingsService.homeDockPerformanceModeSmooth,
      );
      expect(backup['homeDockRowSpacing'], 8);
      expect(backup['appLocaleMode'], SettingsService.appLocaleVietnamese);
      expect(backup['settingsUiTransparencyPercent'], 70);
      expect(backup['settingsBackdropTheme'], 'ocean_navy');
      expect(backup['appCardCornerRadius'], 18);
      expect(backup['appCardLayoutScalePercent'], 95);
      expect(
        backup['appHighlightAnimationColorPreset'],
        SettingsService.appCardHighlightColorMint,
      );
      expect(backup['appCardMediaScalePercent'], 125);
      expect(backup['showRamInStatusBar'], true);
      expect(backup['statusBarClockScalePercent'], 150);
    });

    test("backup and restore include wallpaper repeat count", () async {
      await settingsService.applyBackupMap(const <String, dynamic>{
        'videoWallpaperRepeatCountPerItem': 5,
      });

      final backup = settingsService.toBackupMap();

      expect(settingsService.videoWallpaperRepeatCountPerItem, 5);
      expect(backup['videoWallpaperRepeatCountPerItem'], 5);
    });

    test("missing new backup keys fall back to defaults", () async {
      await settingsService.setAppLocaleMode(SettingsService.appLocaleEnglish);
      await settingsService.setHomeDockAutoCollapseEnabled(false);
      await settingsService.setHomeDockBlurEnabled(true);
      await settingsService.setHomeDockPerformanceMode(
        SettingsService.homeDockPerformanceModeQuality,
      );
      await settingsService.setAppCardLayoutScalePercent(110);
      await settingsService.setAppHighlightAnimationColorPreset(
        SettingsService.appCardHighlightColorCoral,
      );
      await settingsService.setAppCardMediaScalePercent(125);
      await settingsService.setVideoWallpaperRepeatCountPerItem(8);
      await settingsService.setStatusBarClockScalePercent(180);
      await settingsService.setSettingsBackdropTheme(
        TvSettingsBackdropTheme.forestMoss,
      );

      await settingsService.applyBackupMap(const <String, dynamic>{
        'homeDockRowsPreset': 2,
      });

      expect(settingsService.homeDockRowsPreset, 2);
      expect(
        settingsService.homeDockCollapsedRowsPreset,
        SettingsService.homeDockCollapsedRowsDefault,
      );
      expect(settingsService.homeDockAutoCollapseEnabled, true);
      expect(
        settingsService.homeDockAutoCollapseDelaySeconds,
        SettingsService.homeDockAutoCollapseDelayDefault,
      );
      expect(settingsService.homeDockBlurEnabled, true);
      expect(
        settingsService.homeDockGlassIntensityPercent,
        SettingsService.homeDockGlassIntensityDefault,
      );
      expect(
        settingsService.homeDockPerformanceMode,
        SettingsService.homeDockPerformanceModeOff,
      );
      expect(
        settingsService.homeDockRowSpacing,
        SettingsService.homeDockRowSpacingDefault,
      );
      expect(settingsService.appLocaleMode, SettingsService.appLocaleDefault);
      expect(
        settingsService.settingsUiTransparencyPercent,
        SettingsService.settingsUiTransparencyDefault,
      );
      expect(
        settingsService.appCardLayoutScalePercent,
        SettingsService.appCardLayoutScaleDefault,
      );
      expect(
        settingsService.appHighlightAnimationColorPreset,
        SettingsService.appCardHighlightColorDefault,
      );
      expect(
        settingsService.appCardMediaScalePercent,
        SettingsService.appCardMediaScaleDefault,
      );
      expect(
        settingsService.videoWallpaperRepeatCountPerItem,
        SettingsService.videoWallpaperRepeatCountPerItemDefault,
      );
      expect(
        settingsService.statusBarClockScalePercent,
        SettingsService.statusBarClockScaleDefault,
      );
      expect(
        settingsService.settingsBackdropTheme,
        TvSettingsBackdropTheme.deepSlate,
      );
    });

    test("legacy blur backup migrates to glass intensity", () async {
      await settingsService.applyBackupMap(const <String, dynamic>{
        'homeDockBlurEnabled': true,
      });

      expect(settingsService.homeDockBlurEnabled, true);
      expect(
        settingsService.homeDockGlassIntensityPercent,
        SettingsService.homeDockGlassIntensityLegacyOnDefault,
      );
    });

    test("media scale snaps to supported range and steps", () async {
      await settingsService.setAppCardMediaScalePercent(127);
      expect(settingsService.appCardMediaScalePercent, 125);

      await settingsService.setAppCardMediaScalePercent(83);
      expect(settingsService.appCardMediaScalePercent, 85);

      await settingsService.setAppCardMediaScalePercent(12);
      expect(
        settingsService.appCardMediaScalePercent,
        SettingsService.appCardMediaScaleMin,
      );
    });

    test("layout scale snaps to supported range and steps", () async {
      await settingsService.setAppCardLayoutScalePercent(117);
      expect(
        settingsService.appCardLayoutScalePercent,
        SettingsService.appCardLayoutScaleMax,
      );

      await settingsService.setAppCardLayoutScalePercent(86);
      expect(settingsService.appCardLayoutScalePercent, 85);

      await settingsService.setAppCardLayoutScalePercent(12);
      expect(
        settingsService.appCardLayoutScalePercent,
        SettingsService.appCardLayoutScaleMin,
      );
    });

    test("video repeat count snaps to supported range", () async {
      await settingsService.setVideoWallpaperRepeatCountPerItem(27);
      expect(
        settingsService.videoWallpaperRepeatCountPerItem,
        SettingsService.videoWallpaperRepeatCountPerItemMax,
      );

      await settingsService.setVideoWallpaperRepeatCountPerItem(0);
      expect(
        settingsService.videoWallpaperRepeatCountPerItem,
        SettingsService.videoWallpaperRepeatCountPerItemMin,
      );
    });

    test("clock scale snaps to supported range and steps", () async {
      await settingsService.setStatusBarClockScalePercent(183);
      expect(
        settingsService.statusBarClockScalePercent,
        SettingsService.statusBarClockScaleMax,
      );

      await settingsService.setStatusBarClockScalePercent(133);
      expect(settingsService.statusBarClockScalePercent, 130);

      await settingsService.setStatusBarClockScalePercent(65);
      expect(
        settingsService.statusBarClockScalePercent,
        SettingsService.statusBarClockScaleMin,
      );
    });

    test("auto collapse delay snaps to supported range and steps", () async {
      await settingsService.setHomeDockAutoCollapseDelaySeconds(63);
      expect(
        settingsService.homeDockAutoCollapseDelaySeconds,
        SettingsService.homeDockAutoCollapseDelayMax,
      );

      await settingsService.setHomeDockAutoCollapseDelaySeconds(27);
      expect(settingsService.homeDockAutoCollapseDelaySeconds, 25);

      await settingsService.setHomeDockAutoCollapseDelaySeconds(1);
      expect(
        settingsService.homeDockAutoCollapseDelaySeconds,
        SettingsService.homeDockAutoCollapseDelayMin,
      );
    });

    test("collapsed rows stay within the supported range", () async {
      await settingsService.setHomeDockCollapsedRowsPreset(9);
      expect(
        settingsService.homeDockCollapsedRowsPreset,
        SettingsService.homeDockCollapsedRowsMax,
      );

      await settingsService.setHomeDockCollapsedRowsPreset(-1);
      expect(
        settingsService.homeDockCollapsedRowsPreset,
        SettingsService.homeDockCollapsedRowsMin,
      );
    });

    test("row spacing snaps to supported range and steps", () async {
      await settingsService.setHomeDockRowSpacing(29);
      expect(
        settingsService.homeDockRowSpacing,
        SettingsService.homeDockRowSpacingMax,
      );

      await settingsService.setHomeDockRowSpacing(9);
      expect(settingsService.homeDockRowSpacing, 9);

      await settingsService.setHomeDockRowSpacing(1);
      expect(
        settingsService.homeDockRowSpacing,
        1,
      );
    });

    test("settings transparency snaps to supported range and steps", () async {
      await settingsService.setSettingsUiTransparencyPercent(96);
      expect(
        settingsService.settingsUiTransparencyPercent,
        SettingsService.settingsUiTransparencyMax,
      );

      await settingsService.setSettingsUiTransparencyPercent(34);
      expect(settingsService.settingsUiTransparencyPercent, 35);

      await settingsService.setSettingsUiTransparencyPercent(1);
      expect(
        settingsService.settingsUiTransparencyPercent,
        0,
      );
    });
  });

  group("settingsBackdropTheme", () {
    test("defaults to deepSlate when nothing is stored", () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      await sharedPreferences.clear();
      final service = SettingsService(sharedPreferences);

      expect(service.settingsBackdropTheme, TvSettingsBackdropTheme.deepSlate);
    });

    test("saves and restores each TvSettingsBackdropTheme accurately", () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      await sharedPreferences.clear();
      final service = SettingsService(sharedPreferences);

      // Default is deepSlate. Transition through all themes including deepSlate
      const sequence = [
        TvSettingsBackdropTheme.obsidianOled,
        TvSettingsBackdropTheme.oceanNavy,
        TvSettingsBackdropTheme.smokyAmethyst,
        TvSettingsBackdropTheme.forestMoss,
        TvSettingsBackdropTheme.warmEspresso,
        TvSettingsBackdropTheme.deepSlate,
      ];
      for (final theme in sequence) {
        await service.setSettingsBackdropTheme(theme);
        expect(service.settingsBackdropTheme, theme);
        expect(
          sharedPreferences.getString("settings_backdrop_theme"),
          theme.key,
        );
      }
    });

    test("safely falls back to deepSlate for null, empty, wrong type or invalid string keys", () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      await sharedPreferences.clear();
      final service = SettingsService(sharedPreferences);

      // Null or not set
      expect(service.settingsBackdropTheme, TvSettingsBackdropTheme.deepSlate);

      // Empty string
      await sharedPreferences.setString("settings_backdrop_theme", "");
      expect(service.settingsBackdropTheme, TvSettingsBackdropTheme.deepSlate);

      // Invalid string key
      await sharedPreferences.setString("settings_backdrop_theme", "non_existent_key_xyz");
      expect(service.settingsBackdropTheme, TvSettingsBackdropTheme.deepSlate);

      // Directly test TvSettingsBackdropTheme.fromKey
      expect(TvSettingsBackdropTheme.fromKey(null), TvSettingsBackdropTheme.deepSlate);
      expect(TvSettingsBackdropTheme.fromKey(""), TvSettingsBackdropTheme.deepSlate);
      expect(TvSettingsBackdropTheme.fromKey("unknown"), TvSettingsBackdropTheme.deepSlate);
      expect(TvSettingsBackdropTheme.fromKey("obsidian_oled"), TvSettingsBackdropTheme.obsidianOled);
      expect(TvSettingsBackdropTheme.fromKey("ocean_navy"), TvSettingsBackdropTheme.oceanNavy);
      expect(TvSettingsBackdropTheme.fromKey("smoky_amethyst"), TvSettingsBackdropTheme.smokyAmethyst);
      expect(TvSettingsBackdropTheme.fromKey("forest_moss"), TvSettingsBackdropTheme.forestMoss);
      expect(TvSettingsBackdropTheme.fromKey("warm_espresso"), TvSettingsBackdropTheme.warmEspresso);
      expect(TvSettingsBackdropTheme.fromKey("deep_slate"), TvSettingsBackdropTheme.deepSlate);
    });

    test("notifies listeners on theme change and does not notify when setting same theme (idempotency)", () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      await sharedPreferences.clear();
      final service = SettingsService(sharedPreferences);

      var notifyCount = 0;
      service.addListener(() {
        notifyCount++;
      });

      // Default is deepSlate. Setting deepSlate again should not notify (idempotent)
      await service.setSettingsBackdropTheme(TvSettingsBackdropTheme.deepSlate);
      expect(notifyCount, 0);

      // Changing to oceanNavy should notify once
      await service.setSettingsBackdropTheme(TvSettingsBackdropTheme.oceanNavy);
      expect(notifyCount, 1);
      expect(service.settingsBackdropTheme, TvSettingsBackdropTheme.oceanNavy);

      // Setting oceanNavy again should not notify
      await service.setSettingsBackdropTheme(TvSettingsBackdropTheme.oceanNavy);
      expect(notifyCount, 1);

      // Changing to warmEspresso should notify
      await service.setSettingsBackdropTheme(TvSettingsBackdropTheme.warmEspresso);
      expect(notifyCount, 2);
      expect(service.settingsBackdropTheme, TvSettingsBackdropTheme.warmEspresso);
    });

    test("backup and restore preserves settingsBackdropTheme correctly", () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      await sharedPreferences.clear();
      final service = SettingsService(sharedPreferences);

      await service.setSettingsBackdropTheme(TvSettingsBackdropTheme.smokyAmethyst);
      final backup = service.toBackupMap();
      expect(backup['settingsBackdropTheme'], 'smoky_amethyst');

      // Clear preferences to simulate new device / reset
      await sharedPreferences.clear();
      final restoredService = SettingsService(sharedPreferences);
      expect(restoredService.settingsBackdropTheme, TvSettingsBackdropTheme.deepSlate);

      await restoredService.applyBackupMap(backup);
      expect(restoredService.settingsBackdropTheme, TvSettingsBackdropTheme.smokyAmethyst);

      // Fallback check when backup contains an invalid or unknown theme key
      await restoredService.applyBackupMap(const <String, dynamic>{
        'settingsBackdropTheme': 'hacked_or_unknown_theme',
      });
      expect(restoredService.settingsBackdropTheme, TvSettingsBackdropTheme.deepSlate);
    });

    test("locale migration and sanitization defaults to Vietnamese", () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      await sharedPreferences.clear();

      // Case 1: fresh install or null locale migrates to Vietnamese
      final freshService = SettingsService(sharedPreferences);
      expect(freshService.appLocaleMode, SettingsService.appLocaleVietnamese);

      // Case 2: legacy 'system' locale migrates to Vietnamese
      await sharedPreferences.setString('app_locale_mode', 'system');
      final legacyService = SettingsService(sharedPreferences);
      expect(legacyService.appLocaleMode, SettingsService.appLocaleVietnamese);

      // Case 3: english is preserved
      await legacyService.setAppLocaleMode('en');
      expect(legacyService.appLocaleMode, SettingsService.appLocaleEnglish);

      // Case 4: any invalid/unknown locale sanitizes to Vietnamese
      await legacyService.setAppLocaleMode('fr');
      expect(legacyService.appLocaleMode, SettingsService.appLocaleVietnamese);

      // Case 5: backup restore sanitizes locale
      await legacyService.applyBackupMap(const <String, dynamic>{
        'appLocaleMode': 'unknown_lang',
      });
      expect(legacyService.appLocaleMode, SettingsService.appLocaleVietnamese);

      await legacyService.applyBackupMap(const <String, dynamic>{
        'appLocaleMode': 'en',
      });
      expect(legacyService.appLocaleMode, SettingsService.appLocaleEnglish);
    });

    test("statusBarDateStyle getter, setter, default, and backup/restore", () async {
      final sharedPreferences = await SharedPreferences.getInstance();
      await sharedPreferences.clear();
      final settingsService = SettingsService(sharedPreferences);

      expect(settingsService.statusBarDateStyle, SettingsService.defaultDateStyle);

      await settingsService.setStatusBarDateStyle(SettingsService.dateStyleBold);
      expect(settingsService.statusBarDateStyle, SettingsService.dateStyleBold);

      await settingsService.setStatusBarDateStyle(SettingsService.dateStyleMonospace);
      expect(settingsService.statusBarDateStyle, SettingsService.dateStyleMonospace);

      await settingsService.setDateFormat("Thứ 5 ngày d/M/y");
      expect(settingsService.dateFormat, "Thứ 5 ngày d/M/y");

      final backup = settingsService.toBackupMap();
      expect(backup['statusBarDateStyle'], SettingsService.dateStyleMonospace);
      expect(backup['dateFormat'], "Thứ 5 ngày d/M/y");

      await sharedPreferences.clear();
      final freshService = SettingsService(sharedPreferences);
      await freshService.applyBackupMap(backup);
      expect(freshService.statusBarDateStyle, SettingsService.dateStyleMonospace);
      expect(freshService.dateFormat, "Thứ 5 ngày d/M/y");
    });
  });
}
