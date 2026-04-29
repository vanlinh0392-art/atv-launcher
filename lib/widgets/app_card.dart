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

import 'package:flauncher/app_image_cache_invalidator.dart';
import 'package:flauncher/app_image_type.dart';
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

class AppCard extends StatefulWidget {
  static const int _maxImageCacheSize = 96;
  static final LinkedHashMap<String, Tuple2<AppImageType, ImageProvider>>
      _resolvedImageCache =
      LinkedHashMap<String, Tuple2<AppImageType, ImageProvider>>();
  static final LinkedHashMap<String,
          Future<Tuple2<AppImageType, ImageProvider>>> _imageLoadCache =
      LinkedHashMap<String, Future<Tuple2<AppImageType, ImageProvider>>>();

  final App application;
  final Category category;
  final bool autofocus;
  final AppCardFocusCallback? onFocused;
  final void Function(AxisDirection) onMove;
  final VoidCallback onMoveEnd;

  const AppCard({
    super.key,
    required this.application,
    required this.category,
    required this.autofocus,
    this.onFocused,
    required this.onMove,
    required this.onMoveEnd,
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

  static Future<Tuple2<AppImageType, ImageProvider>> _putImageLoadFuture(
    String packageName,
    Future<Tuple2<AppImageType, ImageProvider>> Function() loader,
  ) {
    final cachedFuture = _imageLoadCache.remove(packageName);
    if (cachedFuture != null) {
      _imageLoadCache[packageName] = cachedFuture;
      return cachedFuture;
    }

    final future = loader().then((image) {
      _rememberImage(packageName, image);
      return image;
    }).catchError((Object error) {
      _imageLoadCache.remove(packageName);
      throw error;
    });
    _imageLoadCache[packageName] = future;
    _trimImageCaches();
    return future;
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
  }

  static void _clearImageCaches() {
    _resolvedImageCache.clear();
    _imageLoadCache.clear();
  }

  static void _trimImageCaches() {
    while (_resolvedImageCache.length > _maxImageCacheSize) {
      _imageLoadCache.remove(_resolvedImageCache.keys.first);
      _resolvedImageCache.remove(_resolvedImageCache.keys.first);
    }
    while (_imageLoadCache.length > _maxImageCacheSize) {
      _imageLoadCache.remove(_imageLoadCache.keys.first);
    }
  }
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  bool _moving = false;

  late Future<Tuple2<AppImageType, ImageProvider>> _appImageLoadFuture;
  Tuple2<AppImageType, ImageProvider>? _resolvedAppImage;
  Object? _appImageLoadError;
  int? _lastSeenImageCacheRevision;
  late final AnimationController _animation = AnimationController(
    vsync: this,
    lowerBound: 0,
    upperBound: 255,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();

    FocusManager.instance.addHighlightModeListener(_focusHighlightModeChanged);
    _lastSeenImageCacheRevision = AppImageCacheInvalidator.instance.revision;
    AppImageCacheInvalidator.instance.addListener(_syncImageCacheRevision);
    _bindAppImage();
  }

  @override
  void didUpdateWidget(covariant AppCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.application.packageName != widget.application.packageName) {
      _bindAppImage();
    }
  }

  @override
  void dispose() {
    FocusManager.instance
        .removeHighlightModeListener(_focusHighlightModeChanged);
    AppImageCacheInvalidator.instance.removeListener(_syncImageCacheRevision);
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
                      duration: const Duration(milliseconds: 90),
                      curve: Curves.easeOutCubic,
                      transformAlignment: Alignment.center,
                      transform: _scaleTransform(context),
                      child: RepaintBoundary(
                        child: Material(
                          borderRadius: BorderRadius.circular(cornerRadius),
                          clipBehavior: Clip.antiAlias,
                          elevation: shouldHighlight ? 16 : 0,
                          shadowColor: Colors.black,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              InkWell(
                                autofocus: widget.autofocus,
                                focusColor: Colors.transparent,
                                child: _appImage(
                                  layout,
                                  layoutScale: layoutScale,
                                  mediaScale: mediaScale,
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
                                  widget.onFocused?.call(context);
                                },
                              ),
                              if (_moving) ..._arrows(),
                              IgnorePointer(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 140),
                                  curve: Curves.easeOutCubic,
                                  opacity:
                                      shouldHighlight ? 0 : idleShadeOpacity,
                                  child: Container(color: Colors.black),
                                ),
                              ),
                              Selector<SettingsService, bool>(
                                selector: (_, settingsService) =>
                                    settingsService
                                        .appHighlightAnimationEnabled &&
                                    shouldHighlight,
                                builder: (context, highlight, _) {
                                  if (highlight) {
                                    _animation.repeat(reverse: true);
                                    return AnimatedBuilder(
                                      animation: _animation,
                                      builder: (context, child) =>
                                          IgnorePointer(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              cornerRadius,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withAlpha(
                                                _animation.value.round(),
                                              ),
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  _animation.stop();
                                  return const SizedBox();
                                },
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

  Future<Tuple2<AppImageType, ImageProvider>> _loadAppBannerOrIcon(
      AppsService service) async {
    Uint8List bytes = Uint8List(0);

    bytes = await service.getAppBanner(widget.application.packageName);
    AppImageType type = AppImageType.Banner;

    if (bytes.isEmpty) {
      type = AppImageType.Icon;
      bytes = await service.getAppIcon(widget.application.packageName);
    }

    return Tuple2(type, MemoryImage(bytes));
  }

  Widget _appImage(
    _AppCardLayout layout, {
    required double layoutScale,
    required double mediaScale,
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
          child: _bannerMedia(tuple.item2, mediaScale),
        );
      }

      return ColoredBox(
        color: surfaceColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final iconLaneWidth = constraints.maxWidth * layout.iconLaneFactor;
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
                              image: tuple.item2,
                              fit: BoxFit.contain,
                              width: iconLaneWidth,
                              height: constraints.maxHeight,
                              filterQuality: FilterQuality.low,
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

  Widget _bannerMedia(ImageProvider imageProvider, double mediaScale) {
    final shrinkFactor = mediaScale < 1 ? mediaScale : 1.0;
    final zoomScale = mediaScale > 1 ? mediaScale : 1.0;

    return ClipRect(
      child: Center(
        child: Transform.scale(
          scale: zoomScale,
          child: FractionallySizedBox(
            widthFactor: shrinkFactor,
            heightFactor: shrinkFactor,
            child: Image(
              image: imageProvider,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
            ),
          ),
        ),
      ),
    );
  }

  void _bindAppImage() {
    final packageName = widget.application.packageName;
    _resolvedAppImage = AppCard._getCachedImage(packageName);
    _appImageLoadError = null;
    _appImageLoadFuture = AppCard._putImageLoadFuture(
      packageName,
      () async {
        final image = await _loadAppBannerOrIcon(
          Provider.of<AppsService>(context, listen: false),
        );
        return image;
      },
    );
    if (_resolvedAppImage != null) {
      return;
    }
    unawaited(
      _appImageLoadFuture.then((value) {
        if (!mounted) {
          return;
        }
        setState(() {
          _resolvedAppImage = value;
          _appImageLoadError = null;
        });
      }).catchError((Object error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _appImageLoadError = error;
        });
      }),
    );
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

  void _focusHighlightModeChanged(FocusHighlightMode mode) {
    setState(() {});
  }

  bool _shouldHighlight(BuildContext context) {
    return FocusManager.instance.highlightMode ==
            FocusHighlightMode.traditional &&
        Focus.of(context).hasFocus;
  }

  Matrix4 _scaleTransform(BuildContext context) {
    double scale = 1.0;
    if (!_moving && _shouldHighlight(context)) {
      scale = 1.05;
    }
    return Matrix4.diagonal3Values(scale, scale, 1.0);
  }

  List<Widget> _arrows() => [
        _arrow(Alignment.centerLeft, Icons.keyboard_arrow_left, () {
          widget.onMove(AxisDirection.left);
        }),
        _arrow(Alignment.topCenter, Icons.keyboard_arrow_up, () {
          widget.onMove(AxisDirection.up);
        }),
        _arrow(Alignment.bottomCenter, Icons.keyboard_arrow_down, () {
          widget.onMove(AxisDirection.down);
        }),
        _arrow(Alignment.centerRight, Icons.keyboard_arrow_right, () {
          widget.onMove(AxisDirection.right);
        }),
      ];

  Widget _arrow(Alignment alignment, IconData icon, VoidCallback onTap) =>
      Align(
        alignment: alignment,
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
      );

  KeyEventResult _onPressed(BuildContext context, LogicalKeyboardKey? key) {
    if (_moving) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _ensureFullyVisible());
      if (key == LogicalKeyboardKey.arrowLeft) {
        widget.onMove(AxisDirection.left);
      } else if (key == LogicalKeyboardKey.arrowUp) {
        widget.onMove(AxisDirection.up);
      } else if (key == LogicalKeyboardKey.arrowRight) {
        widget.onMove(AxisDirection.right);
      } else if (key == LogicalKeyboardKey.arrowDown) {
        widget.onMove(AxisDirection.down);
      } else if (_validationKeys.contains(key) ||
          key == LogicalKeyboardKey.escape) {
        setState(() => _moving = false);
        widget.onMoveEnd();
      } else {
        return KeyEventResult.ignored;
      }

      return KeyEventResult.handled;
    } else if (_validationKeys.contains(key)) {
      unawaited(_launchApplication(context));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onLongPress(BuildContext context, LogicalKeyboardKey? key) {
    if (!_moving && (key == null || longPressableKeys.contains(key))) {
      _showPanel(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _showPanel(BuildContext context) async {
    final result = await showDialog<ApplicationInfoPanelResult>(
      context: context,
      builder: (context) => ApplicationInfoPanel(
        category: widget.category,
        application: widget.application,
      ),
    );
    if (result == ApplicationInfoPanelResult.reorderApp) {
      setState(() => _moving = true);
    }
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

  void _ensureFullyVisible() {
    final scrollable = _findHostScrollableState();
    final renderObject = context.findRenderObject();
    if (scrollable == null || renderObject == null) {
      return;
    }

    if (!scrollable.position.hasPixels) {
      return;
    }

    scrollable.position.ensureVisible(
      renderObject,
      alignment: 0.5,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
    );
  }

  ScrollableState? _findHostScrollableState() {
    ScrollableState? result;

    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        final isVertical =
            axisDirectionToAxis(state.widget.axisDirection) == Axis.vertical;
        final canScroll = state.widget.physics is! NeverScrollableScrollPhysics;
        if (isVertical && canScroll) {
          result = state;
          return false;
        }
      }
      return true;
    });

    return result;
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
