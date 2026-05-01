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
import 'package:flauncher/home_performance_profile.dart';
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
import 'package:flauncher/widgets/home_reorder.dart';
import 'package:flauncher/widgets/launcher_alternative_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'models/category.dart';

typedef _WallpaperSnapshot = ({
  String wallpaperMode,
  ImageProvider<Object>? wallpaper,
  Gradient gradient,
  bool isVideoMode,
  int? videoTextureId,
  String videoFit,
  String videoBlur,
  int videoDimPercent,
});

typedef _WallpaperStatusSnapshot = ({
  bool videoReady,
  double videoWidth,
  double videoHeight,
});

typedef _HomeDockSettingsSnapshot = ({
  int dockRowsPreset,
  int collapsedRowsPreset,
  bool autoCollapseEnabled,
  int autoCollapseDelaySeconds,
  bool showCategoryTitles,
  int glassIntensityPercent,
  String performanceMode,
  double rowSpacing,
});

typedef _HomeSectionsSnapshot = ({
  bool initialized,
  List<LauncherSection> sections,
  String signature,
});

typedef _NavigationSnapshot = ({
  int homeSequence,
  String reason,
});

class FLauncher extends StatelessWidget {
  const FLauncher({super.key});

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
        policy: RowByRowTraversalPolicy(),
        child: Stack(
          children: [
            const _WallpaperLayer(),
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
                  child: const _HomeContent(),
                ),
              ),
            ),
          ],
        ),
      );
}

class _WallpaperLayer extends StatelessWidget {
  const _WallpaperLayer();

  @override
  Widget build(BuildContext context) {
    final performanceMode = context.select<SettingsService, String>(
      (service) => service.homeDockPerformanceMode,
    );
    final wallpaper = context.select<WallpaperService, _WallpaperSnapshot>(
      (service) => (
        wallpaperMode: service.wallpaperMode,
        wallpaper: service.wallpaper,
        gradient: service.gradient.gradient,
        isVideoMode: service.isVideoMode,
        videoTextureId: service.videoTextureId,
        videoFit: service.videoFit,
        videoBlur: service.videoBlur,
        videoDimPercent: service.videoDimPercent,
      ),
    );
    final wallpaperStatus =
        context.select<SystemBridgeService, _WallpaperStatusSnapshot>(
      (service) {
        final status = service.wallpaperStatus;
        return (
          videoReady: status['videoReady'] == true,
          videoWidth: ((status['videoWidth'] as num?) ?? 1920).toDouble(),
          videoHeight: ((status['videoHeight'] as num?) ?? 1080).toDouble(),
        );
      },
    );
    return _buildWallpaperLayer(
      context,
      wallpaper: wallpaper,
      wallpaperStatus: wallpaperStatus,
      performanceProfile: HomePerformanceProfile.resolve(performanceMode),
    );
  }
}

class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  String? _lastScheduledHomeUsableKey;
  String? _pendingHomeUsableKey;

  void _scheduleHomeUsableSignal(BuildContext context, String key) {
    if (_lastScheduledHomeUsableKey == key || _pendingHomeUsableKey == key) {
      return;
    }
    _pendingHomeUsableKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingHomeUsableKey != key) {
        return;
      }
      _pendingHomeUsableKey = null;
      _lastScheduledHomeUsableKey = key;
      context.read<WallpaperService>().notifyHomeVisibleAndUsable();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dockSettings =
        context.select<SettingsService, _HomeDockSettingsSnapshot>(
      (settingsService) => (
        dockRowsPreset: settingsService.homeDockRowsPreset,
        collapsedRowsPreset: settingsService.homeDockCollapsedRowsPreset,
        autoCollapseEnabled: settingsService.homeDockAutoCollapseEnabled,
        autoCollapseDelaySeconds:
            settingsService.homeDockAutoCollapseDelaySeconds,
        showCategoryTitles: settingsService.showCategoryTitles,
        glassIntensityPercent: settingsService.homeDockGlassIntensityPercent,
        performanceMode: settingsService.homeDockPerformanceMode,
        rowSpacing: settingsService.homeDockRowSpacing.toDouble(),
      ),
    );
    final videoWallpaperActive = context.select<WallpaperService, bool>(
      (service) => service.isVideoMode && service.videoTextureId != null,
    );
    final homeReorderModeEnabled = context.select<AppsService, bool>(
      (service) => service.homeReorderModeEnabled,
    );
    final navigation =
        context.select<SystemBridgeService, _NavigationSnapshot>((service) {
      final rawNavigation = service.status['navigation'];
      final map = rawNavigation is Map
          ? rawNavigation.cast<String, dynamic>()
          : const <String, dynamic>{};
      return (
        homeSequence: ((map['homeSequence'] as num?) ?? 0).toInt(),
        reason: map['reason']?.toString() ?? '',
      );
    });
    final launcherVisible = context.select<LauncherState, bool>(
      (state) => state.launcherVisible,
    );

    return Selector2<AppsService, ProfileSecurityService?,
        _HomeSectionsSnapshot>(
      selector: (_, appsService, security) {
        if (!appsService.initialized) {
          return const (
            initialized: false,
            sections: <LauncherSection>[],
            signature: 'loading',
          );
        }
        final sections = security == null
            ? appsService.launcherSections
            : security.filterLauncherSections(appsService.launcherSections);
        return (
          initialized: true,
          sections: sections,
          signature: _launcherSectionsSignature(sections),
        );
      },
      shouldRebuild: (previous, next) =>
          previous.initialized != next.initialized ||
          previous.signature != next.signature,
      builder: (context, homeSections, _) {
        if (!homeSections.initialized) {
          return const _HomeLoadingState();
        }

        if (launcherVisible) {
          _scheduleHomeUsableSignal(
            context,
            '${homeSections.signature}|${navigation.homeSequence}',
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) => _HomeDockViewport(
            sections: homeSections.sections,
            maxWidth: constraints.maxWidth,
            maxHeight: constraints.maxHeight,
            dockRowsPreset: dockSettings.dockRowsPreset,
            collapsedRowsPreset: dockSettings.collapsedRowsPreset,
            autoCollapseEnabled: dockSettings.autoCollapseEnabled,
            autoCollapseDelaySeconds: dockSettings.autoCollapseDelaySeconds,
            showCategoryTitles: dockSettings.showCategoryTitles,
            glassIntensityPercent: dockSettings.glassIntensityPercent,
            performanceMode: dockSettings.performanceMode,
            videoWallpaperActive: videoWallpaperActive,
            rowSpacing: dockSettings.rowSpacing,
            homeSequence: navigation.homeSequence,
            homeNavigationReason: navigation.reason,
            homeReorderModeEnabled: homeReorderModeEnabled,
          ),
        );
      },
    );
  }
}

String _launcherSectionsSignature(List<LauncherSection> sections) {
  final buffer = StringBuffer();
  for (final section in sections) {
    buffer.write(section.runtimeType);
    buffer.write(':');
    buffer.write(section.id);
    buffer.write(':');
    buffer.write(section.order);
    if (section is LauncherSpacer) {
      buffer.write(':');
      buffer.write(section.height);
    } else if (section is Category) {
      buffer.write(':');
      buffer.write(section.name);
      buffer.write(':');
      buffer.write(section.sort.name);
      buffer.write(':');
      buffer.write(section.type.name);
      buffer.write(':');
      buffer.write(section.columnsCount);
      buffer.write(':');
      buffer.write(section.rowHeight);
      buffer.write(':');
      for (final app in section.applications) {
        buffer.write(app.packageName);
        buffer.write('@');
        buffer.write(app.name);
        buffer.write('@');
        buffer.write(app.hidden ? 1 : 0);
        buffer.write(',');
      }
    }
    buffer.write('|');
  }
  return buffer.toString();
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
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

Widget _buildWallpaperLayer(
  BuildContext context, {
  required _WallpaperSnapshot wallpaper,
  required _WallpaperStatusSnapshot wallpaperStatus,
  required HomePerformanceProfile performanceProfile,
}) {
  final physicalSize = MediaQuery.sizeOf(context);
  final baseWallpaper =
      wallpaper.wallpaperMode != 'gradient' && wallpaper.wallpaper != null
          ? Image(
              image: wallpaper.wallpaper!,
              key: const Key('background'),
              fit: BoxFit.cover,
              height: physicalSize.height,
              width: physicalSize.width,
              filterQuality: performanceProfile.wallpaperFilterQuality,
              gaplessPlayback: true,
            )
          : Container(
              key: const Key('background'),
              decoration: BoxDecoration(gradient: wallpaper.gradient),
            );

  if (!wallpaper.isVideoMode || wallpaper.videoTextureId == null) {
    return RepaintBoundary(child: baseWallpaper);
  }

  final blurSigma = performanceProfile
      .capWallpaperVideoBlurSigma(_videoBlurSigma(wallpaper.videoBlur));
  final dimOpacity = wallpaper.videoDimPercent.clamp(0, 100).toDouble() / 100.0;

  Widget videoLayer = SizedBox.expand(
    child: FittedBox(
      fit: _videoBoxFit(wallpaper.videoFit),
      child: SizedBox(
        width: wallpaperStatus.videoWidth,
        height: wallpaperStatus.videoHeight,
        child: Texture(textureId: wallpaper.videoTextureId!),
      ),
    ),
  );

  if (blurSigma > 0) {
    videoLayer = ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: videoLayer,
    );
  }

  return RepaintBoundary(
    child: Stack(
      children: [
        baseWallpaper,
        if (wallpaperStatus.videoReady) Positioned.fill(child: videoLayer),
        if (wallpaperStatus.videoReady && dimOpacity > 0)
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withOpacity(dimOpacity)),
          ),
      ],
    ),
  );
}

BoxFit _videoBoxFit(String fit) {
  switch (fit) {
    case 'fit':
      return BoxFit.contain;
    case 'fill':
      return BoxFit.fill;
    default:
      return BoxFit.cover;
  }
}

double _videoBlurSigma(String blur) {
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
  final String performanceMode;
  final bool videoWallpaperActive;
  final double rowSpacing;
  final int homeSequence;
  final String homeNavigationReason;
  final bool homeReorderModeEnabled;

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
    required this.performanceMode,
    required this.videoWallpaperActive,
    required this.rowSpacing,
    required this.homeSequence,
    required this.homeNavigationReason,
    required this.homeReorderModeEnabled,
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
  bool _reorderModeActive = false;
  bool _pendingCenterAfterExpand = false;
  String? _activeSectionName;
  String? _lastFocusedRowSignature;
  BuildContext? _lastFocusedItemContext;

  HomePerformanceProfile get _performanceProfile =>
      HomePerformanceProfile.resolve(widget.performanceMode);

  @override
  void initState() {
    super.initState();
    _collapsed = widget.autoCollapseEnabled;
    _activeSectionName = _firstCategoryName(widget.sections);
  }

  @override
  void didUpdateWidget(covariant _HomeDockViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.homeSequence != oldWidget.homeSequence &&
        widget.homeSequence > 0 &&
        widget.homeNavigationReason == 'home_reentry') {
      _handleHomeReentry();
    }
    if (widget.homeReorderModeEnabled != oldWidget.homeReorderModeEnabled) {
      if (widget.homeReorderModeEnabled) {
        _enterHomeReorderArmedMode();
      } else {
        _exitHomeReorderArmedMode();
      }
    }
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

  void _handleHomeReentry() {
    if (widget.homeReorderModeEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.read<AppsService>().setHomeReorderModeEnabled(false);
      });
    }
    if (_isAlreadyAtHomeTop()) {
      return;
    }
    _collapseTimer?.cancel();
    if (mounted) {
      setState(() {
        _activeSectionName = _firstCategoryName(widget.sections);
        _lastFocusedRowSignature = null;
        _hasInteractedSinceEntry = !widget.autoCollapseEnabled;
        _collapsed = widget.autoCollapseEnabled;
      });
    }
    _resetDockToStart();
  }

  bool _isAlreadyAtHomeTop() {
    final nodes = _dockTraversalNodes();
    if (nodes.isEmpty) {
      return false;
    }
    final firstNode = nodes.first;
    final currentFocus = FocusManager.instance.primaryFocus;
    final atTop = !_dockScrollController.hasClients ||
        (_dockScrollController.offset -
                    _dockScrollController.position.minScrollExtent)
                .abs() <
            1;
    return atTop && identical(currentFocus, firstNode);
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
    final performanceProfile = _performanceProfile;
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
      performanceMode: widget.performanceMode,
      videoWallpaperActive: widget.videoWallpaperActive,
      child: KeyedSubtree(
        key: const Key('home_bottom_dock_scroll'),
        child: ListView(
          key: _dockListKey,
          controller: _dockScrollController,
          cacheExtent: metrics.rowStride *
              math.max(
                (_visibleRows + performanceProfile.dockCacheRowsAhead)
                    .toDouble(),
                performanceProfile.dockMinimumCacheRows.toDouble(),
              ),
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
                child: RepaintBoundary(
                  child: _DockSectionLabel(
                    title: _activeSectionName!,
                    glassIntensityPercent: widget.glassIntensityPercent,
                    performanceMode: widget.performanceMode,
                  ),
                ),
              ),
            Focus(
              focusNode: _dockFocusNode,
              canRequestFocus: false,
              onFocusChange: _handleDockFocusChange,
              onKeyEvent: _handleDockKeyEvent,
              child: AnimatedContainer(
                duration: performanceProfile.dockHeightAnimationDuration,
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
      final onReorder = (
        String categoryName,
        BuildContext itemContext,
        HomeAppReorderEventType eventType, {
        bool committed = false,
      }) =>
          _handleAppReorder(
            categoryName,
            itemContext,
            eventType,
            committed: committed,
          );

      final categoryWidget = switch (category.type) {
        CategoryType.row => CategoryRow(
            key: sectionKey,
            category: category,
            applications: category.applications,
            autofocusFirstItem: shouldAutofocus,
            rowSpacing: widget.rowSpacing,
            onApplicationFocused: onFocused,
            onApplicationReorder: onReorder,
          ),
        CategoryType.grid => AppsGrid(
            key: sectionKey,
            category: category,
            applications: category.applications,
            autofocusFirstItem: shouldAutofocus,
            rowSpacing: widget.rowSpacing,
            onApplicationFocused: onFocused,
            onApplicationReorder: onReorder,
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
    if (widget.autoCollapseEnabled &&
        _hasInteractedSinceEntry &&
        !widget.homeReorderModeEnabled &&
        !_reorderModeActive) {
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
    if (current == null) {
      return false;
    }
    final nodes = _dockTraversalNodes();
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
        _hasInteractedSinceEntry &&
        !widget.homeReorderModeEnabled &&
        !_reorderModeActive) {
      _scheduleCollapse();
    }
  }

  void _handleAppReorder(
    String categoryName,
    BuildContext itemContext,
    HomeAppReorderEventType eventType, {
    bool committed = false,
  }) {
    _lastFocusedItemContext = itemContext;
    switch (eventType) {
      case HomeAppReorderEventType.started:
        _beginDockReorderSession(categoryName, itemContext);
        break;
      case HomeAppReorderEventType.moved:
        _updateDockReorderPosition(categoryName, itemContext);
        break;
      case HomeAppReorderEventType.ended:
        _finishDockReorderSession(
          categoryName,
          itemContext,
          committed: committed,
        );
        break;
    }
  }

  void _expandForInteraction() {
    _collapseTimer?.cancel();
    final shouldExpand = widget.autoCollapseEnabled && _collapsed;

    if (!_hasInteractedSinceEntry || shouldExpand) {
      setState(() {
        _hasInteractedSinceEntry = true;
        _collapsed = false;
        if (shouldExpand) {
          _pendingCenterAfterExpand = true;
        }
      });
    } else {
      _hasInteractedSinceEntry = true;
    }

    if (widget.autoCollapseEnabled &&
        !widget.homeReorderModeEnabled &&
        !_reorderModeActive) {
      _scheduleCollapse();
    }
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    if (!widget.autoCollapseEnabled ||
        !_dockFocusNode.hasFocus ||
        widget.homeReorderModeEnabled ||
        _reorderModeActive) {
      return;
    }
    _collapseTimer = Timer(
      Duration(seconds: widget.autoCollapseDelaySeconds),
      _collapseDock,
    );
  }

  void _collapseDock() {
    if (!mounted ||
        !widget.autoCollapseEnabled ||
        !_dockFocusNode.hasFocus ||
        widget.homeReorderModeEnabled ||
        _reorderModeActive) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _collapsed) {
        return;
      }
      _centerLatestFocusedRow(animate: false);
      _pendingCenterAfterExpand = false;
    });
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

  void _beginDockReorderSession(
    String categoryName,
    BuildContext itemContext,
  ) {
    _collapseTimer?.cancel();
    final shouldExpand = widget.autoCollapseEnabled && _collapsed;
    final shouldUpdateSection = _activeSectionName != categoryName;
    if (mounted &&
        (!_reorderModeActive || shouldExpand || shouldUpdateSection)) {
      setState(() {
        _reorderModeActive = true;
        _hasInteractedSinceEntry = true;
        if (shouldExpand) {
          _collapsed = false;
          _pendingCenterAfterExpand = true;
        }
        _activeSectionName = categoryName;
      });
    } else {
      _reorderModeActive = true;
      _hasInteractedSinceEntry = true;
    }
    if (!shouldExpand) {
      _scheduleCenterForReorder(itemContext);
    }
  }

  void _updateDockReorderPosition(
    String categoryName,
    BuildContext itemContext,
  ) {
    if (_activeSectionName != categoryName && mounted) {
      setState(() {
        _activeSectionName = categoryName;
      });
    }
    _scheduleCenterForReorder(itemContext);
  }

  void _finishDockReorderSession(
    String categoryName,
    BuildContext itemContext, {
    required bool committed,
  }) {
    if (_activeSectionName != categoryName && mounted) {
      setState(() {
        _activeSectionName = categoryName;
        _reorderModeActive = false;
      });
    } else {
      _reorderModeActive = false;
    }
    _scheduleCenterForReorder(itemContext, animate: !committed);
    if (widget.autoCollapseEnabled &&
        _dockFocusNode.hasFocus &&
        _hasInteractedSinceEntry &&
        !widget.homeReorderModeEnabled) {
      _scheduleCollapse();
    }
  }

  void _enterHomeReorderArmedMode() {
    _collapseTimer?.cancel();
    final shouldExpand = widget.autoCollapseEnabled && _collapsed;
    final firstCategoryName = _firstCategoryName(widget.sections);
    if (mounted) {
      setState(() {
        _hasInteractedSinceEntry = true;
        _activeSectionName = firstCategoryName;
        _lastFocusedRowSignature = null;
        _lastFocusedItemContext = null;
        if (shouldExpand) {
          _collapsed = false;
          _pendingCenterAfterExpand = true;
        }
      });
    } else {
      _hasInteractedSinceEntry = true;
      _activeSectionName = firstCategoryName;
      _lastFocusedRowSignature = null;
      _lastFocusedItemContext = null;
      if (shouldExpand) {
        _collapsed = false;
        _pendingCenterAfterExpand = true;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _jumpDockToTop();
      _focusFirstDockItem();
      _centerLatestFocusedRow(animate: false);
    });
  }

  void _exitHomeReorderArmedMode() {
    if (widget.autoCollapseEnabled &&
        _dockFocusNode.hasFocus &&
        _hasInteractedSinceEntry &&
        !_reorderModeActive) {
      _scheduleCollapse();
    }
  }

  void _scheduleCenterForReorder(
    BuildContext itemContext, {
    bool animate = false,
  }) {
    if (_collapsed) {
      _jumpDockToTop();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastFocusedItemContext != itemContext || _collapsed) {
        return;
      }
      _centerFocusedItemInDock(itemContext, animate: animate);
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
      return;
    }
    if (_pendingCenterAfterExpand) {
      final nodes = _dockTraversalNodes();
      if (nodes.isNotEmpty) {
        final fallbackContext = nodes.first.context;
        if (fallbackContext != null &&
            _isDockDescendant(fallbackContext, dockContext)) {
          _centerFocusedItemInDock(fallbackContext, animate: animate);
        }
      }
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
    final scrollDelta = itemCenterY - viewportCenterY;
    final currentOffset = _dockScrollController.offset;
    final targetOffset = (currentOffset + scrollDelta).clamp(
      _dockScrollController.position.minScrollExtent,
      _dockScrollController.position.maxScrollExtent,
    );

    if ((targetOffset - currentOffset).abs() < 1.0) {
      return;
    }

    final targetDelta = (targetOffset - currentOffset).abs();
    if (!animate || targetDelta < _performanceProfile.dockScrollJumpThreshold) {
      _dockScrollController.jumpTo(targetOffset);
      return;
    }

    if (animate) {
      _dockScrollController.animateTo(
        targetOffset,
        duration: _performanceProfile.dockScrollDuration(
            targetDelta, viewport.size.height),
        curve: Curves.easeOutCubic,
      );
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
    final nodes = _dockTraversalNodes();
    if (nodes.isEmpty) {
      return;
    }
    nodes.first.requestFocus();
  }

  List<FocusNode> _dockTraversalNodes() {
    return _dockFocusNode.traversalDescendants
        .where(
          (node) =>
              node.context != null &&
              node.canRequestFocus &&
              !node.skipTraversal,
        )
        .toList(growable: false);
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
  final String performanceMode;

  const _DockSectionLabel({
    required this.title,
    required this.glassIntensityPercent,
    required this.performanceMode,
  });

  @override
  Widget build(BuildContext context) {
    final performanceProfile = HomePerformanceProfile.resolve(performanceMode);
    final intensity = glassIntensityPercent.clamp(0, 100).toDouble() / 100.0;
    final blurSigma = lerpDouble(
          0,
          math.min(performanceProfile.dockStaticMaxBlurSigma, 10),
          intensity,
        ) ??
        0;
    final fillOpacity = lerpDouble(0.08, 0.44, intensity) ?? 0.08;
    final borderOpacity = lerpDouble(0.10, 0.22, intensity) ?? 0.10;
    final shadowOpacity = lerpDouble(0.06, 0.18, intensity) ?? 0.06;
    final useBackdropBlur = performanceProfile.dockBackdropBlurEnabled &&
        intensity >= 0.16 &&
        blurSigma > 0;

    final surface = DecoratedBox(
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
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: useBackdropBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: surface,
            )
          : surface,
    );
  }
}

class _BottomDockShell extends StatelessWidget {
  final double height;
  final int glassIntensityPercent;
  final String performanceMode;
  final bool videoWallpaperActive;
  final Widget child;

  const _BottomDockShell({
    required this.height,
    required this.glassIntensityPercent,
    required this.performanceMode,
    required this.videoWallpaperActive,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final profile = HomePerformanceProfile.resolve(performanceMode);
    final intensity = glassIntensityPercent.clamp(0, 100).toDouble() / 100.0;
    final maxBlurSigma = videoWallpaperActive
        ? profile.dockVideoMaxBlurSigma
        : profile.dockStaticMaxBlurSigma;
    final blurSigma = lerpDouble(0, maxBlurSigma, intensity) ?? 0;
    final borderOpacity = lerpDouble(0.10, 0.16, intensity) ?? 0.10;
    final shadowOpacity = videoWallpaperActive
        ? (lerpDouble(0.08, profile.dockVideoShadowOpacity, intensity) ?? 0.08)
        : (lerpDouble(0.10, profile.dockStaticShadowOpacity, intensity) ??
            0.10);
    final shadowBlurRadius = videoWallpaperActive
        ? profile.dockVideoShadowBlurRadius
        : profile.dockStaticShadowBlurRadius;
    final useBackdropBlur = profile.dockBackdropBlurEnabled &&
        (!videoWallpaperActive || profile.dockVideoBackdropBlurEnabled) &&
        intensity >= 0.14 &&
        blurSigma > 0;
    final fakeGlassBoost =
        videoWallpaperActive ? profile.dockVideoFakeGlassBoost : 1.0;
    final backgroundColors = <Color>[
      _scaledOpacity(const Color(0x6E132238), intensity * fakeGlassBoost),
      _scaledOpacity(const Color(0x8A14253B), intensity * fakeGlassBoost),
      _scaledOpacity(const Color(0xA316263B), intensity * fakeGlassBoost),
    ];

    return RepaintBoundary(
      child: Container(
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
              blurRadius: shadowBlurRadius,
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
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.012 * intensity),
                  ),
                ),
              ),
              Positioned.fill(
                child: !useBackdropBlur
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
              if (intensity > 0)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(
                              (0.16 * intensity * fakeGlassBoost)
                                  .clamp(0.0, 0.22)),
                          Colors.white.withOpacity(
                              (0.03 * intensity * fakeGlassBoost)
                                  .clamp(0.0, 0.06)),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.22, 0.72],
                      ),
                    ),
                  ),
                ),
              if (intensity > 0.32)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.4,
                        colors: [
                          Colors.white.withOpacity(
                              (0.15 * intensity * fakeGlassBoost)
                                  .clamp(0.0, 0.2)),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              RepaintBoundary(child: child),
            ],
          ),
        ),
      ),
    );
  }

  static Color _scaledOpacity(Color color, double factor) {
    return color.withOpacity((color.opacity * factor).clamp(0.0, 1.0));
  }
}
