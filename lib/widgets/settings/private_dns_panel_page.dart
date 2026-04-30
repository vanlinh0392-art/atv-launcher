import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class PrivateDnsPanelPage extends StatefulWidget {
  static const String routeName = "private_dns_panel";
  final FocusNode? primaryFocusNode;

  const PrivateDnsPanelPage({
    super.key,
    this.primaryFocusNode,
  });

  @override
  State<PrivateDnsPanelPage> createState() => _PrivateDnsPanelPageState();
}

class _PrivateDnsPanelPageState extends State<PrivateDnsPanelPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final host = context
            .read<SystemBridgeService>()
            .privateDnsStatus['selectedHost']
            ?.toString() ??
        'dns.adguard.com';
    _controller = TextEditingController(text: host);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Consumer<SystemBridgeService>(
      builder: (context, bridgeService, _) {
        final status = bridgeService.privateDnsStatus;
        return ListView(
          key: const PageStorageKey<String>(PrivateDnsPanelPage.routeName),
          children: [
            SettingsAdaptiveGrid(
              children: [
                SettingsMetricTile(
                  label: localizations.modeSettingLabel,
                  value: localizedPrivateDnsMode(
                    localizations,
                    status['effectiveMode']?.toString() ?? '',
                  ),
                  icon: Icons.router_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.hostnameLabel,
                  value: status['specifier']?.toString() ?? '-',
                  icon: Icons.dns_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.accessPathLabel,
                  value: status['hasWriteSecureSettings'] == true
                      ? localizations.wssLabel
                      : localizations.localAdbLabel,
                  icon: Icons.security_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsActionCard(
                    focusNode: widget.primaryFocusNode,
                    title: localizations.privateDnsHostname,
                    subtitle: _controller.text.trim().isEmpty
                        ? localizations.privateDnsHostname
                        : _controller.text.trim(),
                    icon: Icons.edit_note_outlined,
                    onPressed: () => _editHostname(context),
                  ),
                  const SizedBox(height: 12),
                  SettingsAdaptiveGrid(
                    minChildWidth: 220,
                    maxColumns: 3,
                    children: [
                      SettingsActionCard(
                        title: localizations.applyHost,
                        subtitle: _controller.text.trim(),
                        icon: Icons.check_circle_outline,
                        onPressed: () async => _showMessage(
                          context,
                          (await bridgeService.applyPrivateDns(
                                mode: 'hostname',
                                host: _controller.text.trim(),
                              ))['message']
                                  ?.toString() ??
                              localizations.privateDnsUpdated,
                        ),
                      ),
                      SettingsActionCard(
                        title: localizations.turnOff,
                        subtitle: localizedPrivateDnsMode(
                          localizations,
                          'off',
                        ),
                        icon: Icons.block_outlined,
                        onPressed: () async => _showMessage(
                          context,
                          (await bridgeService.applyPrivateDns(
                                      mode: 'off'))['message']
                                  ?.toString() ??
                              localizations.privateDnsDisabled,
                        ),
                      ),
                      SettingsActionCard(
                        title: localizations.reset,
                        subtitle: localizations.privateDnsReset,
                        icon: Icons.restart_alt,
                        onPressed: () async => _showMessage(
                          context,
                          (await bridgeService.resetPrivateDns())['message']
                                  ?.toString() ??
                              localizations.privateDnsReset,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editHostname(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final dialogController = TextEditingController(text: _controller.text);
    final nextValue = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.privateDnsHostname),
        content: TextField(
          controller: dialogController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: localizations.privateDnsHostname,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(localizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              dialogController.text.trim(),
            ),
            child: Text(localizations.save),
          ),
        ],
      ),
    );
    dialogController.dispose();
    if (nextValue == null || !mounted) {
      return;
    }
    setState(() {
      _controller.text = nextValue;
    });
  }
}
