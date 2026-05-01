import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
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
  static const String _headerDebugLabel = 'permissions_summary_header';
  static const String _summaryDebugLabel = 'permissions_summary_metrics';
  bool _showAdvanced = false;
  late final FocusNode _headerFocusNode;

  @override
  void initState() {
    super.initState();
    _headerFocusNode = FocusNode(debugLabel: _headerDebugLabel);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bridgeService = context.read<SystemBridgeService>();
      if (bridgeService.provisioningStatus.isEmpty) {
        bridgeService.refreshLite();
      }
    });
  }

  @override
  void dispose() {
    _headerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final bridgeService = context.read<SystemBridgeService>();

    return Selector<SystemBridgeService, Map<String, dynamic>>(
      selector: (_, service) => service.provisioningStatus,
      builder: (context, status, _) {
        final health = status['health']?.toString() ?? 'missing_required';
        final missingRequired =
            ((status['missingRequiredCount'] as num?) ?? 0).toInt();
        final missingRecommended =
            ((status['missingRecommendedCount'] as num?) ?? 0).toInt();
        final requirements = ((status['requirements'] as List?) ?? const [])
            .map((item) => (item as Map).cast<String, dynamic>())
            .toList(growable: false);
        final adbEnabled = _isRequirementGranted(requirements, 'adb_enabled');
        final adbWifiEnabled =
            _isRequirementGranted(requirements, 'adb_wifi_enabled');
        final commands = ((status['commands'] as List?) ?? const [])
            .map((item) => item.toString())
            .toList(growable: false);
        final wizardSteps = _compactWizardSteps(localizations);
        final missingRequirements = requirements
            .where((item) => item['granted'] != true)
            .toList(growable: false);
        final missingRequiredRequirements = missingRequirements
            .where((item) => _requirementImportance(item) == 'required')
            .toList(growable: false);
        final missingRecommendedRequirements = missingRequirements
            .where((item) => _requirementImportance(item) == 'recommended')
            .toList(growable: false);
        final missingOptionalRequirements = missingRequirements
            .where((item) => _requirementImportance(item) == 'optional')
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SettingsSummarySection(
                      debugLabel: _headerDebugLabel,
                      focusNode: _headerFocusNode,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  localizations.provisioningWizardTitle,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              SettingsStatusChip(
                                label:
                                    '${localizations.adbLabel} ${adbEnabled ? localizations.yesLabel : localizations.noLabel}',
                                color: adbEnabled
                                    ? const Color(0xFF7BE0A5)
                                    : const Color(0xFFFFC970),
                              ),
                              const SizedBox(width: 10),
                              SettingsStatusChip(
                                label:
                                    '${localizations.adbWifiLabel} ${adbWifiEnabled ? localizations.yesLabel : localizations.noLabel}',
                                color: adbWifiEnabled
                                    ? const Color(0xFF8CCBFF)
                                    : const Color(0x66FFFFFF),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            adbEnabled
                                ? localizations.provisioningWizardDescription
                                : localizations.wizardStepOpenDeveloperOptions,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white70,
                                ),
                          ),
                          if (!adbEnabled) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0x22FFC970),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0x66FFC970),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations.requirementAdbEnabledGuidance,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: const Color(0xFFFFD99A),
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    localizations.wizardStepGrantWss,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SettingsSummarySection(
                      debugLabel: _summaryDebugLabel,
                      child: SettingsAdaptiveGrid(
                        minChildWidth: 180,
                        maxColumns: 3,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SettingsMetricTile(
                            label: localizations.permissionHealthLabel,
                            value: localizedProvisioningHealth(
                              localizations,
                              health,
                            ),
                            icon: health == 'healthy'
                                ? Icons.verified_user_outlined
                                : Icons.warning_amber_outlined,
                          ),
                          SettingsMetricTile(
                            label: localizations.requiredMissingLabel,
                            value: missingRequired.toString(),
                            icon: Icons.warning_amber_outlined,
                          ),
                          SettingsMetricTile(
                            label: localizations.recommendedMissingLabel,
                            value: missingRecommended.toString(),
                            icon: Icons.info_outline,
                          ),
                        ],
                      ),
                    ),
                    if (missingRequirements.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        key: const Key('permissions_missing_summary'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.045),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.09),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizations.missingSetupItemsTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              localizations.missingSetupItemsDescription,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                            if (missingRequiredRequirements.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _MissingRequirementsGroup(
                                title: localizations.requiredMissingLabel,
                                color: _requirementImportanceColor('required'),
                                labels: missingRequiredRequirements
                                    .map(
                                      (item) => _requirementLabel(
                                        localizations,
                                        item['name']?.toString() ?? '',
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ],
                            if (missingRecommendedRequirements.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _MissingRequirementsGroup(
                                title: localizations.recommendedMissingLabel,
                                color:
                                    _requirementImportanceColor('recommended'),
                                labels: missingRecommendedRequirements
                                    .map(
                                      (item) => _requirementLabel(
                                        localizations,
                                        item['name']?.toString() ?? '',
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ],
                            if (missingOptionalRequirements.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _MissingRequirementsGroup(
                                title: localizations.optionalMissingLabel,
                                color: _requirementImportanceColor('optional'),
                                labels: missingOptionalRequirements
                                    .map(
                                      (item) => _requirementLabel(
                                        localizations,
                                        item['name']?.toString() ?? '',
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Column(
                      children: [
                        SettingsActionCard(
                          key: const Key('permissions_quick_grant_button'),
                          focusNode: widget.primaryFocusNode,
                          onMoveUpAtBoundary: () {
                            _headerFocusNode.requestFocus();
                            return true;
                          },
                          title: localizations.grantViaLocalAdb,
                          subtitle: adbEnabled
                              ? localizations.provisioningWizardDescription
                              : localizations.wizardStepOpenDeveloperOptions,
                          icon: Icons.auto_fix_high_outlined,
                          onPressed: () async => _runQuickGrant(
                            context,
                            bridgeService,
                          ),
                        ),
                        if (!adbEnabled) ...[
                          const SizedBox(height: 10),
                          SettingsActionCard(
                            title: localizations.openDeveloperOptions,
                            subtitle: localizations.wizardStepGrantWss,
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
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SettingsSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.provisioningWizardTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    for (var index = 0; index < wizardSteps.length; index += 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SettingsStatusChip(
                              label: '${index + 1}',
                              color: const Color(0xFF8CCBFF),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(wizardSteps[index])),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    Column(
                      children: [
                        SettingsActionCard(
                          title: localizations.grantMediaAccess,
                          subtitle: localizations.requirementMediaReadLabel,
                          icon: Icons.perm_media_outlined,
                          onPressed: () async => _showActionResult(
                            context,
                            await bridgeService.requestMediaReadPermission(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SettingsActionCard(
                          title: localizations.batteryAccess,
                          subtitle: localizations.wizardStepWhitelistBattery,
                          icon: Icons.battery_charging_full_outlined,
                          onPressed: () async {
                            await bridgeService.openSpecificSettingsPage(
                              'battery',
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        SettingsActionCard(
                          title: localizations.overlayAccess,
                          subtitle:
                              localizations.requirementSystemAlertWindowLabel,
                          icon: Icons.layers_outlined,
                          onPressed: () async {
                            await bridgeService.openSpecificSettingsPage(
                              'overlay',
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        SettingsActionCard(
                          title: localizations.writeSettingsAccess,
                          subtitle: localizations.requirementWriteSettingsLabel,
                          icon: Icons.edit_note_outlined,
                          onPressed: () async {
                            await bridgeService.openSpecificSettingsPage(
                              'write_settings',
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SettingsSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PermissionsAdvancedToggleTile(
                      key: const Key('permissions_advanced_toggle'),
                      title: localizations.requirementChecklistTitle,
                      subtitle:
                          '${localizations.requiredMissingLabel}: $missingRequired  /  ${localizations.recommendedMissingLabel}: $missingRecommended',
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
                            subtitle: _requirementGuidance(
                              localizations,
                              item['name']?.toString() ?? '',
                              item['guidance']?.toString() ?? '',
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
                            subtitle: _requirementGuidance(
                              localizations,
                              item['name']?.toString() ?? '',
                              item['guidance']?.toString() ?? '',
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

  static List<String> _compactWizardSteps(AppLocalizations localizations) => [
        localizations.wizardStepOpenDeveloperOptions,
        localizations.wizardStepGrantWss,
        localizations.wizardStepGrantMediaAccess,
        '${localizations.wizardStepAllowOverlayAndWriteSettings}  /  ${localizations.wizardStepWhitelistBattery}',
      ];

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
      default:
        return name;
    }
  }

  static String _requirementGuidance(
    AppLocalizations localizations,
    String name,
    String fallback,
  ) {
    switch (name) {
      case 'android.permission.WRITE_SECURE_SETTINGS':
        return localizations.requirementWriteSecureSettingsGuidance;
      case 'android.permission.WRITE_SETTINGS':
        return localizations.requirementWriteSettingsGuidance;
      case 'android.permission.SYSTEM_ALERT_WINDOW':
        return localizations.requirementSystemAlertWindowGuidance;
      case 'ignore_battery_optimizations':
        return localizations.requirementIgnoreBatteryGuidance;
      case 'post_notifications':
        return localizations.requirementPostNotificationsGuidance;
      case 'device_owner':
        return localizations.requirementDeviceOwnerGuidance;
      case 'adb_enabled':
        return localizations.requirementAdbEnabledGuidance;
      case 'adb_wifi_enabled':
        return localizations.requirementAdbWifiEnabledGuidance;
      case 'request_install_packages':
        return localizations.requirementInstallPackagesGuidance;
      case 'android.permission.READ_MEDIA_VIDEO':
      case 'android.permission.READ_EXTERNAL_STORAGE':
        return localizations.requirementMediaReadGuidance;
      default:
        return fallback;
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
  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback onPressed;

  const _PermissionsAdvancedToggleTile({
    super.key,
    required this.title,
    required this.subtitle,
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
    final subtitleColor =
        _focused ? Colors.white.withOpacity(0.86) : Colors.white70;
    return EnsureVisible(
      alignment: EnsureVisible.settingsAlignment,
      settleFrameCount: 1,
      preferImmediate: true,
      child: Focus(
        onFocusChange: (value) {
          if (_focused != value) {
            setState(() {
              _focused = value;
            });
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
              localNodes: <FocusNode>[Focus.of(context)],
            )) {
              Focus.of(context).focusInDirection(direction);
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: _focused
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: subtitleColor),
                        ),
                      ],
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

class _PermissionRequirementTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool granted;
  final String importance;

  const _PermissionRequirementTile({
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.importance,
  });

  @override
  Widget build(BuildContext context) {
    final color = granted
        ? const Color(0xFF7BE0A5)
        : _requirementImportanceColor(importance);
    final icon = granted
        ? Icons.check_circle
        : switch (importance) {
            'recommended' => Icons.warning_amber_rounded,
            'optional' => Icons.info_outline,
            _ => Icons.gpp_bad_outlined,
          };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: color,
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: granted ? Colors.white70 : color.withOpacity(0.92),
            ),
      ),
    );
  }
}

class _MissingRequirementsGroup extends StatelessWidget {
  final String title;
  final Color color;
  final List<String> labels;

  const _MissingRequirementsGroup({
    required this.title,
    required this.color,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in labels)
              SettingsStatusChip(
                label: label,
                color: color,
              ),
          ],
        ),
      ],
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
