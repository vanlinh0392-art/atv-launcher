import 'dart:async';
import 'dart:math' as math;

import 'package:flauncher/models/search_result_item.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/providers/search_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/pin_pad_dialog.dart';
import 'package:flauncher/widgets/settings/accessibility_manager_panel_page.dart';
import 'package:flauncher/widgets/settings/backup_restore_panel_page.dart';
import 'package:flauncher/widgets/settings/density_panel_page.dart';
import 'package:flauncher/widgets/settings/diagnostics_panel_page.dart';
import 'package:flauncher/widgets/settings/home_layout_panel_page.dart';
import 'package:flauncher/widgets/settings/permissions_panel_page.dart';
import 'package:flauncher/widgets/settings/private_dns_panel_page.dart';
import 'package:flauncher/widgets/settings/profiles_security_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flauncher/widgets/settings/system_core_panel_page.dart';
import 'package:flauncher/widgets/settings/voice_search_panel_page.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

Future<void> showSearchOverlayDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => SearchOverlayDialog(parentContext: context),
  );
}

class SearchOverlayDialog extends StatefulWidget {
  final BuildContext parentContext;

  const SearchOverlayDialog({
    super.key,
    required this.parentContext,
  });

  @override
  State<SearchOverlayDialog> createState() => _SearchOverlayDialogState();
}

class _SearchOverlayDialogState extends State<SearchOverlayDialog> {
  static const List<String> _filters = <String>[
    'all',
    'app',
    'settings',
    'input',
    'media',
    'action',
  ];

  final TextEditingController _queryController = TextEditingController();
  final FocusNode _queryFocusNode = FocusNode(debugLabel: 'search_query');
  final FocusNode _voiceFocusNode = FocusNode(debugLabel: 'search_voice');
  final FocusNode _closeFocusNode = FocusNode(debugLabel: 'search_close');
  late final Map<String, FocusNode> _filterNodes;

  List<FocusNode> _resultNodes = const <FocusNode>[];
  String _selectedFilter = 'all';
  bool _loadingSources = false;

  @override
  void initState() {
    super.initState();
    _filterNodes = Map<String, FocusNode>.fromEntries(
      _filters.map(
        (filter) => MapEntry(
          filter,
          FocusNode(debugLabel: 'search_filter_$filter'),
        ),
      ),
    );
    _queryController.addListener(_handleQueryChanged);
    unawaited(_refreshSources());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusFilter(_selectedFilter);
    });
  }

  @override
  void dispose() {
    _queryController
      ..removeListener(_handleQueryChanged)
      ..dispose();
    _queryFocusNode.dispose();
    _voiceFocusNode.dispose();
    _closeFocusNode.dispose();
    for (final node in _filterNodes.values) {
      node.dispose();
    }
    for (final node in _resultNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final mediaSize = MediaQuery.sizeOf(context);
    final dialogWidth = math.min(1220.0, math.max(720.0, mediaSize.width - 72));
    final dialogHeight =
        math.min(760.0, math.max(520.0, mediaSize.height - 72));
    final compactLayout = dialogHeight < 700;
    final contentPadding = compactLayout ? 20.0 : 24.0;
    final sectionGap = compactLayout ? 8.0 : 12.0;
    return Consumer4<AppsService, SearchService, SystemBridgeService,
        ProfileSecurityService?>(
      builder:
          (context, appsService, searchService, bridgeService, security, _) {
        final items = _buildItems(
          localizations: localizations,
          appsService: appsService,
          searchService: searchService,
          security: security,
        );
        final results = searchService.rankResults(
          query: _queryController.text,
          items: items,
          filter: _selectedFilter,
        );
        _syncResultNodes(results.length);

        return PopScope(
          canPop: true,
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.escape): _close,
              const SingleActivator(LogicalKeyboardKey.gameButtonB): _close,
            },
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: math.max(24, (mediaSize.width - dialogWidth) / 2),
                vertical: math.max(20, (mediaSize.height - dialogHeight) / 2),
              ),
              child: FocusTraversalGroup(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xFF08131F),
                        Color(0xFF102338),
                        Color(0xFF091522),
                      ],
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x88000000),
                        blurRadius: 44,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: SizedBox(
                      width: dialogWidth,
                      height: dialogHeight,
                      child: Column(
                        children: <Widget>[
                          _buildTopBar(
                            localizations,
                            searchService,
                            bridgeService,
                            contentPadding: contentPadding,
                            compactLayout: compactLayout,
                          ),
                          SizedBox(height: sectionGap),
                          _buildFilterRow(localizations, results.isNotEmpty),
                          if (_loadingSources || searchService.busy)
                            const LinearProgressIndicator(minHeight: 2),
                          SizedBox(height: sectionGap),
                          Expanded(
                            child: _buildResultsPane(
                              localizations: localizations,
                              results: results,
                              searchService: searchService,
                              appsService: appsService,
                              bridgeService: bridgeService,
                              contentPadding: contentPadding,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(
    AppLocalizations localizations,
    SearchService searchService,
    SystemBridgeService bridgeService, {
    required double contentPadding,
    required bool compactLayout,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        contentPadding,
        contentPadding,
        contentPadding,
        0,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                    _focusFilter(_selectedFilter),
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                    _voiceFocusNode.requestFocus(),
              },
              child: TextField(
                controller: _queryController,
                focusNode: _queryFocusNode,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: localizations.searchHint,
                  prefixIcon: const Icon(Icons.search_outlined),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide:
                        const BorderSide(color: Color(0xFF8CCBFF), width: 2),
                  ),
                ),
                style: Theme.of(context).textTheme.titleMedium,
                textInputAction: TextInputAction.search,
              ),
            ),
          ),
          SizedBox(width: compactLayout ? 10 : 14),
          _TopBarButton(
            focusNode: _voiceFocusNode,
            icon: Icons.mic_none_outlined,
            tooltip: localizations.testSpeechCaptureAction,
            onPressed: () => _triggerVoiceSearch(
              searchService: searchService,
              bridgeService: bridgeService,
            ),
            onLeft: _queryFocusNode.requestFocus,
            onRight: _closeFocusNode.requestFocus,
            onDown: () => _focusFilter(_selectedFilter),
            compactLayout: compactLayout,
          ),
          SizedBox(width: compactLayout ? 8 : 10),
          _TopBarButton(
            focusNode: _closeFocusNode,
            icon: Icons.close,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: _close,
            onLeft: _voiceFocusNode.requestFocus,
            onDown: () => _focusFilter(_selectedFilter),
            compactLayout: compactLayout,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(AppLocalizations localizations, bool hasResults) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List<Widget>.generate(_filters.length, (index) {
            final filter = _filters[index];
            return Padding(
              padding:
                  EdgeInsets.only(right: index == _filters.length - 1 ? 0 : 10),
              child: _SearchFilterChip(
                focusNode: _filterNodes[filter]!,
                label: _searchFilterLabel(localizations, filter),
                selected: _selectedFilter == filter,
                onPressed: () => _setFilter(filter),
                onLeft:
                    index > 0 ? () => _focusFilter(_filters[index - 1]) : null,
                onRight: index < _filters.length - 1
                    ? () => _focusFilter(_filters[index + 1])
                    : null,
                onUp: _queryFocusNode.requestFocus,
                onDown: hasResults ? () => _focusResult(0) : null,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildResultsPane({
    required AppLocalizations localizations,
    required List<SearchResultItem> results,
    required SearchService searchService,
    required AppsService appsService,
    required SystemBridgeService bridgeService,
    required double contentPadding,
  }) {
    if (results.isEmpty) {
      return Center(
        child: Text(
          localizations.noSearchResults,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.white70),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        contentPadding,
        0,
        contentPadding,
        contentPadding,
      ),
      child: ListView.separated(
        key: const Key('search_results_list'),
        padding: EdgeInsets.zero,
        itemCount: results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = results[index];
          return _SearchResultTile(
            key: ValueKey<String>('search_result_${item.id}'),
            focusNode: _resultNodes[index],
            item: item,
            onPressed: () => _selectResult(
              item: item,
              searchService: searchService,
              appsService: appsService,
              bridgeService: bridgeService,
            ),
            onUp: index == 0
                ? () => _focusFilter(_selectedFilter)
                : () => _focusResult(index - 1),
            onDown: index < results.length - 1
                ? () => _focusResult(index + 1)
                : null,
          );
        },
      ),
    );
  }

  Future<void> _refreshSources() async {
    if (_loadingSources) {
      return;
    }
    setState(() => _loadingSources = true);
    try {
      await context.read<SearchService>().refreshRemoteSources();
    } finally {
      if (mounted) {
        setState(() => _loadingSources = false);
      }
    }
  }

  void _handleQueryChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _setFilter(String filter) {
    if (_selectedFilter == filter) {
      return;
    }
    setState(() {
      _selectedFilter = filter;
    });
  }

  void _focusFilter(String filter) {
    _filterNodes[filter]?.requestFocus();
  }

  void _focusResult(int index) {
    if (index < 0 || index >= _resultNodes.length) {
      return;
    }
    _resultNodes[index].requestFocus();
  }

  void _syncResultNodes(int count) {
    if (_resultNodes.length == count) {
      return;
    }
    for (final node in _resultNodes) {
      node.dispose();
    }
    _resultNodes = List<FocusNode>.generate(
      count,
      (index) => FocusNode(debugLabel: 'search_result_$index'),
      growable: false,
    );
  }

  Future<void> _triggerVoiceSearch({
    required SearchService searchService,
    required SystemBridgeService bridgeService,
  }) async {
    if (searchService.defaultSearchMode !=
        SearchService.searchModeLocalOverlay) {
      final result = await bridgeService.testVoiceSearch();
      if (!mounted) {
        return;
      }
      final message = result['message']?.toString() ??
          AppLocalizations.of(context)!.actionCompleted;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final result = await searchService.startSpeechRecognizer();
    if (!mounted) {
      return;
    }
    final text = result['text']?.toString().trim() ?? '';
    final localizations = AppLocalizations.of(context)!;
    final message = text.isNotEmpty
        ? localizations.speechCapturedMessage(text)
        : (result['message']?.toString() ??
            localizations.speechCaptureNoTextMessage);
    if (text.isNotEmpty) {
      _queryController
        ..text = text
        ..selection = TextSelection.collapsed(offset: text.length);
      _setFilter('all');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (_resultNodes.isNotEmpty) {
          _focusResult(0);
        } else {
          _focusFilter('all');
        }
      });
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectResult({
    required SearchResultItem item,
    required SearchService searchService,
    required AppsService appsService,
    required SystemBridgeService bridgeService,
  }) async {
    await searchService.recordSelection(item, query: _queryController.text);

    switch (item.kind) {
      case SearchResultKind.app:
        final packageName = item.payload['packageName']?.toString() ?? '';
        final application = appsService.applications
            .where((app) => app.packageName == packageName)
            .firstOrNull;
        if (application == null) {
          return;
        }
        final canLaunch = await ensureAppLaunchAccess(context, application);
        if (!canLaunch || !mounted) {
          return;
        }
        _close();
        await appsService.launchApp(application);
        break;
      case SearchResultKind.settings:
        await _openSettingsRoute(item.payload['route']?.toString() ?? '');
        break;
      case SearchResultKind.input:
        final inputId = item.payload['inputId']?.toString() ?? '';
        if (inputId.isEmpty) {
          return;
        }
        _close();
        await searchService.launchTvInput(inputId);
        break;
      case SearchResultKind.media:
        final uri = item.payload['uri']?.toString() ?? '';
        if (uri.isEmpty) {
          return;
        }
        _close();
        await searchService.launchMediaUri(uri);
        break;
      case SearchResultKind.action:
        await _runAction(
          item.payload['action']?.toString() ?? '',
          appsService: appsService,
        );
        break;
    }
  }

  Future<void> _runAction(
    String action, {
    required AppsService appsService,
  }) async {
    switch (action) {
      case 'open_system_settings':
        _close();
        await appsService.openSettings();
        break;
      case 'start_ambient_mode':
        _close();
        await appsService.startAmbientMode();
        break;
      default:
        break;
    }
  }

  Future<void> _openSettingsRoute(String route) async {
    if (route.isEmpty) {
      return;
    }
    final localizations = AppLocalizations.of(context)!;
    final allowed = await ensureSecurityAccess(
      context,
      title: localizations.unlockSettingsTitle,
      description: localizations.unlockSettingsDescription,
    );
    if (!allowed || !mounted) {
      return;
    }

    _close();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      try {
        Navigator.of(widget.parentContext).pushNamed(route);
      } catch (_) {
        showDialog<void>(
          context: widget.parentContext,
          builder: (_) => SettingsPanel(initialRoute: route),
        );
      }
    });
  }

  List<SearchResultItem> _buildItems({
    required AppLocalizations localizations,
    required AppsService appsService,
    required SearchService searchService,
    required ProfileSecurityService? security,
  }) {
    final visibleApps = appsService.applications.where((app) {
      if (security == null) {
        return !app.hidden;
      }
      return security.isAppVisible(app);
    });

    return <SearchResultItem>[
      ...visibleApps.map(
        (app) => SearchResultItem(
          id: 'app:${app.packageName}',
          kind: SearchResultKind.app,
          title: app.name,
          subtitle: app.packageName,
          keywords: '${app.packageName} ${app.version}',
          locked: security?.isAppLocked(app) ?? false,
          payload: <String, dynamic>{
            'packageName': app.packageName,
          },
        ),
      ),
      ..._settingsItems(localizations),
      ...searchService.tvInputs
          .map((item) => _tvInputItem(localizations, item))
          .whereType<SearchResultItem>(),
      ...searchService.searchableMedia
          .map((item) => _mediaItem(item))
          .whereType<SearchResultItem>(),
      ..._actionItems(localizations),
    ];
  }

  List<SearchResultItem> _settingsItems(AppLocalizations localizations) {
    return <SearchResultItem>[
      _settingsItem(
        route: HomeLayoutPanelPage.routeName,
        title: localizations.settingsDestinationHomeTitle,
        subtitle: localizations.settingsDestinationHomeSubtitle,
      ),
      _settingsItem(
        route: WallpaperPanelPage.routeName,
        title: localizations.settingsDestinationWallpaperTitle,
        subtitle: localizations.settingsDestinationWallpaperSubtitle,
      ),
      _settingsItem(
        route: VoiceSearchPanelPage.routeName,
        title: localizations.settingsDestinationVoiceTitle,
        subtitle: localizations.settingsDestinationVoiceSubtitle,
      ),
      _settingsItem(
        route: ProfilesSecurityPanelPage.routeName,
        title: localizations.settingsDestinationProfilesTitle,
        subtitle: localizations.settingsDestinationProfilesSubtitle,
      ),
      _settingsItem(
        route: AccessibilityManagerPanelPage.routeName,
        title: localizations.settingsDestinationAccessibilityTitle,
        subtitle: localizations.settingsDestinationAccessibilitySubtitle,
      ),
      _settingsItem(
        route: SystemCorePanelPage.routeName,
        title: localizations.settingsDestinationSystemCoreTitle,
        subtitle: localizations.settingsDestinationSystemCoreSubtitle,
      ),
      _settingsItem(
        route: DensityPanelPage.routeName,
        title: localizations.settingsDestinationDensityTitle,
        subtitle: localizations.settingsDestinationDensitySubtitle,
      ),
      _settingsItem(
        route: PrivateDnsPanelPage.routeName,
        title: localizations.settingsDestinationPrivateDnsTitle,
        subtitle: localizations.settingsDestinationPrivateDnsSubtitle,
      ),
      _settingsItem(
        route: PermissionsPanelPage.routeName,
        title: localizations.settingsDestinationPermissionsTitle,
        subtitle: localizations.settingsDestinationPermissionsSubtitle,
      ),
      _settingsItem(
        route: BackupRestorePanelPage.routeName,
        title: localizations.settingsDestinationBackupTitle,
        subtitle: localizations.settingsDestinationBackupSubtitle,
      ),
      _settingsItem(
        route: DiagnosticsPanelPage.routeName,
        title: localizations.settingsDestinationDiagnosticsTitle,
        subtitle: localizations.settingsDestinationDiagnosticsSubtitle,
      ),
    ];
  }

  SearchResultItem _settingsItem({
    required String route,
    required String title,
    required String subtitle,
  }) {
    return SearchResultItem(
      id: 'settings:$route',
      kind: SearchResultKind.settings,
      title: title,
      subtitle: subtitle,
      keywords: '$title $subtitle',
      payload: <String, dynamic>{'route': route},
    );
  }

  SearchResultItem? _tvInputItem(
    AppLocalizations localizations,
    Map<String, dynamic> map,
  ) {
    final inputId = map['inputId']?.toString() ??
        map['id']?.toString() ??
        map['key']?.toString() ??
        '';
    if (inputId.isEmpty) {
      return null;
    }
    final title = map['label']?.toString() ??
        map['name']?.toString() ??
        localizations.genericInputLabel;
    final subtitle = map['description']?.toString() ??
        map['packageName']?.toString() ??
        localizations.genericInputLabel;
    final keywords = <String>[
      title,
      subtitle,
      map['type']?.toString() ?? '',
      map['inputId']?.toString() ?? '',
    ].join(' ');
    return SearchResultItem(
      id: 'input:$inputId',
      kind: SearchResultKind.input,
      title: title,
      subtitle: subtitle,
      keywords: keywords,
      payload: <String, dynamic>{'inputId': inputId},
    );
  }

  SearchResultItem? _mediaItem(Map<String, dynamic> map) {
    final uri = map['uri']?.toString() ?? '';
    if (uri.isEmpty) {
      return null;
    }
    final title = map['title']?.toString() ??
        map['displayName']?.toString() ??
        map['name']?.toString() ??
        map['fileName']?.toString() ??
        uri;
    final subtitle = map['bucketName']?.toString() ??
        map['relativePath']?.toString() ??
        map['mimeType']?.toString() ??
        '';
    final keywords = <String>[
      title,
      subtitle,
      map['uri']?.toString() ?? '',
      map['artist']?.toString() ?? '',
    ].join(' ');
    return SearchResultItem(
      id: 'media:$uri',
      kind: SearchResultKind.media,
      title: title,
      subtitle: subtitle,
      keywords: keywords,
      payload: <String, dynamic>{'uri': uri},
    );
  }

  List<SearchResultItem> _actionItems(AppLocalizations localizations) {
    return <SearchResultItem>[
      SearchResultItem(
        id: 'action:system_settings',
        kind: SearchResultKind.action,
        title: localizations.systemSettings,
        subtitle: localizations.actionOpenSystemSettingsSubtitle,
        keywords:
            '${localizations.systemSettings} ${localizations.actionOpenSystemSettingsSubtitle}',
        payload: const <String, dynamic>{'action': 'open_system_settings'},
      ),
      SearchResultItem(
        id: 'action:ambient_mode',
        kind: SearchResultKind.action,
        title: localizations.ambientModeAction,
        subtitle: localizations.actionStartAmbientModeSubtitle,
        keywords:
            '${localizations.ambientModeAction} ${localizations.actionStartAmbientModeSubtitle}',
        payload: const <String, dynamic>{'action': 'start_ambient_mode'},
      ),
    ];
  }

  String _searchFilterLabel(AppLocalizations localizations, String value) {
    switch (value) {
      case 'app':
        return localizations.searchFilterApps;
      case 'settings':
        return localizations.searchFilterSettings;
      case 'input':
        return localizations.searchFilterInputs;
      case 'media':
        return localizations.searchFilterMedia;
      case 'action':
        return localizations.searchFilterActions;
      default:
        return localizations.searchFilterAll;
    }
  }

  void _close() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

class _TopBarButton extends StatelessWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onDown;
  final bool compactLayout;

  const _TopBarButton({
    required this.focusNode,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.onLeft,
    this.onRight,
    this.onDown,
    this.compactLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        if (onLeft != null)
          const SingleActivator(LogicalKeyboardKey.arrowLeft): onLeft!,
        if (onRight != null)
          const SingleActivator(LogicalKeyboardKey.arrowRight): onRight!,
        if (onDown != null)
          const SingleActivator(LogicalKeyboardKey.arrowDown): onDown!,
      },
      child: SizedBox(
        width: compactLayout ? 56 : 64,
        height: compactLayout ? 56 : 64,
        child: IconButton(
          focusNode: focusNode,
          iconSize: compactLayout ? 24 : 28,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.06),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
          ),
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon),
        ),
      ),
    );
  }
}

class _SearchFilterChip extends StatelessWidget {
  final FocusNode focusNode;
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  const _SearchFilterChip({
    required this.focusNode,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.onLeft,
    this.onRight,
    this.onUp,
    this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        if (onLeft != null)
          const SingleActivator(LogicalKeyboardKey.arrowLeft): onLeft!,
        if (onRight != null)
          const SingleActivator(LogicalKeyboardKey.arrowRight): onRight!,
        if (onUp != null)
          const SingleActivator(LogicalKeyboardKey.arrowUp): onUp!,
        if (onDown != null)
          const SingleActivator(LogicalKeyboardKey.arrowDown): onDown!,
      },
      child: FocusableActionDetector(
        focusNode: focusNode,
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            final borderColor = focused
                ? const Color(0xFF8CCBFF)
                : (selected ? const Color(0xFF8CCBFF) : Colors.white24);
            final backgroundColor = selected
                ? const Color(0xFF214A73)
                : Colors.white.withOpacity(focused ? 0.10 : 0.05);
            return TextButton(
              focusNode: focusNode,
              onPressed: onPressed,
              style: TextButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: borderColor, width: focused ? 2 : 1),
                ),
              ),
              child: Text(label),
            );
          },
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final FocusNode focusNode;
  final SearchResultItem item;
  final VoidCallback onPressed;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  const _SearchResultTile({
    super.key,
    required this.focusNode,
    required this.item,
    required this.onPressed,
    this.onUp,
    this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        if (onUp != null)
          const SingleActivator(LogicalKeyboardKey.arrowUp): onUp!,
        if (onDown != null)
          const SingleActivator(LogicalKeyboardKey.arrowDown): onDown!,
      },
      child: FocusableActionDetector(
        focusNode: focusNode,
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(focused ? 0.12 : 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: focused
                      ? const Color(0xFF8CCBFF)
                      : Colors.white.withOpacity(0.06),
                  width: focused ? 2 : 1,
                ),
              ),
              child: ListTile(
                focusNode: focusNode,
                autofocus: false,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                onTap: onPressed,
                leading: Icon(_iconForKind(item.kind), size: 28),
                title: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: item.subtitle.trim().isEmpty
                    ? null
                    : Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: item.locked
                    ? const Icon(Icons.lock_outline, color: Colors.white70)
                    : const Icon(Icons.chevron_right, color: Colors.white70),
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _iconForKind(SearchResultKind kind) {
    switch (kind) {
      case SearchResultKind.app:
        return Icons.apps_outlined;
      case SearchResultKind.settings:
        return Icons.settings_outlined;
      case SearchResultKind.input:
        return Icons.input_outlined;
      case SearchResultKind.media:
        return Icons.video_library_outlined;
      case SearchResultKind.action:
        return Icons.bolt_outlined;
    }
  }
}
