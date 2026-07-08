import 'dart:async';

import 'package:flauncher/app_card_highlight_palette.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flauncher/widgets/settings/date_time_format_dialog.dart';
import 'package:flauncher/widgets/settings/flauncher_about_dialog.dart';
import 'package:flauncher/widgets/settings/launcher_sections_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/status_bar_panel_page.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
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
  static const List<String> _appHighlightColorOptions = <String>[
    SettingsService.appCardHighlightColorLightBlue,
    SettingsService.appCardHighlightColorMint,
    SettingsService.appCardHighlightColorAmber,
    SettingsService.appCardHighlightColorCoral,
    SettingsService.appCardHighlightColorViolet,
    SettingsService.appCardHighlightColorWhite,
  ];

  final FocusNode? primaryFocusNode;

  const HomeLayoutPanelPage({
    super.key,
    this.primaryFocusNode,
  });

  @override
  State<HomeLayoutPanelPage> createState() => _HomeLayoutPanelPageState();
}

class _HomeLayoutPanelPageState extends State<HomeLayoutPanelPage> {
  late final FocusNode _appLocaleFocusNode;
  bool _showDeferredSections = false;
  Timer? _deferredSectionsTimer;
  late final Map<_HomeLayoutQuickTarget, GlobalKey> _quickTargetKeys =
      <_HomeLayoutQuickTarget, GlobalKey>{
    for (final target in _HomeLayoutQuickTarget.values)
      target: GlobalKey(debugLabel: 'home_layout_target_${target.name}'),
  };
  late final Map<_HomeLayoutQuickTarget, FocusNode> _quickTargetFocusNodes =
      <_HomeLayoutQuickTarget, FocusNode>{};

  @override
  void initState() {
    super.initState();
    _scheduleDeferredSections();
    _appLocaleFocusNode = widget.primaryFocusNode ??
        FocusNode(debugLabel: 'home_layout_target_appLocale');
    for (final target in _HomeLayoutQuickTarget.values) {
      _quickTargetFocusNodes[target] =
          target == _HomeLayoutQuickTarget.appLocale
              ? _appLocaleFocusNode
              : FocusNode(debugLabel: 'home_layout_target_${target.name}');
    }
    if (widget.primaryFocusNode != null) {
      return;
    }
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
    _deferredSectionsTimer?.cancel();
    for (final focusNode in _quickTargetFocusNodes.values) {
      if (identical(focusNode, widget.primaryFocusNode)) {
        continue;
      }
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsSurfaceCard(
                  child: SettingsChoiceCard<String>(
                    key: _quickTargetKeys[_HomeLayoutQuickTarget.appLocale],
                    focusNode: _quickTargetFocusNodes[
                        _HomeLayoutQuickTarget.appLocale],
                    selectorKey: const Key('app_locale_mode_selector'),
                    optionKeyPrefix: 'app_locale_mode_option',
                    title: localizations.appLanguageTitle,
                    subtitle: localizations.appLanguageDescription,
                    icon: Icons.language_outlined,
                    value: settingsService.appLocaleMode,
                    options: <SettingsChoiceOption<String>>[
                      SettingsChoiceOption<String>(
                        value: SettingsService.appLocaleSystem,
                        label: localizations.appLanguageSystem,
                      ),
                      SettingsChoiceOption<String>(
                        value: SettingsService.appLocaleEnglish,
                        label: localizations.appLanguageEnglish,
                      ),
                      SettingsChoiceOption<String>(
                        value: SettingsService.appLocaleVietnamese,
                        label: localizations.appLanguageVietnamese,
                      ),
                    ],
                    valueLabelBuilder: (value) =>
                        _localeModeLabel(localizations, value),
                    onChanged: settingsService.setAppLocaleMode,
                  ),
                ),
                const SizedBox(height: 18),
                SettingsSurfaceCard(
                  child: SettingsChoiceCard<int>(
                    key: _quickTargetKeys[_HomeLayoutQuickTarget.dockRows],
                    focusNode:
                        _quickTargetFocusNodes[_HomeLayoutQuickTarget.dockRows],
                    selectorKey: const Key('home_dock_rows_selector'),
                    optionKeyPrefix: 'home_dock_rows_option',
                    title: localizations.homeDockHeightTitle,
                    subtitle: localizations.homeDockHeightDescription,
                    icon: Icons.view_agenda_outlined,
                    value: settingsService.homeDockRowsPreset,
                    options: const <SettingsChoiceOption<int>>[
                      SettingsChoiceOption<int>(value: 2, label: '2'),
                      SettingsChoiceOption<int>(value: 3, label: '3'),
                      SettingsChoiceOption<int>(value: 4, label: '4'),
                    ],
                    valueLabelBuilder: (value) => value.toString(),
                    onChanged: settingsService.setHomeDockRowsPreset,
                  ),
                ),
                const SizedBox(height: 18),
                SettingsSurfaceCard(
                  child: SettingsChoiceCard<int>(
                    key: _quickTargetKeys[_HomeLayoutQuickTarget.collapsedRows],
                    focusNode: _quickTargetFocusNodes[
                        _HomeLayoutQuickTarget.collapsedRows],
                    selectorKey: const Key('home_dock_collapsed_rows_selector'),
                    optionKeyPrefix: 'home_dock_collapsed_rows_option',
                    title: localizations.homeDockCollapsedRowsTitle,
                    subtitle: localizations.homeDockCollapsedRowsDescription,
                    icon: Icons.unfold_less_double_outlined,
                    value: settingsService.homeDockCollapsedRowsPreset,
                    options: const <SettingsChoiceOption<int>>[
                      SettingsChoiceOption<int>(value: 1, label: '1'),
                      SettingsChoiceOption<int>(value: 2, label: '2'),
                    ],
                    valueLabelBuilder: (value) => value.toString(),
                    onChanged: settingsService.setHomeDockCollapsedRowsPreset,
                  ),
                ),
                const SizedBox(height: 18),
                SettingsSurfaceCard(
                  child: RoundedSwitchListTile(
                    key: _quickTargetKeys[_HomeLayoutQuickTarget.autoCollapse],
                    focusNode: _quickTargetFocusNodes[
                        _HomeLayoutQuickTarget.autoCollapse],
                    debugLabel: 'home_layout_target_autoCollapse',
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
                ),
                const SizedBox(height: 18),
                SettingsSurfaceCard(
                  child: SettingsChoiceCard<int>(
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
                        .map((value) => SettingsChoiceOption<int>(
                              value: value,
                              label: '${value}s',
                            ))
                        .toList(growable: false),
                    valueLabelBuilder: (value) => '${value}s',
                    onChanged:
                        settingsService.setHomeDockAutoCollapseDelaySeconds,
                  ),
                ),
                const SizedBox(height: 18),
                SettingsSurfaceCard(
                  child: SettingsChoiceCard<int>(
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
                        .map((value) => SettingsChoiceOption<int>(
                              value: value,
                              label: '${value}%',
                            ))
                        .toList(growable: false),
                    valueLabelBuilder: (value) => '${value}%',
                    onChanged: settingsService.setHomeDockGlassIntensityPercent,
                  ),
                ),
                const SizedBox(height: 18),
                SettingsSurfaceCard(
                  child: SettingsChoiceCard<String>(
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
                        .map((value) => SettingsChoiceOption<String>(
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
                ),
                const SizedBox(height: 18),
                SettingsSurfaceCard(
                  child: SettingsStepperCard(
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
                ),
                const SizedBox(height: 18),
                SettingsSurfaceCard(
                  child: SettingsStepperCard(
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
                ),
                const SizedBox(height: 18),
                SettingsSurfaceCard(
                  child: SettingsStepperCard(
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
                ),
                const SizedBox(height: 18),
                SettingsSurfaceCard(
                  child: SettingsStepperCard(
                    key: _quickTargetKeys[_HomeLayoutQuickTarget.cardSize],
                    focusNode:
                        _quickTargetFocusNodes[_HomeLayoutQuickTarget.cardSize],
                    selectorKey: const Key('app_card_layout_scale_stepper'),
                    buttonKeyPrefix: 'app_card_layout_scale',
                    title: localizations.appCardLayoutSizeTitle,
                    subtitle: localizations.appCardLayoutSizeDescription,
                    icon: Icons.crop_16_9_outlined,
                    value: settingsService.appCardLayoutScalePercent,
                    valueLabelBuilder: (value) => '${value}%',
                    minimum:
                        HomeLayoutPanelPage._appCardLayoutScaleOptions.first,
                    maximum:
                        HomeLayoutPanelPage._appCardLayoutScaleOptions.last,
                    step: 5,
                    onChanged: settingsService.setAppCardLayoutScalePercent,
                  ),
                ),
                const SizedBox(height: 18),
                SettingsSurfaceCard(
                  child: SettingsStepperCard(
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
                ),
                const SizedBox(height: 18),
                SettingsSurfaceCard(
                  child: Column(
                    children: [
                      RoundedSwitchListTile(
                        debugLabel: 'home_layout_app_highlight_animation',
                        value: settingsService.appHighlightAnimationEnabled,
                        onChanged:
                            settingsService.setAppHighlightAnimationEnabled,
                        title: Text(localizations.appCardHighlightAnimation,
                            style: Theme.of(context).textTheme.bodyMedium),
                        secondary: const Icon(Icons.filter_center_focus),
                      ),
                      const SizedBox(height: 10),
                      SettingsChoiceCard<String>(
                        selectorKey:
                            const Key('app_card_highlight_color_selector'),
                        optionKeyPrefix: 'app_card_highlight_color_option',
                        title: localizations.appCardHighlightColorTitle,
                        subtitle:
                            localizations.appCardHighlightColorDescription,
                        icon: Icons.palette_outlined,
                        value: settingsService.appHighlightAnimationColorPreset,
                        options: HomeLayoutPanelPage._appHighlightColorOptions
                            .map(
                              (value) => SettingsChoiceOption<String>(
                                value: value,
                                label: _highlightColorLabel(
                                  localizations,
                                  value,
                                ),
                                swatchColor:
                                    appCardHighlightPresetColors[value],
                              ),
                            )
                            .toList(growable: false),
                        valueLabelBuilder: (value) =>
                            _highlightColorLabel(localizations, value),
                        onChanged:
                            settingsService.setAppHighlightAnimationColorPreset,
                      ),
                      const SizedBox(height: 10),
                      RoundedSwitchListTile(
                        debugLabel: 'home_layout_app_key_click',
                        value: settingsService.appKeyClickEnabled,
                        onChanged: settingsService.setAppKeyClickEnabled,
                        title: Text(localizations.appKeyClick,
                            style: Theme.of(context).textTheme.bodyMedium),
                        secondary: const Icon(Icons.notifications_active),
                      ),
                      const SizedBox(height: 10),
                      RoundedSwitchListTile(
                        debugLabel: 'home_layout_show_category_titles',
                        value: settingsService.showCategoryTitles,
                        onChanged: settingsService.setShowCategoryTitles,
                        title: Text(localizations.showCategoryTitles,
                            style: Theme.of(context).textTheme.bodyMedium),
                        secondary: const Icon(Icons.abc),
                      ),
                    ],
                  ),
                ),
                if (_showDeferredSections) ...[
                  const SizedBox(height: 18),
                  SettingsSurfaceCard(
                    child: Column(
                      children: [
                        SettingsActionCard(
                          title: localizations.applications,
                          icon: Icons.apps_outlined,
                          onPressed: () async => Navigator.of(context)
                              .pushNamed(ApplicationsPanelPage.routeName),
                        ),
                        const SizedBox(height: 10),
                        SettingsActionCard(
                          title: localizations.launcherSections,
                          icon: Icons.category_outlined,
                          onPressed: () async => Navigator.of(context)
                              .pushNamed(LauncherSectionsPanelPage.routeName),
                        ),
                        const SizedBox(height: 10),
                        SettingsActionCard(
                          title: localizations.statusBar,
                          subtitle: localizations.statusBarDescription,
                          icon: Icons.tips_and_updates_outlined,
                          onPressed: () async => Navigator.of(context)
                              .pushNamed(StatusBarPanelPage.routeName),
                        ),
                        const SizedBox(height: 10),
                        SettingsActionCard(
                          title: localizations.systemSettings,
                          subtitle:
                              localizations.actionOpenSystemSettingsSubtitle,
                          icon: Icons.settings_outlined,
                          onPressed: () async =>
                              context.read<AppsService>().openSettings(),
                        ),
                        const SizedBox(height: 10),
                        SettingsActionCard(
                          title: localizations.dateAndTimeFormat,
                          icon: Icons.date_range_outlined,
                          onPressed: () => _dateTimeFormatDialog(context),
                        ),
                        const SizedBox(height: 10),
                        SettingsActionCard(
                          title: localizations.backButtonAction,
                          icon: Icons.arrow_back_outlined,
                          onPressed: () => _backButtonActionDialog(context),
                        ),
                        const SizedBox(height: 10),
                        SettingsActionCard(
                          title: localizations.aboutFlauncher,
                          icon: Icons.info_outline,
                          onPressed: () async => showDialog(
                            context: context,
                            builder: (_) => FutureBuilder<PackageInfo>(
                              future: PackageInfo.fromPlatform(),
                              builder: (context, snapshot) =>
                                  snapshot.connectionState ==
                                          ConnectionState.done
                                      ? FLauncherAboutDialog(
                                          packageInfo: snapshot.data!)
                                      : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleDeferredSections() {
    _deferredSectionsTimer?.cancel();
    _deferredSectionsTimer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted || _showDeferredSections) {
        return;
      }
      setState(() {
        _showDeferredSections = true;
      });
    });
  }

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

  String _highlightColorLabel(AppLocalizations localizations, String value) {
    switch (value) {
      case SettingsService.appCardHighlightColorMint:
        return localizations.colorPresetMint;
      case SettingsService.appCardHighlightColorAmber:
        return localizations.colorPresetAmber;
      case SettingsService.appCardHighlightColorCoral:
        return localizations.colorPresetCoral;
      case SettingsService.appCardHighlightColorViolet:
        return localizations.colorPresetViolet;
      case SettingsService.appCardHighlightColorWhite:
        return localizations.colorPresetWhite;
      default:
        return localizations.colorPresetLightBlue;
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

}
