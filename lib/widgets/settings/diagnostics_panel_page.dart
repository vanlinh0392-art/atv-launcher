import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class DiagnosticsPanelPage extends StatelessWidget {
  static const String routeName = "diagnostics_panel";

  const DiagnosticsPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Consumer<SystemBridgeService>(
      builder: (context, bridgeService, _) {
        final report = bridgeService.diagnosticsReport;
        final lineCount =
            report.isEmpty ? 0 : '\n'.allMatches(report).length + 1;

        return ListView(
          key: const PageStorageKey<String>(DiagnosticsPanelPage.routeName),
          children: [
            SettingsAdaptiveGrid(
              children: [
                SettingsMetricTile(
                  label: localizations.reportLines,
                  value: lineCount.toString(),
                  icon: Icons.receipt_long_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.adbAutomationPolicyTitle,
                  value: localizedAdbPolicy(
                    localizations,
                    bridgeService.adbAutomationStatus['policy']?.toString() ??
                        '',
                  ),
                  icon: Icons.adb_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.coreHealthLabel,
                  value: localizedBridgeHealth(
                    localizations,
                    bridgeService.systemCoreStatus['coreServiceHealth']
                            ?.toString() ??
                        '',
                  ),
                  icon: Icons.favorite_outline,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => bridgeService.refreshDiagnostics(),
                        icon: const Icon(Icons.refresh),
                        label: Text(localizations.refreshLabel),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: report)),
                        icon: const Icon(Icons.copy_outlined),
                        label: Text(localizations.copyReport),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SelectableText(
                    report,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
