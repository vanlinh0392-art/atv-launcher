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

  const HomeLayoutPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Consumer<SettingsService>(
      builder: (context, settingsService, __) => ListView(
        key: const PageStorageKey<String>(HomeLayoutPanelPage.routeName),
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
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.of(context)
                      .pushNamed(ApplicationsPanelPage.routeName),
                  icon: const Icon(Icons.apps),
                  label: Text(localizations.applications),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context)
                      .pushNamed(LauncherSectionsPanelPage.routeName),
                  icon: const Icon(Icons.category_outlined),
                  label: Text(localizations.launcherSections),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context)
                      .pushNamed(StatusBarPanelPage.routeName),
                  icon: const Icon(Icons.tips_and_updates_outlined),
                  label: Text(localizations.statusBar),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => context.read<AppsService>().openSettings(),
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(localizations.systemSettings),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async => await _dateTimeFormatDialog(context),
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(localizations.dateAndTimeFormat),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async => await _backButtonActionDialog(context),
                  icon: const Icon(Icons.arrow_back_outlined),
                  label: Text(localizations.backButtonAction),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SettingsSurfaceCard(
            child: Column(
              children: [
                _SegmentedSettingCard<String>(
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
                _DiscreteSliderTile(
                  sliderKey: const Key('home_dock_auto_collapse_delay_slider'),
                  title: localizations.homeDockAutoCollapseDelayTitle,
                  subtitle: localizations.homeDockAutoCollapseDelayDescription,
                  icon: Icons.timer_outlined,
                  value: settingsService.homeDockAutoCollapseDelaySeconds,
                  minimum: SettingsService.homeDockAutoCollapseDelayMin,
                  maximum: SettingsService.homeDockAutoCollapseDelayMax,
                  step: SettingsService.homeDockAutoCollapseDelayStep,
                  suffix: 's',
                  onChanged:
                      settingsService.setHomeDockAutoCollapseDelaySeconds,
                ),
                const SizedBox(height: 10),
                _DiscreteSliderTile(
                  sliderKey: const Key('home_dock_glass_intensity_slider'),
                  title: localizations.homeDockGlassIntensityTitle,
                  subtitle: localizations.homeDockGlassIntensityDescription,
                  icon: Icons.blur_on_outlined,
                  value: settingsService.homeDockGlassIntensityPercent,
                  minimum: SettingsService.homeDockGlassIntensityMin,
                  maximum: SettingsService.homeDockGlassIntensityMax,
                  step: SettingsService.homeDockGlassIntensityStep,
                  suffix: '%',
                  onChanged: settingsService.setHomeDockGlassIntensityPercent,
                ),
                const SizedBox(height: 10),
                _DiscreteSliderTile(
                  sliderKey: const Key('home_dock_row_spacing_slider'),
                  title: localizations.homeDockRowSpacingTitle,
                  subtitle: localizations.homeDockRowSpacingDescription,
                  icon: Icons.height_outlined,
                  value: settingsService.homeDockRowSpacing,
                  minimum: SettingsService.homeDockRowSpacingMin,
                  maximum: SettingsService.homeDockRowSpacingMax,
                  step: SettingsService.homeDockRowSpacingStep,
                  suffix: 'dp',
                  onChanged: settingsService.setHomeDockRowSpacing,
                ),
                const SizedBox(height: 10),
                _IntegerStepperTile(
                  title: localizations.iconCornerRadiusTitle,
                  subtitle: localizations.iconCornerRadiusDescription,
                  icon: Icons.rounded_corner_outlined,
                  value: settingsService.appCardCornerRadius,
                  minimum: 0,
                  maximum: 24,
                  suffix: 'dp',
                  onChanged: settingsService.setAppCardCornerRadius,
                ),
                const SizedBox(height: 10),
                _DiscreteSliderTile(
                  sliderKey: const Key('app_card_layout_scale_slider'),
                  title: localizations.appCardLayoutSizeTitle,
                  subtitle: localizations.appCardLayoutSizeDescription,
                  icon: Icons.crop_16_9_outlined,
                  value: settingsService.appCardLayoutScalePercent,
                  minimum: SettingsService.appCardLayoutScaleMin,
                  maximum: SettingsService.appCardLayoutScaleMax,
                  step: SettingsService.appCardLayoutScaleStep,
                  suffix: '%',
                  onChanged: settingsService.setAppCardLayoutScalePercent,
                ),
                const SizedBox(height: 10),
                _DiscreteSliderTile(
                  title: localizations.iconSizeTitle,
                  subtitle: localizations.iconSizeDescription,
                  icon: Icons.photo_size_select_large_outlined,
                  value: settingsService.appCardMediaScalePercent,
                  minimum: SettingsService.appCardMediaScaleMin,
                  maximum: SettingsService.appCardMediaScaleMax,
                  step: SettingsService.appCardMediaScaleStep,
                  suffix: '%',
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) =>
                        snapshot.connectionState == ConnectionState.done
                            ? FLauncherAboutDialog(packageInfo: snapshot.data!)
                            : const SizedBox.shrink(),
                  ),
                ),
                icon: const Icon(Icons.info_outline),
                label: Text(localizations.aboutFlauncher),
              ),
            ),
          ),
        ],
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
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _shiftSelection(-1),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _shiftSelection(1),
          },
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

  void _shiftSelection(int direction) {
    final currentIndex =
        widget.segments.indexWhere((segment) => segment.value == widget.value);
    if (currentIndex < 0) {
      return;
    }
    final nextIndex =
        (currentIndex + direction).clamp(0, widget.segments.length - 1);
    if (nextIndex == currentIndex) {
      return;
    }
    widget.onSelectionChanged(<T>{widget.segments[nextIndex].value});
  }
}

class _IntegerStepperTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final int value;
  final int minimum;
  final int maximum;
  final String suffix;
  final ValueChanged<int> onChanged;

  const _IntegerStepperTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.suffix,
    required this.onChanged,
  });

  @override
  State<_IntegerStepperTile> createState() => _IntegerStepperTileState();
}

class _IntegerStepperTileState extends State<_IntegerStepperTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final canDecrease = widget.value > widget.minimum;
    final canIncrease = widget.value < widget.maximum;
    return EnsureVisible(
      alignment: 0.12,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _shiftValue(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _shiftValue(1),
        },
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
              child: Row(
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
                  ExcludeFocus(
                    child: FilledButton.tonal(
                      onPressed: canDecrease
                          ? () => widget.onChanged(widget.value - 1)
                          : null,
                      child: const Icon(Icons.remove),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${widget.value}${widget.suffix}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 12),
                  ExcludeFocus(
                    child: FilledButton.tonal(
                      onPressed: canIncrease
                          ? () => widget.onChanged(widget.value + 1)
                          : null,
                      child: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _shiftValue(int delta) {
    final next = (widget.value + delta).clamp(widget.minimum, widget.maximum);
    if (next != widget.value) {
      widget.onChanged(next);
    }
  }
}

class _DiscreteSliderTile extends StatefulWidget {
  final Key? sliderKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final int value;
  final int minimum;
  final int maximum;
  final int step;
  final String suffix;
  final ValueChanged<int> onChanged;

  const _DiscreteSliderTile({
    this.sliderKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.step,
    required this.suffix,
    required this.onChanged,
  });

  @override
  State<_DiscreteSliderTile> createState() => _DiscreteSliderTileState();
}

class _DiscreteSliderTileState extends State<_DiscreteSliderTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => EnsureVisible(
        alignment: 0.12,
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _shiftValue(-widget.step),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _shiftValue(widget.step),
          },
          child: FocusableActionDetector(
            onShowFocusHighlight: (value) {
              if (_focused != value) {
                setState(() => _focused = value);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: _focused
                    ? const Color(0x1A2F7BF5)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _focused
                      ? const Color(0xFF9ED4FF)
                      : Colors.white.withOpacity(0.05),
                  width: _focused ? 2.2 : 1,
                ),
                boxShadow: _focused
                    ? const [
                        BoxShadow(
                          color: Color(0x4D2A6BD8),
                          blurRadius: 28,
                          spreadRadius: 1,
                          offset: Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ]
                    : const [
                        BoxShadow(
                          color: Color(0x1F000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
              ),
              padding: const EdgeInsets.all(16),
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
                      const SizedBox(width: 16),
                      Text(
                        '${widget.value}${widget.suffix}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ExcludeFocus(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 8,
                        overlayShape: SliderComponentShape.noOverlay,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 10),
                        inactiveTrackColor: Colors.white24,
                        activeTrackColor: const Color(0xFF8CCBFF),
                        thumbColor: const Color(0xFFB7DBFF),
                      ),
                      child: Slider(
                        key: widget.sliderKey ??
                            const Key('app_card_media_scale_slider'),
                        value: widget.value.toDouble(),
                        min: widget.minimum.toDouble(),
                        max: widget.maximum.toDouble(),
                        divisions:
                            ((widget.maximum - widget.minimum) / widget.step)
                                .round(),
                        label: '${widget.value}${widget.suffix}',
                        onChanged: (value) =>
                            widget.onChanged(_snapValue(value)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  void _shiftValue(int delta) {
    final next = (widget.value + delta).clamp(widget.minimum, widget.maximum);
    if (next != widget.value) {
      widget.onChanged(next);
    }
  }

  int _snapValue(double rawValue) {
    final stepOffset = ((rawValue - widget.minimum) / widget.step).round();
    return (widget.minimum + (stepOffset * widget.step))
        .clamp(widget.minimum, widget.maximum);
  }
}
