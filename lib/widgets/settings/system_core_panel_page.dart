import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class SystemCorePanelPage extends StatelessWidget {
  static const String routeName = "system_core_panel";
  static const String _summaryDebugLabel = 'system_core_summary_metrics';
  final FocusNode? primaryFocusNode;

  const SystemCorePanelPage({
    super.key,
    this.primaryFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final bridgeService = context.read<SystemBridgeService>();
    final status = context.select<SystemBridgeService, Map<String, dynamic>>(
      (service) => service.systemCoreStatus,
    );
    final adb = context.select<SystemBridgeService, Map<String, dynamic>>(
      (service) => service.adbAutomationStatus,
    );
    final provisioning =
        context.select<SystemBridgeService, Map<String, dynamic>>(
      (service) => service.provisioningStatus,
    );
    final policy = adb['policy']?.toString() ?? 'off';
    final disableOnSleep = adb['disableOnSleep'] == true;

    return ListView(
      key: const PageStorageKey<String>(SystemCorePanelPage.routeName),
      children: [
        SettingsSummarySection(
          debugLabel: _summaryDebugLabel,
          child: SettingsMetricsGrid(
            minChildWidth: 168,
            maxColumns: 4,
            children: [
              SettingsMetricTile(
                label: localizations.adbLabel,
                value: localizedOnOff(localizations, status['adbEnabled']),
                icon: Icons.adb_outlined,
              ),
              SettingsMetricTile(
                label: localizations.adbWifiLabel,
                value: localizedOnOff(localizations, status['adbWifiEnabled']),
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
                value: localizedProvisioningHealth(
                  localizations,
                  provisioning['health']?.toString() ?? 'missing_required',
                ),
                icon: Icons.verified_user_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SettingsSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localizations.adbAutomationPolicyTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              SettingsChoiceCard<String>(
                focusNode: primaryFocusNode,
                onMoveUpAtBoundary: () => focusCurrentSettingsNodeByDebugLabel(
                  _summaryDebugLabel,
                ),
                selectorKey: const Key('system_core_adb_policy_selector'),
                optionKeyPrefix: 'system_core_adb_policy_option',
                title: localizations.adbAutomationPolicyTitle,
                subtitle: localizations.disableAdbOnSleepSubtitle,
                icon: Icons.adb_outlined,
                value: policy,
                options: <SettingsChoiceOption<String>>[
                  SettingsChoiceOption<String>(
                    value: 'off',
                    label: localizations.adbPolicyOff,
                  ),
                  SettingsChoiceOption<String>(
                    value: 'adb_only',
                    label: localizations.adbPolicyAdbOnly,
                  ),
                  SettingsChoiceOption<String>(
                    value: 'adb_and_wifi',
                    label: localizations.adbPolicyAdbAndWifi,
                  ),
                ],
                valueLabelBuilder: (value) => localizedAdbPolicy(
                  localizations,
                  value,
                ),
                onChanged: (value) => bridgeService.setAdbAutomationPolicy(
                  policy: value,
                  disableOnSleep: disableOnSleep,
                ),
              ),
              const SizedBox(height: 10),
              RoundedSwitchListTile(
                value: disableOnSleep,
                onChanged: (value) => bridgeService.setAdbAutomationPolicy(
                  policy: policy,
                  disableOnSleep: value,
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.disableAdbOnSleepTitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizations.disableAdbOnSleepSubtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
                secondary: const Icon(Icons.power_settings_new_outlined),
              ),
              const SizedBox(height: 14),
              SettingsAdaptiveGrid(
                minChildWidth: 210,
                maxColumns: 3,
                children: [
                  SettingsActionCard(
                    title: localizations.enableNow,
                    subtitle: localizations.adbLabel,
                    icon: Icons.flash_on_outlined,
                    onPressed: () async {
                      await bridgeService.setAdbEnabledNow(true);
                    },
                  ),
                  SettingsActionCard(
                    title: localizations.disableNow,
                    subtitle: localizations.adbLabel,
                    icon: Icons.power_settings_new_outlined,
                    onPressed: () async {
                      await bridgeService.setAdbEnabledNow(false);
                    },
                  ),
                  SettingsActionCard(
                    title: localizations.runHealNow,
                    subtitle: localizations.coreHealthLabel,
                    icon: Icons.build_outlined,
                    onPressed: () async {
                      await bridgeService.repairAccessibility();
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
              Text(localizations.coreSnapshotTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              _StatusRow(
                  label: localizations.batteryOptimizationIgnored,
                  value: localizedYesNo(
                      localizations, status['batteryOptimizationIgnored'])),
              _StatusRow(
                  label: localizations.deviceOwner,
                  value: localizedYesNo(localizations, status['deviceOwner'])),
              _StatusRow(
                  label: localizations.accessibilityMaster,
                  value: localizedYesNo(
                      localizations, status['accessibilityMasterEnabled'])),
              _StatusRow(
                  label: localizations.managedAccessibilityPackages,
                  value:
                      status['managedAccessibilityPackages']?.toString() ?? '-'),
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
        SettingsAdaptiveGrid(
          minChildWidth: 220,
          maxColumns: 2,
          children: [
            SettingsActionCard(
              title: localizations.developerOptions,
              icon: Icons.developer_mode_outlined,
              onPressed: () async {
                await bridgeService.openSpecificSettingsPage('development');
              },
            ),
            SettingsActionCard(
              title: localizations.batterySettings,
              icon: Icons.battery_charging_full_outlined,
              onPressed: () async {
                await bridgeService.openSpecificSettingsPage('battery');
              },
            ),
          ],
        ),
      ],
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
