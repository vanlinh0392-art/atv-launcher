import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class SystemCorePanelPage extends StatelessWidget {
  static const String routeName = "system_core_panel";

  const SystemCorePanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Consumer<SystemBridgeService>(
      builder: (context, bridgeService, _) {
        final status = bridgeService.systemCoreStatus;
        final adb = bridgeService.adbAutomationStatus;
        final provisioning = bridgeService.provisioningStatus;
        final policy = adb['policy']?.toString() ?? 'off';
        final disableOnSleep = adb['disableOnSleep'] == true;

        return ListView(
          key: const PageStorageKey<String>(SystemCorePanelPage.routeName),
          children: [
            SettingsAdaptiveGrid(
              children: [
                SettingsMetricTile(
                  label: localizations.adbLabel,
                  value: localizedOnOff(localizations, status['adbEnabled']),
                  icon: Icons.adb_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.adbWifiLabel,
                  value:
                      localizedOnOff(localizations, status['adbWifiEnabled']),
                  icon: Icons.wifi_tethering_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.coreHealthLabel,
                  value: localizedBridgeHealth(
                    localizations,
                    status['coreServiceHealth']?.toString() ?? '',
                  ),
                  icon: Icons.favorite_outline,
                ),
                SettingsMetricTile(
                  label: localizations.permissionHealthLabel,
                  value: localizedProvisioningHealth(localizations,
                      provisioning['health']?.toString() ?? 'missing_required'),
                  icon: Icons.verified_user_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(localizations.adbAutomationPolicyTitle,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _PolicyChip(
                        label: localizations.adbPolicyOff,
                        selected: policy == 'off',
                        onTap: () => bridgeService.setAdbAutomationPolicy(
                          policy: 'off',
                          disableOnSleep: disableOnSleep,
                        ),
                      ),
                      _PolicyChip(
                        label: localizations.adbPolicyAdbOnly,
                        selected: policy == 'adb_only',
                        onTap: () => bridgeService.setAdbAutomationPolicy(
                          policy: 'adb_only',
                          disableOnSleep: disableOnSleep,
                        ),
                      ),
                      _PolicyChip(
                        label: localizations.adbPolicyAdbAndWifi,
                        selected: policy == 'adb_and_wifi',
                        onTap: () => bridgeService.setAdbAutomationPolicy(
                          policy: 'adb_and_wifi',
                          disableOnSleep: disableOnSleep,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    value: disableOnSleep,
                    onChanged: (value) => bridgeService.setAdbAutomationPolicy(
                      policy: policy,
                      disableOnSleep: value,
                    ),
                    title: Text(localizations.disableAdbOnSleepTitle),
                    subtitle: Text(localizations.disableAdbOnSleepSubtitle),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => bridgeService.setAdbEnabledNow(true),
                        icon: const Icon(Icons.flash_on_outlined),
                        label: Text(localizations.enableNow),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => bridgeService.setAdbEnabledNow(false),
                        icon: const Icon(Icons.power_settings_new_outlined),
                        label: Text(localizations.disableNow),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => bridgeService.repairAccessibility(),
                        icon: const Icon(Icons.build_outlined),
                        label: Text(localizations.runHealNow),
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
                  Text(localizations.coreSnapshotTitle,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  _StatusRow(
                      label: localizations.batteryOptimizationIgnored,
                      value: localizedYesNo(
                          localizations, status['batteryOptimizationIgnored'])),
                  _StatusRow(
                      label: localizations.deviceOwner,
                      value:
                          localizedYesNo(localizations, status['deviceOwner'])),
                  _StatusRow(
                      label: localizations.accessibilityMaster,
                      value: localizedYesNo(
                          localizations, status['accessibilityMasterEnabled'])),
                  _StatusRow(
                      label: localizations.managedAccessibilityPackages,
                      value:
                          status['managedAccessibilityPackages']?.toString() ??
                              '-'),
                  _StatusRow(
                      label: localizations.lastRecoveryReason,
                      value: status['lastRecoveryReason']?.toString() ?? '-'),
                  _StatusRow(
                      label: localizations.lastSuccess,
                      value: status['lastSuccessAtText']?.toString() ?? '-'),
                  _StatusRow(
                      label: localizations.lastAdbPolicyApply,
                      value: status['adbLastAppliedAtText']?.toString() ?? '-'),
                  _StatusRow(
                      label: localizations.lastAdbReason,
                      value: status['adbLastReason']?.toString() ?? '-'),
                  _StatusRow(
                      label: localizations.lastAdbState,
                      value: localizedAdbPolicy(
                        localizations,
                        status['adbLastState']?.toString() ?? '',
                      )),
                  _StatusRow(
                      label: localizations.missingServices,
                      value: status['missingServices']?.toString() ?? '-'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () =>
                      bridgeService.openSpecificSettingsPage('development'),
                  icon: const Icon(Icons.developer_mode_outlined),
                  label: Text(localizations.developerOptions),
                ),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      bridgeService.openSpecificSettingsPage('battery'),
                  icon: const Icon(Icons.battery_charging_full_outlined),
                  label: Text(localizations.batterySettings),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PolicyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PolicyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value),
    );
  }
}
