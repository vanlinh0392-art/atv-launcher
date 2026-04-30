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

import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/widgets/pin_pad_dialog.dart';
import 'package:flauncher/widgets/right_panel_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/app.dart';
import '../models/category.dart';

class ApplicationInfoPanel extends StatelessWidget {
  final Category? category;
  final App application;
  final ImageProvider? applicationIcon;

  const ApplicationInfoPanel(
      {required this.category,
      required this.application,
      this.applicationIcon});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    final security = context.watch<ProfileSecurityService?>();
    final canManage = security?.canUseSensitiveAppActions() ?? true;

    return RightPanelDialog(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(
        children: [
          if (applicationIcon != null)
            Image(image: applicationIcon!, width: 50)
          else
            const Icon(Icons.image_not_supported_outlined),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              application.name,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        application.packageName,
        style: Theme.of(context).textTheme.bodySmall,
        overflow: TextOverflow.ellipsis,
      ),
      Text(
        "v${application.version}",
        style: Theme.of(context).textTheme.bodySmall,
        overflow: TextOverflow.ellipsis,
      ),
      if (!canManage) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Text(
            localizations.sensitiveActionsLockedHint,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          ),
        ),
      ],
      const Divider(),
      Expanded(
          child: SingleChildScrollView(
              child: Column(children: [
        TextButton(
          child: Row(
            children: [
              const Icon(Icons.open_in_new),
              Container(width: 8),
              Text(localizations.open,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          onPressed: () async {
            final allowed = await ensureAppLaunchAccess(
              context,
              application,
              title: localizations.unlockAppTitle,
              description: localizations.unlockAppDescription(application.name),
            );
            if (!allowed || !context.mounted) {
              return;
            }
            await context.read<AppsService>().launchApp(application);
            Navigator.of(context).pop();
          },
        ),
        if (canManage)
          TextButton(
            child: Row(
              children: [
                Icon(application.hidden
                    ? Icons.visibility
                    : Icons.visibility_off_outlined),
                Container(width: 8),
                Text(
                    application.hidden
                        ? localizations.show
                        : localizations.hide,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            onPressed: () async {
              if (application.hidden) {
                await context.read<AppsService>().showApplication(application);
              } else {
                await context.read<AppsService>().hideApplication(application);
              }
              Navigator.of(context).pop();
            },
          ),
        if (canManage && category != null)
          TextButton(
            child: Row(
              children: [
                const Icon(Icons.delete_sweep_outlined),
                Container(width: 8),
                Flexible(
                  child: Text(
                    localizations.removeFrom(category!.name),
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            onPressed: () async {
              await context
                  .read<AppsService>()
                  .removeFromCategory(application, category!);
              Navigator.of(context).pop();
            },
          ),
        if (canManage) ...[
          const Divider(),
          TextButton(
            child: Row(
              children: [
                const Icon(Icons.info_outlined),
                Container(width: 8),
                Text(localizations.appInfo,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            onPressed: () =>
                context.read<AppsService>().openAppInfo(application),
          ),
          TextButton(
            child: Row(
              children: [
                const Icon(Icons.delete_outlined),
                Container(width: 8),
                Text(localizations.uninstall,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            onPressed: () async {
              await context.read<AppsService>().uninstallApp(application);
              Navigator.of(context).pop();
            },
          ),
        ],
      ])))
    ]));
  }
}
