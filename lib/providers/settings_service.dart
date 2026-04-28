/*
 * FLauncher
 * Copyright (C) 2021  Etienne Fesser
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

import 'dart:async';

import 'package:flauncher/widgets/settings/back_button_actions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _appHighlightAnimationEnabledKey = "app_highlight_animation_enabled";
const _appKeyClickEnabledKey = "app_key_click_enabled";
const _autoHideAppBar = "auto_hide_app_bar";
const _gradientUuidKey = "gradient_uuid";
const _backButtonAction = "back_button_action";
const _dateFormat = "date_format";
const _homeDockRowsPreset = "home_dock_rows_preset";
const _homeDockCollapsedRowsPreset = "home_dock_collapsed_rows_preset";
const _homeDockAutoCollapseEnabled = "home_dock_auto_collapse_enabled";
const _homeDockAutoCollapseDelaySeconds =
    "home_dock_auto_collapse_delay_seconds";
const _homeDockBlurEnabled = "home_dock_blur_enabled";
const _homeDockGlassIntensityPercent = "home_dock_glass_intensity_percent";
const _homeDockRowSpacing = "home_dock_row_spacing";
const _appLocaleMode = "app_locale_mode";
const _showCategoryTitles = "show_category_titles";
const _showDateInStatusBar = "show_date_in_status_bar";
const _showRamInStatusBar = "show_ram_in_status_bar";
const _statusBarClockScalePercent = "status_bar_clock_scale_percent";
const _showTimeInStatusBar = "show_time_in_status_bar";
const _timeFormat = "time_format";
const _appCardCornerRadius = "app_card_corner_radius";
const _appCardLayoutScalePercent = "app_card_layout_scale_percent";
const _appCardMediaScalePercent = "app_card_media_scale_percent";
const _wallpaperMode = "wallpaper_mode";
const _wallpaperAssetUri = "wallpaper_asset_uri";
const _wallpaperPreviewPath = "wallpaper_preview_path";
const _videoWallpaperSourceType = "video_wallpaper_source_type";
const _videoWallpaperUris = "video_wallpaper_uris";
const _videoWallpaperFolderUri = "video_wallpaper_folder_uri";
const _videoWallpaperFolderBucketId = "video_wallpaper_folder_bucket_id";
const _videoWallpaperFolderName = "video_wallpaper_folder_name";
const _videoWallpaperOrderMode = "video_wallpaper_order_mode";
const _videoWallpaperAdvanceMode = "video_wallpaper_advance_mode";
const _videoWallpaperSwitchIntervalSeconds =
    "video_wallpaper_switch_interval_seconds";
const _videoWallpaperPlaylistLoop = "video_wallpaper_playlist_loop";
const _videoWallpaperLoop = "video_wallpaper_loop";
const _videoWallpaperMute = "video_wallpaper_mute";
const _videoWallpaperFit = "video_wallpaper_fit";
const _videoWallpaperDimPercent = "video_wallpaper_dim_percent";
const _videoWallpaperBlur = "video_wallpaper_blur";
const _videoWallpaperAutoResume = "video_wallpaper_auto_resume";
const _backupLastExportName = "backup_last_export_name";
const _backupLastImportName = "backup_last_import_name";
const _backupLastRestoreSummary = "backup_last_restore_summary";
const _backupLastRestoreAt = "backup_last_restore_at";

class SettingsService extends ChangeNotifier {
  static final defaultDateFormat = "EEEE d";
  static final defaultTimeFormat = "H:mm";
  static const String appLocaleSystem = "system";
  static const String appLocaleEnglish = "en";
  static const String appLocaleVietnamese = "vi";
  static const int appCardLayoutScaleMin = 70;
  static const int appCardLayoutScaleMax = 115;
  static const int appCardLayoutScaleDefault = 85;
  static const int appCardLayoutScaleStep = 5;
  static const int appCardMediaScaleMin = 80;
  static const int appCardMediaScaleMax = 125;
  static const int appCardMediaScaleDefault = 100;
  static const int appCardMediaScaleStep = 5;
  static const int statusBarClockScaleMin = 100;
  static const int statusBarClockScaleMax = 180;
  static const int statusBarClockScaleDefault = 100;
  static const int statusBarClockScaleStep = 10;
  static const int homeDockGlassIntensityMin = 0;
  static const int homeDockGlassIntensityMax = 100;
  static const int homeDockGlassIntensityDefault = 0;
  static const int homeDockGlassIntensityStep = 5;
  static const int homeDockGlassIntensityLegacyOnDefault = 55;
  static const int homeDockAutoCollapseDelayMin = 5;
  static const int homeDockAutoCollapseDelayMax = 60;
  static const int homeDockAutoCollapseDelayDefault = 15;
  static const int homeDockAutoCollapseDelayStep = 5;
  static const int homeDockCollapsedRowsMin = 1;
  static const int homeDockCollapsedRowsMax = 2;
  static const int homeDockCollapsedRowsDefault = 1;
  static const int homeDockRowSpacingMin = 4;
  static const int homeDockRowSpacingMax = 28;
  static const int homeDockRowSpacingDefault = 12;
  static const int homeDockRowSpacingStep = 2;

  final SharedPreferences _sharedPreferences;

  bool get appHighlightAnimationEnabled =>
      _sharedPreferences.getBool(_appHighlightAnimationEnabledKey) ?? true;

  bool get appKeyClickEnabled =>
      _sharedPreferences.getBool(_appKeyClickEnabledKey) ?? true;

  bool get autoHideAppBarEnabled =>
      _sharedPreferences.getBool(_autoHideAppBar) ?? false;

  bool get showCategoryTitles =>
      _sharedPreferences.getBool(_showCategoryTitles) ?? true;

  bool get showDateInStatusBar =>
      _sharedPreferences.getBool(_showDateInStatusBar) ?? true;

  bool get showRamInStatusBar =>
      _sharedPreferences.getBool(_showRamInStatusBar) ?? false;

  int get statusBarClockScalePercent => _normalizeStatusBarClockScale(
      _sharedPreferences.getInt(_statusBarClockScalePercent) ??
          statusBarClockScaleDefault);

  bool get showTimeInStatusBar =>
      _sharedPreferences.getBool(_showTimeInStatusBar) ?? true;

  String? get gradientUuid => _sharedPreferences.getString(_gradientUuidKey);

  String get backButtonAction =>
      _sharedPreferences.getString(_backButtonAction) ??
      BACK_BUTTON_ACTION_NOTHING;

  String get dateFormat =>
      _sharedPreferences.getString(_dateFormat) ?? defaultDateFormat;

  int get homeDockRowsPreset =>
      (_sharedPreferences.getInt(_homeDockRowsPreset) ?? 3).clamp(2, 4);

  int get homeDockCollapsedRowsPreset => _normalizeHomeDockCollapsedRows(
        _sharedPreferences.getInt(_homeDockCollapsedRowsPreset) ??
            homeDockCollapsedRowsDefault,
      );

  bool get homeDockAutoCollapseEnabled =>
      _sharedPreferences.getBool(_homeDockAutoCollapseEnabled) ?? true;

  int get homeDockAutoCollapseDelaySeconds =>
      _normalizeHomeDockAutoCollapseDelay(
        _sharedPreferences.getInt(_homeDockAutoCollapseDelaySeconds) ??
            homeDockAutoCollapseDelayDefault,
      );

  int get homeDockGlassIntensityPercent {
    if (_sharedPreferences.containsKey(_homeDockGlassIntensityPercent)) {
      return _normalizeHomeDockGlassIntensity(
        _sharedPreferences.getInt(_homeDockGlassIntensityPercent) ??
            homeDockGlassIntensityDefault,
      );
    }
    final legacyBlurEnabled =
        _sharedPreferences.getBool(_homeDockBlurEnabled) ?? false;
    return legacyBlurEnabled ? homeDockGlassIntensityLegacyOnDefault : 0;
  }

  bool get homeDockBlurEnabled => homeDockGlassIntensityPercent > 0;

  int get homeDockRowSpacing => _normalizeHomeDockRowSpacing(
        _sharedPreferences.getInt(_homeDockRowSpacing) ??
            homeDockRowSpacingDefault,
      );

  String get appLocaleMode => _sanitizeAppLocaleMode(
      _sharedPreferences.getString(_appLocaleMode) ?? appLocaleSystem);

  String get timeFormat =>
      _sharedPreferences.getString(_timeFormat) ?? defaultTimeFormat;

  int get appCardCornerRadius =>
      (_sharedPreferences.getInt(_appCardCornerRadius) ?? 8).clamp(0, 24);

  int get appCardLayoutScalePercent => _normalizeAppCardLayoutScale(
      _sharedPreferences.getInt(_appCardLayoutScalePercent) ??
          appCardLayoutScaleDefault);

  int get appCardMediaScalePercent => _normalizeAppCardMediaScale(
      _sharedPreferences.getInt(_appCardMediaScalePercent) ??
          appCardMediaScaleDefault);

  String get wallpaperMode =>
      _sharedPreferences.getString(_wallpaperMode) ?? "gradient";

  String get wallpaperAssetUri =>
      _sharedPreferences.getString(_wallpaperAssetUri) ?? "";

  String get wallpaperPreviewPath =>
      _sharedPreferences.getString(_wallpaperPreviewPath) ?? "";

  String get videoWallpaperSourceType =>
      _sharedPreferences.getString(_videoWallpaperSourceType) ?? "single_file";

  List<String> get videoWallpaperUris =>
      _sharedPreferences.getStringList(_videoWallpaperUris) ?? const <String>[];

  String get videoWallpaperFolderUri =>
      _sharedPreferences.getString(_videoWallpaperFolderUri) ?? "";

  String get videoWallpaperFolderBucketId =>
      _sharedPreferences.getString(_videoWallpaperFolderBucketId) ?? "";

  String get videoWallpaperFolderName =>
      _sharedPreferences.getString(_videoWallpaperFolderName) ?? "";

  String get videoWallpaperOrderMode =>
      _sharedPreferences.getString(_videoWallpaperOrderMode) ?? "sequential";

  String get videoWallpaperAdvanceMode =>
      _sharedPreferences.getString(_videoWallpaperAdvanceMode) ??
      "on_completion";

  int get videoWallpaperSwitchIntervalSeconds =>
      _sharedPreferences.getInt(_videoWallpaperSwitchIntervalSeconds) ?? 30;

  bool get videoWallpaperPlaylistLoop =>
      _sharedPreferences.getBool(_videoWallpaperPlaylistLoop) ?? true;

  bool get videoWallpaperLoop =>
      _sharedPreferences.getBool(_videoWallpaperLoop) ?? true;

  bool get videoWallpaperMute =>
      _sharedPreferences.getBool(_videoWallpaperMute) ?? true;

  String get videoWallpaperFit =>
      _sharedPreferences.getString(_videoWallpaperFit) ?? "center-crop";

  int get videoWallpaperDimPercent =>
      _sharedPreferences.getInt(_videoWallpaperDimPercent) ?? 15;

  String get videoWallpaperBlur =>
      _sharedPreferences.getString(_videoWallpaperBlur) ?? "off";

  bool get videoWallpaperAutoResume =>
      _sharedPreferences.getBool(_videoWallpaperAutoResume) ?? true;

  String get backupLastExportName =>
      _sharedPreferences.getString(_backupLastExportName) ?? "";

  String get backupLastImportName =>
      _sharedPreferences.getString(_backupLastImportName) ?? "";

  String get backupLastRestoreSummary =>
      _sharedPreferences.getString(_backupLastRestoreSummary) ?? "";

  int get backupLastRestoreAt =>
      _sharedPreferences.getInt(_backupLastRestoreAt) ?? 0;

  SettingsService(this._sharedPreferences);

  Future<void> set(String key, bool value) async {
    await _sharedPreferences.setBool(key, value);
    notifyListeners();
  }

  Future<void> setAppHighlightAnimationEnabled(bool value) async {
    return set(_appHighlightAnimationEnabledKey, value);
  }

  Future<void> setAppKeyClickEnabled(bool value) async {
    return set(_appKeyClickEnabledKey, value);
  }

  Future<void> setAutoHideAppBarEnabled(bool value) async {
    return set(_autoHideAppBar, value);
  }

  Future<void> setGradientUuid(String value) async {
    await _sharedPreferences.setString(_gradientUuidKey, value);
    notifyListeners();
  }

  Future<void> setBackButtonAction(String value) async {
    await _sharedPreferences.setString(_backButtonAction, value);
    notifyListeners();
  }

  Future<void> setDateTimeFormat(
      String dateFormatString, String timeFormatString) async {
    await Future.wait([
      _sharedPreferences.setString(_dateFormat, dateFormatString),
      _sharedPreferences.setString(_timeFormat, timeFormatString),
    ]);
    notifyListeners();
  }

  Future<void> setHomeDockRowsPreset(int value) async {
    await _sharedPreferences.setInt(_homeDockRowsPreset, value.clamp(2, 4));
    notifyListeners();
  }

  Future<void> setHomeDockCollapsedRowsPreset(int value) async {
    await _sharedPreferences.setInt(
      _homeDockCollapsedRowsPreset,
      _normalizeHomeDockCollapsedRows(value),
    );
    notifyListeners();
  }

  Future<void> setHomeDockAutoCollapseEnabled(bool enabled) async {
    return set(_homeDockAutoCollapseEnabled, enabled);
  }

  Future<void> setHomeDockAutoCollapseDelaySeconds(int value) async {
    await _sharedPreferences.setInt(
      _homeDockAutoCollapseDelaySeconds,
      _normalizeHomeDockAutoCollapseDelay(value),
    );
    notifyListeners();
  }

  Future<void> setHomeDockBlurEnabled(bool enabled) async {
    return setHomeDockGlassIntensityPercent(
      enabled ? homeDockGlassIntensityLegacyOnDefault : 0,
    );
  }

  Future<void> setHomeDockGlassIntensityPercent(int value) async {
    final normalized = _normalizeHomeDockGlassIntensity(value);
    await Future.wait([
      _sharedPreferences.setInt(_homeDockGlassIntensityPercent, normalized),
      _sharedPreferences.setBool(_homeDockBlurEnabled, normalized > 0),
    ]);
    notifyListeners();
  }

  Future<void> setHomeDockRowSpacing(int value) async {
    await _sharedPreferences.setInt(
      _homeDockRowSpacing,
      _normalizeHomeDockRowSpacing(value),
    );
    notifyListeners();
  }

  Future<void> setAppLocaleMode(String value) async {
    await _sharedPreferences.setString(
        _appLocaleMode, _sanitizeAppLocaleMode(value));
    notifyListeners();
  }

  Future<void> setShowCategoryTitles(bool show) async {
    return set(_showCategoryTitles, show);
  }

  Future<void> setShowDateInStatusBar(bool show) async {
    return set(_showDateInStatusBar, show);
  }

  Future<void> setShowRamInStatusBar(bool show) async {
    return set(_showRamInStatusBar, show);
  }

  Future<void> setStatusBarClockScalePercent(int value) async {
    await _sharedPreferences.setInt(
      _statusBarClockScalePercent,
      _normalizeStatusBarClockScale(value),
    );
    notifyListeners();
  }

  Future<void> setShowTimeInStatusBar(bool show) async {
    return set(_showTimeInStatusBar, show);
  }

  Future<void> setAppCardCornerRadius(int value) async {
    await _sharedPreferences.setInt(_appCardCornerRadius, value.clamp(0, 24));
    notifyListeners();
  }

  Future<void> setAppCardLayoutScalePercent(int value) async {
    await _sharedPreferences.setInt(
      _appCardLayoutScalePercent,
      _normalizeAppCardLayoutScale(value),
    );
    notifyListeners();
  }

  Future<void> setAppCardMediaScalePercent(int value) async {
    await _sharedPreferences.setInt(
      _appCardMediaScalePercent,
      _normalizeAppCardMediaScale(value),
    );
    notifyListeners();
  }

  Future<void> setWallpaperMode(String value) async {
    await _sharedPreferences.setString(_wallpaperMode, value);
    notifyListeners();
  }

  Future<void> setWallpaperAssetUri(String value) async {
    await _sharedPreferences.setString(_wallpaperAssetUri, value);
    notifyListeners();
  }

  Future<void> setWallpaperPreviewPath(String value) async {
    await _sharedPreferences.setString(_wallpaperPreviewPath, value);
    notifyListeners();
  }

  Future<void> setVideoWallpaperSourceType(String value) async {
    await _sharedPreferences.setString(_videoWallpaperSourceType, value);
    notifyListeners();
  }

  Future<void> setVideoWallpaperUris(List<String> values) async {
    await _sharedPreferences.setStringList(
      _videoWallpaperUris,
      values
          .where((value) => value.trim().isNotEmpty)
          .map((value) => value.trim())
          .toList(growable: false),
    );
    notifyListeners();
  }

  Future<void> setVideoWallpaperFolderUri(String value) async {
    await _sharedPreferences.setString(_videoWallpaperFolderUri, value);
    notifyListeners();
  }

  Future<void> setVideoWallpaperFolderBucketId(String value) async {
    await _sharedPreferences.setString(_videoWallpaperFolderBucketId, value);
    notifyListeners();
  }

  Future<void> setVideoWallpaperFolderName(String value) async {
    await _sharedPreferences.setString(_videoWallpaperFolderName, value);
    notifyListeners();
  }

  Future<void> setVideoWallpaperOrderMode(String value) async {
    await _sharedPreferences.setString(_videoWallpaperOrderMode, value);
    notifyListeners();
  }

  Future<void> setVideoWallpaperAdvanceMode(String value) async {
    await _sharedPreferences.setString(_videoWallpaperAdvanceMode, value);
    notifyListeners();
  }

  Future<void> setVideoWallpaperSwitchIntervalSeconds(int value) async {
    await _sharedPreferences.setInt(
      _videoWallpaperSwitchIntervalSeconds,
      value.clamp(5, 86400).toInt(),
    );
    notifyListeners();
  }

  Future<void> setVideoWallpaperPlaylistLoop(bool value) async {
    await _sharedPreferences.setBool(_videoWallpaperPlaylistLoop, value);
    notifyListeners();
  }

  Future<void> setVideoWallpaperLoop(bool value) async {
    await _sharedPreferences.setBool(_videoWallpaperLoop, value);
    notifyListeners();
  }

  Future<void> setVideoWallpaperMute(bool value) async {
    await _sharedPreferences.setBool(_videoWallpaperMute, value);
    notifyListeners();
  }

  Future<void> setVideoWallpaperFit(String value) async {
    await _sharedPreferences.setString(_videoWallpaperFit, value);
    notifyListeners();
  }

  Future<void> setVideoWallpaperDimPercent(int value) async {
    await _sharedPreferences.setInt(_videoWallpaperDimPercent, value);
    notifyListeners();
  }

  Future<void> setVideoWallpaperBlur(String value) async {
    await _sharedPreferences.setString(_videoWallpaperBlur, value);
    notifyListeners();
  }

  Future<void> setVideoWallpaperAutoResume(bool value) async {
    await _sharedPreferences.setBool(_videoWallpaperAutoResume, value);
    notifyListeners();
  }

  Future<void> setBackupLastExportName(String value) async {
    await _sharedPreferences.setString(_backupLastExportName, value);
    notifyListeners();
  }

  Future<void> setBackupLastImportName(String value) async {
    await _sharedPreferences.setString(_backupLastImportName, value);
    notifyListeners();
  }

  Future<void> setBackupLastRestoreSummary(String value) async {
    await _sharedPreferences.setString(_backupLastRestoreSummary, value);
    notifyListeners();
  }

  Future<void> setBackupLastRestoreAt(int epochMillis) async {
    await _sharedPreferences.setInt(_backupLastRestoreAt, epochMillis);
    notifyListeners();
  }

  Map<String, dynamic> toBackupMap() {
    return <String, dynamic>{
      'appHighlightAnimationEnabled': appHighlightAnimationEnabled,
      'appKeyClickEnabled': appKeyClickEnabled,
      'autoHideAppBarEnabled': autoHideAppBarEnabled,
      'gradientUuid': gradientUuid,
      'backButtonAction': backButtonAction,
      'dateFormat': dateFormat,
      'homeDockRowsPreset': homeDockRowsPreset,
      'homeDockCollapsedRowsPreset': homeDockCollapsedRowsPreset,
      'homeDockAutoCollapseEnabled': homeDockAutoCollapseEnabled,
      'homeDockAutoCollapseDelaySeconds': homeDockAutoCollapseDelaySeconds,
      'homeDockBlurEnabled': homeDockBlurEnabled,
      'homeDockGlassIntensityPercent': homeDockGlassIntensityPercent,
      'homeDockRowSpacing': homeDockRowSpacing,
      'appLocaleMode': appLocaleMode,
      'statusBarClockScalePercent': statusBarClockScalePercent,
      'timeFormat': timeFormat,
      'appCardCornerRadius': appCardCornerRadius,
      'appCardLayoutScalePercent': appCardLayoutScalePercent,
      'appCardMediaScalePercent': appCardMediaScalePercent,
      'showCategoryTitles': showCategoryTitles,
      'showDateInStatusBar': showDateInStatusBar,
      'showRamInStatusBar': showRamInStatusBar,
      'showTimeInStatusBar': showTimeInStatusBar,
      'wallpaperMode': wallpaperMode,
      'wallpaperAssetUri': wallpaperAssetUri,
      'wallpaperPreviewPath': wallpaperPreviewPath,
      'videoWallpaperSourceType': videoWallpaperSourceType,
      'videoWallpaperUris': videoWallpaperUris,
      'videoWallpaperFolderUri': videoWallpaperFolderUri,
      'videoWallpaperFolderBucketId': videoWallpaperFolderBucketId,
      'videoWallpaperFolderName': videoWallpaperFolderName,
      'videoWallpaperOrderMode': videoWallpaperOrderMode,
      'videoWallpaperAdvanceMode': videoWallpaperAdvanceMode,
      'videoWallpaperSwitchIntervalSeconds':
          videoWallpaperSwitchIntervalSeconds,
      'videoWallpaperPlaylistLoop': videoWallpaperPlaylistLoop,
      'videoWallpaperLoop': videoWallpaperLoop,
      'videoWallpaperMute': videoWallpaperMute,
      'videoWallpaperFit': videoWallpaperFit,
      'videoWallpaperDimPercent': videoWallpaperDimPercent,
      'videoWallpaperBlur': videoWallpaperBlur,
      'videoWallpaperAutoResume': videoWallpaperAutoResume,
    };
  }

  Future<void> applyBackupMap(Map<String, dynamic> data) async {
    await Future.wait([
      _sharedPreferences.setBool(
        _appHighlightAnimationEnabledKey,
        _readBool(
            data, 'appHighlightAnimationEnabled', appHighlightAnimationEnabled),
      ),
      _sharedPreferences.setBool(
        _appKeyClickEnabledKey,
        _readBool(data, 'appKeyClickEnabled', appKeyClickEnabled),
      ),
      _sharedPreferences.setBool(
        _autoHideAppBar,
        _readBool(data, 'autoHideAppBarEnabled', autoHideAppBarEnabled),
      ),
      _sharedPreferences.setString(
        _gradientUuidKey,
        _readString(data, 'gradientUuid', gradientUuid ?? ''),
      ),
      _sharedPreferences.setString(
        _backButtonAction,
        _readString(data, 'backButtonAction', backButtonAction),
      ),
      _sharedPreferences.setString(
          _dateFormat, _readString(data, 'dateFormat', dateFormat)),
      _sharedPreferences.setInt(
        _homeDockRowsPreset,
        _readInt(data, 'homeDockRowsPreset', homeDockRowsPreset)
            .clamp(2, 4)
            .toInt(),
      ),
      _sharedPreferences.setInt(
        _homeDockCollapsedRowsPreset,
        _normalizeHomeDockCollapsedRows(
          _readInt(
            data,
            'homeDockCollapsedRowsPreset',
            homeDockCollapsedRowsDefault,
          ),
        ),
      ),
      _sharedPreferences.setBool(
        _homeDockAutoCollapseEnabled,
        _readBool(
          data,
          'homeDockAutoCollapseEnabled',
          true,
        ),
      ),
      _sharedPreferences.setInt(
        _homeDockAutoCollapseDelaySeconds,
        _normalizeHomeDockAutoCollapseDelay(
          _readInt(
            data,
            'homeDockAutoCollapseDelaySeconds',
            homeDockAutoCollapseDelayDefault,
          ),
        ),
      ),
      _sharedPreferences.setBool(
        _homeDockBlurEnabled,
        _resolveHomeDockBlurEnabledForBackup(data),
      ),
      _sharedPreferences.setInt(
        _homeDockGlassIntensityPercent,
        _resolveHomeDockGlassIntensityForBackup(data),
      ),
      _sharedPreferences.setInt(
        _homeDockRowSpacing,
        _normalizeHomeDockRowSpacing(
          _readInt(
            data,
            'homeDockRowSpacing',
            homeDockRowSpacingDefault,
          ),
        ),
      ),
      _sharedPreferences.setString(
        _appLocaleMode,
        _sanitizeAppLocaleMode(
          _readString(data, 'appLocaleMode', appLocaleSystem),
        ),
      ),
      _sharedPreferences.setInt(
        _statusBarClockScalePercent,
        _normalizeStatusBarClockScale(
          _readInt(
            data,
            'statusBarClockScalePercent',
            statusBarClockScaleDefault,
          ),
        ),
      ),
      _sharedPreferences.setString(
          _timeFormat, _readString(data, 'timeFormat', timeFormat)),
      _sharedPreferences.setInt(
        _appCardCornerRadius,
        _readInt(data, 'appCardCornerRadius', appCardCornerRadius)
            .clamp(0, 24)
            .toInt(),
      ),
      _sharedPreferences.setInt(
        _appCardLayoutScalePercent,
        _normalizeAppCardLayoutScale(
          _readInt(
            data,
            'appCardLayoutScalePercent',
            appCardLayoutScaleDefault,
          ),
        ),
      ),
      _sharedPreferences.setInt(
        _appCardMediaScalePercent,
        _normalizeAppCardMediaScale(
          _readInt(
            data,
            'appCardMediaScalePercent',
            appCardMediaScaleDefault,
          ),
        ),
      ),
      _sharedPreferences.setBool(
        _showCategoryTitles,
        _readBool(data, 'showCategoryTitles', showCategoryTitles),
      ),
      _sharedPreferences.setBool(
        _showDateInStatusBar,
        _readBool(data, 'showDateInStatusBar', showDateInStatusBar),
      ),
      _sharedPreferences.setBool(
        _showRamInStatusBar,
        _readBool(data, 'showRamInStatusBar', showRamInStatusBar),
      ),
      _sharedPreferences.setBool(
        _showTimeInStatusBar,
        _readBool(data, 'showTimeInStatusBar', showTimeInStatusBar),
      ),
      _sharedPreferences.setString(
        _wallpaperMode,
        _readString(data, 'wallpaperMode', wallpaperMode),
      ),
      _sharedPreferences.setString(
        _wallpaperAssetUri,
        _readString(data, 'wallpaperAssetUri', wallpaperAssetUri),
      ),
      _sharedPreferences.setString(
        _wallpaperPreviewPath,
        _readString(data, 'wallpaperPreviewPath', wallpaperPreviewPath),
      ),
      _sharedPreferences.setString(
        _videoWallpaperSourceType,
        _readString(data, 'videoWallpaperSourceType', videoWallpaperSourceType),
      ),
      _sharedPreferences.setStringList(
        _videoWallpaperUris,
        _readStringList(data, 'videoWallpaperUris', videoWallpaperUris),
      ),
      _sharedPreferences.setString(
        _videoWallpaperFolderUri,
        _readString(data, 'videoWallpaperFolderUri', videoWallpaperFolderUri),
      ),
      _sharedPreferences.setString(
        _videoWallpaperFolderBucketId,
        _readString(
            data, 'videoWallpaperFolderBucketId', videoWallpaperFolderBucketId),
      ),
      _sharedPreferences.setString(
        _videoWallpaperFolderName,
        _readString(data, 'videoWallpaperFolderName', videoWallpaperFolderName),
      ),
      _sharedPreferences.setString(
        _videoWallpaperOrderMode,
        _readString(data, 'videoWallpaperOrderMode', videoWallpaperOrderMode),
      ),
      _sharedPreferences.setString(
        _videoWallpaperAdvanceMode,
        _readString(
            data, 'videoWallpaperAdvanceMode', videoWallpaperAdvanceMode),
      ),
      _sharedPreferences.setInt(
        _videoWallpaperSwitchIntervalSeconds,
        _readInt(data, 'videoWallpaperSwitchIntervalSeconds',
                videoWallpaperSwitchIntervalSeconds)
            .clamp(5, 86400)
            .toInt(),
      ),
      _sharedPreferences.setBool(
        _videoWallpaperPlaylistLoop,
        _readBool(
            data, 'videoWallpaperPlaylistLoop', videoWallpaperPlaylistLoop),
      ),
      _sharedPreferences.setBool(
        _videoWallpaperLoop,
        _readBool(data, 'videoWallpaperLoop', videoWallpaperLoop),
      ),
      _sharedPreferences.setBool(
        _videoWallpaperMute,
        _readBool(data, 'videoWallpaperMute', videoWallpaperMute),
      ),
      _sharedPreferences.setString(
        _videoWallpaperFit,
        _readString(data, 'videoWallpaperFit', videoWallpaperFit),
      ),
      _sharedPreferences.setInt(
        _videoWallpaperDimPercent,
        _readInt(data, 'videoWallpaperDimPercent', videoWallpaperDimPercent)
            .clamp(0, 100)
            .toInt(),
      ),
      _sharedPreferences.setString(
        _videoWallpaperBlur,
        _readString(data, 'videoWallpaperBlur', videoWallpaperBlur),
      ),
      _sharedPreferences.setBool(
        _videoWallpaperAutoResume,
        _readBool(data, 'videoWallpaperAutoResume', videoWallpaperAutoResume),
      ),
    ]);
    notifyListeners();
  }

  static bool _readBool(Map<String, dynamic> data, String key, bool fallback) {
    final dynamic value = data[key];
    return value is bool ? value : fallback;
  }

  static int _readInt(Map<String, dynamic> data, String key, int fallback) {
    final dynamic value = data[key];
    return value is int ? value : (value is num ? value.toInt() : fallback);
  }

  static String _readString(
      Map<String, dynamic> data, String key, String fallback) {
    final dynamic value = data[key];
    return value is String ? value : fallback;
  }

  static List<String> _readStringList(
    Map<String, dynamic> data,
    String key,
    List<String> fallback,
  ) {
    final dynamic value = data[key];
    if (value is List) {
      return value
          .whereType<Object>()
          .map((entry) => entry.toString())
          .where((entry) => entry.trim().isNotEmpty)
          .toList(growable: false);
    }
    return fallback;
  }

  static String _sanitizeAppLocaleMode(String value) {
    switch (value) {
      case appLocaleEnglish:
      case appLocaleVietnamese:
        return value;
      default:
        return appLocaleSystem;
    }
  }

  static int _normalizeAppCardMediaScale(int value) {
    final normalized = value.clamp(appCardMediaScaleMin, appCardMediaScaleMax);
    final offset = normalized - appCardMediaScaleMin;
    final snappedStep = (offset / appCardMediaScaleStep).round();
    return appCardMediaScaleMin + (snappedStep * appCardMediaScaleStep);
  }

  static int _normalizeAppCardLayoutScale(int value) {
    final normalized =
        value.clamp(appCardLayoutScaleMin, appCardLayoutScaleMax);
    final offset = normalized - appCardLayoutScaleMin;
    final snappedStep = (offset / appCardLayoutScaleStep).round();
    return appCardLayoutScaleMin + (snappedStep * appCardLayoutScaleStep);
  }

  static int _normalizeStatusBarClockScale(int value) {
    final normalized =
        value.clamp(statusBarClockScaleMin, statusBarClockScaleMax);
    final offset = normalized - statusBarClockScaleMin;
    final snappedStep = (offset / statusBarClockScaleStep).round();
    return statusBarClockScaleMin + (snappedStep * statusBarClockScaleStep);
  }

  static int _normalizeHomeDockGlassIntensity(int value) {
    final normalized =
        value.clamp(homeDockGlassIntensityMin, homeDockGlassIntensityMax);
    final offset = normalized - homeDockGlassIntensityMin;
    final snappedStep = (offset / homeDockGlassIntensityStep).round();
    return homeDockGlassIntensityMin +
        (snappedStep * homeDockGlassIntensityStep);
  }

  static int _normalizeHomeDockAutoCollapseDelay(int value) {
    final normalized = value.clamp(
      homeDockAutoCollapseDelayMin,
      homeDockAutoCollapseDelayMax,
    );
    final offset = normalized - homeDockAutoCollapseDelayMin;
    final snappedStep = (offset / homeDockAutoCollapseDelayStep).round();
    return homeDockAutoCollapseDelayMin +
        (snappedStep * homeDockAutoCollapseDelayStep);
  }

  static int _normalizeHomeDockCollapsedRows(int value) => value.clamp(
        homeDockCollapsedRowsMin,
        homeDockCollapsedRowsMax,
      );

  static int _normalizeHomeDockRowSpacing(int value) {
    final normalized = value.clamp(
      homeDockRowSpacingMin,
      homeDockRowSpacingMax,
    );
    final offset = normalized - homeDockRowSpacingMin;
    final snappedStep = (offset / homeDockRowSpacingStep).round();
    return homeDockRowSpacingMin + (snappedStep * homeDockRowSpacingStep);
  }

  static int _resolveHomeDockGlassIntensityForBackup(
      Map<String, dynamic> data) {
    if (data.containsKey('homeDockGlassIntensityPercent')) {
      return _normalizeHomeDockGlassIntensity(
        _readInt(
          data,
          'homeDockGlassIntensityPercent',
          homeDockGlassIntensityDefault,
        ),
      );
    }
    final legacyBlurEnabled = _readBool(data, 'homeDockBlurEnabled', false);
    return legacyBlurEnabled ? homeDockGlassIntensityLegacyOnDefault : 0;
  }

  static bool _resolveHomeDockBlurEnabledForBackup(Map<String, dynamic> data) {
    return _resolveHomeDockGlassIntensityForBackup(data) > 0;
  }
}
