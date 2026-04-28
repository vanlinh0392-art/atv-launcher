import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class PrivateDnsPanelPage extends StatefulWidget {
  static const String routeName = "private_dns_panel";

  const PrivateDnsPanelPage({super.key});

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
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                        labelText: localizations.privateDnsHostname),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () async => _showMessage(
                          context,
                          (await bridgeService.applyPrivateDns(
                                mode: 'hostname',
                                host: _controller.text.trim(),
                              ))['message']
                                  ?.toString() ??
                              localizations.privateDnsUpdated,
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(localizations.applyHost),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async => _showMessage(
                          context,
                          (await bridgeService.applyPrivateDns(
                                      mode: 'off'))['message']
                                  ?.toString() ??
                              localizations.privateDnsDisabled,
                        ),
                        icon: const Icon(Icons.block_outlined),
                        label: Text(localizations.turnOff),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async => _showMessage(
                          context,
                          (await bridgeService.resetPrivateDns())['message']
                                  ?.toString() ??
                              localizations.privateDnsReset,
                        ),
                        icon: const Icon(Icons.restart_alt),
                        label: Text(localizations.reset),
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
}
