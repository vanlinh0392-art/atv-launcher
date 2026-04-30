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
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_service.dart';

class StatusBarPanelPage extends StatelessWidget {
  static const String routeName = "status_bar_panel";
  final FocusNode? primaryFocusNode;

  const StatusBarPanelPage({
    super.key,
    this.primaryFocusNode,
  });

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
                focusNode: primaryFocusNode,
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
              SettingsStepperCard(
                selectorKey: const Key('status_bar_clock_scale_stepper'),
                buttonKeyPrefix: 'status_bar_clock_scale',
                title: localizations.dateAndTimeScaleTitle,
                subtitle: localizations.dateAndTimeScaleDescription,
                icon: Icons.text_fields_outlined,
                value: settings.statusBarClockScalePercent,
                minimum: SettingsService.statusBarClockScaleMin,
                maximum: SettingsService.statusBarClockScaleMax,
                step: SettingsService.statusBarClockScaleStep,
                valueLabelBuilder: (value) => '$value%',
                onChanged: settings.setStatusBarClockScalePercent,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
