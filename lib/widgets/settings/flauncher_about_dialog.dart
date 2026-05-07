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

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

class FLauncherAboutDialog extends StatelessWidget {
  static const String _legaleseOwner = String.fromEnvironment(
    'LAUNCHER_LEGALESE_OWNER',
    defaultValue: 'ATV Launcher',
  );
  static const String _sourceRepoUrl = String.fromEnvironment(
    'LAUNCHER_SOURCE_REPO_URL',
    defaultValue: 'https://github.com/vanlinh0392-art/atv-launcher',
  );

  final PackageInfo packageInfo;

  const FLauncherAboutDialog({
    super.key,
    required this.packageInfo,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AboutDialog(
      applicationName: packageInfo.appName,
      applicationVersion: "${packageInfo.version} (${packageInfo.buildNumber})",
      applicationIcon: Image.asset("assets/logo.png", height: 72),
      applicationLegalese: "© 2026 $_legaleseOwner",
      children: [
        const SizedBox(height: 24),
        Text(localizations.textAboutDialog(_sourceRepoUrl)),
      ],
    );
  }
}
