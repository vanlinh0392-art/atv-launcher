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
        SettingsService.homeDockPerformanceModeDefault,
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
        'appCardCornerRadius': 18,
        'appCardLayoutScalePercent': 95,
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
      expect(settingsService.appCardCornerRadius, 18);
      expect(settingsService.appCardLayoutScalePercent, 95);
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
      expect(backup['appCardCornerRadius'], 18);
      expect(backup['appCardLayoutScalePercent'], 95);
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
      await settingsService.setAppCardMediaScalePercent(125);
      await settingsService.setVideoWallpaperRepeatCountPerItem(8);
      await settingsService.setStatusBarClockScalePercent(180);

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
        SettingsService.homeDockPerformanceModeDefault,
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
}
