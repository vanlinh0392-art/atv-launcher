import 'dart:math' as math;

import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/widgets/pin_pad_dialog.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class ProfilesSecurityPanelPage extends StatefulWidget {
  static const String routeName = 'profiles_security_panel';

  const ProfilesSecurityPanelPage({super.key});

  @override
  State<ProfilesSecurityPanelPage> createState() =>
      _ProfilesSecurityPanelPageState();
}

class _ProfilesSecurityPanelPageState extends State<ProfilesSecurityPanelPage> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Consumer2<ProfileSecurityService, AppsService>(
      builder: (context, security, appsService, _) {
        final hiddenAppsCount =
            appsService.applications.where((app) => app.hidden).length;
        final lockedAppsCount = security
            .profileById(ProfileSecurityService.ownerProfileId)
            .lockedPackages
            .length;
        final viewSize = MediaQuery.sizeOf(context);
        final metricsWideLayout = viewSize.width >= 1080;
        final splitLayout = viewSize.width >= 1500 && viewSize.height >= 820;

        return ListView(
          key:
              const PageStorageKey<String>(ProfilesSecurityPanelPage.routeName),
          padding: EdgeInsets.zero,
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: metricsWideLayout ? 4 : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: metricsWideLayout ? 2.35 : 2.0,
              children: [
                SettingsMetricTile(
                  width: double.infinity,
                  label: localizations.ownerPinStatusLabel,
                  value: security.hasPin
                      ? localizations.profilePinSet
                      : localizations.profilePinNotSet,
                  icon: Icons.pin_outlined,
                ),
                SettingsMetricTile(
                  width: double.infinity,
                  label: localizations.settingsLockTitle,
                  value: security.settingsLockEnabled
                      ? localizations.settingStateOn
                      : localizations.settingStateOff,
                  icon: Icons.lock_person_outlined,
                ),
                SettingsMetricTile(
                  width: double.infinity,
                  label: localizations.hiddenAppsProfileLabel,
                  value: '$hiddenAppsCount',
                  icon: Icons.visibility_off_outlined,
                ),
                SettingsMetricTile(
                  width: double.infinity,
                  label: localizations.lockedAppsProfileLabel,
                  value: '$lockedAppsCount',
                  icon: Icons.lock_outline,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (splitLayout)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: const _AppVisibilityCard(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _LauncherSecurityCard(
                      security: security,
                    ),
                  ),
                ],
              )
            else ...[
              const _AppVisibilityCard(),
              const SizedBox(height: 14),
              _LauncherSecurityCard(
                security: security,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AppVisibilityCard extends StatelessWidget {
  const _AppVisibilityCard();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return SettingsSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.settingsDestinationProfilesTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            localizations.settingsDestinationProfilesSubtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 14),
          _ProfileActionTile(
            icon: Icons.visibility_off_outlined,
            title: localizations.manageHiddenAppsAction,
            subtitle: localizations.manageHiddenAppsDescription,
            onPressed: () => _openManager(context, hiddenMode: true),
          ),
          const SizedBox(height: 10),
          _ProfileActionTile(
            icon: Icons.lock_outline,
            title: localizations.manageLockedAppsAction,
            subtitle: localizations.manageLockedAppsDescription,
            onPressed: () => _openManager(context, hiddenMode: false),
          ),
        ],
      ),
    );
  }

  Future<void> _openManager(
    BuildContext context, {
    required bool hiddenMode,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _AppSecurityPackageManagerDialog(
        hiddenMode: hiddenMode,
      ),
    );
  }
}

class _LauncherSecurityCard extends StatelessWidget {
  final ProfileSecurityService security;

  const _LauncherSecurityCard({
    required this.security,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return SettingsSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.settingsLockTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            localizations.settingsLockSubtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 10),
          RoundedSwitchListTile(
            autofocus: true,
            value: security.settingsLockEnabled,
            onChanged: security.setSettingsLockEnabled,
            title: Text(
              localizations.settingsLockTitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            secondary: const Icon(Icons.lock_person_outlined),
          ),
          const SizedBox(height: 10),
          _ProfileActionTile(
            icon: Icons.pin_outlined,
            title: security.hasPin
                ? localizations.changeOwnerPinAction
                : localizations.setOwnerPinAction,
            subtitle: security.hasPin
                ? localizations.ownerPinConfirmDescription
                : localizations.ownerPinSetDescription,
            onPressed: () => _upsertOwnerPin(context),
          ),
          const SizedBox(height: 10),
          _ProfileActionTile(
            icon: Icons.no_encryption_gmailerrorred_outlined,
            title: localizations.clearOwnerPinAction,
            subtitle: localizations.clearOwnerPinDescription,
            enabled: security.hasPin,
            onPressed: () => _clearOwnerPin(context),
          ),
        ],
      ),
    );
  }

  Future<void> _upsertOwnerPin(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    String? currentPin;
    if (security.hasPin) {
      currentPin = await showPinPadDialog(
        context,
        title: localizations.enterCurrentOwnerPinTitle,
        description: localizations.enterCurrentOwnerPinDescription,
        confirmLabel: localizations.unlockAction,
      );
      if (currentPin == null || !context.mounted) {
        return;
      }
      if (!security.verifyPin(currentPin)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.invalidPinMessage)),
        );
        return;
      }
    }
    final newPin = await showPinPadDialog(
      context,
      title: localizations.ownerPinSetTitle,
      description: localizations.ownerPinSetDescription,
      confirmLabel: localizations.save,
    );
    if (newPin == null || !context.mounted) {
      return;
    }
    final confirmation = await showPinPadDialog(
      context,
      title: localizations.ownerPinConfirmTitle,
      description: localizations.ownerPinConfirmDescription,
      confirmLabel: localizations.save,
    );
    if (confirmation == null || !context.mounted) {
      return;
    }
    if (newPin != confirmation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.pinsDidNotMatchMessage)),
      );
      return;
    }
    final success = security.hasPin
        ? await security.changeOwnerPin(
            currentPin: currentPin!,
            newPin: newPin,
          )
        : await security.setOwnerPin(newPin);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? localizations.ownerPinSavedMessage
              : localizations.invalidPinMessage,
        ),
      ),
    );
  }

  Future<void> _clearOwnerPin(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    if (!security.hasPin) {
      return;
    }
    final currentPin = await showPinPadDialog(
      context,
      title: localizations.enterCurrentOwnerPinTitle,
      description: localizations.enterCurrentOwnerPinDescription,
      confirmLabel: localizations.unlockAction,
    );
    if (currentPin == null || !context.mounted) {
      return;
    }
    if (!security.verifyPin(currentPin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.invalidPinMessage)),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(localizations.clearOwnerPinAction),
            content: Text(localizations.clearOwnerPinDescription),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(localizations.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(localizations.clearAction),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    final success = await security.clearOwnerPinWithVerification(currentPin);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        success
            ? localizations.ownerPinClearedMessage
            : localizations.invalidPinMessage,
      ),
    ));
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool enabled;
  final VoidCallback onPressed;

  const _ProfileActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.enabled = true,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(enabled ? 0.03 : 0.015),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        minVerticalPadding: 0,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        enabled: enabled,
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: enabled ? onPressed : null,
      ),
    );
  }
}

class _AppSecurityPackageManagerDialog extends StatefulWidget {
  final bool hiddenMode;

  const _AppSecurityPackageManagerDialog({
    required this.hiddenMode,
  });

  @override
  State<_AppSecurityPackageManagerDialog> createState() =>
      _AppSecurityPackageManagerDialogState();
}

class _AppSecurityPackageManagerDialogState
    extends State<_AppSecurityPackageManagerDialog> {
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Consumer2<ProfileSecurityService, AppsService>(
      builder: (context, security, appsService, _) {
        final normalizedFilter = _filter.trim().toLowerCase();
        final filteredApps = appsService.applications.where((app) {
          if (normalizedFilter.isEmpty) {
            return true;
          }
          return app.name.toLowerCase().contains(normalizedFilter) ||
              app.packageName.toLowerCase().contains(normalizedFilter);
        }).toList(growable: false);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 120, vertical: 40),
          child: SettingsSurfaceCard(
            padding: const EdgeInsets.all(22),
            child: SizedBox(
              width: math.min(MediaQuery.sizeOf(context).width - 80, 980.0),
              height: math.min(MediaQuery.sizeOf(context).height - 120, 620.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.hiddenMode
                        ? localizations.manageHiddenAppsDialogTitle
                        : localizations.manageLockedAppsDialogTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _filterController,
                    autofocus: true,
                    onChanged: (value) => setState(() => _filter = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: localizations.filterAppsHint,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: filteredApps.isEmpty
                        ? Center(
                            child: Text(localizations.noAppsMatchFilter),
                          )
                        : ListView.separated(
                            itemCount: filteredApps.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final app = filteredApps[index];
                              final enabled = widget.hiddenMode
                                  ? app.hidden
                                  : security.isPackageLockedForProfile(
                                      ProfileSecurityService.ownerProfileId,
                                      app.packageName,
                                    );
                              return RoundedSwitchListTile(
                                value: enabled,
                                onChanged: (value) {
                                  if (widget.hiddenMode) {
                                    if (value) {
                                      appsService.hideApplication(app);
                                    } else {
                                      appsService.showApplication(app);
                                    }
                                  } else {
                                    security.setPackageLockedForProfile(
                                      ProfileSecurityService.ownerProfileId,
                                      app.packageName,
                                      value,
                                    );
                                  }
                                },
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      app.name,
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      app.packageName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.white70),
                                    ),
                                  ],
                                ),
                                secondary: Icon(
                                  widget.hiddenMode
                                      ? Icons.visibility_off_outlined
                                      : Icons.lock_outline,
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(localizations.closeAction),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
