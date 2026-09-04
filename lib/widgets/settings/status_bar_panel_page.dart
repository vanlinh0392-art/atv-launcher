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
      key: const PageStorageKey<String>(StatusBarPanelPage.routeName),
      children: [
        SettingsSurfaceCard(
          padding: TvDrawerTokens.surfacePadding,
          child: Column(
            children: [
              SettingsChoiceCard<String>(
                focusNode: primaryFocusNode,
                selectorKey: const Key('status_bar_date_format_card'),
                optionKeyPrefix: 'status_bar_date_format',
                title: 'Định dạng ngày',
                icon: Icons.calendar_month_outlined,
                value: settings.dateFormat,
                options: const [
                  SettingsChoiceOption<String>(
                    value: "Thứ 5 ngày d/M/y",
                    label: "Thứ 5 ngày 3/9/2026",
                  ),
                  SettingsChoiceOption<String>(
                    value: "Thứ 5 ngày d-M-y",
                    label: "Thứ 5 ngày 3-9-2026",
                  ),
                  SettingsChoiceOption<String>(
                    value: "E d/M",
                    label: "Th 5 3/9 (Gọn)",
                  ),
                  SettingsChoiceOption<String>(
                    value: "d/M/y",
                    label: "03/09/2026",
                  ),
                ],
                valueLabelBuilder: (val) {
                  if (val == "Thứ 5 ngày d/M/y") return "Thứ 5 ngày 3/9/2026";
                  if (val == "Thứ 5 ngày d-M-y") return "Thứ 5 ngày 3-9-2026";
                  if (val == "E d/M") return "Th 5 3/9 (Gọn)";
                  if (val == "d/M/y") return "03/09/2026";
                  return val;
                },
                onChanged: settings.setDateFormat,
              ),
              const SizedBox(height: TvDrawerTokens.rowSpacing),
              SettingsChoiceCard<String>(
                selectorKey: const Key('status_bar_time_format_card'),
                optionKeyPrefix: 'status_bar_time_format',
                title: 'Định dạng giờ',
                icon: Icons.access_time_outlined,
                value: settings.timeFormat,
                options: const [
                  SettingsChoiceOption<String>(
                    value: "H:mm",
                    label: "24 giờ (14:30)",
                  ),
                  SettingsChoiceOption<String>(
                    value: "h:mm a",
                    label: "12 giờ (02:30 PM)",
                  ),
                  SettingsChoiceOption<String>(
                    value: "H:mm:ss",
                    label: "Kèm giây (14:30:45)",
                  ),
                ],
                valueLabelBuilder: (val) {
                  switch (val) {
                    case "H:mm":
                      return "24 giờ (14:30)";
                    case "h:mm a":
                      return "12 giờ (02:30 PM)";
                    case "H:mm:ss":
                      return "Kèm giây (14:30:45)";
                    default:
                      return val;
                  }
                },
                onChanged: settings.setTimeFormat,
              ),
              const SizedBox(height: TvDrawerTokens.rowSpacing),
              SettingsChoiceCard<String>(
                selectorKey: const Key('status_bar_date_style_card'),
                optionKeyPrefix: 'status_bar_date_style',
                title: 'Kiểu chữ',
                icon: Icons.font_download_outlined,
                value: settings.statusBarDateStyle,
                options: const [
                  SettingsChoiceOption<String>(
                    value: SettingsService.dateStyleStandard,
                    label: "Hiện đại (Roboto)",
                  ),
                  SettingsChoiceOption<String>(
                    value: SettingsService.dateStyleBold,
                    label: "Đậm nét (Tương phản cao)",
                  ),
                  SettingsChoiceOption<String>(
                    value: SettingsService.dateStyleMonospace,
                    label: "Số điện tử (Monospace)",
                  ),
                ],
                valueLabelBuilder: (val) {
                  switch (val) {
                    case SettingsService.dateStyleBold:
                      return "Đậm nét (Tương phản cao)";
                    case SettingsService.dateStyleMonospace:
                      return "Số điện tử (Monospace)";
                    case SettingsService.dateStyleStandard:
                    default:
                      return "Hiện đại (Roboto)";
                  }
                },
                onChanged: settings.setStatusBarDateStyle,
              ),
              const SizedBox(height: TvDrawerTokens.rowSpacing),
              SettingsStepperCard(
                selectorKey: const Key('status_bar_clock_scale_stepper'),
                buttonKeyPrefix: 'status_bar_clock_scale',
                title: localizations.dateAndTimeScaleTitle,
                icon: Icons.text_fields_outlined,
                value: settings.statusBarClockScalePercent,
                minimum: SettingsService.statusBarClockScaleMin,
                maximum: SettingsService.statusBarClockScaleMax,
                step: SettingsService.statusBarClockScaleStep,
                valueLabelBuilder: (value) => '$value%',
                onChanged: settings.setStatusBarClockScalePercent,
              ),
              const SizedBox(height: TvDrawerTokens.rowSpacing),
              RoundedSwitchListTile(
                value: settings.showDateInStatusBar,
                onChanged: settings.setShowDateInStatusBar,
                title: Text(
                  localizations.date,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                secondary: const Icon(Icons.calendar_today_outlined),
              ),
              const SizedBox(height: TvDrawerTokens.rowSpacing),
              RoundedSwitchListTile(
                value: settings.showTimeInStatusBar,
                onChanged: settings.setShowTimeInStatusBar,
                title: Text(
                  localizations.time,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                secondary: const Icon(Icons.watch_later_outlined),
              ),
              const SizedBox(height: TvDrawerTokens.rowSpacing),
              RoundedSwitchListTile(
                value: settings.showWeatherInStatusBar,
                onChanged: settings.setShowWeatherInStatusBar,
                title: Text(
                  localizations.showWeatherInStatusBar,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                secondary: const Icon(Icons.wb_sunny_outlined),
              ),
              const SizedBox(height: TvDrawerTokens.rowSpacing),
              RoundedSwitchListTile(
                value: settings.showRamInStatusBar,
                onChanged: settings.setShowRamInStatusBar,
                title: Text(
                  localizations.showRamInStatusBar,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                secondary: const Icon(Icons.memory_outlined),
              ),
              const SizedBox(height: TvDrawerTokens.rowSpacing),
              RoundedSwitchListTile(
                value: settings.autoHideAppBarEnabled,
                onChanged: settings.setAutoHideAppBarEnabled,
                title: Text(
                  localizations.autoHideAppBar,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                secondary: const Icon(Icons.visibility_off_outlined),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
