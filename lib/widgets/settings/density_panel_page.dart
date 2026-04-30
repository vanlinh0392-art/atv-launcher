import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DensityPanelPage extends StatefulWidget {
  static const String routeName = "density_panel";
  final FocusNode? primaryFocusNode;

  const DensityPanelPage({
    super.key,
    this.primaryFocusNode,
  });

  @override
  State<DensityPanelPage> createState() => _DensityPanelPageState();
}

class _DensityPanelPageState extends State<DensityPanelPage> {
  static const String _summaryDebugLabel = 'density_summary_metrics';
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final density = context
            .read<SystemBridgeService>()
            .densityStatus['currentDensity']
            ?.toString() ??
        '';
    _controller = TextEditingController(text: density);
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
        final status = bridgeService.densityStatus;

        return ListView(
          key: const PageStorageKey<String>(DensityPanelPage.routeName),
          children: [
            SettingsSummarySection(
              debugLabel: _summaryDebugLabel,
              child: SettingsAdaptiveGrid(
                children: [
                  SettingsMetricTile(
                    label: localizations.currentDpi,
                    value: status['currentDensity']?.toString() ?? '-',
                    icon: Icons.monitor_outlined,
                  ),
                  SettingsMetricTile(
                    label: localizations.factoryDpi,
                    value: status['factoryDensity']?.toString() ?? '-',
                    icon: Icons.settings_backup_restore_outlined,
                  ),
                  SettingsMetricTile(
                    label: localizations.overrideLabel,
                    value: status['overrideDensity']?.toString() ?? '-',
                    icon: Icons.tune_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.alt_route_outlined),
                    title: Text(localizations.executionPathLabel),
                    subtitle: Text(status['executionPath']?.toString() ?? '-'),
                  ),
                  EnsureVisible(
                    alignment: EnsureVisible.settingsAlignment,
                    preferImmediate: true,
                    child: TextField(
                      controller: _controller,
                      autofocus: false,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: localizations.customDpiRange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsAdaptiveGrid(
                    minChildWidth: 220,
                    maxColumns: 2,
                    children: [
                      SettingsActionCard(
                        key: const Key('density_apply_button'),
                        focusNode: widget.primaryFocusNode,
                        onMoveUpAtBoundary: () =>
                            focusCurrentSettingsNodeByDebugLabel(
                          _summaryDebugLabel,
                        ),
                        title: localizations.applyLabel,
                        subtitle: localizations.customDpiRange,
                        icon: Icons.check_circle_outline,
                        onPressed: () async {
                          final density = int.tryParse(_controller.text.trim());
                          if (density == null) {
                            _showMessage(context, localizations.enterValidDpi);
                            return;
                          }
                          _showMessage(
                            context,
                            (await bridgeService
                                        .applyDensity(density))['message']
                                    ?.toString() ??
                                localizations.densityUpdated,
                          );
                        },
                      ),
                      SettingsActionCard(
                        onMoveUpAtBoundary: () =>
                            focusCurrentSettingsNodeByDebugLabel(
                          _summaryDebugLabel,
                        ),
                        title: localizations.reset,
                        subtitle: localizations.factoryDpi,
                        icon: Icons.restart_alt,
                        onPressed: () async => _showMessage(
                          context,
                          (await bridgeService.resetDensity())['message']
                                  ?.toString() ??
                              localizations.densityReset,
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
}
