import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const String _customInputDebugLabel = 'density_custom_input';
  late final TextEditingController _controller;
  late final FocusNode _customDpiFocusNode;
  bool _customDpiFocused = false;

  @override
  void initState() {
    super.initState();
    final density = context
            .read<SystemBridgeService>()
            .densityStatus['currentDensity']
            ?.toString() ??
        '';
    _controller = TextEditingController(text: density);
    _customDpiFocusNode = FocusNode(debugLabel: _customInputDebugLabel);
    _customDpiFocusNode.addListener(_handleCustomDpiFocusChanged);
  }

  @override
  void dispose() {
    _customDpiFocusNode
      ..removeListener(_handleCustomDpiFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final bridgeService = context.read<SystemBridgeService>();
    final status = context.select<SystemBridgeService, Map<String, dynamic>>(
      (service) => service.densityStatus,
    );

    return ListView(
      key: const PageStorageKey<String>(DensityPanelPage.routeName),
      children: [
        SettingsSummarySection(
          debugLabel: _summaryDebugLabel,
          child: SettingsMetricsGrid(
            minChildWidth: 176,
            maxColumns: 3,
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
                child: Focus(
                  canRequestFocus: false,
                  onKeyEvent: (_, event) {
                    if (event is! KeyDownEvent ||
                        !_customDpiFocusNode.hasFocus) {
                      return KeyEventResult.ignored;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      if (focusCurrentSettingsNodeByDebugLabel(
                        _summaryDebugLabel,
                      )) {
                        return KeyEventResult.handled;
                      }
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      if (_focusPrimaryAction()) {
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: SettingsFocusFrame(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                    borderRadius: BorderRadius.circular(18),
                    focusEmphasis: 1.12,
                    variant: SettingsFocusFrameVariant.rowOnly,
                    focused: _customDpiFocused,
                    child: TextField(
                      key: const Key('density_custom_input_field'),
                      focusNode: _customDpiFocusNode,
                      controller: _controller,
                      autofocus: false,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: localizations.customDpiRange,
                      ),
                    ),
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
                    onMoveUpAtBoundary: _focusCustomDpiField,
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
                        (await bridgeService.applyDensity(density))['message']
                                ?.toString() ??
                            localizations.densityUpdated,
                      );
                    },
                  ),
                  SettingsActionCard(
                    onMoveUpAtBoundary: _focusCustomDpiField,
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
  }

  void _handleCustomDpiFocusChanged() {
    if (_customDpiFocused == _customDpiFocusNode.hasFocus) {
      return;
    }
    if (!mounted) {
      _customDpiFocused = _customDpiFocusNode.hasFocus;
      return;
    }
    setState(() {
      _customDpiFocused = _customDpiFocusNode.hasFocus;
    });
  }

  bool _focusCustomDpiField() {
    if (!_customDpiFocusNode.canRequestFocus) {
      return false;
    }
    _customDpiFocusNode.requestFocus();
    return true;
  }

  bool _focusPrimaryAction() {
    final primaryFocusNode = widget.primaryFocusNode;
    if (primaryFocusNode != null && primaryFocusNode.canRequestFocus) {
      primaryFocusNode.requestFocus();
      return true;
    }
    return focusCurrentSettingsNodeByDebugLabel('density_primary_apply');
  }

  void _showMessage(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
