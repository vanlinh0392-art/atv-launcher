import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class DiagnosticsPanelPage extends StatefulWidget {
  static const String routeName = "diagnostics_panel";
  final FocusNode? primaryFocusNode;

  const DiagnosticsPanelPage({
    super.key,
    this.primaryFocusNode,
  });

  @override
  State<DiagnosticsPanelPage> createState() => _DiagnosticsPanelPageState();
}

class _DiagnosticsPanelPageState extends State<DiagnosticsPanelPage> {
  static const String _summaryDebugLabel = 'diagnostics_summary_metrics';

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
        final report = bridgeService.diagnosticsReport;
        final lineCount =
            report.isEmpty ? 0 : '\n'.allMatches(report).length + 1;

        return ListView(
          key: const PageStorageKey<String>(DiagnosticsPanelPage.routeName),
          children: [
            SettingsSummarySection(
              debugLabel: _summaryDebugLabel,
              child: SettingsAdaptiveGrid(
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
            ),
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsAdaptiveGrid(
                    minChildWidth: 220,
                    maxColumns: 2,
                    children: [
                      SettingsActionCard(
                        key: const Key('diagnostics_refresh_button'),
                        focusNode: widget.primaryFocusNode,
                        onMoveUpAtBoundary: () =>
                            focusCurrentSettingsNodeByDebugLabel(
                          _summaryDebugLabel,
                        ),
                        title: localizations.refreshLabel,
                        subtitle: localizations.reportLines,
                        icon: Icons.refresh,
                        onPressed: () async => bridgeService.refreshFull(),
                      ),
                      SettingsActionCard(
                        onMoveUpAtBoundary: () =>
                            focusCurrentSettingsNodeByDebugLabel(
                          _summaryDebugLabel,
                        ),
                        title: localizations.copyReport,
                        subtitle: localizations.reportLines,
                        icon: Icons.copy_outlined,
                        onPressed: () async =>
                            Clipboard.setData(ClipboardData(text: report)),
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
