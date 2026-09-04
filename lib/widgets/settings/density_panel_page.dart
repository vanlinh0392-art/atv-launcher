import 'dart:async';

import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
  late final FocusNode _presetFocusNode;
  late final bool _ownsPresetFocusNode;

  static const List<int> _presetDensities = <int>[240, 280, 320, 360];

  static const List<SettingsChoiceOption<int>> _presetOptions =
      <SettingsChoiceOption<int>>[
    SettingsChoiceOption<int>(value: 240, label: '240 (Nhỏ gọn)'),
    SettingsChoiceOption<int>(value: 280, label: '280 (Cân đối)'),
    SettingsChoiceOption<int>(value: 320, label: '320 (Tiêu chuẩn)'),
    SettingsChoiceOption<int>(value: 360, label: '360 (Lớn)'),
  ];

  @override
  void initState() {
    super.initState();
    _ownsPresetFocusNode = widget.primaryFocusNode == null;
    _presetFocusNode = widget.primaryFocusNode ??
        FocusNode(debugLabel: 'density_primary_apply');
    if (_ownsPresetFocusNode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final focusLabel = FocusManager.instance.primaryFocus?.debugLabel ?? '';
        if (focusLabel.contains('settings_rail_')) return;
        _presetFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    if (_ownsPresetFocusNode) {
      _presetFocusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final bridgeService = context.read<SystemBridgeService>();
    final status = context.select<SystemBridgeService, Map<String, dynamic>>(
      (service) => service.densityStatus,
    );

    final currentDensityVal = status['currentDensity'];
    final currentDensity = currentDensityVal is int
        ? currentDensityVal
        : int.tryParse(currentDensityVal?.toString() ?? '') ?? 320;

    final factoryDensityVal = status['factoryDensity'];
    final factoryDensity = factoryDensityVal is int
        ? factoryDensityVal
        : int.tryParse(factoryDensityVal?.toString() ?? '');

    final isPreset = _presetDensities.contains(currentDensity);

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: ListView(
        key: const PageStorageKey<String>(DensityPanelPage.routeName),
        children: [
          if (!isPreset) ...[
            SettingsSurfaceCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.amberAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      factoryDensity != null
                          ? 'Đang dùng DPI tùy chỉnh: $currentDensity DPI (Gốc: $factoryDensity)'
                          : 'Đang dùng DPI tùy chỉnh: $currentDensity DPI',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.92),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TvDrawerTokens.surfaceSpacing),
          ],
          SettingsSurfaceCard(
            child: SettingsChoiceCard<int>(
              focusNode: _presetFocusNode,
              selectorKey: const Key('density_preset_selector'),
              optionKeyPrefix: 'density_preset_option',
              title: localizations.settingsDestinationDensityTitle,
              icon: Icons.monitor_outlined,
              value: currentDensity,
              options: _presetOptions,
              valueLabelBuilder: _densityValueLabel,
              onChanged: (newDensity) => _handleDensityChanged(
                context,
                bridgeService,
                status,
                localizations,
                newDensity,
              ),
            ),
          ),
          const SizedBox(height: TvDrawerTokens.surfaceSpacing),
          SettingsSurfaceCard(
            child: SettingsActionCard(
              key: const Key('density_reset_button'),
              title: 'Đặt lại DPI gốc',
              subtitle: factoryDensity != null
                  ? 'Mặc định: $factoryDensity DPI'
                  : null,
              icon: Icons.restart_alt,
              onPressed: () => _handleResetDensity(
                context,
                bridgeService,
                localizations,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _densityValueLabel(int value) {
    switch (value) {
      case 240:
        return '240 (Nhỏ gọn)';
      case 280:
        return '280 (Cân đối)';
      case 320:
        return '320 (Tiêu chuẩn)';
      case 360:
        return '360 (Lớn)';
      default:
        return '$value DPI';
    }
  }

  Future<void> _handleDensityChanged(
    BuildContext context,
    SystemBridgeService bridgeService,
    Map<String, dynamic> status,
    AppLocalizations localizations,
    int newDensity,
  ) async {
    final prevDensityVal = status['currentDensity'];
    final prevDensity = prevDensityVal is int
        ? prevDensityVal
        : int.tryParse(prevDensityVal?.toString() ?? '');
    final hadOverride = status['overrideDensity'] != null;

    if (newDensity == prevDensity) {
      return;
    }

    final result = await bridgeService.applyDensity(newDensity);
    if (!context.mounted) return;

    _showMessage(
      context,
      result['message']?.toString() ?? localizations.densityUpdated,
    );

    final keep = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DpiSafetyConfirmationDialog(
        newDensity: newDensity,
      ),
    );

    if (keep != true && context.mounted) {
      if (hadOverride && prevDensity != null && prevDensity > 0) {
        await bridgeService.applyDensity(prevDensity);
      } else {
        await bridgeService.resetDensity();
      }
      if (context.mounted) {
        _showMessage(context, 'Đã hoàn tác DPI.');
      }
    }
  }

  Future<void> _handleResetDensity(
    BuildContext context,
    SystemBridgeService bridgeService,
    AppLocalizations localizations,
  ) async {
    final result = await bridgeService.resetDensity();
    if (!context.mounted) return;
    _showMessage(
      context,
      result['message']?.toString() ?? localizations.densityReset,
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

class _DpiSafetyConfirmationDialog extends StatefulWidget {
  final int newDensity;

  const _DpiSafetyConfirmationDialog({required this.newDensity});

  @override
  State<_DpiSafetyConfirmationDialog> createState() =>
      _DpiSafetyConfirmationDialogState();
}

class _DpiSafetyConfirmationDialogState
    extends State<_DpiSafetyConfirmationDialog> {
  Timer? _timer;
  int _secondsLeft = 10;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        Navigator.of(context).pop(false);
      } else {
        setState(() {
          _secondsLeft -= 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(false);
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AlertDialog(
            title: const Text('Xác nhận mật độ DPI mới'),
            content: Text(
              'Đã áp dụng DPI ${widget.newDensity}. Bạn có muốn giữ lại thiết lập này không?\n\nTự động hoàn tác sau $_secondsLeft giây...',
            ),
            actions: [
              FilledButton(
                autofocus: true,
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hoàn tác ngay (Khuyên dùng)'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Giữ lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
