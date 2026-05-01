import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const String _summaryDebugLabel = 'accessibility_summary_metrics';
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

        return SingleChildScrollView(
          key: const PageStorageKey<String>(
            AccessibilityManagerPanelPage.routeName,
          ),
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsSummarySection(
                debugLabel: _summaryDebugLabel,
                child: SettingsMetricsGrid(
                  minChildWidth: 176,
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
                        for (final entry in <_AccessibilityActionConfig>[
                          _AccessibilityActionConfig(
                            onPressed: () async => _showResult(
                              context,
                              await bridgeService.repairAccessibility(),
                            ),
                            icon: Icons.build_outlined,
                            label: localizations.repairLabel,
                          ),
                          _AccessibilityActionConfig(
                            onPressed: () async => _showResult(
                              context,
                              await bridgeService
                                  .grantWriteSecureSettingsWithLocalAdb(),
                            ),
                            icon: Icons.adb_outlined,
                            label: localizations.grantWssViaLocalAdb,
                          ),
                          _AccessibilityActionConfig(
                            onPressed: () async {
                              bridgeService.openAccessibilitySettings();
                            },
                            icon: Icons.settings_accessibility,
                            label: localizations.openAccessibilitySettings,
                          ),
                          _AccessibilityActionConfig(
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
                                ? localizations
                                    .hideManagedAccessibilityAppsAction
                                : localizations
                                    .showManagedAccessibilityAppsAction,
                          ),
                        ].asMap().entries)
                          _AccessibilityActionButton(
                            key: entry.value.key,
                            focusNode: entry.value.focusNode,
                            onMoveUpAtBoundary: entry.key < actionsMaxColumns
                                ? () => focusCurrentSettingsNodeByDebugLabel(
                                      _summaryDebugLabel,
                                    )
                                : null,
                            onPressed: entry.value.onPressed,
                            icon: entry.value.icon,
                            label: entry.value.label,
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
                      ListView.separated(
                        shrinkWrap: true,
                        primary: false,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: apps.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final app = apps[index];
                          final packageName =
                              app['packageName']?.toString() ?? '';
                          final canManage =
                              app['hasAccessibilityService'] == true;
                          final enabled = app['accessibilityEnabled'] == true;
                          final managed = app['managed'] == true;

                          return _ManagedAccessibilityAppTile(
                            title: app['label']?.toString() ??
                                (packageName.isEmpty ? '-' : packageName),
                            subtitle: packageName,
                            enabled: enabled,
                            canManage: canManage,
                            actionLabel: canManage
                                ? managed && enabled
                                    ? localizations.removeLabel
                                    : localizations.manageLabel
                                : localizations.noService,
                            onPressed: !canManage || packageName.isEmpty
                                ? null
                                : () async => _showResult(
                                      context,
                                      await bridgeService
                                          .setManagedAccessibility(
                                        packageName,
                                        !managed || !enabled,
                                      ),
                                    ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
  final SettingsBoundaryMoveHandler? onMoveUpAtBoundary;
  final Future<void> Function()? onPressed;
  final IconData icon;
  final String label;

  const _AccessibilityActionButton({
    super.key,
    this.focusNode,
    this.onMoveUpAtBoundary,
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
        onMoveUpAtBoundary: onMoveUpAtBoundary,
        title: label,
        icon: icon,
        focusEmphasis: 1.32,
        onPressed: onPressed,
      ),
    );
  }
}

class _AccessibilityActionConfig {
  final Key? key;
  final FocusNode? focusNode;
  final Future<void> Function()? onPressed;
  final IconData icon;
  final String label;

  const _AccessibilityActionConfig({
    this.key,
    this.focusNode,
    this.onPressed,
    required this.icon,
    required this.label,
  });
}

class _ManagedAccessibilityAppTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool enabled;
  final bool canManage;
  final String actionLabel;
  final Future<void> Function()? onPressed;

  const _ManagedAccessibilityAppTile({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.canManage,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  State<_ManagedAccessibilityAppTile> createState() =>
      _ManagedAccessibilityAppTileState();
}

class _ManagedAccessibilityAppTileState
    extends State<_ManagedAccessibilityAppTile> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    final debugToken =
        widget.subtitle.isNotEmpty ? widget.subtitle : widget.title;
    _focusNode = FocusNode(
      debugLabel:
          'accessibility_managed_app_${debugToken.replaceAll(' ', '_')}',
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canActivate = widget.onPressed != null;
    final iconColor = widget.enabled
        ? const Color(0xFF7BE0A5)
        : (canActivate ? Colors.white54 : Colors.white38);
    final trailingColor =
        canActivate ? Colors.white.withOpacity(0.92) : Colors.white38;
    return EnsureVisible(
      alignment: EnsureVisible.settingsAlignment,
      settleFrameCount: 1,
      preferImmediate: true,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: true,
        onFocusChange: (value) {
          if (_focused != value) {
            setState(() {
              _focused = value;
            });
          }
        },
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }
          final direction = event.logicalKey == LogicalKeyboardKey.arrowUp
              ? TraversalDirection.up
              : event.logicalKey == LogicalKeyboardKey.arrowDown
                  ? TraversalDirection.down
                  : null;
          if (direction != null) {
            if (!moveSettingsVerticalFocus(
              direction: direction,
              localNodes: <FocusNode>[_focusNode],
            )) {
              _focusNode.focusInDirection(direction);
            }
            return KeyEventResult.handled;
          }
          if (isSettingsActivateKey(event.logicalKey) && canActivate) {
            widget.onPressed?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SettingsFocusFrame(
          padding: EdgeInsets.zero,
          variant: SettingsFocusFrameVariant.rowOnly,
          focusEmphasis: 1.28,
          focused: _focused,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canActivate ? () => widget.onPressed!.call() : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    widget.enabled
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: iconColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: _focused
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                        ),
                        if (widget.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.actionLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: trailingColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
