import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AccessibilityManagerPanelPage extends StatefulWidget {
  static const String routeName = "accessibility_manager_panel";

  const AccessibilityManagerPanelPage({super.key});

  @override
  State<AccessibilityManagerPanelPage> createState() =>
      _AccessibilityManagerPanelPageState();
}

class _AccessibilityManagerPanelPageState
    extends State<AccessibilityManagerPanelPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SystemBridgeService>().refreshAccessibilitySnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Consumer<SystemBridgeService>(
      builder: (context, bridgeService, _) {
        final snapshot = bridgeService.accessibilitySnapshot;
        final apps = bridgeService.accessibilityApps;

        return ListView(
          key: const PageStorageKey<String>(
            AccessibilityManagerPanelPage.routeName,
          ),
          children: [
            SettingsAdaptiveGrid(
              children: [
                SettingsMetricTile(
                  label: localizations.wssLabel,
                  value: localizedGrantedMissing(
                    localizations,
                    snapshot['writeSecureSettingsGranted'],
                  ),
                  icon: Icons.verified_user_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.masterSwitch,
                  value: localizedOnOff(
                    localizations,
                    snapshot['accessibilityMasterEnabled'],
                  ),
                  icon: Icons.accessibility_new_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.managedApps,
                  value: snapshot['managedPackageCount']?.toString() ?? '0',
                  icon: Icons.manage_accounts_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.fact_check_outlined),
                    title: Text(localizations.guardianVerifyResult),
                    subtitle:
                        Text(snapshot['lastVerifyResult']?.toString() ?? '-'),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () async => _showResult(
                          context,
                          await bridgeService.repairAccessibility(),
                        ),
                        icon: const Icon(Icons.build_outlined),
                        label: Text(localizations.repairLabel),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async => _showResult(
                          context,
                          await bridgeService
                              .grantWriteSecureSettingsWithLocalAdb(),
                        ),
                        icon: const Icon(Icons.adb_outlined),
                        label: Text(localizations.grantWssViaLocalAdb),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            bridgeService.openAccessibilitySettings(),
                        icon: const Icon(Icons.settings_accessibility),
                        label: Text(localizations.openAccessibilitySettings),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: SizedBox(
                height: 420,
                child: ListView.builder(
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    final canManage = app['hasAccessibilityService'] == true;
                    final enabled = app['accessibilityEnabled'] == true;
                    final managed = app['managed'] == true;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        enabled
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color:
                            enabled ? const Color(0xFF7BE0A5) : Colors.white38,
                      ),
                      title: Text(app['label']?.toString() ??
                          app['packageName']?.toString() ??
                          '-'),
                      subtitle: Text(app['packageName']?.toString() ?? ''),
                      trailing: canManage
                          ? FilledButton.tonal(
                              onPressed: () async => _showResult(
                                context,
                                await bridgeService.setManagedAccessibility(
                                  app['packageName']?.toString() ?? '',
                                  !managed || !enabled,
                                ),
                              ),
                              child: Text(
                                managed && enabled
                                    ? localizations.removeLabel
                                    : localizations.manageLabel,
                              ),
                            )
                          : Text(localizations.noService),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showResult(BuildContext context, Map<String, dynamic> result) {
    if (!context.mounted) {
      return;
    }
    final message = result['message']?.toString() ??
        AppLocalizations.of(context)!.actionCompleted;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
