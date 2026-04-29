import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class PermissionsPanelPage extends StatefulWidget {
  static const String routeName = "permissions_panel";

  const PermissionsPanelPage({super.key});

  @override
  State<PermissionsPanelPage> createState() => _PermissionsPanelPageState();
}

class _PermissionsPanelPageState extends State<PermissionsPanelPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SystemBridgeService>().refreshFull();
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Consumer<SystemBridgeService>(
      builder: (context, bridgeService, _) {
        final status = bridgeService.provisioningStatus;
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
        final steps = _wizardSteps(localizations);

        return ListView(
          key: const PageStorageKey<String>(PermissionsPanelPage.routeName),
          children: [
            SettingsSurfaceCard(
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
                  const SizedBox(height: 10),
                  Text(
                    adbEnabled
                        ? localizations.provisioningWizardDescription
                        : localizations.wizardStepOpenDeveloperOptions,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                                ?.copyWith(color: const Color(0xFFFFD99A)),
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
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        key: const Key('permissions_quick_grant_button'),
                        onPressed: () async {
                          if (!adbEnabled) {
                            await _showAdbSetupGuidance(context, bridgeService);
                            return;
                          }
                          _showActionResult(
                            context,
                            await bridgeService.runProvisioningAction(
                              action: 'grant_all_local_adb',
                              suggestedPolicy: 'adb_and_wifi',
                            ),
                          );
                        },
                        icon: const Icon(Icons.auto_fix_high_outlined),
                        label: Text(localizations.grantViaLocalAdb),
                      ),
                      if (!adbEnabled)
                        FilledButton.tonalIcon(
                          onPressed: () async => _showActionResult(
                            context,
                            await bridgeService.runProvisioningAction(
                              action: 'open_development',
                            ),
                          ),
                          icon: const Icon(Icons.developer_mode_outlined),
                          label: Text(localizations.openDeveloperOptions),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SettingsAdaptiveGrid(
              children: [
                SettingsMetricTile(
                  label: localizations.permissionHealthLabel,
                  value: localizedProvisioningHealth(localizations, health),
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
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(localizations.provisioningWizardTitle,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Text(
                    localizations.provisioningWizardDescription,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  for (var index = 0; index < steps.length; index += 1)
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
                          Expanded(child: Text(steps[index])),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () async => _showActionResult(
                          context,
                          await bridgeService.requestMediaReadPermission(),
                        ),
                        icon: const Icon(Icons.perm_media_outlined),
                        label: Text(localizations.grantMediaAccess),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async => _showActionResult(
                          context,
                          await bridgeService.runProvisioningAction(
                            action: 'open_development',
                          ),
                        ),
                        icon: const Icon(Icons.developer_mode_outlined),
                        label: Text(localizations.openDeveloperOptions),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            bridgeService.openSpecificSettingsPage('battery'),
                        icon: const Icon(Icons.battery_charging_full_outlined),
                        label: Text(localizations.batteryAccess),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            bridgeService.openSpecificSettingsPage('overlay'),
                        icon: const Icon(Icons.layers_outlined),
                        label: Text(localizations.overlayAccess),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => bridgeService
                            .openSpecificSettingsPage('write_settings'),
                        icon: const Icon(Icons.edit_note_outlined),
                        label: Text(localizations.writeSettingsAccess),
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
                  Text(localizations.requirementChecklistTitle,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  for (final item in requirements)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        item['granted'] == true
                            ? Icons.check_circle
                            : Icons.error_outline,
                        color: item['granted'] == true
                            ? const Color(0xFF7BE0A5)
                            : const Color(0xFFFFC970),
                      ),
                      title: Text(_requirementLabel(
                        localizations,
                        item['name']?.toString() ?? '',
                      )),
                      subtitle: Text(_requirementGuidance(
                        localizations,
                        item['name']?.toString() ?? '',
                        item['guidance']?.toString() ?? '',
                      )),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(localizations.pcProvisioningCommandsTitle,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  for (final command in commands)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: SelectableText(command),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy_outlined),
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: command)),
                      ),
                    ),
                ],
              ),
            ),
          ],
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

  Future<void> _showAdbSetupGuidance(
    BuildContext context,
    SystemBridgeService bridgeService,
  ) async {
    final localizations = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.openDeveloperOptions),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

  static List<String> _wizardSteps(AppLocalizations localizations) => [
        localizations.wizardStepOpenDeveloperOptions,
        localizations.wizardStepGrantWss,
        localizations.wizardStepGrantMediaAccess,
        localizations.wizardStepAllowOverlayAndWriteSettings,
        localizations.wizardStepWhitelistBattery,
        localizations.wizardStepSelectAdbPolicy,
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
}
