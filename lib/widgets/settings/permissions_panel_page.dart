import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class PermissionsPanelPage extends StatefulWidget {
  static const String routeName = "permissions_panel";
  final FocusNode? primaryFocusNode;

  const PermissionsPanelPage({
    super.key,
    this.primaryFocusNode,
  });

  @override
  State<PermissionsPanelPage> createState() => _PermissionsPanelPageState();
}

class _PermissionsPanelPageState extends State<PermissionsPanelPage> {
  static const String _advancedToggleDebugLabel = 'permissions_advanced_toggle';
  bool _showAdvanced = false;
  late final FocusNode _advancedToggleFocusNode;

  @override
  void initState() {
    super.initState();
    _advancedToggleFocusNode = FocusNode(debugLabel: _advancedToggleDebugLabel);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bridgeService = context.read<SystemBridgeService>();
      if (bridgeService.provisioningStatus.isEmpty) {
        bridgeService.refreshLite();
      }
    });
  }

  @override
  void dispose() {
    _advancedToggleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final bridgeService = context.read<SystemBridgeService>();
    final autoGrantOnWake = context.select<SystemBridgeService, bool>(
      (service) => service.autoGrantAdbOnWake,
    );

    return Selector<SystemBridgeService, Map<String, dynamic>>(
      selector: (_, service) => service.provisioningStatus,
      builder: (context, status, _) {
        final requirements = ((status['requirements'] as List?) ?? const [])
            .map((item) => (item as Map).cast<String, dynamic>())
            .toList(growable: false);
        final adbEnabled = _isRequirementGranted(requirements, 'adb_enabled');
        final commands = ((status['commands'] as List?) ?? const [])
            .map((item) => item.toString())
            .toList(growable: false);
        final missingRequirements = requirements
            .where((item) => item['granted'] != true)
            .toList(growable: false);
        final grantedRequirements = requirements
            .where((item) => item['granted'] == true)
            .toList(growable: false);

        return SingleChildScrollView(
          key: const PageStorageKey<String>(PermissionsPanelPage.routeName),
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsSurfaceCard(
                child: Column(
                  children: [
                    SettingsActionCard(
                      key: const Key('permissions_quick_grant_button'),
                      focusNode: widget.primaryFocusNode,
                      title: localizations.grantViaLocalAdb,
                      icon: Icons.auto_fix_high_outlined,
                      onPressed: () async => _runQuickGrant(
                        context,
                        bridgeService,
                      ),
                    ),
                    if (!adbEnabled) ...[
                      const SizedBox(height: TvDrawerTokens.rowSpacing),
                      SettingsActionCard(
                        title: localizations.openDeveloperOptions,
                        icon: Icons.developer_mode_outlined,
                        onPressed: () async => _showActionResult(
                          context,
                          await bridgeService.runProvisioningAction(
                            action: 'open_development',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: TvDrawerTokens.surfaceSpacing),
              SettingsSurfaceCard(
                child: Column(
                  children: [
                    SettingsActionCard(
                      title: localizations.grantMediaAccess,
                      icon: Icons.perm_media_outlined,
                      onPressed: () async => _showActionResult(
                        context,
                        await bridgeService.requestMediaReadPermission(),
                      ),
                    ),
                    const SizedBox(height: TvDrawerTokens.rowSpacing),
                    SettingsActionCard(
                      title: localizations.batteryAccess,
                      icon: Icons.battery_charging_full_outlined,
                      onPressed: () async {
                        await bridgeService.openSpecificSettingsPage(
                          'battery',
                        );
                      },
                    ),
                    const SizedBox(height: TvDrawerTokens.rowSpacing),
                    SettingsActionCard(
                      title: localizations.overlayAccess,
                      icon: Icons.layers_outlined,
                      onPressed: () async {
                        await bridgeService.openSpecificSettingsPage(
                          'overlay',
                        );
                      },
                    ),
                    const SizedBox(height: TvDrawerTokens.rowSpacing),
                    SettingsActionCard(
                      title: localizations.writeSettingsAccess,
                      icon: Icons.edit_note_outlined,
                      onPressed: () async {
                        await bridgeService.openSpecificSettingsPage(
                          'write_settings',
                        );
                      },
                    ),
                    const SizedBox(height: TvDrawerTokens.rowSpacing),
                    RoundedSwitchListTile(
                      key: const Key('permissions_auto_grant_on_wake_switch'),
                      value: autoGrantOnWake,
                      onChanged: (value) =>
                          bridgeService.setAutoGrantAdbOnWake(value),
                      title: Text(
                        localizations.autoGrantAdbOnWakeTitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      secondary: const Icon(Icons.healing_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TvDrawerTokens.surfaceSpacing),
              SettingsSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PermissionsAdvancedToggleTile(
                      key: const Key('permissions_advanced_toggle'),
                      focusNode: _advancedToggleFocusNode,
                      title: localizations.requirementChecklistTitle,
                      expanded: _showAdvanced,
                      onPressed: () {
                        setState(() {
                          _showAdvanced = !_showAdvanced;
                        });
                      },
                    ),
                    if (_showAdvanced) ...[
                      const SizedBox(height: 14),
                      if (missingRequirements.isNotEmpty) ...[
                        Text(
                          localizations.requirementChecklistTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final item in missingRequirements)
                          _PermissionRequirementTile(
                            title: _requirementLabel(
                              localizations,
                              item['name']?.toString() ?? '',
                            ),
                            granted: false,
                            importance: _requirementImportance(item),
                          ),
                      ],
                      if (grantedRequirements.isNotEmpty) ...[
                        if (missingRequirements.isNotEmpty)
                          const SizedBox(height: 8),
                        Text(
                          localizations.grantedLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final item in grantedRequirements)
                          _PermissionRequirementTile(
                            title: _requirementLabel(
                              localizations,
                              item['name']?.toString() ?? '',
                            ),
                            granted: true,
                            importance: _requirementImportance(item),
                          ),
                      ],
                      if (commands.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          localizations.pcProvisioningCommandsTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        for (final command in commands)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SettingsActionCard(
                              title: command,
                              icon: Icons.copy_outlined,
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: command),
                                );
                              },
                            ),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static void _showActionResult(
    BuildContext context,
    Map<String, dynamic> result,
  ) {
    if (!context.mounted) {
      return;
    }
    final message = result['message']?.toString() ??
        (result['granted'] == true
            ? AppLocalizations.of(context)!.actionCompleted
            : AppLocalizations.of(context)!.actionDidNotComplete);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runQuickGrant(
    BuildContext context,
    SystemBridgeService bridgeService,
  ) async {
    final result = await bridgeService.runProvisioningAction(
      action: 'grant_all_local_adb',
      suggestedPolicy: 'adb_and_wifi',
    );
    if (!context.mounted) {
      return;
    }
    if (result['requiresAdbSetup'] == true) {
      await _showAdbSetupGuidance(
        context,
        bridgeService,
        detailMessage: result['message']?.toString(),
      );
      return;
    }
    if (result['requiresAdbAuthorization'] == true) {
      await _showLocalAdbAuthorizationGuidance(
        context,
        bridgeService,
        detailMessage: result['message']?.toString(),
      );
      return;
    }
    _showActionResult(context, result);
  }

  Future<void> _showAdbSetupGuidance(
      BuildContext context, SystemBridgeService bridgeService,
      {String? detailMessage}) async {
    final localizations = AppLocalizations.of(context)!;
    final trimmedDetail = detailMessage?.trim() ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.openDeveloperOptions),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trimmedDetail.isNotEmpty) ...[
              Text(trimmedDetail),
              const SizedBox(height: 10),
            ],
            Text(localizations.wizardStepOpenDeveloperOptions),
            const SizedBox(height: 10),
            Text(localizations.wizardStepGrantWss),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(localizations.closeAction),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              _showActionResult(
                context,
                await bridgeService.runProvisioningAction(
                  action: 'open_development',
                ),
              );
            },
            child: Text(localizations.openDeveloperOptions),
          ),
        ],
      ),
    );
  }

  Future<void> _showLocalAdbAuthorizationGuidance(
      BuildContext context, SystemBridgeService bridgeService,
      {String? detailMessage}) async {
    final localizations = AppLocalizations.of(context)!;
    final trimmedDetail = detailMessage?.trim() ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.localAdbAuthorizationTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trimmedDetail.isNotEmpty) ...[
              Text(trimmedDetail),
              const SizedBox(height: 10),
            ],
            Text(localizations.localAdbAuthorizationHint),
            const SizedBox(height: 10),
            Text(localizations.localAdbAuthorizationOpenDeveloperOptionsHint),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(localizations.closeAction),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              _showActionResult(
                context,
                await bridgeService.runProvisioningAction(
                  action: 'open_development',
                ),
              );
            },
            child: Text(localizations.openDeveloperOptions),
          ),
        ],
      ),
    );
  }

  static String _requirementLabel(
    AppLocalizations localizations,
    String name,
  ) {
    switch (name) {
      case 'android.permission.WRITE_SECURE_SETTINGS':
        return localizations.requirementWriteSecureSettingsLabel;
      case 'android.permission.WRITE_SETTINGS':
        return localizations.requirementWriteSettingsLabel;
      case 'android.permission.SYSTEM_ALERT_WINDOW':
        return localizations.requirementSystemAlertWindowLabel;
      case 'ignore_battery_optimizations':
        return localizations.requirementIgnoreBatteryLabel;
      case 'post_notifications':
        return localizations.requirementPostNotificationsLabel;
      case 'device_owner':
        return localizations.requirementDeviceOwnerLabel;
      case 'adb_enabled':
        return localizations.requirementAdbEnabledLabel;
      case 'adb_wifi_enabled':
        return localizations.requirementAdbWifiEnabledLabel;
      case 'request_install_packages':
        return localizations.requirementInstallPackagesLabel;
      case 'android.permission.READ_MEDIA_VIDEO':
      case 'android.permission.READ_EXTERNAL_STORAGE':
        return localizations.requirementMediaReadLabel;
      case 'launcher_accessibility_service':
        return localizations.requirementLauncherAccessibilityLabel;
      default:
        return name;
    }
  }

  static bool _isRequirementGranted(
    List<Map<String, dynamic>> requirements,
    String name,
  ) {
    for (final item in requirements) {
      if (item['name']?.toString() == name) {
        return item['granted'] == true;
      }
    }
    return false;
  }

  static String _requirementImportance(Map<String, dynamic> item) =>
      item['importance']?.toString() ?? 'required';
}

class _PermissionsAdvancedToggleTile extends StatefulWidget {
  final FocusNode? focusNode;
  final String title;
  final bool expanded;
  final VoidCallback onPressed;

  const _PermissionsAdvancedToggleTile({
    super.key,
    this.focusNode,
    required this.title,
    required this.expanded,
    required this.onPressed,
  });

  @override
  State<_PermissionsAdvancedToggleTile> createState() =>
      _PermissionsAdvancedToggleTileState();
}

class _PermissionsAdvancedToggleTileState
    extends State<_PermissionsAdvancedToggleTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = _focused ? Colors.white : Colors.white70;
    return EnsureVisible(
      alignment: EnsureVisible.settingsAlignment,
      settleFrameCount: 1,
      preferImmediate: true,
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (value) {
          if (_focused != value) {
            setState(() {
              _focused = value;
            });
          }
        },
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }
          final direction = event.logicalKey == LogicalKeyboardKey.arrowUp
              ? TraversalDirection.up
              : event.logicalKey == LogicalKeyboardKey.arrowDown
                  ? TraversalDirection.down
                  : null;
          if (direction != null) {
            if (!moveSettingsVerticalFocus(
              direction: direction,
              localNodes: <FocusNode>[node],
            )) {
              node.focusInDirection(direction);
            }
            return KeyEventResult.handled;
          }
          if (isSettingsActivateKey(event.logicalKey)) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SettingsFocusFrame(
          padding: EdgeInsets.zero,
          variant: SettingsFocusFrameVariant.rowOnly,
          focusEmphasis: 1.26,
          focused: _focused,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.tune_outlined, color: iconColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: _focused
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    widget.expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: iconColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionRequirementTile extends StatefulWidget {
  final String title;
  final bool granted;
  final String importance;

  const _PermissionRequirementTile({
    required this.title,
    required this.granted,
    required this.importance,
  });

  @override
  State<_PermissionRequirementTile> createState() =>
      _PermissionRequirementTileState();
}

class _PermissionRequirementTileState extends State<_PermissionRequirementTile> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    final debugToken = widget.title.trim().replaceAll(RegExp(r'\s+'), '_');
    _focusNode = FocusNode(debugLabel: 'permission_requirement_$debugToken');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.granted
        ? const Color(0xFF7BE0A5)
        : _requirementImportanceColor(widget.importance);
    final icon = widget.granted
        ? Icons.check_circle
        : switch (widget.importance) {
            'recommended' => Icons.warning_amber_rounded,
            'optional' => Icons.info_outline,
            _ => Icons.gpp_bad_outlined,
          };
    final titleColor = _focused ? Colors.white : Colors.white.withOpacity(0.96);
    return EnsureVisible(
      alignment: EnsureVisible.settingsAlignment,
      settleFrameCount: 1,
      preferImmediate: true,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: true,
        onFocusChange: (value) {
          if (_focused != value) {
            setState(() => _focused = value);
          }
        },
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }
          final direction = event.logicalKey == LogicalKeyboardKey.arrowUp
              ? TraversalDirection.up
              : event.logicalKey == LogicalKeyboardKey.arrowDown
                  ? TraversalDirection.down
                  : null;
          if (direction != null) {
            if (!moveSettingsVerticalFocus(
              direction: direction,
              localNodes: <FocusNode>[_focusNode],
            )) {
              if (direction == TraversalDirection.up &&
                  focusNearestSettingsSummaryAbove(_focusNode)) {
                return KeyEventResult.handled;
              }
              _focusNode.focusInDirection(direction);
            }
            return KeyEventResult.handled;
          }
          if (isSettingsActivateKey(event.logicalKey)) {
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SettingsFocusFrame(
          padding: EdgeInsets.zero,
          variant: SettingsFocusFrameVariant.rowOnly,
          focusEmphasis: 1.18,
          focused: _focused,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: titleColor,
                          fontWeight:
                              _focused ? FontWeight.w700 : FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _requirementImportanceColor(String importance) {
  switch (importance) {
    case 'recommended':
      return const Color(0xFFFFC970);
    case 'optional':
      return const Color(0xFF8CCBFF);
    default:
      return const Color(0xFFFF8A80);
  }
}
