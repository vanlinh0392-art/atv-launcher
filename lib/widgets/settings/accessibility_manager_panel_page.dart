import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AccessibilityManagerPanelPage extends StatefulWidget {
  static const String routeName = "accessibility_manager_panel";
  final FocusNode? primaryFocusNode;

  const AccessibilityManagerPanelPage({
    super.key,
    this.primaryFocusNode,
  });

  @override
  State<AccessibilityManagerPanelPage> createState() =>
      _AccessibilityManagerPanelPageState();
}

class _AccessibilityManagerPanelPageState
    extends State<AccessibilityManagerPanelPage> {
  bool _showManagedApps = false;

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
    final bridgeService = context.read<SystemBridgeService>();
    final viewSize = MediaQuery.sizeOf(context);
    final metricsMaxColumns =
        viewSize.width >= 1180 && viewSize.height >= 760 ? 3 : 2;
    final actionsMaxColumns =
        viewSize.width >= 1460 && viewSize.height >= 860 ? 3 : 2;

    return Selector<SystemBridgeService, Map<String, dynamic>>(
      selector: (_, service) => service.accessibilitySnapshot,
      builder: (context, snapshot, _) {
        final apps = _showManagedApps
            ? (((snapshot['apps'] as List?) ?? const [])
                .map((item) => (item as Map).cast<String, dynamic>())
                .toList(growable: false))
            : const <Map<String, dynamic>>[];

        return ListView(
          key: const PageStorageKey<String>(
            AccessibilityManagerPanelPage.routeName,
          ),
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            SettingsAdaptiveGrid(
              maxColumns: metricsMaxColumns,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.fact_check_outlined),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizations.guardianVerifyResult,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              snapshot['lastVerifyResult']?.toString() ?? '-',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white70,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SettingsAdaptiveGrid(
                    minChildWidth: 208,
                    maxColumns: actionsMaxColumns,
                    children: [
                      _AccessibilityActionButton(
                        onPressed: () async => _showResult(
                          context,
                          await bridgeService.repairAccessibility(),
                        ),
                        icon: Icons.build_outlined,
                        label: localizations.repairLabel,
                      ),
                      _AccessibilityActionButton(
                        onPressed: () async => _showResult(
                          context,
                          await bridgeService
                              .grantWriteSecureSettingsWithLocalAdb(),
                        ),
                        icon: Icons.adb_outlined,
                        label: localizations.grantWssViaLocalAdb,
                      ),
                      _AccessibilityActionButton(
                        onPressed: () async {
                          bridgeService.openAccessibilitySettings();
                        },
                        icon: Icons.settings_accessibility,
                        label: localizations.openAccessibilitySettings,
                      ),
                      _AccessibilityActionButton(
                        key: const Key('accessibility_toggle_apps_button'),
                        focusNode: widget.primaryFocusNode,
                        onPressed: () async {
                          setState(() {
                            _showManagedApps = !_showManagedApps;
                          });
                        },
                        icon: _showManagedApps
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        label: _showManagedApps
                            ? localizations.hideManagedAccessibilityAppsAction
                            : localizations.showManagedAccessibilityAppsAction,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_showManagedApps) ...[
              const SizedBox(height: 18),
              SettingsSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.managedApps,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 360,
                      child: ListView.builder(
                        itemCount: apps.length,
                        itemBuilder: (context, index) {
                          final app = apps[index];
                          final canManage =
                              app['hasAccessibilityService'] == true;
                          final enabled = app['accessibilityEnabled'] == true;
                          final managed = app['managed'] == true;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              enabled
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: enabled
                                  ? const Color(0xFF7BE0A5)
                                  : Colors.white38,
                            ),
                            title: Text(app['label']?.toString() ??
                                app['packageName']?.toString() ??
                                '-'),
                            subtitle:
                                Text(app['packageName']?.toString() ?? ''),
                            trailing: canManage
                                ? FilledButton.tonal(
                                    onPressed: () async => _showResult(
                                      context,
                                      await bridgeService
                                          .setManagedAccessibility(
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
                  ],
                ),
              ),
            ],
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

class _AccessibilityActionButton extends StatelessWidget {
  final FocusNode? focusNode;
  final Future<void> Function()? onPressed;
  final IconData icon;
  final String label;

  const _AccessibilityActionButton({
    super.key,
    this.focusNode,
    this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: SettingsActionCard(
        focusNode: focusNode,
        title: label,
        icon: icon,
        focusEmphasis: 1.32,
        onPressed: onPressed,
      ),
    );
  }
}
