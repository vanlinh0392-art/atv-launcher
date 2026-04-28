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

class HomeLayoutPanelPage extends StatelessWidget {
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
              children: [
                SettingsMetricTile(
                  label: localizations.appCardHighlightAnimation,
                  value: _boolLabel(localizations,
                      settingsService.appHighlightAnimationEnabled),
                  icon: Icons.filter_center_focus,
                ),
                SettingsMetricTile(
                  label: localizations.appKeyClick,
                  value: _boolLabel(
                      localizations, settingsService.appKeyClickEnabled),
                  icon: Icons.notifications_active_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.showCategoryTitles,
                  value: _visibilityLabel(
                      localizations, settingsService.showCategoryTitles),
                  icon: Icons.abc_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.appLanguageTitle,
                  value: _localeModeLabel(
                    localizations,
                    settingsService.appLocaleMode,
                  ),
                  icon: Icons.language_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.homeDockHeightTitle,
                  value: settingsService.homeDockRowsPreset.toString(),
                  icon: Icons.view_agenda_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.homeDockCollapsedRowsTitle,
                  value: settingsService.homeDockCollapsedRowsPreset.toString(),
                  icon: Icons.unfold_less_double_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.homeDockAutoCollapseTitle,
                  value: _boolLabel(
                    localizations,
                    settingsService.homeDockAutoCollapseEnabled,
                  ),
                  icon: Icons.unfold_less_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.homeDockAutoCollapseDelayTitle,
                  value: '${settingsService.homeDockAutoCollapseDelaySeconds}s',
                  icon: Icons.timer_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.homeDockGlassIntensityTitle,
                  value: '${settingsService.homeDockGlassIntensityPercent}%',
                  icon: Icons.blur_on_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.homeDockRowSpacingTitle,
                  value: '${settingsService.homeDockRowSpacing}dp',
                  icon: Icons.height_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.iconCornerRadiusTitle,
                  value: '${settingsService.appCardCornerRadius}dp',
                  icon: Icons.rounded_corner_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.settingsUiTransparencyTitle,
                  value: '${settingsService.settingsUiTransparencyPercent}%',
                  icon: Icons.opacity_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.appCardLayoutSizeTitle,
                  value: '${settingsService.appCardLayoutScalePercent}%',
                  icon: Icons.crop_16_9_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.iconSizeTitle,
                  value: '${settingsService.appCardMediaScalePercent}%',
                  icon: Icons.photo_size_select_large_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: Column(
                children: [
                  _SegmentedSettingCard<String>(
                    key: const Key('home_layout_language_card'),
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
                    selectorKey:
                        const Key('home_dock_auto_collapse_delay_selector'),
                    optionKeyPrefix: 'home_dock_auto_collapse_delay_option',
                    title: localizations.homeDockAutoCollapseDelayTitle,
                    subtitle:
                        localizations.homeDockAutoCollapseDelayDescription,
                    icon: Icons.timer_outlined,
                    value: settingsService.homeDockAutoCollapseDelaySeconds,
                    options: _dockCollapseDelayOptions
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
                    selectorKey:
                        const Key('home_dock_glass_intensity_selector'),
                    optionKeyPrefix: 'home_dock_glass_intensity_option',
                    title: localizations.homeDockGlassIntensityTitle,
                    subtitle: localizations.homeDockGlassIntensityDescription,
                    icon: Icons.blur_on_outlined,
                    value: settingsService.homeDockGlassIntensityPercent,
                    options: _dockGlassIntensityOptions
                        .map((value) => _ChoiceOption<int>(
                              value: value,
                              label: '${value}%',
                            ))
                        .toList(growable: false),
                    valueLabelBuilder: (value) => '${value}%',
                    onChanged: settingsService.setHomeDockGlassIntensityPercent,
                  ),
                  const SizedBox(height: 10),
                  _StepperSettingCard(
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
                    selectorKey:
                        const Key('settings_ui_transparency_stepper'),
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
                    selectorKey: const Key('app_card_layout_scale_selector'),
                    optionKeyPrefix: 'app_card_layout_scale_option',
                    title: localizations.appCardLayoutSizeTitle,
                    subtitle: localizations.appCardLayoutSizeDescription,
                    icon: Icons.crop_16_9_outlined,
                    value: settingsService.appCardLayoutScalePercent,
                    options: _appCardLayoutScaleOptions
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

  String _visibilityLabel(AppLocalizations localizations, bool value) => value
      ? localizations.settingVisibilityShown
      : localizations.settingVisibilityHidden;

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

class _SegmentedSettingCard<T> extends StatefulWidget {
  final Key? segmentedButtonKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final T value;
  final List<ButtonSegment<T>> segments;
  final ValueChanged<Set<T>> onSelectionChanged;

  const _SegmentedSettingCard({
    super.key,
    this.segmentedButtonKey,
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
  bool _focused = false;

  @override
  Widget build(BuildContext context) => EnsureVisible(
        alignment: 0.12,
        child: Focus(
          canRequestFocus: false,
          onKeyEvent: (_, event) => _handleSelectionKeyEvent(event),
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
                    ExcludeFocus(
                      child: SegmentedButton<T>(
                        key: widget.segmentedButtonKey,
                        showSelectedIcon: false,
                        multiSelectionEnabled: false,
                        segments: widget.segments,
                        selected: <T>{widget.value},
                        onSelectionChanged: widget.onSelectionChanged,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  KeyEventResult _handleSelectionKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      return _shiftSelection(-1)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      return _shiftSelection(1)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  bool _shiftSelection(int direction) {
    final currentIndex =
        widget.segments.indexWhere((segment) => segment.value == widget.value);
    if (currentIndex < 0) {
      return false;
    }
    final nextIndex =
        (currentIndex + direction).clamp(0, widget.segments.length - 1);
    if (nextIndex == currentIndex) {
      return false;
    }
    widget.onSelectionChanged(<T>{widget.segments[nextIndex].value});
    return true;
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
  bool _focused = false;

  @override
  Widget build(BuildContext context) => EnsureVisible(
        alignment: 0.12,
        child: Focus(
          canRequestFocus: false,
          onKeyEvent: (_, event) => _handleSelectionKeyEvent(event),
          child: FocusableActionDetector(
            onShowFocusHighlight: (value) {
              if (_focused != value) {
                setState(() => _focused = value);
              }
            },
            child: SettingsFocusFrame(
              key: widget.selectorKey,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _focused ? 1 : 0.96,
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
                    ExcludeFocus(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: widget.options.map((option) {
                          final selected = option.value == widget.value;
                          final button = selected
                              ? FilledButton(
                                  onPressed: () =>
                                      widget.onChanged(option.value),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(option.label),
                                )
                              : FilledButton.tonal(
                                  onPressed: () =>
                                      widget.onChanged(option.value),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(option.label),
                                );
                          final buttonKeyPrefix = widget.optionKeyPrefix;
                          if (buttonKeyPrefix == null) {
                            return button;
                          }
                          return KeyedSubtree(
                            key: ValueKey<String>(
                              '${buttonKeyPrefix}_${option.value}',
                            ),
                            child: button,
                          );
                        }).toList(growable: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  KeyEventResult _handleSelectionKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      return _shiftSelection(-1)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      return _shiftSelection(1)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  bool _shiftSelection(int direction) {
    final currentIndex =
        widget.options.indexWhere((option) => option.value == widget.value);
    if (currentIndex < 0) {
      return false;
    }
    final nextIndex =
        (currentIndex + direction).clamp(0, widget.options.length - 1);
    if (nextIndex == currentIndex) {
      return false;
    }
    widget.onChanged(widget.options[nextIndex].value);
    return true;
  }
}

class _StepperSettingCard extends StatefulWidget {
  final Key? selectorKey;
  final String? buttonKeyPrefix;
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
    this.selectorKey,
    this.buttonKeyPrefix,
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
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final canDecrease = widget.value > widget.minimum;
    final canIncrease = widget.value < widget.maximum;
    return EnsureVisible(
      alignment: 0.12,
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: (_, event) => _handleStepperKeyEvent(event),
        child: FocusableActionDetector(
          onShowFocusHighlight: (value) {
            if (_focused != value) {
              setState(() => _focused = value);
            }
          },
          child: SettingsFocusFrame(
            key: widget.selectorKey,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _focused ? 1 : 0.96,
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
                      ExcludeFocus(
                        child: FilledButton.tonal(
                          onPressed: canDecrease
                              ? () => _shiftValue(-widget.step)
                              : null,
                          key: widget.buttonKeyPrefix == null
                              ? null
                              : ValueKey<String>(
                                  '${widget.buttonKeyPrefix}_decrease',
                                ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
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
                      ExcludeFocus(
                        child: FilledButton.tonal(
                          onPressed: canIncrease
                              ? () => _shiftValue(widget.step)
                              : null,
                          key: widget.buttonKeyPrefix == null
                              ? null
                              : ValueKey<String>(
                                  '${widget.buttonKeyPrefix}_increase',
                                ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
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

  KeyEventResult _handleStepperKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      return _shiftValue(-widget.step)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      return _shiftValue(widget.step)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
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
