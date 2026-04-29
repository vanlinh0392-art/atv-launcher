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

import 'package:flauncher/widgets/right_panel_dialog.dart';
import 'package:flauncher/widgets/settings/accessibility_manager_panel_page.dart';
import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flauncher/widgets/settings/backup_restore_panel_page.dart';
import 'package:flauncher/widgets/settings/density_panel_page.dart';
import 'package:flauncher/widgets/settings/diagnostics_panel_page.dart';
import 'package:flauncher/widgets/settings/launcher_sections_panel_page.dart';
import 'package:flauncher/widgets/settings/gradient_panel_page.dart';
import 'package:flauncher/widgets/settings/home_layout_panel_page.dart';
import 'package:flauncher/widgets/settings/launcher_section_panel_page.dart';
import 'package:flauncher/widgets/settings/permissions_panel_page.dart';
import 'package:flauncher/widgets/settings/private_dns_panel_page.dart';
import 'package:flauncher/widgets/settings/profiles_security_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_panel_page.dart';
import 'package:flauncher/widgets/settings/status_bar_panel_page.dart';
import 'package:flauncher/widgets/settings/system_core_panel_page.dart';
import 'package:flauncher/widgets/settings/voice_search_panel_page.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
import 'package:flutter/material.dart';

class SettingsPanel extends StatefulWidget {
  final String? initialRoute;

  const SettingsPanel({Key? key, this.initialRoute}) : super(key: key);

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) {
            return;
          }
          final handledByInnerNavigator =
              await _navigatorKey.currentState!.maybePop();
          if (!handledByInnerNavigator && mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final settingsTheme = theme.copyWith(
                textButtonTheme: TextButtonThemeData(
                  style: SettingsButtonStyles.text(context),
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: SettingsButtonStyles.filled(context),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: SettingsButtonStyles.elevated(context),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: SettingsButtonStyles.text(context),
                ),
                iconButtonTheme: IconButtonThemeData(
                  style: SettingsButtonStyles.icon(context),
                ),
              );
              return Theme(
                data: settingsTheme,
                child: RightPanelDialog(
                  width: 1360,
                  child: Navigator(
                    key: _navigatorKey,
                    initialRoute:
                        widget.initialRoute ?? SettingsPanelPage.routeName,
                    onGenerateRoute: (settings) {
                      switch (settings.name) {
                        case SettingsPanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => SettingsPanelPage());
                        case HomeLayoutPanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => HomeLayoutPanelPage());
                        case WallpaperPanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => WallpaperPanelPage());
                        case VoiceSearchPanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => VoiceSearchPanelPage());
                        case ProfilesSecurityPanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => ProfilesSecurityPanelPage());
                        case AccessibilityManagerPanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => AccessibilityManagerPanelPage());
                        case SystemCorePanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => SystemCorePanelPage());
                        case DensityPanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => DensityPanelPage());
                        case PrivateDnsPanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => PrivateDnsPanelPage());
                        case PermissionsPanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => PermissionsPanelPage());
                        case BackupRestorePanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => BackupRestorePanelPage());
                        case DiagnosticsPanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => DiagnosticsPanelPage());
                        case StatusBarPanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => StatusBarPanelPage());
                        case GradientPanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => GradientPanelPage());
                        case ApplicationsPanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => ApplicationsPanelPage());
                        case LauncherSectionsPanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => LauncherSectionsPanelPage());
                        case LauncherSectionPanelPage.routeName:
                          return MaterialPageRoute(
                              builder: (_) => LauncherSectionPanelPage(
                                  sectionIndex: settings.arguments as int?));
                        default:
                          throw ArgumentError.value(
                            settings.name,
                            "settings.name",
                            "Route not supported.",
                          );
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
}
