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
import 'package:flauncher/widgets/settings/system_core_panel_page.dart';
import 'package:flauncher/widgets/settings/voice_search_panel_page.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsPanelPage extends StatefulWidget {
  static const String routeName = "settings_panel";

  const SettingsPanelPage({super.key});

  @override
  State<SettingsPanelPage> createState() => _SettingsPanelPageState();
}

class _SettingsPanelPageState extends State<SettingsPanelPage> {
  late String _selectedRoute;
  late final FocusNode _detailEntryNode;
  late final FocusScopeNode _detailScopeNode;
  final PageStorageBucket _detailPageStorageBucket = PageStorageBucket();
  List<FocusNode> _railFocusNodes = const [];
  bool _detailPaneActive = false;

  @override
  void initState() {
    super.initState();
    _selectedRoute = HomeLayoutPanelPage.routeName;
    _detailEntryNode = FocusNode(debugLabel: 'settings_detail_entry');
    _detailScopeNode = FocusScopeNode(debugLabel: 'settings_detail_scope');
  }

  @override
  void dispose() {
    _detailEntryNode.dispose();
    _detailScopeNode.dispose();
    for (final node in _railFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final destinations = _destinations(localizations);
    _syncRailFocusNodes(destinations.length);
    final selectedIndex = destinations.indexWhere(
      (item) => item.route == _selectedRoute,
    );
    final destination = destinations.firstWhere(
      (item) => item.route == _selectedRoute,
      orElse: () => destinations.first,
    );

    return SettingsContentView(
      title: localizations.settingsShellTitle,
      subtitle: localizations.settingsShellSubtitle,
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
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final item = destinations[index];
                          final selected = item.route == _selectedRoute;
                          return _RailTile(
                            focusNode: _railFocusNodes[index],
                            item: item,
                            selected: selected,
                            autofocus: index == 0,
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
                focusNode: _detailEntryNode,
                onFocusChange: (hasFocus) {
                  if (!hasFocus || !_detailEntryNode.hasFocus) {
                    return;
                  }
                  _detailScopeNode.nextFocus();
                },
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
                  return KeyEventResult.ignored;
                },
                child: FocusScope(
                  node: _detailScopeNode,
                  onFocusChange: _handleDetailScopeFocusChange,
                  child: SettingsSurfaceCard(
                    key: const Key('settings_detail_pane_card'),
                    highlighted: _detailPaneActive,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destination.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          destination.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
    if (!_detailPaneActive) {
      setState(() {
        _detailPaneActive = true;
      });
    }
    _detailEntryNode.requestFocus();
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
      return false;
    }
    searcher.findBestFocusNode(candidates, current).requestFocus();
    return true;
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
      ];

  Widget _buildPage(String route) {
    switch (route) {
      case HomeLayoutPanelPage.routeName:
        return HomeLayoutPanelPage();
      case WallpaperPanelPage.routeName:
        return WallpaperPanelPage();
      case VoiceSearchPanelPage.routeName:
        return VoiceSearchPanelPage();
      case ProfilesSecurityPanelPage.routeName:
        return ProfilesSecurityPanelPage();
      case AccessibilityManagerPanelPage.routeName:
        return AccessibilityManagerPanelPage();
      case SystemCorePanelPage.routeName:
        return SystemCorePanelPage();
      case DensityPanelPage.routeName:
        return DensityPanelPage();
      case PrivateDnsPanelPage.routeName:
        return PrivateDnsPanelPage();
      case PermissionsPanelPage.routeName:
        return PermissionsPanelPage();
      case BackupRestorePanelPage.routeName:
        return BackupRestorePanelPage();
      case DiagnosticsPanelPage.routeName:
        return DiagnosticsPanelPage();
      default:
        return const SizedBox.shrink();
    }
  }
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
