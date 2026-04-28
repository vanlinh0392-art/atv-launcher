/*
 * FLauncher
 * Copyright (C) 2024 Oscar Rojas
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

import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_service.dart';

class StatusBarPanelPage extends StatelessWidget {
  static const String routeName = "status_bar_panel";

  const StatusBarPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();

    return ListView(
      children: [
        SettingsAdaptiveGrid(
          children: [
            SettingsMetricTile(
              label: localizations.autoHideAppBar,
              value: settings.autoHideAppBarEnabled
                  ? localizations.settingStateOn
                  : localizations.settingStateOff,
              icon: Icons.visibility_off_outlined,
            ),
            SettingsMetricTile(
              label: localizations.showRamInStatusBar,
              value: settings.showRamInStatusBar
                  ? localizations.settingStateOn
                  : localizations.settingStateOff,
              icon: Icons.memory_outlined,
            ),
            SettingsMetricTile(
              label: localizations.dateAndTimeScaleTitle,
              value: '${settings.statusBarClockScalePercent}%',
              icon: Icons.text_fields_outlined,
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsSurfaceCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              RoundedSwitchListTile(
                autofocus: true,
                value: settings.autoHideAppBarEnabled,
                onChanged: settings.setAutoHideAppBarEnabled,
                title: Text(
                  localizations.autoHideAppBar,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                secondary: const Icon(Icons.visibility_off_outlined),
              ),
              const SizedBox(height: 10),
              RoundedSwitchListTile(
                value: settings.showRamInStatusBar,
                onChanged: settings.setShowRamInStatusBar,
                title: Text(
                  localizations.showRamInStatusBar,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                secondary: const Icon(Icons.memory_outlined),
              ),
              const SizedBox(height: 10),
              RoundedSwitchListTile(
                value: settings.showDateInStatusBar,
                onChanged: settings.setShowDateInStatusBar,
                title: Text(
                  localizations.date,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                secondary: const Icon(Icons.calendar_today_outlined),
              ),
              const SizedBox(height: 10),
              RoundedSwitchListTile(
                value: settings.showTimeInStatusBar,
                onChanged: settings.setShowTimeInStatusBar,
                title: Text(
                  localizations.time,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                secondary: const Icon(Icons.watch_later_outlined),
              ),
              const SizedBox(height: 10),
              _ClockScaleSlider(
                value: settings.statusBarClockScalePercent,
                onChanged: settings.setStatusBarClockScalePercent,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClockScaleSlider extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _ClockScaleSlider({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_ClockScaleSlider> createState() => _ClockScaleSliderState();
}

class _ClockScaleSliderState extends State<_ClockScaleSlider> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _shiftValue(-SettingsService.statusBarClockScaleStep),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _shiftValue(SettingsService.statusBarClockScaleStep),
      },
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) {
          if (_focused != value) {
            setState(() => _focused = value);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_focused ? 0.06 : 0.03),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _focused
                  ? const Color(0xFF8CCBFF)
                  : Colors.white.withOpacity(0.05),
              width: _focused ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.text_fields_outlined, color: Colors.white70),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.dateAndTimeScaleTitle,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          localizations.dateAndTimeScaleDescription,
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
                    '${widget.value}%',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SliderTheme(
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
                  value: widget.value.toDouble(),
                  min: SettingsService.statusBarClockScaleMin.toDouble(),
                  max: SettingsService.statusBarClockScaleMax.toDouble(),
                  divisions: ((SettingsService.statusBarClockScaleMax -
                              SettingsService.statusBarClockScaleMin) /
                          SettingsService.statusBarClockScaleStep)
                      .round(),
                  label: '${widget.value}%',
                  onChanged: (value) => widget.onChanged(_snapValue(value)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shiftValue(int delta) {
    final next = (widget.value + delta).clamp(
      SettingsService.statusBarClockScaleMin,
      SettingsService.statusBarClockScaleMax,
    );
    if (next != widget.value) {
      widget.onChanged(next);
    }
  }

  int _snapValue(double rawValue) {
    final stepOffset =
        ((rawValue - SettingsService.statusBarClockScaleMin) /
                SettingsService.statusBarClockScaleStep)
            .round();
    return (SettingsService.statusBarClockScaleMin +
            (stepOffset * SettingsService.statusBarClockScaleStep))
        .clamp(
      SettingsService.statusBarClockScaleMin,
      SettingsService.statusBarClockScaleMax,
    );
  }
}
