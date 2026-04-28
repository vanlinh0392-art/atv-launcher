/*
 * FLauncher
 * Copyright (C) 2021  Etienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flauncher/custom_traversal_policy.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/apps_grid.dart';
import 'package:flauncher/widgets/category_row.dart';
import 'package:flauncher/widgets/focus_aware_app_bar.dart';
import 'package:flauncher/widgets/home_card_metrics.dart';
import 'package:flauncher/widgets/launcher_alternative_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'models/category.dart';

const Duration _dockHeightAnimationDuration = Duration(milliseconds: 320);

class FLauncher extends StatelessWidget {
  const FLauncher({super.key});

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
        policy: RowByRowTraversalPolicy(),
        child: Stack(
          children: [
            Consumer2<WallpaperService, SystemBridgeService>(
              builder: (_, wallpaperService, systemBridgeService, __) =>
                  _wallpaper(context, wallpaperService, systemBridgeService),
            ),
            Consumer<LauncherState>(
              builder: (_, state, child) => Visibility(
                visible: state.launcherVisible,
                replacement: const Center(child: AlternativeLauncherView()),
                child: child!,
              ),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: FocusAwareAppBar(),
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Consumer3<AppsService, SettingsService,
                      ProfileSecurityService?>(
                    builder:
                        (context, appsService, settingsService, security, _) {
                      if (!appsService.initialized) {
                        return _emptyState(context);
                      }

                      final sections = security == null
                          ? appsService.launcherSections
                          : security.filterLauncherSections(
                              appsService.launcherSections,
                            );

                      return LayoutBuilder(
                        builder: (context, constraints) => _HomeDockViewport(
                          sections: sections,
                          maxWidth: constraints.maxWidth,
                          maxHeight: constraints.maxHeight,
                          dockRowsPreset: settingsService.homeDockRowsPreset,
                          collapsedRowsPreset:
                              settingsService.homeDockCollapsedRowsPreset,
                          autoCollapseEnabled:
                              settingsService.homeDockAutoCollapseEnabled,
                          autoCollapseDelaySeconds:
                              settingsService.homeDockAutoCollapseDelaySeconds,
                          showCategoryTitles:
                              settingsService.showCategoryTitles,
                          glassIntensityPercent:
                              settingsService.homeDockGlassIntensityPercent,
                          rowSpacing:
                              settingsService.homeDockRowSpacing.toDouble(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _wallpaper(
    BuildContext context,
    WallpaperService wallpaperService,
    SystemBridgeService systemBridgeService,
  ) {
    final physicalSize = MediaQuery.sizeOf(context);
    final baseWallpaper = wallpaperService.wallpaperMode != 'gradient' &&
            wallpaperService.wallpaper != null
        ? Image(
            image: wallpaperService.wallpaper!,
            key: const Key('background'),
            fit: BoxFit.cover,
            height: physicalSize.height,
            width: physicalSize.width,
          )
        : Container(
            key: const Key('background'),
            decoration:
                BoxDecoration(gradient: wallpaperService.gradient.gradient),
          );

    if (!wallpaperService.isVideoMode ||
        wallpaperService.videoTextureId == null) {
      return baseWallpaper;
    }

    final wallpaperStatus = systemBridgeService.wallpaperStatus;
    final videoReady = wallpaperStatus['videoReady'] == true;
    final videoWidth =
        ((wallpaperStatus['videoWidth'] as num?) ?? 1920).toDouble();
    final videoHeight =
        ((wallpaperStatus['videoHeight'] as num?) ?? 1080).toDouble();
    final blurSigma = _blurSigma(wallpaperService.videoBlur);
    final dimOpacity =
        wallpaperService.videoDimPercent.clamp(0, 100).toDouble() / 100.0;

    Widget videoLayer = SizedBox.expand(
      child: FittedBox(
        fit: _videoFit(wallpaperService.videoFit),
        child: SizedBox(
          width: videoWidth,
          height: videoHeight,
          child: Texture(textureId: wallpaperService.videoTextureId!),
        ),
      ),
    );

    if (blurSigma > 0) {
      videoLayer = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: videoLayer,
      );
    }

    return Stack(
      children: [
        baseWallpaper,
        if (videoReady) Positioned.fill(child: videoLayer),
        if (videoReady && dimOpacity > 0)
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withOpacity(dimOpacity)),
          ),
      ],
    );
  }

  BoxFit _videoFit(String fit) {
    switch (fit) {
      case 'fit':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      default:
        return BoxFit.cover;
    }
  }

  double _blurSigma(String blur) {
    switch (blur) {
      case 'low':
        return 2;
      case 'medium':
        return 5;
      case 'high':
        return 9;
      default:
        return 0;
    }
  }

  Widget _emptyState(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            localizations.loading,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}

class _HomeDockViewport extends StatefulWidget {
  final List<LauncherSection> sections;
  final double maxWidth;
  final double maxHeight;
  final int dockRowsPreset;
  final int collapsedRowsPreset;
  final bool autoCollapseEnabled;
  final int autoCollapseDelaySeconds;
  final bool showCategoryTitles;
  final int glassIntensityPercent;
  final double rowSpacing;

  const _HomeDockViewport({
    required this.sections,
    required this.maxWidth,
    required this.maxHeight,
    required this.dockRowsPreset,
    required this.collapsedRowsPreset,
    required this.autoCollapseEnabled,
    required this.autoCollapseDelaySeconds,
    required this.showCategoryTitles,
    required this.glassIntensityPercent,
    required this.rowSpacing,
  });

  @override
  State<_HomeDockViewport> createState() => _HomeDockViewportState();
}

class _HomeDockViewportState extends State<_HomeDockViewport> {
  final FocusNode _dockFocusNode = FocusNode(debugLabel: 'home_dock_scope');
  final GlobalKey _dockListKey = GlobalKey(debugLabel: 'home_dock_list');
  final ScrollController _dockScrollController = ScrollController();
  Timer? _collapseTimer;
  bool _collapsed = false;
  bool _hasInteractedSinceEntry = false;
  String? _activeSectionName;
  String? _lastFocusedRowSignature;
  BuildContext? _lastFocusedItemContext;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.autoCollapseEnabled;
    _activeSectionName = _firstCategoryName(widget.sections);
  }

  @override
  void didUpdateWidget(covariant _HomeDockViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextTitle = _activeSectionName;
    if (nextTitle == null || !_hasCategoryNamed(widget.sections, nextTitle)) {
      _activeSectionName = _firstCategoryName(widget.sections);
    }

    if (!widget.autoCollapseEnabled && _collapsed) {
      _collapseTimer?.cancel();
      _collapsed = false;
      _hasInteractedSinceEntry = true;
    } else if (widget.autoCollapseEnabled && !oldWidget.autoCollapseEnabled) {
      _collapsed = true;
      _hasInteractedSinceEntry = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_collapsed) {
          return;
        }
        _resetDockToStart();
      });
    }
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _dockScrollController.dispose();
    _dockFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = resolveHomeCardMetricsForSections(
      widget.sections,
      widget.maxWidth,
      preferredCategoryName: _activeSectionName,
      rowSpacing: widget.rowSpacing,
    );
    final dockHeight = metrics.dockHeightForRows(
      rows: _visibleRows,
      maxHeight: widget.maxHeight,
      rowSpacing: widget.rowSpacing,
    );
    final dockChild = _BottomDockShell(
      height: dockHeight,
      glassIntensityPercent: widget.glassIntensityPercent,
      child: KeyedSubtree(
        key: const Key('home_bottom_dock_scroll'),
        child: ListView(
          key: _dockListKey,
          controller: _dockScrollController,
          cacheExtent: metrics.rowStride * math.max(_visibleRows + 2, 4),
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            0,
            homeDockScrollTopPadding,
            0,
            homeDockScrollBottomPadding,
          ),
          children: _sectionChildren(),
        ),
      ),
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: Transform.translate(
        offset: const Offset(0, homeDockVerticalOffset),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (widget.showCategoryTitles &&
                _activeSectionName != null &&
                _activeSectionName!.trim().isNotEmpty)
              Positioned(
                left: 22,
                top: -34,
                child: _DockSectionLabel(
                  title: _activeSectionName!,
                  glassIntensityPercent: widget.glassIntensityPercent,
                ),
              ),
            Focus(
              focusNode: _dockFocusNode,
              canRequestFocus: false,
              onFocusChange: _handleDockFocusChange,
              onKeyEvent: _handleDockKeyEvent,
              child: AnimatedContainer(
                duration: _dockHeightAnimationDuration,
                curve: Curves.easeInOutCubic,
                onEnd: _handleDockHeightAnimationEnd,
                height: dockHeight,
                child: dockChild,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _visibleRows {
    if (widget.autoCollapseEnabled && _collapsed) {
      return widget.collapsedRowsPreset.clamp(1, widget.dockRowsPreset);
    }
    return widget.dockRowsPreset.clamp(2, 4);
  }

  List<Widget> _sectionChildren() {
    final children = <Widget>[];
    var autofocusAssigned = false;
    var insertedCategory = false;

    for (final section in widget.sections) {
      final sectionKey = Key(section.id.toString());

      if (section is LauncherSpacer) {
        children.add(
          SizedBox(key: sectionKey, height: section.height.toDouble()),
        );
        continue;
      }

      final category = section as Category;
      final shouldAutofocus = !autofocusAssigned;
      final onFocused = (
        String categoryName,
        BuildContext itemContext,
        int rowIndex,
      ) =>
          _handleAppFocused(categoryName, itemContext, rowIndex);

      final categoryWidget = switch (category.type) {
        CategoryType.row => CategoryRow(
            key: sectionKey,
            category: category,
            applications: category.applications,
            autofocusFirstItem: shouldAutofocus,
            rowSpacing: widget.rowSpacing,
            onApplicationFocused: onFocused,
          ),
        CategoryType.grid => AppsGrid(
            key: sectionKey,
            category: category,
            applications: category.applications,
            autofocusFirstItem: shouldAutofocus,
            rowSpacing: widget.rowSpacing,
            onApplicationFocused: onFocused,
          ),
      };

      autofocusAssigned = true;
      if (insertedCategory) {
        children.add(const SizedBox(height: homeCategorySectionGap));
      }
      children.add(categoryWidget);
      insertedCategory = true;
    }

    return children;
  }

  void _handleDockFocusChange(bool hasFocus) {
    if (!hasFocus) {
      _collapseTimer?.cancel();
      return;
    }
    if (widget.autoCollapseEnabled && _hasInteractedSinceEntry) {
      _scheduleCollapse();
    }
  }

  KeyEventResult _handleDockKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final direction = _traversalDirectionForKey(event.logicalKey);
    if (direction != null &&
        (direction == TraversalDirection.up ||
            direction == TraversalDirection.down)) {
      _expandForInteraction();
      if (_moveFocusWithinDock(direction)) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (widget.autoCollapseEnabled && _collapsed && direction != null) {
      _expandForInteraction();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        FocusManager.instance.primaryFocus?.focusInDirection(direction);
      });
      return KeyEventResult.handled;
    }
    if (_isDockInteractionKey(event.logicalKey)) {
      _expandForInteraction();
    }
    return KeyEventResult.ignored;
  }

  bool _isDockInteractionKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  TraversalDirection? _traversalDirectionForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) {
      return TraversalDirection.up;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return TraversalDirection.down;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      return TraversalDirection.left;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return TraversalDirection.right;
    }
    return null;
  }

  bool _moveFocusWithinDock(TraversalDirection direction) {
    final current = FocusManager.instance.primaryFocus;
    final dockContext = _dockListKey.currentContext;
    if (current == null || dockContext == null) {
      return false;
    }
    final nodes = FocusManager.instance.rootScope.traversalDescendants
        .where((node) => _isDockDescendant(node.context, dockContext))
        .toList(growable: false);
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

  bool _isDockDescendant(BuildContext? candidate, BuildContext dockContext) {
    if (candidate == null) {
      return false;
    }
    if (candidate == dockContext) {
      return true;
    }
    var isDescendant = false;
    candidate.visitAncestorElements((element) {
      if (element == dockContext) {
        isDescendant = true;
        return false;
      }
      return true;
    });
    return isDescendant;
  }

  void _handleAppFocused(
    String categoryName,
    BuildContext itemContext,
    int rowIndex,
  ) {
    final rowSignature = '$categoryName::$rowIndex';
    final rowChanged = rowSignature != _lastFocusedRowSignature;
    _lastFocusedRowSignature = rowSignature;
    _lastFocusedItemContext = itemContext;
    if (_activeSectionName != categoryName && mounted) {
      setState(() {
        _activeSectionName = categoryName;
      });
    }
    if (rowChanged) {
      _scheduleCenterFocusedRow(itemContext);
    }
    if (widget.autoCollapseEnabled &&
        _dockFocusNode.hasFocus &&
        _hasInteractedSinceEntry) {
      _scheduleCollapse();
    }
  }

  void _expandForInteraction() {
    _collapseTimer?.cancel();
    final shouldExpand = widget.autoCollapseEnabled && _collapsed;

    if (!_hasInteractedSinceEntry || shouldExpand) {
      setState(() {
        _hasInteractedSinceEntry = true;
        _collapsed = false;
      });
    } else {
      _hasInteractedSinceEntry = true;
    }

    if (widget.autoCollapseEnabled) {
      _scheduleCollapse();
    }
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    if (!widget.autoCollapseEnabled || !_dockFocusNode.hasFocus) {
      return;
    }
    _collapseTimer = Timer(
      Duration(seconds: widget.autoCollapseDelaySeconds),
      _collapseDock,
    );
  }

  void _collapseDock() {
    if (!mounted || !widget.autoCollapseEnabled || !_dockFocusNode.hasFocus) {
      return;
    }
    if (_collapsed) {
      return;
    }
    setState(() {
      _collapsed = true;
      _activeSectionName = _firstCategoryName(widget.sections);
      _lastFocusedRowSignature = null;
    });
    _resetDockToStart();
  }

  void _handleDockHeightAnimationEnd() {
    if (_collapsed) {
      _jumpDockToTop();
      return;
    }
    _centerLatestFocusedRow(animate: false);
  }

  void _scheduleCenterFocusedRow(BuildContext itemContext) {
    if (_collapsed) {
      _jumpDockToTop();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastFocusedItemContext != itemContext) {
        return;
      }
      _centerFocusedItemInDock(itemContext);
    });
  }

  void _centerLatestFocusedRow({required bool animate}) {
    if (_collapsed) {
      _jumpDockToTop();
      return;
    }
    final dockContext = _dockListKey.currentContext;
    if (dockContext == null) {
      return;
    }
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext != null &&
        _isDockDescendant(focusedContext, dockContext)) {
      _centerFocusedItemInDock(focusedContext, animate: animate);
      return;
    }
    final lastFocusedItemContext = _lastFocusedItemContext;
    if (lastFocusedItemContext != null &&
        _isDockDescendant(lastFocusedItemContext, dockContext)) {
      _centerFocusedItemInDock(lastFocusedItemContext, animate: animate);
    }
  }

  void _centerFocusedItemInDock(
    BuildContext itemContext, {
    bool animate = true,
  }) {
    final dockContext = _dockListKey.currentContext;
    if (dockContext == null ||
        !_dockScrollController.hasClients ||
        !_isDockDescendant(itemContext, dockContext)) {
      return;
    }
    final viewport = dockContext.findRenderObject();
    final item = itemContext.findRenderObject();
    if (viewport is! RenderBox ||
        item is! RenderBox ||
        !viewport.attached ||
        !item.attached) {
      return;
    }

    final itemTopLeft = item.localToGlobal(Offset.zero, ancestor: viewport);
    final itemCenterY = itemTopLeft.dy + (item.size.height / 2);
    final viewportCenterY = viewport.size.height / 2;
    final delta = itemCenterY - viewportCenterY;
    final currentOffset = _dockScrollController.offset;
    final targetOffset = (currentOffset + delta).clamp(
      _dockScrollController.position.minScrollExtent,
      _dockScrollController.position.maxScrollExtent,
    );

    if ((targetOffset - currentOffset).abs() < 1.0) {
      return;
    }

    if (animate) {
      _dockScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      );
    } else {
      _dockScrollController.jumpTo(targetOffset);
    }
  }

  void _resetDockToStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _jumpDockToTop();
      _focusFirstDockItem();
    });
  }

  void _jumpDockToTop() {
    if (!_dockScrollController.hasClients) {
      return;
    }
    final minScrollExtent = _dockScrollController.position.minScrollExtent;
    if ((_dockScrollController.offset - minScrollExtent).abs() < 1) {
      return;
    }
    _dockScrollController.jumpTo(minScrollExtent);
  }

  void _focusFirstDockItem() {
    final dockContext = _dockListKey.currentContext;
    if (dockContext == null) {
      return;
    }
    final nodes = FocusManager.instance.rootScope.traversalDescendants
        .where((node) => _isDockDescendant(node.context, dockContext))
        .toList(growable: false);
    if (nodes.isEmpty) {
      return;
    }
    nodes.first.requestFocus();
  }
}

String? _firstCategoryName(List<LauncherSection> sections) {
  for (final section in sections) {
    if (section is Category) {
      return section.name;
    }
  }
  return null;
}

bool _hasCategoryNamed(List<LauncherSection> sections, String name) {
  return sections.whereType<Category>().any((section) => section.name == name);
}

class _DockSectionLabel extends StatelessWidget {
  final String title;
  final int glassIntensityPercent;

  const _DockSectionLabel({
    required this.title,
    required this.glassIntensityPercent,
  });

  @override
  Widget build(BuildContext context) {
    final intensity = glassIntensityPercent.clamp(0, 100).toDouble() / 100.0;
    final blurSigma = lerpDouble(0, 10, intensity) ?? 0;
    final fillOpacity = lerpDouble(0.08, 0.44, intensity) ?? 0.08;
    final borderOpacity = lerpDouble(0.10, 0.22, intensity) ?? 0.10;
    final shadowOpacity = lerpDouble(0.06, 0.18, intensity) ?? 0.06;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF14253B).withOpacity(fillOpacity),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(borderOpacity),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(shadowOpacity),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(0, 1),
                    blurRadius: 6,
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

class _BottomDockShell extends StatelessWidget {
  final double height;
  final int glassIntensityPercent;
  final Widget child;

  const _BottomDockShell({
    required this.height,
    required this.glassIntensityPercent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final intensity = glassIntensityPercent.clamp(0, 100).toDouble() / 100.0;
    final blurSigma = lerpDouble(0, 20, intensity) ?? 0;
    final borderOpacity = lerpDouble(0.10, 0.16, intensity) ?? 0.10;
    final shadowOpacity = lerpDouble(0.14, 0.27, intensity) ?? 0.14;
    final backgroundColors = <Color>[
      _scaledOpacity(const Color(0x6E132238), intensity),
      _scaledOpacity(const Color(0x8A14253B), intensity),
      _scaledOpacity(const Color(0xA316263B), intensity),
    ];

    return Container(
      key: const Key('home_bottom_dock'),
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(38)),
        border: Border.all(color: Colors.white.withOpacity(borderOpacity)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: backgroundColors,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withOpacity(shadowOpacity * intensity),
            blurRadius: 34,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(38)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: intensity <= 0
                  ? const SizedBox.shrink()
                  : BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: blurSigma,
                        sigmaY: blurSigma,
                      ),
                      child: ColoredBox(
                        color: Colors.white.withOpacity(0.025 * intensity),
                      ),
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.012 * intensity),
                ),
              ),
            ),
            if (intensity > 0)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.16 * intensity),
                        Colors.white.withOpacity(0.03 * intensity),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.22, 0.72],
                    ),
                  ),
                ),
              ),
            if (intensity > 0.1)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.4,
                      colors: [
                        Colors.white.withOpacity(0.15 * intensity),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }

  static Color _scaledOpacity(Color color, double factor) {
    return color.withOpacity((color.opacity * factor).clamp(0.0, 1.0));
  }
}
