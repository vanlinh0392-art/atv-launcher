import 'dart:async';
import 'dart:math' as math;

import 'package:flauncher/custom_traversal_policy.dart';
import 'package:flauncher/widgets/settings/accessibility_manager_panel_page.dart';
import 'package:flauncher/widgets/settings/backup_restore_panel_page.dart';
import 'package:flauncher/widgets/settings/density_panel_page.dart';
import 'package:flauncher/widgets/settings/diagnostics_panel_page.dart';
import 'package:flauncher/widgets/settings/home_layout_panel_page.dart';
import 'package:flauncher/widgets/settings/permissions_panel_page.dart';
import 'package:flauncher/widgets/settings/private_dns_panel_page.dart';
import 'package:flauncher/widgets/settings/profiles_security_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_perf_probe.dart';
import 'package:flauncher/widgets/settings/status_bar_panel_page.dart';
import 'package:flauncher/widgets/settings/system_core_panel_page.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flauncher/widgets/settings/update_panel_page.dart';
import 'package:flauncher/widgets/settings/voice_search_panel_page.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsPanelPage extends StatefulWidget {
  static const String routeName = "settings_panel";
  final String? initialSelectedRoute;
  final bool autoFocusDetailOnOpen;
  final ValueChanged<String>? onBenchmarkReady;
  final ValueChanged<SettingsBenchmarkDpadSample>? onBenchmarkDpadSample;

  const SettingsPanelPage({
    super.key,
    this.initialSelectedRoute,
    this.autoFocusDetailOnOpen = false,
    this.onBenchmarkReady,
    this.onBenchmarkDpadSample,
  });

  @override
  State<SettingsPanelPage> createState() => _SettingsPanelPageState();
}

class _SettingsPanelPageState extends State<SettingsPanelPage> {
  late String _selectedRoute;
  late final FocusScopeNode _detailScopeNode;
  final PageStorageBucket _detailPageStorageBucket = PageStorageBucket();
  List<FocusNode> _railFocusNodes = const [];
  late final Map<String, FocusNode> _detailPrimaryFocusNodes;
  bool _detailPaneActive = false;
  bool _detailContentReady = false;
  bool _pendingDetailFocus = false;
  bool _benchmarkReadyReported = false;
  Timer? _benchmarkSettleTimer;
  _PendingBenchmarkSample? _pendingBenchmarkSample;

  @override
  void initState() {
    super.initState();
    _detailScopeNode = FocusScopeNode(debugLabel: 'settings_detail_scope');
    _detailPrimaryFocusNodes = <String, FocusNode>{
      HomeLayoutPanelPage.routeName:
          FocusNode(debugLabel: 'home_layout_target_appLocale'),
      WallpaperPanelPage.routeName:
          FocusNode(debugLabel: 'wallpaper_primary_source_action'),
      VoiceSearchPanelPage.routeName:
          FocusNode(debugLabel: 'voice_search_primary_mode'),
      PrivateDnsPanelPage.routeName:
          FocusNode(debugLabel: 'private_dns_primary_hostname_action'),
      PermissionsPanelPage.routeName:
          FocusNode(debugLabel: 'permissions_primary_quick_grant'),
      BackupRestorePanelPage.routeName:
          FocusNode(debugLabel: 'backup_restore_primary_export'),
      SystemCorePanelPage.routeName:
          FocusNode(debugLabel: 'system_core_primary_policy'),
      StatusBarPanelPage.routeName:
          FocusNode(debugLabel: 'status_bar_primary_toggle'),
      ProfilesSecurityPanelPage.routeName:
          FocusNode(debugLabel: 'profiles_security_primary_lock'),
      AccessibilityManagerPanelPage.routeName:
          FocusNode(debugLabel: 'accessibility_primary_toggle_apps'),
      DensityPanelPage.routeName:
          FocusNode(debugLabel: 'density_primary_apply'),
      DiagnosticsPanelPage.routeName:
          FocusNode(debugLabel: 'diagnostics_primary_refresh'),
      UpdatePanelPage.routeName: FocusNode(debugLabel: 'updates_primary_check'),
    };
    _selectedRoute = _detailPrimaryFocusNodes.containsKey(
      widget.initialSelectedRoute,
    )
        ? widget.initialSelectedRoute!
        : HomeLayoutPanelPage.routeName;
    if (_benchmarkEnabled) {
      HardwareKeyboard.instance.addHandler(_handleBenchmarkRawKey);
      FocusManager.instance.addListener(_handleBenchmarkFocusChange);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _detailContentReady = true;
      });
      if (widget.autoFocusDetailOnOpen) {
        _pendingDetailFocus = true;
      }
      if (_pendingDetailFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _focusDetailPane();
        });
      }
    });
  }

  @override
  void dispose() {
    if (_benchmarkEnabled) {
      HardwareKeyboard.instance.removeHandler(_handleBenchmarkRawKey);
      FocusManager.instance.removeListener(_handleBenchmarkFocusChange);
    }
    _benchmarkSettleTimer?.cancel();
    _detailScopeNode.dispose();
    for (final node in _railFocusNodes) {
      node.dispose();
    }
    for (final node in _detailPrimaryFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  bool get _benchmarkEnabled =>
      widget.onBenchmarkReady != null || widget.onBenchmarkDpadSample != null;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final destinations = _destinations(localizations);
    _syncRailFocusNodes(destinations.length);
    final selectedIndex = destinations.indexWhere(
      (item) => item.route == _selectedRoute,
    );
    return PopScope(
      canPop: !_detailPaneActive,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_detailPaneActive) {
          return;
        }
        _focusSelectedRail();
      },
      child: SettingsContentView(
        title: localizations.settingsShellTitle,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RepaintBoundary(
              child: SizedBox(
                width: 320,
                child: SettingsSurfaceCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                        child: Text(
                          localizations.settingsControlCenterTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          key: const PageStorageKey<String>(
                            'settings_destination_rail',
                          ),
                          physics: const ClampingScrollPhysics(),
                          itemCount: destinations.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final item = destinations[index];
                            final selected = item.route == _selectedRoute;
                            return _RailTile(
                              focusNode: _railFocusNodes[index],
                              item: item,
                              selected: selected,
                              autofocus: index ==
                                  (selectedIndex < 0 ? 0 : selectedIndex),
                              onPressed: () => _selectRoute(item.route),
                              onEnterDetail: _focusDetailPane,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: RepaintBoundary(
                child: Focus(
                  canRequestFocus: false,
                  onKeyEvent: (_, event) {
                    if (event is! KeyDownEvent) {
                      return KeyEventResult.ignored;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      if (_moveFocusWithinDetail(TraversalDirection.left)) {
                        return KeyEventResult.handled;
                      }
                      _focusSelectedRail();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                        _moveFocusWithinDetail(TraversalDirection.right)) {
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: FocusScope(
                    node: _detailScopeNode,
                    onFocusChange: _handleDetailScopeFocusChange,
                    child: SettingsSurfaceCard(
                      key: const Key('settings_detail_pane_card'),
                      highlighted: _detailPaneActive,
                      padding: const EdgeInsets.all(14),
                      child: _detailContentReady
                          ? FocusTraversalGroup(
                              policy: RowByRowTraversalPolicy(),
                              child: PageStorage(
                                bucket: _detailPageStorageBucket,
                                child: KeyedSubtree(
                                  key: ValueKey<String>(_selectedRoute),
                                  child: _buildPage(
                                    selectedIndex < 0
                                        ? destinations.first.route
                                        : _selectedRoute,
                                  ),
                                ),
                              ),
                            )
                          : _SettingsDetailPlaceholder(
                              label: localizations.loading,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _syncRailFocusNodes(int count) {
    if (_railFocusNodes.length == count) {
      return;
    }
    for (final node in _railFocusNodes) {
      node.dispose();
    }
    _railFocusNodes = List<FocusNode>.generate(
      count,
      (index) => FocusNode(debugLabel: 'settings_rail_$index'),
      growable: false,
    );
  }

  void _selectRoute(String route) {
    if (_selectedRoute == route) {
      return;
    }
    setState(() {
      _selectedRoute = route;
      _detailPaneActive = false;
    });
  }

  void _focusDetailPane() {
    if (!mounted) {
      return;
    }
    if (!_detailContentReady) {
      _pendingDetailFocus = true;
      return;
    }
    _pendingDetailFocus = false;
    if (!_detailPaneActive) {
      setState(() {
        _detailPaneActive = true;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _requestDetailFocus(
          preferredNode: _detailPrimaryFocusNodes[_selectedRoute]);
    });
  }

  void _focusSelectedRail() {
    final selectedIndex = _destinations(AppLocalizations.of(context)!)
        .indexWhere((item) => item.route == _selectedRoute);
    if (_detailPaneActive) {
      setState(() {
        _detailPaneActive = false;
      });
    }
    if (selectedIndex >= 0 && selectedIndex < _railFocusNodes.length) {
      _railFocusNodes[selectedIndex].requestFocus();
    }
  }

  void _handleDetailScopeFocusChange(bool hasFocus) {
    if (_detailPaneActive == hasFocus) {
      return;
    }
    setState(() {
      _detailPaneActive = hasFocus;
    });
  }

  bool _moveFocusWithinDetail(TraversalDirection direction) {
    final current = FocusManager.instance.primaryFocus;
    if (current == null) {
      return false;
    }
    final nodes = _detailScopeNode.traversalDescendants.toList(growable: false);
    if (nodes.isEmpty || !nodes.contains(current)) {
      return false;
    }
    final searcher = NodeSearcher(direction);
    final candidates = searcher.findCandidates(nodes, current);
    if (candidates.isEmpty) {
      if ((direction == TraversalDirection.left ||
              direction == TraversalDirection.right) &&
          _shouldUseRelaxedHorizontalDetailFallback(current)) {
        final fallback = _findRelaxedHorizontalDetailCandidate(
          current: current,
          direction: direction,
          nodes: nodes,
        );
        if (fallback != null) {
          fallback.requestFocus();
          return true;
        }
        final sequentialFallback = _findSequentialActionGridCandidate(
          current: current,
          direction: direction,
          nodes: nodes,
        );
        if (sequentialFallback != null) {
          sequentialFallback.requestFocus();
          return true;
        }
      }
      return false;
    }
    searcher.findBestFocusNode(candidates, current).requestFocus();
    return true;
  }

  bool _shouldUseRelaxedHorizontalDetailFallback(FocusNode current) {
    return _isSettingsActionCardNode(current);
  }

  FocusNode? _findRelaxedHorizontalDetailCandidate({
    required FocusNode current,
    required TraversalDirection direction,
    required List<FocusNode> nodes,
  }) {
    final candidates = nodes.where((node) {
      if (identical(node, current) ||
          !node.canRequestFocus ||
          node.context == null) {
        return false;
      }
      if (direction == TraversalDirection.left &&
          node.rect.center.dx >= current.rect.center.dx) {
        return false;
      }
      if (direction == TraversalDirection.right &&
          node.rect.center.dx <= current.rect.center.dx) {
        return false;
      }
      return _isWithinRelaxedHorizontalBand(current, node);
    }).toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }
    final searcher = NodeSearcher(direction);
    return searcher.findBestFocusNode(
      toCandidateNodes(candidates),
      current,
    );
  }

  FocusNode? _findSequentialActionGridCandidate({
    required FocusNode current,
    required TraversalDirection direction,
    required List<FocusNode> nodes,
  }) {
    final currentIndex = nodes.indexOf(current);
    if (currentIndex < 0) {
      return null;
    }
    final currentGrid = _settingsAdaptiveGridOf(current);
    if (currentGrid == null) {
      return null;
    }
    final step = direction == TraversalDirection.left ? -1 : 1;
    for (var index = currentIndex + step;
        index >= 0 && index < nodes.length;
        index += step) {
      final candidate = nodes[index];
      if (!_isSettingsActionCardNode(candidate) ||
          !candidate.canRequestFocus ||
          candidate.context == null) {
        continue;
      }
      if (identical(_settingsAdaptiveGridOf(candidate), currentGrid)) {
        return candidate;
      }
    }
    return null;
  }

  bool _isWithinRelaxedHorizontalBand(FocusNode current, FocusNode candidate) {
    final centerDistance =
        (current.rect.center.dy - candidate.rect.center.dy).abs();
    final sharedHeight = math.min(current.rect.height, candidate.rect.height);
    final tolerance = math.max(10.0, sharedHeight * 0.45);
    if (centerDistance <= tolerance) {
      return true;
    }
    return current.rect.top < candidate.rect.bottom &&
        current.rect.bottom > candidate.rect.top;
  }

  bool _isSettingsActionCardNode(FocusNode node) =>
      node.context?.findAncestorWidgetOfExactType<SettingsActionCard>() != null;

  SettingsAdaptiveGrid? _settingsAdaptiveGridOf(FocusNode node) =>
      node.context?.findAncestorWidgetOfExactType<SettingsAdaptiveGrid>();

  void _requestDetailFocus({FocusNode? preferredNode}) {
    if (_tryRequestDetailFocusNode(preferredNode) ||
        _tryRequestDetailFocusNode(_firstFocusableDetailNode())) {
      _scheduleDetailFocusVerification(preferredNode);
      _maybeReportBenchmarkReady();
      return;
    }
    if (_detailScopeNode.context != null) {
      _detailScopeNode.nextFocus();
      _scheduleDetailFocusVerification(preferredNode);
      _maybeReportBenchmarkReady();
    }
  }

  bool _tryRequestDetailFocusNode(FocusNode? node) {
    if (node == null || !node.canRequestFocus || node.context == null) {
      return false;
    }
    node.requestFocus();
    return true;
  }

  void _scheduleDetailFocusVerification(FocusNode? preferredNode) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isPrimaryFocusWithinDetail) {
        return;
      }
      if (_tryRequestDetailFocusNode(preferredNode) ||
          _tryRequestDetailFocusNode(_firstFocusableDetailNode())) {
        _maybeReportBenchmarkReady();
        return;
      }
      if (_detailScopeNode.context != null) {
        _detailScopeNode.nextFocus();
        _maybeReportBenchmarkReady();
      }
    });
  }

  FocusNode? _firstFocusableDetailNode() {
    final candidates = _detailScopeNode.traversalDescendants
        .where(
          (node) =>
              node.canRequestFocus &&
              node.context != null &&
              node.enclosingScope != null,
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }
    return candidates.first;
  }

  bool get _isPrimaryFocusWithinDetail {
    final current = FocusManager.instance.primaryFocus;
    return current != null && _isFocusWithinDetail(current);
  }

  bool _handleBenchmarkRawKey(KeyEvent event) {
    if (!_benchmarkEnabled || event is! KeyDownEvent) {
      return false;
    }
    final key = _benchmarkKeyLabel(event.logicalKey);
    if (key == null) {
      return false;
    }
    final current = FocusManager.instance.primaryFocus;
    if (current == null || !_isFocusWithinDetail(current)) {
      return false;
    }
    _benchmarkSettleTimer?.cancel();
    _pendingBenchmarkSample = _PendingBenchmarkSample(
      key: key,
      fromFocus: _focusDebugLabel(current),
      startedAt: DateTime.now(),
    );
    return false;
  }

  void _handleBenchmarkFocusChange() {
    _maybeReportBenchmarkReady();
    final pending = _pendingBenchmarkSample;
    if (pending == null) {
      return;
    }
    final current = FocusManager.instance.primaryFocus;
    if (current == null) {
      return;
    }
    final nextFocus = _focusDebugLabel(current);
    if (nextFocus.isEmpty || nextFocus == pending.fromFocus) {
      return;
    }
    _pendingBenchmarkSample = pending.copyWith(toFocus: nextFocus);
    _benchmarkSettleTimer?.cancel();
    _benchmarkSettleTimer = Timer(
      const Duration(milliseconds: 32),
      _finalizeBenchmarkSample,
    );
  }

  void _finalizeBenchmarkSample() {
    final pending = _pendingBenchmarkSample;
    if (pending == null) {
      return;
    }
    _pendingBenchmarkSample = null;
    final toFocus = pending.toFocus;
    if (toFocus == null || toFocus == pending.fromFocus) {
      return;
    }
    widget.onBenchmarkDpadSample?.call(
      SettingsBenchmarkDpadSample(
        key: pending.key,
        fromFocus: pending.fromFocus,
        toFocus: toFocus,
        inputToSettledFrameMs:
            DateTime.now().difference(pending.startedAt).inMilliseconds,
      ),
    );
  }

  void _maybeReportBenchmarkReady() {
    if (!_benchmarkEnabled ||
        _benchmarkReadyReported ||
        !widget.autoFocusDetailOnOpen) {
      return;
    }
    final current = FocusManager.instance.primaryFocus;
    if (current == null || !_isFocusWithinDetail(current)) {
      return;
    }
    _benchmarkReadyReported = true;
    widget.onBenchmarkReady?.call(_focusDebugLabel(current));
  }

  bool _isFocusWithinDetail(FocusNode node) =>
      _detailScopeNode.traversalDescendants.contains(node);

  String _focusDebugLabel(FocusNode node) {
    FocusNode? current = node;
    while (current != null) {
      final label = current.debugLabel?.trim() ?? '';
      if (label.isNotEmpty) {
        return label.replaceAll(' ', '_');
      }
      current = current.parent;
    }
    return 'unknown_focus';
  }

  String? _benchmarkKeyLabel(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) {
      return 'UP';
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return 'DOWN';
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      return 'LEFT';
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return 'RIGHT';
    }
    return null;
  }

  List<_SettingsDestination> _destinations(AppLocalizations localizations) => [
        _SettingsDestination(
          route: HomeLayoutPanelPage.routeName,
          icon: Icons.home_outlined,
          title: localizations.settingsDestinationHomeTitle,
          subtitle: localizations.settingsDestinationHomeSubtitle,
        ),
        _SettingsDestination(
          route: WallpaperPanelPage.routeName,
          icon: Icons.wallpaper_outlined,
          title: localizations.settingsDestinationWallpaperTitle,
          subtitle: localizations.settingsDestinationWallpaperSubtitle,
        ),
        _SettingsDestination(
          route: VoiceSearchPanelPage.routeName,
          icon: Icons.mic_none_outlined,
          title: localizations.settingsDestinationVoiceTitle,
          subtitle: localizations.settingsDestinationVoiceSubtitle,
        ),
        _SettingsDestination(
          route: ProfilesSecurityPanelPage.routeName,
          icon: Icons.admin_panel_settings_outlined,
          title: localizations.settingsDestinationProfilesTitle,
          subtitle: localizations.settingsDestinationProfilesSubtitle,
        ),
        _SettingsDestination(
          route: AccessibilityManagerPanelPage.routeName,
          icon: Icons.settings_accessibility,
          title: localizations.settingsDestinationAccessibilityTitle,
          subtitle: localizations.settingsDestinationAccessibilitySubtitle,
        ),
        _SettingsDestination(
          route: SystemCorePanelPage.routeName,
          icon: Icons.memory_outlined,
          title: localizations.settingsDestinationSystemCoreTitle,
          subtitle: localizations.settingsDestinationSystemCoreSubtitle,
        ),
        _SettingsDestination(
          route: DensityPanelPage.routeName,
          icon: Icons.monitor_outlined,
          title: localizations.settingsDestinationDensityTitle,
          subtitle: localizations.settingsDestinationDensitySubtitle,
        ),
        _SettingsDestination(
          route: PrivateDnsPanelPage.routeName,
          icon: Icons.router_outlined,
          title: localizations.settingsDestinationPrivateDnsTitle,
          subtitle: localizations.settingsDestinationPrivateDnsSubtitle,
        ),
        _SettingsDestination(
          route: PermissionsPanelPage.routeName,
          icon: Icons.verified_user_outlined,
          title: localizations.settingsDestinationPermissionsTitle,
          subtitle: localizations.settingsDestinationPermissionsSubtitle,
        ),
        _SettingsDestination(
          route: BackupRestorePanelPage.routeName,
          icon: Icons.inventory_2_outlined,
          title: localizations.settingsDestinationBackupTitle,
          subtitle: localizations.settingsDestinationBackupSubtitle,
        ),
        _SettingsDestination(
          route: DiagnosticsPanelPage.routeName,
          icon: Icons.receipt_long_outlined,
          title: localizations.settingsDestinationDiagnosticsTitle,
          subtitle: localizations.settingsDestinationDiagnosticsSubtitle,
        ),
        _SettingsDestination(
          route: UpdatePanelPage.routeName,
          icon: Icons.system_update_outlined,
          title: localizations.settingsDestinationUpdatesTitle,
          subtitle: localizations.settingsDestinationUpdatesSubtitle,
        ),
      ];

  Widget _buildPage(String route) {
    final primaryFocusNode = _detailPrimaryFocusNodes[route];
    switch (route) {
      case HomeLayoutPanelPage.routeName:
        return HomeLayoutPanelPage(primaryFocusNode: primaryFocusNode);
      case WallpaperPanelPage.routeName:
        return WallpaperPanelPage(primaryFocusNode: primaryFocusNode);
      case VoiceSearchPanelPage.routeName:
        return VoiceSearchPanelPage(primaryFocusNode: primaryFocusNode);
      case ProfilesSecurityPanelPage.routeName:
        return ProfilesSecurityPanelPage(primaryFocusNode: primaryFocusNode);
      case AccessibilityManagerPanelPage.routeName:
        return AccessibilityManagerPanelPage(
            primaryFocusNode: primaryFocusNode);
      case SystemCorePanelPage.routeName:
        return SystemCorePanelPage(primaryFocusNode: primaryFocusNode);
      case DensityPanelPage.routeName:
        return DensityPanelPage(primaryFocusNode: primaryFocusNode);
      case PrivateDnsPanelPage.routeName:
        return PrivateDnsPanelPage(primaryFocusNode: primaryFocusNode);
      case PermissionsPanelPage.routeName:
        return PermissionsPanelPage(primaryFocusNode: primaryFocusNode);
      case BackupRestorePanelPage.routeName:
        return BackupRestorePanelPage(primaryFocusNode: primaryFocusNode);
      case DiagnosticsPanelPage.routeName:
        return DiagnosticsPanelPage(primaryFocusNode: primaryFocusNode);
      case UpdatePanelPage.routeName:
        return UpdatePanelPage(primaryFocusNode: primaryFocusNode);
      case StatusBarPanelPage.routeName:
        return StatusBarPanelPage(primaryFocusNode: primaryFocusNode);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SettingsDetailPlaceholder extends StatelessWidget {
  final String label;

  const _SettingsDetailPlaceholder({
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      );
}

class _PendingBenchmarkSample {
  final String key;
  final String fromFocus;
  final DateTime startedAt;
  final String? toFocus;

  const _PendingBenchmarkSample({
    required this.key,
    required this.fromFocus,
    required this.startedAt,
    this.toFocus,
  });

  _PendingBenchmarkSample copyWith({
    String? toFocus,
  }) =>
      _PendingBenchmarkSample(
        key: key,
        fromFocus: fromFocus,
        startedAt: startedAt,
        toFocus: toFocus ?? this.toFocus,
      );
}

class _RailTile extends StatefulWidget {
  final _SettingsDestination item;
  final FocusNode focusNode;
  final bool selected;
  final bool autofocus;
  final VoidCallback onPressed;
  final VoidCallback onEnterDetail;

  const _RailTile({
    required this.item,
    required this.focusNode,
    required this.selected,
    required this.onPressed,
    required this.onEnterDetail,
    this.autofocus = false,
  });

  @override
  State<_RailTile> createState() => _RailTileState();
}

class _RailTileState extends State<_RailTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.selected || _focused;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xA62A6BD8)
            : Colors.white.withOpacity(0.022),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF9ED4FF)
              : Colors.white.withOpacity(0.04),
          width: highlighted ? 2.2 : 1,
        ),
        boxShadow: highlighted
            ? const [
                BoxShadow(
                  color: Color(0x332A6BD8),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ]
            : const [],
      ),
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            widget.onEnterDetail();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            widget.onEnterDetail();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        onFocusChange: (hasFocus) {
          if (_focused != hasFocus) {
            setState(() => _focused = hasFocus);
          }
          if (hasFocus && !widget.selected) {
            widget.onPressed();
          }
        },
        child: InkWell(
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(22),
          onTap: widget.selected ? widget.onEnterDetail : widget.onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(widget.item.icon, color: Colors.white, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              highlighted ? FontWeight.w700 : FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsDestination {
  final String route;
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsDestination({
    required this.route,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
