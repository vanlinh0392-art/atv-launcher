import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class SystemCorePanelPage extends StatelessWidget {
  static const String routeName = "system_core_panel";
  static const String _snapshotDebugLabel = 'system_core_snapshot_section';
  final FocusNode? primaryFocusNode;

  const SystemCorePanelPage({
    super.key,
    this.primaryFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final bridgeService = context.read<SystemBridgeService>();
    final status = context.select<SystemBridgeService, Map<String, dynamic>>(
      (service) => service.systemCoreStatus,
    );
    final adb = context.select<SystemBridgeService, Map<String, dynamic>>(
      (service) => service.adbAutomationStatus,
    );
    final policy = adb['policy']?.toString() ?? 'off';
    final disableOnSleep = adb['disableOnSleep'] == true;
    final snapshotEntries = <_SystemCoreSnapshotEntry>[
      _SystemCoreSnapshotEntry(
        label: localizations.accessibilityMaster,
        value: localizedYesNo(
          localizations,
          status['accessibilityMasterEnabled'],
        ),
      ),
      _SystemCoreSnapshotEntry(
        label: localizations.lastAdbState,
        value: localizedAdbPolicy(
          localizations,
          status['adbLastState']?.toString() ?? '',
        ),
      ),
      _SystemCoreSnapshotEntry(
        label: localizations.lastSuccess,
        value: status['lastSuccessAtText']?.toString() ?? '-',
      ),
    ];

    return ListView(
      key: const PageStorageKey<String>(SystemCorePanelPage.routeName),
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        SettingsSurfaceCard(
          padding: TvDrawerTokens.surfacePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizations.adbAutomationPolicyTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: TvDrawerTokens.rowSpacing),
              SettingsChoiceCard<String>(
                focusNode: primaryFocusNode,
                selectorKey: const Key('system_core_adb_policy_selector'),
                optionKeyPrefix: 'system_core_adb_policy_option',
                title: localizations.adbAutomationPolicyTitle,
                icon: Icons.adb_outlined,
                value: policy,
                options: <SettingsChoiceOption<String>>[
                  SettingsChoiceOption<String>(
                    value: 'off',
                    label: localizations.adbPolicyOff,
                  ),
                  SettingsChoiceOption<String>(
                    value: 'adb_only',
                    label: localizations.adbPolicyAdbOnly,
                  ),
                  SettingsChoiceOption<String>(
                    value: 'adb_and_wifi',
                    label: localizations.adbPolicyAdbAndWifi,
                  ),
                ],
                valueLabelBuilder: (value) => localizedAdbPolicy(
                  localizations,
                  value,
                ),
                onChanged: (value) => bridgeService.setAdbAutomationPolicy(
                  policy: value,
                  disableOnSleep: disableOnSleep,
                ),
              ),
              const SizedBox(height: TvDrawerTokens.rowSpacing),
              RoundedSwitchListTile(
                value: disableOnSleep,
                onChanged: (value) => bridgeService.setAdbAutomationPolicy(
                  policy: policy,
                  disableOnSleep: value,
                ),
                title: Text(
                  localizations.disableAdbOnSleepTitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                secondary: const Icon(Icons.power_settings_new_outlined),
              ),
              const SizedBox(height: TvDrawerTokens.rowSpacing),
              SettingsAdaptiveGrid(
                spacing: 8,
                runSpacing: 8,
                minChildWidth: 240,
                maxColumns: 2,
                forceSingleColumn: false,
                children: [
                  _buildCompactActionCard(
                    key: const Key('system_core_enable_now_button'),
                    title: localizations.enableNow,
                    icon: Icons.flash_on_outlined,
                    onPressed: () async {
                      await bridgeService.setAdbEnabledNow(true);
                    },
                  ),
                  _buildCompactActionCard(
                    key: const Key('system_core_disable_now_button'),
                    title: localizations.disableNow,
                    icon: Icons.power_settings_new_outlined,
                    onPressed: () async {
                      await bridgeService.setAdbEnabledNow(false);
                    },
                  ),
                ],
              ),
              const SizedBox(height: TvDrawerTokens.rowSpacing),
              _buildCompactActionCard(
                key: const Key('system_core_heal_button'),
                title: localizations.runHealNow,
                icon: Icons.build_outlined,
                onPressed: () async {
                  await bridgeService.repairAccessibility();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: TvDrawerTokens.surfaceSpacing),
        _SystemCoreSnapshotSection(
          title: localizations.coreSnapshotTitle,
          debugLabel: _snapshotDebugLabel,
          entries: snapshotEntries,
        ),
        const SizedBox(height: TvDrawerTokens.surfaceSpacing),
        SettingsAdaptiveGrid(
          spacing: 8,
          runSpacing: 8,
          minChildWidth: 240,
          maxColumns: 2,
          forceSingleColumn: false,
          children: [
            _buildCompactActionCard(
              key: const Key('system_core_developer_options_button'),
              onMoveUpAtBoundary: () => focusCurrentSettingsNodeByDebugLabel(
                _snapshotDebugLabel,
              ),
              title: localizations.developerOptions,
              icon: Icons.developer_mode_outlined,
              onPressed: () async {
                await bridgeService.openSpecificSettingsPage('development');
              },
            ),
            _buildCompactActionCard(
              key: const Key('system_core_battery_settings_button'),
              onMoveUpAtBoundary: () => focusCurrentSettingsNodeByDebugLabel(
                _snapshotDebugLabel,
              ),
              title: localizations.batterySettings,
              icon: Icons.battery_charging_full_outlined,
              onPressed: () async {
                await bridgeService.openSpecificSettingsPage('battery');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactActionCard({
    Key? key,
    FocusNode? focusNode,
    SettingsBoundaryMoveHandler? onMoveUpAtBoundary,
    required String title,
    required IconData icon,
    required Future<void> Function()? onPressed,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TvDrawerTokens.cardMinHeight),
      child: SettingsActionCard(
        key: key,
        focusNode: focusNode,
        onMoveUpAtBoundary: onMoveUpAtBoundary,
        title: title,
        icon: icon,
        focusEmphasis: 1.16,
        onPressed: onPressed,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        titleMaxLines: 1,
        iconSize: 20,
        trailingIconSize: 20,
      ),
    );
  }
}

class _SystemCoreSnapshotEntry {
  final String label;
  final String value;

  const _SystemCoreSnapshotEntry({
    required this.label,
    required this.value,
  });
}

class _SystemCoreSnapshotSection extends StatefulWidget {
  final String title;
  final String debugLabel;
  final List<_SystemCoreSnapshotEntry> entries;

  const _SystemCoreSnapshotSection({
    required this.title,
    required this.debugLabel,
    required this.entries,
  });

  @override
  State<_SystemCoreSnapshotSection> createState() =>
      _SystemCoreSnapshotSectionState();
}

class _SystemCoreSnapshotSectionState
    extends State<_SystemCoreSnapshotSection> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: widget.debugLabel);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSurfaceCard(
      padding: TvDrawerTokens.surfacePadding,
      child: EnsureVisible(
        alignment: EnsureVisible.settingsAlignment,
        settleFrameCount: 1,
        preferImmediate: true,
        child: Focus(
          focusNode: _focusNode,
          canRequestFocus: widget.entries.isNotEmpty,
          onFocusChange: (value) {
            if (_focused != value) {
              setState(() => _focused = value);
            }
          },
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }
            TraversalDirection? direction;
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              direction = TraversalDirection.up;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              direction = TraversalDirection.down;
            }
            if (direction != null) {
              if (!moveSettingsVerticalFocus(
                direction: direction,
                localNodes: <FocusNode>[_focusNode],
              )) {
                if (direction == TraversalDirection.up &&
                    focusNearestSettingsSummaryAbove(_focusNode)) {
                  return KeyEventResult.handled;
                }
                _focusNode.focusInDirection(direction);
              }
              return KeyEventResult.handled;
            }
            if (isSettingsActivateKey(event.logicalKey)) {
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: SettingsFocusFrame(
            key: const Key('system_core_snapshot_section'),
            padding: const EdgeInsets.all(6),
            borderRadius: BorderRadius.circular(20),
            baseColor: Colors.transparent,
            focusEmphasis: 1.12,
            variant: SettingsFocusFrameVariant.rowOnly,
            focused: _focused,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                SettingsAdaptiveGrid(
                  spacing: 8,
                  runSpacing: 8,
                  minChildWidth: 160,
                  maxColumns: 3,
                  forceSingleColumn: false,
                  children: widget.entries
                      .map(
                        (entry) => _SystemCoreSnapshotTile(
                          entry: entry,
                          emphasized: _focused,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemCoreSnapshotTile extends StatelessWidget {
  final _SystemCoreSnapshotEntry entry;
  final bool emphasized;

  const _SystemCoreSnapshotTile({
    required this.entry,
    required this.emphasized,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor =
        emphasized ? Colors.white.withOpacity(0.82) : Colors.white70;
    final valueColor =
        emphasized ? Colors.white : Colors.white.withOpacity(0.9);

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(emphasized ? 0.07 : 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(emphasized ? 0.14 : 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            entry.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: labelColor,
                  height: 1.12,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            entry.value.trim().isEmpty ? '-' : entry.value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: valueColor,
                  height: 1.12,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
