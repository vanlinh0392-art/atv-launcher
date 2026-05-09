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
import 'dart:collection';
import 'dart:math' as math;
import 'package:flauncher/app_card_highlight_palette.dart';
import 'package:flauncher/app_image_cache_invalidator.dart';
import 'package:flauncher/app_image_type.dart';
import 'package:flauncher/home_performance_profile.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/application_info_panel.dart';
import 'package:flauncher/widgets/focus_keyboard_listener.dart';
import 'package:flauncher/widgets/pin_pad_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

import '../models/app.dart';
import '../models/category.dart';

const _validationKeys = [
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.gameButtonA,
];

typedef AppCardFocusCallback = void Function(BuildContext itemContext);
typedef AppCardMoveStartCallback = bool Function(BuildContext itemContext);
typedef AppCardMoveCallback = bool Function(
  BuildContext itemContext,
  AxisDirection direction,
);
typedef AppCardMoveEndCallback = Future<void> Function(
  BuildContext itemContext,
  bool committed,
);
typedef AppCardNavigateCallback = bool Function(AxisDirection direction);

class AppCard extends StatefulWidget {
  static const int _maxImageCacheSize = 24;
  static const int _maxConcurrentImageLoads = 2;
  static const Duration _deferredImageLoadDelay = Duration(milliseconds: 900);
  static final LinkedHashMap<String, Tuple2<AppImageType, ImageProvider>>
      _resolvedImageCache =
      LinkedHashMap<String, Tuple2<AppImageType, ImageProvider>>();
  static final LinkedHashMap<String,
          Future<Tuple2<AppImageType, ImageProvider>>> _imageLoadCache =
      LinkedHashMap<String, Future<Tuple2<AppImageType, ImageProvider>>>();
  static final Queue<_QueuedAppImageLoad> _pendingImageLoads =
      Queue<_QueuedAppImageLoad>();
  static final LinkedHashMap<Object, VoidCallback> _deferredImageLoadCallbacks =
      LinkedHashMap<Object, VoidCallback>();
  static final Map<String, FocusNode> _focusNodesById = <String, FocusNode>{};
  static Timer? _deferredImageLoadBatchTimer;
  static int _activeImageLoads = 0;

  final App application;
  final Category category;
  final bool autofocus;
  final bool eagerImageLoad;
  final String? focusId;
  final AppCardFocusCallback? onFocused;
  final AppCardMoveStartCallback? onMoveStart;
  final AppCardMoveCallback onMove;
  final AppCardMoveEndCallback onMoveEnd;
  final AppCardNavigateCallback? onNavigate;

  const AppCard({
    super.key,
    required this.application,
    required this.category,
    required this.autofocus,
    this.eagerImageLoad = false,
    this.focusId,
    this.onFocused,
    this.onMoveStart,
    required this.onMove,
    required this.onMoveEnd,
    this.onNavigate,
  });

  @override
  State<AppCard> createState() => _AppCardState();

  static Tuple2<AppImageType, ImageProvider>? _getCachedImage(
      String packageName) {
    final image = _resolvedImageCache.remove(packageName);
    if (image != null) {
      _resolvedImageCache[packageName] = image;
    }
    return image;
  }

  static bool _hasCachedImage(String packageName) =>
      _resolvedImageCache.containsKey(packageName);

  static bool _hasPendingImageLoad(String packageName) =>
      _imageLoadCache.containsKey(packageName);

  static Future<Tuple2<AppImageType, ImageProvider>> _putImageLoadFuture(
    String packageName,
    Future<Tuple2<AppImageType, ImageProvider>> Function() loader, {
    bool priority = false,
  }) {
    final cachedFuture = _imageLoadCache.remove(packageName);
    if (cachedFuture != null) {
      _imageLoadCache[packageName] = cachedFuture;
      if (priority) {
        _promotePendingImageLoad(packageName);
      }
      return cachedFuture;
    }

    final completer = Completer<Tuple2<AppImageType, ImageProvider>>();
    late final Future<Tuple2<AppImageType, ImageProvider>> trackedFuture;
    trackedFuture = completer.future.then((image) {
      _rememberImage(packageName, image);
      return image;
    }).whenComplete(() {
      if (identical(_imageLoadCache[packageName], trackedFuture)) {
        _imageLoadCache.remove(packageName);
      }
    });
    _imageLoadCache[packageName] = trackedFuture;
    final request = _QueuedAppImageLoad(
      packageName: packageName,
      loader: loader,
      completer: completer,
    );
    if (priority) {
      _pendingImageLoads.addFirst(request);
    } else {
      _pendingImageLoads.addLast(request);
    }
    _drainPendingImageLoads();
    return trackedFuture;
  }

  static void _rememberImage(
    String packageName,
    Tuple2<AppImageType, ImageProvider> image,
  ) {
    _resolvedImageCache.remove(packageName);
    _resolvedImageCache[packageName] = image;
    _trimImageCaches();
  }

  static void _evictImage(String packageName) {
    _resolvedImageCache.remove(packageName);
    _imageLoadCache.remove(packageName);
    _QueuedAppImageLoad? pendingRequest;
    for (final request in _pendingImageLoads) {
      if (request.packageName == packageName) {
        pendingRequest = request;
        break;
      }
    }
    if (pendingRequest != null) {
      _pendingImageLoads.remove(pendingRequest);
    }
  }

  static void _clearImageCaches() {
    _resolvedImageCache.clear();
    _imageLoadCache.clear();
    _pendingImageLoads.clear();
    _deferredImageLoadCallbacks.clear();
    _deferredImageLoadBatchTimer?.cancel();
    _deferredImageLoadBatchTimer = null;
  }

  static bool requestFocusForId(String focusId) {
    final node = _focusNodesById[focusId];
    if (node == null ||
        node.context == null ||
        !node.canRequestFocus ||
        node.skipTraversal) {
      return false;
    }
    node.requestFocus();
    return true;
  }

  static void prefetchAppImages(
    BuildContext context,
    Iterable<String> packageNames, {
    required bool priority,
  }) {
    final appsService = context.read<AppsService>();
    final uniquePackageNames = LinkedHashSet<String>.from(
      packageNames.where((packageName) => packageName.trim().isNotEmpty),
    );
    for (final packageName in uniquePackageNames) {
      if (_hasCachedImage(packageName)) {
        continue;
      }
      final prefetchFuture = _putImageLoadFuture(
        packageName,
        () => _loadAppBannerOrIconForPackage(appsService, packageName),
        priority: priority,
      );
      unawaited(
        prefetchFuture.then<void>(
          (_) {},
          onError: (_, __) {
            // Prefetch is opportunistic; the focused card will surface failures.
          },
        ),
      );
    }
  }

  static void _trimImageCaches() {
    while (_resolvedImageCache.length > _maxImageCacheSize) {
      _resolvedImageCache.remove(_resolvedImageCache.keys.first);
    }
  }

  static void _promotePendingImageLoad(String packageName) {
    _QueuedAppImageLoad? pendingRequest;
    for (final request in _pendingImageLoads) {
      if (request.packageName == packageName) {
        pendingRequest = request;
        break;
      }
    }
    if (pendingRequest == null) {
      return;
    }
    _pendingImageLoads.remove(pendingRequest);
    _pendingImageLoads.addFirst(pendingRequest);
    _drainPendingImageLoads();
  }

  static void _drainPendingImageLoads() {
    while (_activeImageLoads < _maxConcurrentImageLoads &&
        _pendingImageLoads.isNotEmpty) {
      final request = _pendingImageLoads.removeFirst();
      _activeImageLoads += 1;
      request.loader().then((image) {
        if (!request.completer.isCompleted) {
          request.completer.complete(image);
        }
      }, onError: (Object error, StackTrace stackTrace) {
        if (!request.completer.isCompleted) {
          request.completer.completeError(error, stackTrace);
        }
      }).whenComplete(() {
        _activeImageLoads =
            (_activeImageLoads - 1).clamp(0, _maxConcurrentImageLoads).toInt();
        _drainPendingImageLoads();
      });
    }
  }

  static void _scheduleDeferredImageLoad(
    Object token,
    VoidCallback callback,
  ) {
    _deferredImageLoadCallbacks[token] = callback;
    _deferredImageLoadBatchTimer ??=
        Timer(_deferredImageLoadDelay, _flushDeferredImageLoads);
  }

  static void _cancelDeferredImageLoad(Object token) {
    _deferredImageLoadCallbacks.remove(token);
    if (_deferredImageLoadCallbacks.isEmpty) {
      _deferredImageLoadBatchTimer?.cancel();
      _deferredImageLoadBatchTimer = null;
    }
  }

  static void _flushDeferredImageLoads() {
    _deferredImageLoadBatchTimer = null;
    if (_deferredImageLoadCallbacks.isEmpty) {
      return;
    }
    final callbacks =
        _deferredImageLoadCallbacks.values.toList(growable: false);
    _deferredImageLoadCallbacks.clear();
    for (final callback in callbacks) {
      callback();
    }
  }

  static Future<Tuple2<AppImageType, ImageProvider>>
      _loadAppBannerOrIconForPackage(
    AppsService service,
    String packageName,
  ) async {
    var bytes = await service.getAppBanner(packageName);
    var type = AppImageType.Banner;

    if (bytes.isEmpty) {
      type = AppImageType.Icon;
      bytes = await service.getAppIcon(packageName);
    }

    return Tuple2(type, MemoryImage(bytes));
  }

  static void _registerFocusNode(String focusId, FocusNode node) {
    _focusNodesById[focusId] = node;
  }

  static void _unregisterFocusNode(String focusId, FocusNode node) {
    if (identical(_focusNodesById[focusId], node)) {
      _focusNodesById.remove(focusId);
    }
  }
}

class _QueuedAppImageLoad {
  final String packageName;
  final Future<Tuple2<AppImageType, ImageProvider>> Function() loader;
  final Completer<Tuple2<AppImageType, ImageProvider>> completer;

  _QueuedAppImageLoad({
    required this.packageName,
    required this.loader,
    required this.completer,
  });
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  static const Duration _focusBurstCooldown = Duration(milliseconds: 280);

  bool _moving = false;
  bool _focusBurstActive = false;
  bool? _lastObservedHomeReorderModeEnabled;
  late final FocusNode _cardFocusNode =
      FocusNode(debugLabel: 'app_card_${widget.application.packageName}');

  late Future<Tuple2<AppImageType, ImageProvider>> _appImageLoadFuture;
  Tuple2<AppImageType, ImageProvider>? _resolvedAppImage;
  Object? _appImageLoadError;
  int? _lastSeenImageCacheRevision;
  int _imageLoadRevision = 0;
  final Object _deferredImageLoadToken = Object();
  Timer? _focusBurstTimer;
  late final AnimationController _animation = AnimationController(
    vsync: this,
    lowerBound: 0,
    upperBound: 255,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();

    AppCard._registerFocusNode(_focusRegistryId, _cardFocusNode);
    FocusManager.instance.addHighlightModeListener(_focusHighlightModeChanged);
    _lastSeenImageCacheRevision = AppImageCacheInvalidator.instance.revision;
    AppImageCacheInvalidator.instance.addListener(_syncImageCacheRevision);
    _bindAppImage();
  }

  @override
  void didUpdateWidget(covariant AppCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFocusId = oldWidget.focusId ?? oldWidget.application.packageName;
    if (oldFocusId != _focusRegistryId) {
      AppCard._unregisterFocusNode(oldFocusId, _cardFocusNode);
      AppCard._registerFocusNode(_focusRegistryId, _cardFocusNode);
    }
    if (oldWidget.application.packageName != widget.application.packageName) {
      _bindAppImage();
      return;
    }
    if (!oldWidget.eagerImageLoad && widget.eagerImageLoad) {
      _ensureAppImageLoaded(priority: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final homeReorderModeEnabled =
        Provider.of<AppsService>(context).homeReorderModeEnabled;
    if ((_lastObservedHomeReorderModeEnabled ?? homeReorderModeEnabled) &&
        !homeReorderModeEnabled &&
        _moving) {
      _moving = false;
    }
    _lastObservedHomeReorderModeEnabled = homeReorderModeEnabled;
  }

  @override
  void dispose() {
    FocusManager.instance
        .removeHighlightModeListener(_focusHighlightModeChanged);
    AppImageCacheInvalidator.instance.removeListener(_syncImageCacheRevision);
    AppCard._unregisterFocusNode(_focusRegistryId, _cardFocusNode);
    AppCard._cancelDeferredImageLoad(_deferredImageLoadToken);
    _focusBurstTimer?.cancel();
    _cardFocusNode.dispose();
    _animation.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusKeyboardListener(
        onPressed: (key) => _onPressed(context, key),
        onLongPress: (key) => _onLongPress(context, key),
        builder: (context) {
          final shouldHighlight = _shouldHighlight(context);
          final cornerRadius = context.select<SettingsService, double>(
            (service) => service.appCardCornerRadius.toDouble(),
          );
          final layoutScale = context.select<SettingsService, double>(
            (service) => service.appCardLayoutScalePercent / 100,
          );
          final mediaScale = context.select<SettingsService, double>(
            (service) => service.appCardMediaScalePercent / 100,
          );
          final highlightAnimationEnabled =
              context.select<SettingsService, bool>(
            (service) => service.appHighlightAnimationEnabled,
          );
          final highlightColor = context.select<SettingsService, Color>(
            (service) => resolveAppCardHighlightPresetColor(
              service.appHighlightAnimationColorPreset,
            ),
          );
          final homeReorderModeEnabled = context.select<AppsService, bool>(
            (service) => service.homeReorderModeEnabled,
          );
          final performanceProfile =
              context.select<SettingsService, HomePerformanceProfile>(
            (service) =>
                HomePerformanceProfile.resolve(service.homeDockPerformanceMode),
          );
          final layout = _AppCardLayout.fromMediaScale(mediaScale);
          final locked = context.select<ProfileSecurityService?, bool>(
            (service) => service?.isAppLocked(widget.application) ?? false,
          );
          final idleShadeOpacity = _idleShadeOpacity(
            layoutScale: layoutScale,
            mediaScale: mediaScale,
          );

          return AspectRatio(
            aspectRatio: 16 / 9,
            child: LayoutBuilder(
              builder: (context, constraints) => Center(
                child: Transform.scale(
                  scale: layoutScale,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: AnimatedContainer(
                      duration: _focusBurstActive
                          ? const Duration(milliseconds: 36)
                          : performanceProfile.appCardTransformDuration,
                      curve: Curves.easeOutCubic,
                      transformAlignment: Alignment.center,
                      transform: _scaleTransform(
                        shouldHighlight,
                        performanceProfile,
                      ),
                      child: RepaintBoundary(
                        child: Material(
                          borderRadius: BorderRadius.circular(cornerRadius),
                          clipBehavior: Clip.antiAlias,
                          elevation: shouldHighlight
                              ? performanceProfile.appCardFocusedElevation
                              : 0,
                          shadowColor: Colors.black,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              InkWell(
                                focusNode: _cardFocusNode,
                                autofocus: widget.autofocus,
                                focusColor: Colors.transparent,
                                child: _appImage(
                                  layout,
                                  layoutScale: layoutScale,
                                  mediaScale: mediaScale,
                                  performanceProfile: performanceProfile,
                                ),
                                onTap: () => _onPressed(
                                  context,
                                  LogicalKeyboardKey.enter,
                                ),
                                onLongPress: () => _onLongPress(
                                  context,
                                  LogicalKeyboardKey.enter,
                                ),
                                onFocusChange: (focused) {
                                  if (!focused) {
                                    return;
                                  }
                                  _ensureAppImageLoaded(priority: true);
                                  widget.onFocused?.call(context);
                                },
                              ),
                              if (_moving) ..._arrows(),
                              if (homeReorderModeEnabled &&
                                  !_moving &&
                                  shouldHighlight)
                                _moveReadyBadge(),
                              IgnorePointer(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 140),
                                  curve: Curves.easeOutCubic,
                                  opacity:
                                      shouldHighlight ? 0 : idleShadeOpacity,
                                  child: Container(color: Colors.black),
                                ),
                              ),
                              _highlightFrame(
                                enabled: highlightAnimationEnabled &&
                                    shouldHighlight,
                                cornerRadius: cornerRadius,
                                highlightColor: highlightColor,
                                performanceProfile: performanceProfile,
                                focusBurstActive: _focusBurstActive,
                              ),
                              if (locked) _lockBadge(),
                            ],
                          ),
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

  Widget _highlightFrame({
    required bool enabled,
    required double cornerRadius,
    required Color highlightColor,
    required HomePerformanceProfile performanceProfile,
    required bool focusBurstActive,
  }) {
    if (!enabled) {
      _animation.stop();
      return const SizedBox();
    }

    _animation.duration = performanceProfile.appCardHighlightPulseDuration;
    if (focusBurstActive || !performanceProfile.appCardHighlightPulseEnabled) {
      _animation.stop();
      return _buildHighlightFrameDecoration(
        cornerRadius: cornerRadius,
        highlightColor: highlightColor,
        performanceProfile: performanceProfile,
        pulse: 0,
        suppressGlow: focusBurstActive,
      );
    }

    _animation.repeat(reverse: true);
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final pulse = (_animation.value / 255).clamp(0.0, 1.0);
        return _buildHighlightFrameDecoration(
          cornerRadius: cornerRadius,
          highlightColor: highlightColor,
          performanceProfile: performanceProfile,
          pulse: pulse,
          suppressGlow: false,
        );
      },
    );
  }

  Widget _buildHighlightFrameDecoration({
    required double cornerRadius,
    required Color highlightColor,
    required HomePerformanceProfile performanceProfile,
    required double pulse,
    required bool suppressGlow,
  }) {
    final borderOpacity = performanceProfile.appCardHighlightBorderBaseOpacity +
        (pulse * performanceProfile.appCardHighlightBorderPulseOpacityDelta);
    final glowOpacity = suppressGlow
        ? 0.0
        : performanceProfile.appCardHighlightGlowBaseOpacity +
            (pulse * performanceProfile.appCardHighlightGlowPulseOpacityDelta);
    final glowBlur = performanceProfile.appCardHighlightGlowBaseBlur +
        (pulse * performanceProfile.appCardHighlightGlowPulseBlurDelta);
    final glowSpread = performanceProfile.appCardHighlightGlowBaseSpread +
        (pulse * performanceProfile.appCardHighlightGlowPulseSpreadDelta);

    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cornerRadius),
          border: Border.all(
            color: highlightColor.withOpacity(borderOpacity.clamp(0.0, 1.0)),
            width: performanceProfile.appCardHighlightBorderWidth,
          ),
          boxShadow: glowOpacity <= 0 || glowBlur <= 0
              ? const <BoxShadow>[]
              : [
                  BoxShadow(
                    color: highlightColor.withOpacity(
                      glowOpacity.clamp(0.0, 1.0),
                    ),
                    blurRadius: glowBlur,
                    spreadRadius: glowSpread,
                  ),
                ],
        ),
      ),
    );
  }

  Future<Tuple2<AppImageType, ImageProvider>> _loadAppBannerOrIcon(
      AppsService service) async {
    return AppCard._loadAppBannerOrIconForPackage(
      service,
      widget.application.packageName,
    );
  }

  Widget _appImage(
    _AppCardLayout layout, {
    required double layoutScale,
    required double mediaScale,
    required HomePerformanceProfile performanceProfile,
  }) {
    final app = widget.application;
    final localizations = AppLocalizations.of(context)!;
    final surfaceColor = Color(0xFF0A1520).withOpacity(
      _surfaceOpacity(
        layoutScale: layoutScale,
        mediaScale: mediaScale,
      ),
    );
    final tuple = _resolvedAppImage;
    if (tuple != null) {
      if (tuple.item1 == AppImageType.Banner) {
        return ColoredBox(
          color: surfaceColor,
          child: _bannerMedia(
            tuple.item2,
            mediaScale,
            performanceProfile,
          ),
        );
      }

      return ColoredBox(
        color: surfaceColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final iconLaneWidth = constraints.maxWidth * layout.iconLaneFactor;
            final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
            final cacheWidth =
                _decodeCacheDimension(iconLaneWidth, devicePixelRatio);
            final cacheHeight = _decodeCacheDimension(
              constraints.maxHeight,
              devicePixelRatio,
            );
            return Padding(
              padding: EdgeInsets.all(layout.contentPadding),
              child: Row(
                children: [
                  SizedBox(
                    width: iconLaneWidth,
                    child: ClipRect(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(layout.iconPadding),
                          child: Transform.scale(
                            scale: layout.iconVisualScale,
                            child: Image(
                              image: _resizeImageProvider(
                                tuple.item2,
                                cacheWidth,
                                cacheHeight,
                              ),
                              fit: BoxFit.contain,
                              width: iconLaneWidth,
                              height: constraints.maxHeight,
                              filterQuality:
                                  performanceProfile.appCardFilterQuality,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: layout.textGap,
                        right: layout.trailingPadding,
                      ),
                      child: Text(
                        app.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: (Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.fontSize ??
                                      12) *
                                  layout.titleScale,
                              height: 1.16,
                            ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: layout.textMaxLines,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return ColoredBox(
      color: surfaceColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _appImageLoadError == null
                    ? Icons.apps_rounded
                    : Icons.broken_image_outlined,
                size: 22,
                color: Colors.white70,
              ),
              const SizedBox(height: 8),
              Text(
                _appImageLoadError == null ? localizations.loading : app.name,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bannerMedia(
    ImageProvider imageProvider,
    double mediaScale,
    HomePerformanceProfile performanceProfile,
  ) {
    final shrinkFactor = mediaScale < 1 ? mediaScale : 1.0;
    final zoomScale = mediaScale > 1 ? mediaScale : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = _decodeCacheDimension(
          constraints.maxWidth * math.max(shrinkFactor, zoomScale),
          devicePixelRatio,
        );
        final cacheHeight = _decodeCacheDimension(
          constraints.maxHeight * math.max(shrinkFactor, zoomScale),
          devicePixelRatio,
        );
        return ClipRect(
          child: Center(
            child: Transform.scale(
              scale: zoomScale,
              child: FractionallySizedBox(
                widthFactor: shrinkFactor,
                heightFactor: shrinkFactor,
                child: Image(
                  image: _resizeImageProvider(
                    imageProvider,
                    cacheWidth,
                    cacheHeight,
                  ),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: performanceProfile.appCardFilterQuality,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  ImageProvider _resizeImageProvider(
    ImageProvider imageProvider,
    int? cacheWidth,
    int? cacheHeight,
  ) {
    return ResizeImage.resizeIfNeeded(
      cacheWidth,
      cacheHeight,
      imageProvider,
    );
  }

  int? _decodeCacheDimension(double logicalPixels, double devicePixelRatio) {
    if (!logicalPixels.isFinite || logicalPixels <= 0) {
      return null;
    }
    final physicalPixels = logicalPixels * devicePixelRatio;
    if (!physicalPixels.isFinite || physicalPixels <= 0) {
      return null;
    }
    return math.max(1, physicalPixels.ceil());
  }

  void _bindAppImage() {
    AppCard._cancelDeferredImageLoad(_deferredImageLoadToken);
    final loadRevision = ++_imageLoadRevision;
    final packageName = widget.application.packageName;
    _resolvedAppImage = AppCard._getCachedImage(packageName);
    _appImageLoadError = null;
    if (_resolvedAppImage != null) {
      return;
    }
    if (widget.autofocus ||
        widget.eagerImageLoad ||
        AppCard._hasPendingImageLoad(packageName)) {
      _ensureAppImageLoaded(priority: true, loadRevision: loadRevision);
      return;
    }
    AppCard._scheduleDeferredImageLoad(_deferredImageLoadToken, () {
      if (!mounted) {
        return;
      }
      _ensureAppImageLoaded(priority: false, loadRevision: loadRevision);
    });
  }

  void _syncImageCacheRevision() {
    final invalidator = AppImageCacheInvalidator.instance;
    if (_lastSeenImageCacheRevision == invalidator.revision) {
      return;
    }
    _lastSeenImageCacheRevision = invalidator.revision;
    final packageName = invalidator.packageName;
    if (packageName == null) {
      AppCard._clearImageCaches();
      _bindAppImage();
      return;
    }
    if (packageName == widget.application.packageName) {
      AppCard._evictImage(packageName);
      _bindAppImage();
    }
  }

  void _ensureAppImageLoaded({
    required bool priority,
    int? loadRevision,
  }) {
    if (_resolvedAppImage != null) {
      return;
    }
    AppCard._cancelDeferredImageLoad(_deferredImageLoadToken);
    final packageName = widget.application.packageName;
    final expectedRevision = loadRevision ?? _imageLoadRevision;
    _appImageLoadFuture = AppCard._putImageLoadFuture(
      packageName,
      () async {
        final image = await _loadAppBannerOrIcon(
          Provider.of<AppsService>(context, listen: false),
        );
        return image;
      },
      priority: priority,
    );
    unawaited(
      _appImageLoadFuture.then((value) {
        if (!mounted ||
            expectedRevision != _imageLoadRevision ||
            packageName != widget.application.packageName) {
          return;
        }
        setState(() {
          _resolvedAppImage = value;
          _appImageLoadError = null;
        });
      }).catchError((Object error) {
        if (!mounted ||
            expectedRevision != _imageLoadRevision ||
            packageName != widget.application.packageName) {
          return;
        }
        setState(() {
          _appImageLoadError = error;
        });
      }),
    );
  }

  void _focusHighlightModeChanged(FocusHighlightMode mode) {
    setState(() {});
  }

  bool _shouldHighlight(BuildContext context) {
    return FocusManager.instance.highlightMode ==
            FocusHighlightMode.traditional &&
        Focus.of(context).hasFocus;
  }

  Matrix4 _scaleTransform(
    bool shouldHighlight,
    HomePerformanceProfile performanceProfile,
  ) {
    double scale = 1.0;
    if (!_moving && shouldHighlight) {
      scale = performanceProfile.appCardFocusedScale;
    }
    return Matrix4.diagonal3Values(scale, scale, 1.0);
  }

  List<Widget> _arrows() => [
        _arrow(Alignment.centerLeft, Icons.keyboard_arrow_left, () {
          final moved = widget.onMove(context, AxisDirection.left);
          if (moved) {
            _restoreCardFocusAfterMove();
          }
        }),
        _arrow(Alignment.topCenter, Icons.keyboard_arrow_up, () {
          final moved = widget.onMove(context, AxisDirection.up);
          if (moved) {
            _restoreCardFocusAfterMove();
          }
        }),
        _arrow(Alignment.bottomCenter, Icons.keyboard_arrow_down, () {
          final moved = widget.onMove(context, AxisDirection.down);
          if (moved) {
            _restoreCardFocusAfterMove();
          }
        }),
        _arrow(Alignment.centerRight, Icons.keyboard_arrow_right, () {
          final moved = widget.onMove(context, AxisDirection.right);
          if (moved) {
            _restoreCardFocusAfterMove();
          }
        }),
      ];

  Widget _arrow(Alignment alignment, IconData icon, VoidCallback onTap) =>
      Align(
        alignment: alignment,
        child: ExcludeFocus(
          child: Ink(
            decoration: ShapeDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.8),
              shape: const CircleBorder(),
            ),
            child: SizedBox(
              height: 36,
              width: 36,
              child: IconButton(
                icon: Icon(icon, size: 24),
                onPressed: onTap,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      );

  KeyEventResult _onPressed(BuildContext context, LogicalKeyboardKey? key) {
    final homeReorderModeEnabled =
        context.read<AppsService>().homeReorderModeEnabled;
    final navigationDirection = _navigationDirectionForKey(key);
    if (_moving) {
      var moved = false;
      if (key == LogicalKeyboardKey.arrowLeft) {
        moved = widget.onMove(context, AxisDirection.left);
      } else if (key == LogicalKeyboardKey.arrowUp) {
        moved = widget.onMove(context, AxisDirection.up);
      } else if (key == LogicalKeyboardKey.arrowRight) {
        moved = widget.onMove(context, AxisDirection.right);
      } else if (key == LogicalKeyboardKey.arrowDown) {
        moved = widget.onMove(context, AxisDirection.down);
      } else if (_validationKeys.contains(key)) {
        unawaited(_finishMoveSession(context, committed: true));
      } else if (key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.goBack ||
          key == LogicalKeyboardKey.gameButtonB) {
        unawaited(_finishMoveSession(context, committed: false));
      } else {
        return KeyEventResult.ignored;
      }

      if (moved) {
        _restoreCardFocusAfterMove();
      }

      return KeyEventResult.handled;
    } else if (navigationDirection != null) {
      _markFocusNavigationBurst();
      return (widget.onNavigate?.call(navigationDirection) ?? false)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    } else if (homeReorderModeEnabled && _validationKeys.contains(key)) {
      _enterMoveMode(context);
      return KeyEventResult.handled;
    } else if (homeReorderModeEnabled &&
        (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.goBack ||
            key == LogicalKeyboardKey.gameButtonB)) {
      context.read<AppsService>().setHomeReorderModeEnabled(false);
      return KeyEventResult.handled;
    } else if (_validationKeys.contains(key)) {
      unawaited(_launchApplication(context));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  AxisDirection? _navigationDirectionForKey(LogicalKeyboardKey? key) {
    if (key == LogicalKeyboardKey.arrowLeft) {
      return AxisDirection.left;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      return AxisDirection.up;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return AxisDirection.right;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return AxisDirection.down;
    }
    return null;
  }

  void _markFocusNavigationBurst() {
    _focusBurstTimer?.cancel();
    if (!_focusBurstActive && mounted) {
      setState(() => _focusBurstActive = true);
    }
    _focusBurstTimer = Timer(_focusBurstCooldown, () {
      if (!mounted || !_focusBurstActive) {
        return;
      }
      setState(() => _focusBurstActive = false);
    });
  }

  KeyEventResult _onLongPress(BuildContext context, LogicalKeyboardKey? key) {
    final homeReorderModeEnabled =
        context.read<AppsService>().homeReorderModeEnabled;
    if (!_moving &&
        homeReorderModeEnabled &&
        (key == null || longPressableKeys.contains(key))) {
      _enterMoveMode(context);
      return KeyEventResult.handled;
    }
    if (!_moving &&
        !homeReorderModeEnabled &&
        (key == null || longPressableKeys.contains(key))) {
      unawaited(_showAppMenu(context));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _showAppMenu(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => ApplicationInfoPanel(
        category: widget.category,
        application: widget.application,
      ),
    );
    _restoreCardFocusAfterMove();
  }

  void _enterMoveMode(BuildContext context) {
    final started = widget.onMoveStart?.call(context) ?? true;
    if (!started) {
      return;
    }
    setState(() => _moving = true);
    _restoreCardFocusAfterMove();
  }

  Future<void> _finishMoveSession(
    BuildContext context, {
    required bool committed,
  }) async {
    if (!_moving) {
      return;
    }
    setState(() => _moving = false);
    await widget.onMoveEnd(context, committed);
    _restoreCardFocusAfterMove();
  }

  Future<void> _launchApplication(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final canLaunch = await ensureAppLaunchAccess(
      context,
      widget.application,
      title: localizations.unlockAppTitle,
      description: localizations.unlockAppDescription(widget.application.name),
    );
    if (!canLaunch || !context.mounted) {
      return;
    }
    await context.read<AppsService>().launchApp(widget.application);
  }

  Widget _lockBadge() => Align(
        alignment: Alignment.topRight,
        child: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xCC111C2A),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(Icons.lock_outline, size: 16, color: Colors.white),
        ),
      );

  Widget _moveReadyBadge() => Align(
        alignment: Alignment.topLeft,
        child: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xC0102032),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF7BE0A5), width: 1.2),
          ),
          child: const Icon(
            Icons.open_with_rounded,
            size: 16,
            color: Color(0xFF7BE0A5),
          ),
        ),
      );

  void _restoreCardFocusAfterMove() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _cardFocusNode.requestFocus();
    });
  }

  double _surfaceOpacity({
    required double layoutScale,
    required double mediaScale,
  }) {
    final openness = _surfaceOpenness(
      layoutScale: layoutScale,
      mediaScale: mediaScale,
    );
    return _lerpDouble(0.14, 0.03, openness);
  }

  double _idleShadeOpacity({
    required double layoutScale,
    required double mediaScale,
  }) {
    final openness = _surfaceOpenness(
      layoutScale: layoutScale,
      mediaScale: mediaScale,
    );
    return _lerpDouble(0.10, 0.02, openness);
  }

  double _surfaceOpenness({
    required double layoutScale,
    required double mediaScale,
  }) {
    final layoutShrink = ((1.0 - layoutScale).clamp(0.0, 0.35)) / 0.35;
    final mediaShrink = ((1.0 - mediaScale).clamp(0.0, 0.45)) / 0.45;
    return ((layoutShrink * 0.6) + (mediaShrink * 0.4)).clamp(0.0, 1.0);
  }

  double _lerpDouble(double from, double to, double t) =>
      from + ((to - from) * t.clamp(0.0, 1.0));

  String get _focusRegistryId =>
      widget.focusId ?? widget.application.packageName;
}

class _AppCardLayout {
  final double iconLaneFactor;
  final double contentPadding;
  final double iconPadding;
  final double textGap;
  final double trailingPadding;
  final double iconVisualScale;
  final double titleScale;
  final int textMaxLines;

  const _AppCardLayout({
    required this.iconLaneFactor,
    required this.contentPadding,
    required this.iconPadding,
    required this.textGap,
    required this.trailingPadding,
    required this.iconVisualScale,
    required this.titleScale,
    required this.textMaxLines,
  });

  factory _AppCardLayout.fromMediaScale(double scale) {
    final minScale = SettingsService.appCardMediaScaleMin / 100.0;
    final maxScale = SettingsService.appCardMediaScaleMax / 100.0;
    final normalizedScale = scale.clamp(minScale, maxScale);

    if (normalizedScale <= 1.0) {
      final t =
          ((normalizedScale - minScale) / (1.0 - minScale)).clamp(0.0, 1.0);
      return _AppCardLayout(
        iconLaneFactor: _lerp(0.28, 0.34, t),
        contentPadding: _lerp(14, 10, t),
        iconPadding: _lerp(10, 6, t),
        textGap: _lerp(14, 10, t),
        trailingPadding: _lerp(10, 6, t),
        iconVisualScale: _lerp(0.82, 1.0, t),
        titleScale: 1.0,
        textMaxLines: 3,
      );
    }

    final t = ((normalizedScale - 1.0) / (maxScale - 1.0)).clamp(0.0, 1.0);
    return _AppCardLayout(
      iconLaneFactor: _lerp(0.34, 0.40, t),
      contentPadding: _lerp(10, 8, t),
      iconPadding: _lerp(6, 4, t),
      textGap: _lerp(10, 8, t),
      trailingPadding: _lerp(6, 4, t),
      iconVisualScale: _lerp(1.0, 1.16, t),
      titleScale: _lerp(1.0, 0.96, t),
      textMaxLines: 2,
    );
  }

  static double _lerp(double from, double to, double t) =>
      from + ((to - from) * t);
}
