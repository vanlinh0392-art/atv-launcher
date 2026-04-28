import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class PermissionsPanelPage extends StatelessWidget {
  static const String routeName = "permissions_panel";

  const PermissionsPanelPage({super.key});

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
        final commands = ((status['commands'] as List?) ?? const [])
            .map((item) => item.toString())
            .toList(growable: false);
        final steps = _wizardSteps(localizations);

        return ListView(
          key: const PageStorageKey<String>(PermissionsPanelPage.routeName),
          children: [
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
                      FilledButton.icon(
                        onPressed: () async => _showActionResult(
                          context,
                          await bridgeService.runProvisioningAction(
                            action: 'grant_all_local_adb',
                            suggestedPolicy: 'adb_and_wifi',
                          ),
                        ),
                        icon: const Icon(Icons.auto_fix_high_outlined),
                        label: Text(localizations.grantViaLocalAdb),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async => _showActionResult(
                          context,
                          await bridgeService.requestMediaReadPermission(),
                        ),
                        icon: const Icon(Icons.perm_media_outlined),
                        label: Text(localizations.grantMediaAccess),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => bridgeService.runProvisioningAction(
                            action: 'open_development'),
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
}
