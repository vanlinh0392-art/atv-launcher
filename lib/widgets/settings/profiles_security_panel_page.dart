import 'dart:math' as math;

import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flauncher/widgets/pin_pad_dialog.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class ProfilesSecurityPanelPage extends StatefulWidget {
  static const String routeName = 'profiles_security_panel';
  final FocusNode? primaryFocusNode;

  const ProfilesSecurityPanelPage({
    super.key,
    this.primaryFocusNode,
  });

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
        final metricsWideLayout =
            viewSize.width >= 1200 && viewSize.height >= 780;

        return ListView(
          key:
              const PageStorageKey<String>(ProfilesSecurityPanelPage.routeName),
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            SettingsAdaptiveGrid(
              minChildWidth: metricsWideLayout ? 190 : 240,
              maxColumns: metricsWideLayout ? 4 : 2,
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
            const _AppVisibilityCard(),
            const SizedBox(height: 14),
            _LauncherSecurityCard(
              security: security,
              primaryFocusNode: widget.primaryFocusNode,
            ),
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
            debugLabel: 'profiles_security_manage_hidden_apps',
            onPressed: () => _openManager(context, hiddenMode: true),
          ),
          const SizedBox(height: 10),
          _ProfileActionTile(
            icon: Icons.lock_outline,
            title: localizations.manageLockedAppsAction,
            subtitle: localizations.manageLockedAppsDescription,
            debugLabel: 'profiles_security_manage_locked_apps',
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
  final FocusNode? primaryFocusNode;

  const _LauncherSecurityCard({
    required this.security,
    this.primaryFocusNode,
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
          const SizedBox(height: 8),
          RoundedSwitchListTile(
            focusNode: primaryFocusNode,
            debugLabel: 'profiles_security_primary_lock',
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
            debugLabel: 'profiles_security_owner_pin_upsert',
            onPressed: () => _upsertOwnerPin(context),
          ),
          const SizedBox(height: 10),
          _ProfileActionTile(
            icon: Icons.no_encryption_gmailerrorred_outlined,
            title: localizations.clearOwnerPinAction,
            enabled: security.hasPin,
            debugLabel: 'profiles_security_owner_pin_clear',
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

class _ProfileActionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool enabled;
  final String? debugLabel;
  final VoidCallback onPressed;

  const _ProfileActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.enabled = true,
    this.debugLabel,
    required this.onPressed,
  });

  @override
  State<_ProfileActionTile> createState() => _ProfileActionTileState();
}

class _ProfileActionTileState extends State<_ProfileActionTile> {
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _configureFocusNode();
  }

  @override
  void didUpdateWidget(covariant _ProfileActionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.debugLabel == widget.debugLabel &&
        oldWidget.title == widget.title) {
      return;
    }
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    _configureFocusNode();
  }

  @override
  void dispose() {
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.enabled
        ? (_focused ? Colors.white : Colors.white70)
        : Colors.white38;
    final titleColor = widget.enabled
        ? (_focused ? Colors.white : Colors.white.withOpacity(0.96))
        : Colors.white38;
    final subtitleColor = widget.enabled
        ? (_focused ? Colors.white.withOpacity(0.86) : Colors.white70)
        : Colors.white38;
    return EnsureVisible(
      alignment: EnsureVisible.settingsAlignment,
      preferImmediate: true,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: widget.enabled,
        onFocusChange: (value) {
          if (_focused != value) {
            setState(() => _focused = value);
          }
        },
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }
          if (isSettingsActivateKey(event.logicalKey) && widget.enabled) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SettingsFocusFrame(
          padding: EdgeInsets.zero,
          variant: SettingsFocusFrameVariant.rowOnly,
          focusEmphasis: 1.28,
          focused: _focused,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? widget.onPressed : null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 110),
              opacity: widget.enabled ? (_focused ? 1 : 0.97) : 0.46,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(widget.icon, color: iconColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: titleColor,
                                      fontWeight: _focused
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: subtitleColor),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.chevron_right, color: iconColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _configureFocusNode() {
    _ownsFocusNode = true;
    _focusNode = FocusNode(
      debugLabel: widget.debugLabel ??
          'profile_action_${widget.title}'.replaceAll(' ', '_'),
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
                    autofocus: false,
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
                                autofocus: index == 0,
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
                      autofocus: filteredApps.isEmpty,
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
