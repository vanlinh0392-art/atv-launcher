import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flauncher/widgets/settings/date_time_format_dialog.dart';
import 'package:flauncher/widgets/settings/flauncher_about_dialog.dart';
import 'package:flauncher/widgets/settings/launcher_sections_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/status_bar_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

import '../rounded_switch_list_tile.dart';
import 'back_button_actions.dart';

enum _HomeLayoutQuickTarget {
  appLocale,
  dockRows,
  collapsedRows,
  autoCollapse,
  autoCollapseDelay,
  performanceMode,
  glassIntensity,
  rowSpacing,
  iconCornerRadius,
  settingsTransparency,
  cardSize,
  iconSize,
}

class HomeLayoutPanelPage extends StatefulWidget {
  static const String routeName = "home_layout_panel";
  static const List<int> _dockCollapseDelayOptions = <int>[
    5,
    10,
    15,
    20,
    30,
    45,
    60,
  ];
  static const List<int> _dockGlassIntensityOptions = <int>[
    0,
    20,
    40,
    60,
    80,
    100,
  ];
  static const List<String> _dockPerformanceModeOptions = <String>[
    SettingsService.homeDockPerformanceModeQuality,
    SettingsService.homeDockPerformanceModeBalanced,
    SettingsService.homeDockPerformanceModeSmooth,
    SettingsService.homeDockPerformanceModeOff,
  ];
  static const List<int> _appCardLayoutScaleOptions = <int>[
    70,
    80,
    85,
    90,
    95,
    100,
    105,
    110,
    115,
  ];

  const HomeLayoutPanelPage({super.key});

  @override
  State<HomeLayoutPanelPage> createState() => _HomeLayoutPanelPageState();
}

class _HomeLayoutPanelPageState extends State<HomeLayoutPanelPage> {
  late final Map<_HomeLayoutQuickTarget, GlobalKey> _quickTargetKeys =
      <_HomeLayoutQuickTarget, GlobalKey>{
    for (final target in _HomeLayoutQuickTarget.values)
      target: GlobalKey(debugLabel: 'home_layout_target_${target.name}'),
  };
  late final Map<_HomeLayoutQuickTarget, FocusNode> _quickTargetFocusNodes =
      <_HomeLayoutQuickTarget, FocusNode>{
    for (final target in _HomeLayoutQuickTarget.values)
      target: FocusNode(debugLabel: 'home_layout_target_${target.name}'),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final focusLabel = FocusManager.instance.primaryFocus?.debugLabel ?? '';
      if (focusLabel.contains('settings_rail_')) {
        return;
      }
      _quickTargetFocusNodes[_HomeLayoutQuickTarget.appLocale]?.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final focusNode in _quickTargetFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Consumer<SettingsService>(
        builder: (context, settingsService, __) => ListView(
          key: const PageStorageKey<String>(HomeLayoutPanelPage.routeName),
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            SettingsAdaptiveGrid(
              minChildWidth: 188,
              maxColumns: 4,
              spacing: 10,
              runSpacing: 10,
              children: [
                _QuickSettingTile(
                  key: const ValueKey<String>(
                    'home_layout_quick_tile_app_locale',
                  ),
                  label: localizations.appLanguageTitle,
                  value: _localeModeLabel(
                    localizations,
                    settingsService.appLocaleMode,
                  ),
                  icon: Icons.language_outlined,
                  onPressed: () => _activateQuickTarget(
                    _HomeLayoutQuickTarget.appLocale,
                  ),
                ),
                _QuickSettingTile(
                  key: const ValueKey<String>(
                    'home_layout_quick_tile_dock_rows',
                  ),
                  label: localizations.homeDockHeightTitle,
                  value: settingsService.homeDockRowsPreset.toString(),
                  icon: Icons.view_agenda_outlined,
                  onPressed: () => _activateQuickTarget(
                    _HomeLayoutQuickTarget.dockRows,
                  ),
                ),
                _QuickSettingTile(
                  key: const ValueKey<String>(
                    'home_layout_quick_tile_collapsed_rows',
                  ),
                  label: localizations.homeDockCollapsedRowsTitle,
                  value: settingsService.homeDockCollapsedRowsPreset.toString(),
                  icon: Icons.unfold_less_double_outlined,
                  onPressed: () => _activateQuickTarget(
                    _HomeLayoutQuickTarget.collapsedRows,
                  ),
                ),
                _QuickSettingTile(
                  key: const ValueKey<String>(
                    'home_layout_quick_tile_auto_collapse',
                  ),
                  label: localizations.homeDockAutoCollapseTitle,
                  value: _boolLabel(
                    localizations,
                    settingsService.homeDockAutoCollapseEnabled,
                  ),
                  icon: Icons.unfold_less_outlined,
                  onPressed: () => _activateQuickTarget(
                    _HomeLayoutQuickTarget.autoCollapse,
                  ),
                ),
                _QuickSettingTile(
                  key: const ValueKey<String>(
                    'home_layout_quick_tile_collapse_delay',
                  ),
                  label: localizations.homeDockAutoCollapseDelayTitle,
                  value: '${settingsService.homeDockAutoCollapseDelaySeconds}s',
                  icon: Icons.timer_outlined,
                  onPressed: () => _activateQuickTarget(
                    _HomeLayoutQuickTarget.autoCollapseDelay,
                  ),
                ),
                _QuickSettingTile(
                  key: const ValueKey<String>(
                    'home_layout_quick_tile_glass_intensity',
                  ),
                  label: localizations.homeDockGlassIntensityTitle,
                  value: '${settingsService.homeDockGlassIntensityPercent}%',
                  icon: Icons.blur_on_outlined,
                  onPressed: () => _activateQuickTarget(
                    _HomeLayoutQuickTarget.glassIntensity,
                  ),
                ),
                _QuickSettingTile(
                  key: const ValueKey<String>(
                    'home_layout_quick_tile_performance_mode',
                  ),
                  label: localizations.homeDockPerformanceModeTitle,
                  value: _performanceModeLabel(
                    localizations,
                    settingsService.homeDockPerformanceMode,
                  ),
                  icon: Icons.speed_outlined,
                  onPressed: () => _activateQuickTarget(
                    _HomeLayoutQuickTarget.performanceMode,
                  ),
                ),
                _QuickSettingTile(
                  key: const ValueKey<String>(
                    'home_layout_quick_tile_row_spacing',
                  ),
                  label: localizations.homeDockRowSpacingTitle,
                  value: '${settingsService.homeDockRowSpacing}dp',
                  icon: Icons.height_outlined,
                  onPressed: () => _activateQuickTarget(
                    _HomeLayoutQuickTarget.rowSpacing,
                  ),
                ),
                _QuickSettingTile(
                  key: const ValueKey<String>(
                    'home_layout_quick_tile_corner_radius',
                  ),
                  label: localizations.iconCornerRadiusTitle,
                  value: '${settingsService.appCardCornerRadius}dp',
                  icon: Icons.rounded_corner_outlined,
                  onPressed: () => _activateQuickTarget(
                    _HomeLayoutQuickTarget.iconCornerRadius,
                  ),
                ),
                _QuickSettingTile(
                  key: const ValueKey<String>(
                    'home_layout_quick_tile_settings_transparency',
                  ),
                  label: localizations.settingsUiTransparencyTitle,
                  value: '${settingsService.settingsUiTransparencyPercent}%',
                  icon: Icons.opacity_outlined,
                  onPressed: () => _activateQuickTarget(
                    _HomeLayoutQuickTarget.settingsTransparency,
                  ),
                ),
                _QuickSettingTile(
                  key: const ValueKey<String>(
                    'home_layout_quick_tile_card_size',
                  ),
                  label: localizations.appCardLayoutSizeTitle,
                  value: '${settingsService.appCardLayoutScalePercent}%',
                  icon: Icons.crop_16_9_outlined,
                  onPressed: () => _activateQuickTarget(
                    _HomeLayoutQuickTarget.cardSize,
                  ),
                ),
                _QuickSettingTile(
                  key: const ValueKey<String>(
                    'home_layout_quick_tile_icon_size',
                  ),
                  label: localizations.iconSizeTitle,
                  value: '${settingsService.appCardMediaScalePercent}%',
                  icon: Icons.photo_size_select_large_outlined,
                  onPressed: () => _activateQuickTarget(
                    _HomeLayoutQuickTarget.iconSize,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: Column(
                children: [
                  _SegmentedSettingCard<String>(
                    key: _quickTargetKeys[_HomeLayoutQuickTarget.appLocale],
                    focusNode: _quickTargetFocusNodes[
                        _HomeLayoutQuickTarget.appLocale],
                    segmentedButtonKey: const Key('app_locale_mode_selector'),
                    title: localizations.appLanguageTitle,
                    subtitle: localizations.appLanguageDescription,
                    icon: Icons.language_outlined,
                    value: settingsService.appLocaleMode,
                    segments: <ButtonSegment<String>>[
                      ButtonSegment<String>(
                        value: SettingsService.appLocaleSystem,
                        label: Text(localizations.appLanguageSystem),
                      ),
                      ButtonSegment<String>(
                        value: SettingsService.appLocaleEnglish,
                        label: Text(localizations.appLanguageEnglish),
                      ),
                      ButtonSegment<String>(
                        value: SettingsService.appLocaleVietnamese,
                        label: Text(localizations.appLanguageVietnamese),
                      ),
                    ],
                    onSelectionChanged: (selection) {
                      final value = selection.isEmpty
                          ? SettingsService.appLocaleSystem
                          : selection.first;
                      settingsService.setAppLocaleMode(value);
                    },
                  ),
                  const SizedBox(height: 10),
                  _SegmentedSettingCard(
                    key: _quickTargetKeys[_HomeLayoutQuickTarget.dockRows],
                    focusNode:
                        _quickTargetFocusNodes[_HomeLayoutQuickTarget.dockRows],
                    title: localizations.homeDockHeightTitle,
                    subtitle: localizations.homeDockHeightDescription,
                    icon: Icons.view_agenda_outlined,
                    value: settingsService.homeDockRowsPreset,
                    segments: const <ButtonSegment<int>>[
                      ButtonSegment<int>(value: 2, label: Text('2')),
                      ButtonSegment<int>(value: 3, label: Text('3')),
                      ButtonSegment<int>(value: 4, label: Text('4')),
                    ],
                    onSelectionChanged: (selection) {
                      final value = selection.isEmpty ? 3 : selection.first;
                      settingsService.setHomeDockRowsPreset(value);
                    },
                  ),
                  const SizedBox(height: 10),
                  _SegmentedSettingCard(
                    key: _quickTargetKeys[_HomeLayoutQuickTarget.collapsedRows],
                    focusNode: _quickTargetFocusNodes[
                        _HomeLayoutQuickTarget.collapsedRows],
                    segmentedButtonKey:
                        const Key('home_dock_collapsed_rows_selector'),
                    title: localizations.homeDockCollapsedRowsTitle,
                    subtitle: localizations.homeDockCollapsedRowsDescription,
                    icon: Icons.unfold_less_double_outlined,
                    value: settingsService.homeDockCollapsedRowsPreset,
                    segments: const <ButtonSegment<int>>[
                      ButtonSegment<int>(value: 1, label: Text('1')),
                      ButtonSegment<int>(value: 2, label: Text('2')),
                    ],
                    onSelectionChanged: (selection) {
                      final value = selection.isEmpty ? 1 : selection.first;
                      settingsService.setHomeDockCollapsedRowsPreset(value);
                    },
                  ),
                  const SizedBox(height: 10),
                  RoundedSwitchListTile(
                    key: _quickTargetKeys[_HomeLayoutQuickTarget.autoCollapse],
                    focusNode: _quickTargetFocusNodes[
                        _HomeLayoutQuickTarget.autoCollapse],
                    value: settingsService.homeDockAutoCollapseEnabled,
                    onChanged: settingsService.setHomeDockAutoCollapseEnabled,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.homeDockAutoCollapseTitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          localizations.homeDockAutoCollapseDescription,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                    secondary: const Icon(Icons.unfold_less_outlined),
                  ),
                  const SizedBox(height: 10),
                  _ChoiceSettingCard<int>(
                    key: _quickTargetKeys[
                        _HomeLayoutQuickTarget.autoCollapseDelay],
                    focusNode: _quickTargetFocusNodes[
                        _HomeLayoutQuickTarget.autoCollapseDelay],
                    selectorKey:
                        const Key('home_dock_auto_collapse_delay_selector'),
                    optionKeyPrefix: 'home_dock_auto_collapse_delay_option',
                    title: localizations.homeDockAutoCollapseDelayTitle,
                    subtitle:
                        localizations.homeDockAutoCollapseDelayDescription,
                    icon: Icons.timer_outlined,
                    value: settingsService.homeDockAutoCollapseDelaySeconds,
                    options: HomeLayoutPanelPage._dockCollapseDelayOptions
                        .map((value) => _ChoiceOption<int>(
                              value: value,
                              label: '${value}s',
                            ))
                        .toList(growable: false),
                    valueLabelBuilder: (value) => '${value}s',
                    onChanged:
                        settingsService.setHomeDockAutoCollapseDelaySeconds,
                  ),
                  const SizedBox(height: 10),
                  _ChoiceSettingCard<int>(
                    key:
                        _quickTargetKeys[_HomeLayoutQuickTarget.glassIntensity],
                    focusNode: _quickTargetFocusNodes[
                        _HomeLayoutQuickTarget.glassIntensity],
                    selectorKey:
                        const Key('home_dock_glass_intensity_selector'),
                    optionKeyPrefix: 'home_dock_glass_intensity_option',
                    title: localizations.homeDockGlassIntensityTitle,
                    subtitle: localizations.homeDockGlassIntensityDescription,
                    icon: Icons.blur_on_outlined,
                    value: settingsService.homeDockGlassIntensityPercent,
                    options: HomeLayoutPanelPage._dockGlassIntensityOptions
                        .map((value) => _ChoiceOption<int>(
                              value: value,
                              label: '${value}%',
                            ))
                        .toList(growable: false),
                    valueLabelBuilder: (value) => '${value}%',
                    onChanged: settingsService.setHomeDockGlassIntensityPercent,
                  ),
                  const SizedBox(height: 10),
                  _ChoiceSettingCard<String>(
                    key: _quickTargetKeys[
                        _HomeLayoutQuickTarget.performanceMode],
                    focusNode: _quickTargetFocusNodes[
                        _HomeLayoutQuickTarget.performanceMode],
                    selectorKey:
                        const Key('home_dock_performance_mode_selector'),
                    optionKeyPrefix: 'home_dock_performance_mode_option',
                    title: localizations.homeDockPerformanceModeTitle,
                    subtitle: localizations.homeDockPerformanceModeDescription,
                    icon: Icons.speed_outlined,
                    value: settingsService.homeDockPerformanceMode,
                    options: HomeLayoutPanelPage._dockPerformanceModeOptions
                        .map((value) => _ChoiceOption<String>(
                              value: value,
                              label: _performanceModeLabel(
                                localizations,
                                value,
                              ),
                            ))
                        .toList(growable: false),
                    valueLabelBuilder: (value) => _performanceModeLabel(
                      localizations,
                      value,
                    ),
                    onChanged: settingsService.setHomeDockPerformanceMode,
                  ),
                  const SizedBox(height: 10),
                  _StepperSettingCard(
                    key: _quickTargetKeys[_HomeLayoutQuickTarget.rowSpacing],
                    focusNode: _quickTargetFocusNodes[
                        _HomeLayoutQuickTarget.rowSpacing],
                    selectorKey: const Key('home_dock_row_spacing_stepper'),
                    buttonKeyPrefix: 'home_dock_row_spacing',
                    title: localizations.homeDockRowSpacingTitle,
                    subtitle: localizations.homeDockRowSpacingDescription,
                    icon: Icons.height_outlined,
                    value: settingsService.homeDockRowSpacing,
                    valueLabelBuilder: (value) => '${value}dp',
                    minimum: SettingsService.homeDockRowSpacingMin,
                    maximum: SettingsService.homeDockRowSpacingMax,
                    step: SettingsService.homeDockRowSpacingStep,
                    onChanged: settingsService.setHomeDockRowSpacing,
                  ),
                  const SizedBox(height: 10),
                  _StepperSettingCard(
                    key: _quickTargetKeys[
                        _HomeLayoutQuickTarget.iconCornerRadius],
                    focusNode: _quickTargetFocusNodes[
                        _HomeLayoutQuickTarget.iconCornerRadius],
                    selectorKey: const Key('icon_corner_radius_stepper'),
                    buttonKeyPrefix: 'icon_corner_radius',
                    title: localizations.iconCornerRadiusTitle,
                    subtitle: localizations.iconCornerRadiusDescription,
                    icon: Icons.rounded_corner_outlined,
                    value: settingsService.appCardCornerRadius,
                    valueLabelBuilder: (value) => '${value}dp',
                    minimum: SettingsService.appCardCornerRadiusMin,
                    maximum: SettingsService.appCardCornerRadiusMax,
                    step: 1,
                    onChanged: settingsService.setAppCardCornerRadius,
                  ),
                  const SizedBox(height: 10),
                  _StepperSettingCard(
                    key: _quickTargetKeys[
                        _HomeLayoutQuickTarget.settingsTransparency],
                    focusNode: _quickTargetFocusNodes[
                        _HomeLayoutQuickTarget.settingsTransparency],
                    selectorKey: const Key('settings_ui_transparency_stepper'),
                    buttonKeyPrefix: 'settings_ui_transparency',
                    title: localizations.settingsUiTransparencyTitle,
                    subtitle: localizations.settingsUiTransparencyDescription,
                    icon: Icons.opacity_outlined,
                    value: settingsService.settingsUiTransparencyPercent,
                    valueLabelBuilder: (value) => '${value}%',
                    minimum: SettingsService.settingsUiTransparencyMin,
                    maximum: SettingsService.settingsUiTransparencyMax,
                    step: SettingsService.settingsUiTransparencyStep,
                    onChanged: settingsService.setSettingsUiTransparencyPercent,
                  ),
                  const SizedBox(height: 10),
                  _ChoiceSettingCard<int>(
                    key: _quickTargetKeys[_HomeLayoutQuickTarget.cardSize],
                    focusNode:
                        _quickTargetFocusNodes[_HomeLayoutQuickTarget.cardSize],
                    selectorKey: const Key('app_card_layout_scale_selector'),
                    optionKeyPrefix: 'app_card_layout_scale_option',
                    title: localizations.appCardLayoutSizeTitle,
                    subtitle: localizations.appCardLayoutSizeDescription,
                    icon: Icons.crop_16_9_outlined,
                    value: settingsService.appCardLayoutScalePercent,
                    options: HomeLayoutPanelPage._appCardLayoutScaleOptions
                        .map((value) => _ChoiceOption<int>(
                              value: value,
                              label: '${value}%',
                            ))
                        .toList(growable: false),
                    valueLabelBuilder: (value) => '${value}%',
                    onChanged: settingsService.setAppCardLayoutScalePercent,
                  ),
                  const SizedBox(height: 10),
                  _StepperSettingCard(
                    key: _quickTargetKeys[_HomeLayoutQuickTarget.iconSize],
                    focusNode:
                        _quickTargetFocusNodes[_HomeLayoutQuickTarget.iconSize],
                    selectorKey: const Key('app_card_media_scale_stepper'),
                    buttonKeyPrefix: 'app_card_media_scale',
                    title: localizations.iconSizeTitle,
                    subtitle: localizations.iconSizeDescription,
                    icon: Icons.photo_size_select_large_outlined,
                    value: settingsService.appCardMediaScalePercent,
                    valueLabelBuilder: (value) => '${value}%',
                    minimum: SettingsService.appCardMediaScaleMin,
                    maximum: SettingsService.appCardMediaScaleMax,
                    step: SettingsService.appCardMediaScaleStep,
                    onChanged: settingsService.setAppCardMediaScalePercent,
                  ),
                  const SizedBox(height: 10),
                  RoundedSwitchListTile(
                    value: settingsService.appHighlightAnimationEnabled,
                    onChanged: settingsService.setAppHighlightAnimationEnabled,
                    title: Text(localizations.appCardHighlightAnimation,
                        style: Theme.of(context).textTheme.bodyMedium),
                    secondary: const Icon(Icons.filter_center_focus),
                  ),
                  const SizedBox(height: 10),
                  RoundedSwitchListTile(
                    value: settingsService.appKeyClickEnabled,
                    onChanged: settingsService.setAppKeyClickEnabled,
                    title: Text(localizations.appKeyClick,
                        style: Theme.of(context).textTheme.bodyMedium),
                    secondary: const Icon(Icons.notifications_active),
                  ),
                  const SizedBox(height: 10),
                  RoundedSwitchListTile(
                    value: settingsService.showCategoryTitles,
                    onChanged: settingsService.setShowCategoryTitles,
                    title: Text(localizations.showCategoryTitles,
                        style: Theme.of(context).textTheme.bodyMedium),
                    secondary: const Icon(Icons.abc),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: Column(
                children: [
                  _ActionSettingCard(
                    title: localizations.applications,
                    icon: Icons.apps_outlined,
                    onPressed: () async => Navigator.of(context)
                        .pushNamed(ApplicationsPanelPage.routeName),
                  ),
                  const SizedBox(height: 10),
                  _ActionSettingCard(
                    title: localizations.launcherSections,
                    icon: Icons.category_outlined,
                    onPressed: () async => Navigator.of(context)
                        .pushNamed(LauncherSectionsPanelPage.routeName),
                  ),
                  const SizedBox(height: 10),
                  _ActionSettingCard(
                    title: localizations.statusBar,
                    subtitle: localizations.statusBarDescription,
                    icon: Icons.tips_and_updates_outlined,
                    onPressed: () async => Navigator.of(context)
                        .pushNamed(StatusBarPanelPage.routeName),
                  ),
                  const SizedBox(height: 10),
                  _ActionSettingCard(
                    title: localizations.systemSettings,
                    subtitle: localizations.actionOpenSystemSettingsSubtitle,
                    icon: Icons.settings_outlined,
                    onPressed: () async =>
                        context.read<AppsService>().openSettings(),
                  ),
                  const SizedBox(height: 10),
                  _ActionSettingCard(
                    title: localizations.dateAndTimeFormat,
                    icon: Icons.date_range_outlined,
                    onPressed: () => _dateTimeFormatDialog(context),
                  ),
                  const SizedBox(height: 10),
                  _ActionSettingCard(
                    title: localizations.backButtonAction,
                    icon: Icons.arrow_back_outlined,
                    onPressed: () => _backButtonActionDialog(context),
                  ),
                  const SizedBox(height: 10),
                  _ActionSettingCard(
                    title: localizations.aboutFlauncher,
                    icon: Icons.info_outline,
                    onPressed: () async => showDialog(
                      context: context,
                      builder: (_) => FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) => snapshot
                                    .connectionState ==
                                ConnectionState.done
                            ? FLauncherAboutDialog(packageInfo: snapshot.data!)
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _boolLabel(AppLocalizations localizations, bool value) =>
      value ? localizations.settingStateOn : localizations.settingStateOff;

  String _localeModeLabel(AppLocalizations localizations, String value) {
    switch (value) {
      case SettingsService.appLocaleEnglish:
        return localizations.appLanguageEnglish;
      case SettingsService.appLocaleVietnamese:
        return localizations.appLanguageVietnamese;
      default:
        return localizations.appLanguageSystem;
    }
  }

  String _performanceModeLabel(AppLocalizations localizations, String value) {
    switch (value) {
      case SettingsService.homeDockPerformanceModeQuality:
        return localizations.homeDockPerformanceModeQuality;
      case SettingsService.homeDockPerformanceModeSmooth:
        return localizations.homeDockPerformanceModeSmooth;
      case SettingsService.homeDockPerformanceModeOff:
        return localizations.homeDockPerformanceModeOff;
      default:
        return localizations.homeDockPerformanceModeBalanced;
    }
  }

  Future<void> _backButtonActionDialog(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final service = context.read<SettingsService>();

    final newAction = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(localizations.dialogTitleBackButtonAction),
        children: [
          SimpleDialogOption(
            child: Text(localizations.dialogOptionBackButtonActionDoNothing),
            onPressed: () => Navigator.pop(context, ""),
          ),
          SimpleDialogOption(
            child: Text(localizations.dialogOptionBackButtonActionShowClock),
            onPressed: () => Navigator.pop(context, BACK_BUTTON_ACTION_CLOCK),
          ),
          SimpleDialogOption(
            child:
                Text(localizations.dialogOptionBackButtonActionShowScreensaver),
            onPressed: () =>
                Navigator.pop(context, BACK_BUTTON_ACTION_SCREENSAVER),
          ),
        ],
      ),
    );

    if (newAction != null) {
      await service.setBackButtonAction(newAction);
    }
  }

  Future<void> _dateTimeFormatDialog(BuildContext context) async {
    final service = context.read<SettingsService>();
    final formatTuple = await showDialog<Tuple2<String, String>>(
      context: context,
      builder: (_) =>
          DateTimeFormatDialog(service.dateFormat, service.timeFormat),
    );

    if (formatTuple != null) {
      await service.setDateTimeFormat(formatTuple.item1, formatTuple.item2);
    }
  }

  Future<void> _activateQuickTarget(_HomeLayoutQuickTarget target) async {
    final targetContext = _quickTargetKeys[target]?.currentContext;
    final focusNode = _quickTargetFocusNodes[target];
    if (targetContext == null || focusNode == null) {
      return;
    }

    EnsureVisible.ensureVisible(
      targetContext,
      alignment: 0.12,
    );

    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      focusNode.requestFocus();
    });
  }
}

class _SegmentedSettingCard<T> extends StatefulWidget {
  final Key? segmentedButtonKey;
  final FocusNode? focusNode;
  final String title;
  final String subtitle;
  final IconData icon;
  final T value;
  final List<ButtonSegment<T>> segments;
  final ValueChanged<Set<T>> onSelectionChanged;

  const _SegmentedSettingCard({
    super.key,
    this.segmentedButtonKey,
    this.focusNode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.segments,
    required this.onSelectionChanged,
  });

  @override
  State<_SegmentedSettingCard<T>> createState() =>
      _SegmentedSettingCardState<T>();
}

class _SegmentedSettingCardState<T> extends State<_SegmentedSettingCard<T>> {
  late List<FocusNode> _optionFocusNodes;
  bool _hasFocus = false;
  int _lastFocusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _optionFocusNodes = _buildOptionFocusNodes();
  }

  @override
  void didUpdateWidget(covariant _SegmentedSettingCard<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments.length != widget.segments.length) {
      for (final node in _optionFocusNodes) {
        node.dispose();
      }
      _optionFocusNodes = _buildOptionFocusNodes();
    }
  }

  @override
  void dispose() {
    for (final node in _optionFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EnsureVisible(
        alignment: 0.12,
        child: Focus(
          canRequestFocus: false,
          onFocusChange: (value) {
            if (_hasFocus != value) {
              setState(() => _hasFocus = value);
            }
          },
          onKeyEvent: (_, event) => _handleContainerKeyEvent(event),
          child: Focus(
            focusNode: widget.focusNode,
            child: SettingsFocusFrame(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _hasFocus ? 1 : 0.96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(widget.icon, color: Colors.white70),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.subtitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      key: widget.segmentedButtonKey,
                      spacing: 10,
                      runSpacing: 10,
                      children: List<Widget>.generate(widget.segments.length,
                          (index) {
                        final segment = widget.segments[index];
                        return _SettingsControlButton(
                          focusNode: _optionFocusNodes[index],
                          selected: segment.value == widget.value,
                          onPressed: () =>
                              widget.onSelectionChanged(<T>{segment.value}),
                          onMoveBackOnLeft: index == 0
                              ? () => widget.focusNode?.requestFocus()
                              : null,
                          onFocused: () => _lastFocusedIndex = index,
                          child:
                              segment.label ?? Text(segment.value.toString()),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  List<FocusNode> _buildOptionFocusNodes() => List<FocusNode>.generate(
        widget.segments.length,
        (index) => FocusNode(
          debugLabel:
              '${widget.focusNode?.debugLabel ?? widget.title}_option_$index',
        ),
        growable: false,
      );

  KeyEventResult _handleContainerKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || widget.focusNode?.hasFocus != true) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        _isActivateKey(event.logicalKey)) {
      _focusSelectedOption();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusSelectedOption() {
    if (_optionFocusNodes.isEmpty) {
      return;
    }
    final selectedIndex =
        widget.segments.indexWhere((segment) => segment.value == widget.value);
    final targetIndex = selectedIndex >= 0
        ? selectedIndex
        : _lastFocusedIndex.clamp(0, _optionFocusNodes.length - 1);
    _optionFocusNodes[targetIndex].requestFocus();
  }
}

class _ChoiceOption<T> {
  final T value;
  final String label;

  const _ChoiceOption({
    required this.value,
    required this.label,
  });
}

class _ActionSettingCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Future<void> Function()? onPressed;

  const _ActionSettingCard({
    required this.title,
    this.subtitle,
    required this.icon,
    this.onPressed,
  });

  @override
  State<_ActionSettingCard> createState() => _ActionSettingCardState();
}

class _ActionSettingCardState extends State<_ActionSettingCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => EnsureVisible(
        alignment: 0.12,
        child: FocusableActionDetector(
          onShowFocusHighlight: (value) {
            if (_focused != value) {
              setState(() => _focused = value);
            }
          },
          child: SettingsFocusFrame(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _focused ? 1 : 0.96,
              child: TextButton(
                onPressed: widget.onPressed == null
                    ? null
                    : () => widget.onPressed!.call(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(widget.icon, color: Colors.white70),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.chevron_right, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _ChoiceSettingCard<T> extends StatefulWidget {
  final Key? selectorKey;
  final String? optionKeyPrefix;
  final FocusNode? focusNode;
  final String title;
  final String subtitle;
  final IconData icon;
  final T value;
  final List<_ChoiceOption<T>> options;
  final String Function(T value) valueLabelBuilder;
  final ValueChanged<T> onChanged;

  const _ChoiceSettingCard({
    super.key,
    this.selectorKey,
    this.optionKeyPrefix,
    this.focusNode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.options,
    required this.valueLabelBuilder,
    required this.onChanged,
  });

  @override
  State<_ChoiceSettingCard<T>> createState() => _ChoiceSettingCardState<T>();
}

class _ChoiceSettingCardState<T> extends State<_ChoiceSettingCard<T>> {
  late List<FocusNode> _optionFocusNodes;
  bool _hasFocus = false;
  int _lastFocusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _optionFocusNodes = _buildOptionFocusNodes();
  }

  @override
  void didUpdateWidget(covariant _ChoiceSettingCard<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.length != widget.options.length) {
      for (final node in _optionFocusNodes) {
        node.dispose();
      }
      _optionFocusNodes = _buildOptionFocusNodes();
    }
  }

  @override
  void dispose() {
    for (final node in _optionFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EnsureVisible(
        alignment: 0.12,
        child: Focus(
          canRequestFocus: false,
          onFocusChange: (value) {
            if (_hasFocus != value) {
              setState(() => _hasFocus = value);
            }
          },
          onKeyEvent: (_, event) => _handleContainerKeyEvent(event),
          child: Focus(
            focusNode: widget.focusNode,
            child: SettingsFocusFrame(
              key: widget.selectorKey,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _hasFocus ? 1 : 0.96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(widget.icon, color: Colors.white70),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.subtitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.valueLabelBuilder(widget.value),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          List<Widget>.generate(widget.options.length, (index) {
                        final option = widget.options[index];
                        final buttonKeyPrefix = widget.optionKeyPrefix;
                        final button = _SettingsControlButton(
                          focusNode: _optionFocusNodes[index],
                          selected: option.value == widget.value,
                          onPressed: () => widget.onChanged(option.value),
                          onMoveBackOnLeft: index == 0
                              ? () => widget.focusNode?.requestFocus()
                              : null,
                          onFocused: () => _lastFocusedIndex = index,
                          child: Text(option.label),
                        );
                        if (buttonKeyPrefix == null) {
                          return button;
                        }
                        return KeyedSubtree(
                          key: ValueKey<String>(
                            '${buttonKeyPrefix}_${option.value}',
                          ),
                          child: button,
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  List<FocusNode> _buildOptionFocusNodes() => List<FocusNode>.generate(
        widget.options.length,
        (index) => FocusNode(
          debugLabel:
              '${widget.focusNode?.debugLabel ?? widget.title}_option_$index',
        ),
        growable: false,
      );

  KeyEventResult _handleContainerKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || widget.focusNode?.hasFocus != true) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        _isActivateKey(event.logicalKey)) {
      _focusSelectedOption();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusSelectedOption() {
    if (_optionFocusNodes.isEmpty) {
      return;
    }
    final selectedIndex =
        widget.options.indexWhere((option) => option.value == widget.value);
    final targetIndex = selectedIndex >= 0
        ? selectedIndex
        : _lastFocusedIndex.clamp(0, _optionFocusNodes.length - 1);
    _optionFocusNodes[targetIndex].requestFocus();
  }
}

class _StepperSettingCard extends StatefulWidget {
  final Key? selectorKey;
  final String? buttonKeyPrefix;
  final FocusNode? focusNode;
  final String title;
  final String subtitle;
  final IconData icon;
  final int value;
  final int minimum;
  final int maximum;
  final int step;
  final String Function(int value) valueLabelBuilder;
  final ValueChanged<int> onChanged;

  const _StepperSettingCard({
    super.key,
    this.selectorKey,
    this.buttonKeyPrefix,
    this.focusNode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.step,
    required this.valueLabelBuilder,
    required this.onChanged,
  });

  @override
  State<_StepperSettingCard> createState() => _StepperSettingCardState();
}

class _StepperSettingCardState extends State<_StepperSettingCard> {
  late final FocusNode _decreaseFocusNode;
  late final FocusNode _increaseFocusNode;
  bool _hasFocus = false;
  int _lastFocusedActionIndex = 0;

  @override
  void initState() {
    super.initState();
    final debugBase = widget.focusNode?.debugLabel ?? widget.title;
    _decreaseFocusNode = FocusNode(debugLabel: '${debugBase}_decrease');
    _increaseFocusNode = FocusNode(debugLabel: '${debugBase}_increase');
  }

  @override
  void dispose() {
    _decreaseFocusNode.dispose();
    _increaseFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canDecrease = widget.value > widget.minimum;
    final canIncrease = widget.value < widget.maximum;
    return EnsureVisible(
      alignment: 0.12,
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (value) {
          if (_hasFocus != value) {
            setState(() => _hasFocus = value);
          }
        },
        onKeyEvent: (_, event) => _handleContainerKeyEvent(event),
        child: Focus(
          focusNode: widget.focusNode,
          child: SettingsFocusFrame(
            key: widget.selectorKey,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _hasFocus ? 1 : 0.96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(widget.icon, color: Colors.white70),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _wrapStepperButton(
                        suffix: 'decrease',
                        child: _SettingsControlButton(
                          focusNode: _decreaseFocusNode,
                          selected: false,
                          enabled: canDecrease,
                          onPressed: canDecrease
                              ? () => _shiftValue(-widget.step)
                              : null,
                          onMoveBackOnLeft: () =>
                              widget.focusNode?.requestFocus(),
                          onMoveNextOnRight: () =>
                              _increaseFocusNode.requestFocus(),
                          onFocused: () => _lastFocusedActionIndex = 0,
                          child: const Icon(Icons.remove),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Text(
                            widget.valueLabelBuilder(widget.value),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _wrapStepperButton(
                        suffix: 'increase',
                        child: _SettingsControlButton(
                          focusNode: _increaseFocusNode,
                          selected: false,
                          enabled: canIncrease,
                          onPressed: canIncrease
                              ? () => _shiftValue(widget.step)
                              : null,
                          onFocused: () => _lastFocusedActionIndex = 1,
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleContainerKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || widget.focusNode?.hasFocus != true) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        _isActivateKey(event.logicalKey)) {
      _focusActiveAction();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusActiveAction() {
    final preferredIndex = _lastFocusedActionIndex;
    if (preferredIndex == 0 && widget.value > widget.minimum) {
      _decreaseFocusNode.requestFocus();
      return;
    }
    if (preferredIndex == 1 && widget.value < widget.maximum) {
      _increaseFocusNode.requestFocus();
      return;
    }
    if (widget.value > widget.minimum) {
      _decreaseFocusNode.requestFocus();
      return;
    }
    if (widget.value < widget.maximum) {
      _increaseFocusNode.requestFocus();
    }
  }

  Widget _wrapStepperButton({
    required String suffix,
    required Widget child,
  }) {
    final prefix = widget.buttonKeyPrefix;
    if (prefix == null) {
      return child;
    }
    return KeyedSubtree(
      key: ValueKey<String>('${prefix}_$suffix'),
      child: child,
    );
  }

  bool _shiftValue(int delta) {
    final next = (widget.value + delta).clamp(widget.minimum, widget.maximum);
    if (next != widget.value) {
      widget.onChanged(next);
      return true;
    }
    return false;
  }
}

bool _isActivateKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.enter ||
    key == LogicalKeyboardKey.select ||
    key == LogicalKeyboardKey.space;

class _SettingsControlButton extends StatefulWidget {
  final FocusNode focusNode;
  final Widget child;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;
  final VoidCallback? onMoveBackOnLeft;
  final VoidCallback? onMoveNextOnRight;
  final VoidCallback? onFocused;

  const _SettingsControlButton({
    required this.focusNode,
    required this.child,
    required this.selected,
    this.enabled = true,
    this.onPressed,
    this.onMoveBackOnLeft,
    this.onMoveNextOnRight,
    this.onFocused,
  });

  @override
  State<_SettingsControlButton> createState() => _SettingsControlButtonState();
}

class _SettingsControlButtonState extends State<_SettingsControlButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final chromeSpec = SettingsChromeSpec.of(context);
    final selected = widget.selected;
    final enabled = widget.enabled;
    final visuals = SettingsButtonStyles.resolveControlVisuals(
      chromeSpec,
      variant: selected
          ? SettingsButtonVariant.primary
          : SettingsButtonVariant.neutral,
      focused: _focused,
      enabled: enabled,
      selected: selected,
    );

    return Focus(
      focusNode: widget.focusNode,
      canRequestFocus: enabled,
      onFocusChange: (value) {
        if (_focused != value) {
          setState(() => _focused = value);
        }
        if (value) {
          widget.onFocused?.call();
        }
      },
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            widget.onMoveBackOnLeft != null) {
          widget.onMoveBackOnLeft!.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
            widget.onMoveNextOnRight != null) {
          widget.onMoveNextOnRight!.call();
          return KeyEventResult.handled;
        }
        if (_isActivateKey(event.logicalKey) && enabled) {
          widget.onPressed?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          scale: visuals.scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: visuals.fillColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: visuals.borderColor,
                width: visuals.borderWidth,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: visuals.shadowColor,
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 110),
              opacity: visuals.contentOpacity,
              child: DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: Colors.white.withOpacity(enabled ? 0.96 : 0.42),
                    size: 20,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickSettingTile extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onPressed;

  const _QuickSettingTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_QuickSettingTile> createState() => _QuickSettingTileState();
}

class _QuickSettingTileState extends State<_QuickSettingTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => EnsureVisible(
        alignment: 0.04,
        child: FocusableActionDetector(
          onShowFocusHighlight: (value) {
            if (_focused != value) {
              setState(() => _focused = value);
            }
          },
          child: SettingsFocusFrame(
            padding: EdgeInsets.zero,
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 110),
              opacity: _focused ? 1 : 0.95,
              child: TextButton(
                onPressed: widget.onPressed,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      Icon(widget.icon, size: 18, color: Colors.white70),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
