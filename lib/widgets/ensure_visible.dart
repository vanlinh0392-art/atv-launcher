/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class EnsureVisible extends StatelessWidget {
  static const double settingsAlignment = 0.24;
  static final Expando<_EnsureVisibleTracker> _trackers =
      Expando<_EnsureVisibleTracker>('ensure_visible_tracker');

  final Widget child;
  final double alignment;
  final int settleFrameCount;
  final bool preferImmediate;

  const EnsureVisible({
    Key? key,
    required this.child,
    this.alignment = 0.0,
    this.settleFrameCount = 3,
    this.preferImmediate = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        onFocusChange: (focused) {
          if (focused) {
            scheduleEnsureVisible(
              context,
              alignment: alignment,
              remainingPasses: settleFrameCount,
              preferImmediate: preferImmediate,
            );
          }
        },
        child: child,
      );

  static void scheduleEnsureVisible(
    BuildContext context, {
    required double alignment,
    required int remainingPasses,
    bool preferImmediate = false,
  }) {
    final scrollable = Scrollable.maybeOf(context);
    final position = scrollable?.position;
    final generation = position == null ? null : _nextGeneration(position);
    _scheduleEnsureVisiblePass(
      context,
      alignment: alignment,
      remainingPasses: remainingPasses,
      preferImmediate: preferImmediate,
      trackedPosition: position,
      generation: generation,
    );
  }

  static void _scheduleEnsureVisiblePass(
    BuildContext context, {
    required double alignment,
    required int remainingPasses,
    required bool preferImmediate,
    required ScrollPosition? trackedPosition,
    required int? generation,
  }) {
    if (trackedPosition != null &&
        generation != null &&
        _trackerFor(trackedPosition).generation != generation) {
      return;
    }
    ensureVisible(
      context,
      alignment: alignment,
      preferImmediate: preferImmediate,
    );
    if (remainingPasses <= 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) {
        return;
      }
      if (trackedPosition != null &&
          generation != null &&
          _trackerFor(trackedPosition).generation != generation) {
        return;
      }
      _scheduleEnsureVisiblePass(
        context,
        alignment: alignment,
        remainingPasses: remainingPasses - 1,
        preferImmediate: preferImmediate,
        trackedPosition: trackedPosition,
        generation: generation,
      );
    });
  }

  static void ensureVisible(
    BuildContext context, {
    double alignment = 0.0,
    bool preferImmediate = false,
  }) {
    final scrollable = Scrollable.maybeOf(context);
    final renderObject = context.findRenderObject();
    if (scrollable == null ||
        renderObject == null ||
        !renderObject.attached ||
        !scrollable.position.hasPixels) {
      return;
    }

    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) {
      Scrollable.ensureVisible(
        context,
        alignment: alignment,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        curve: Curves.easeOutCubic,
        duration: const Duration(milliseconds: 90),
      );
      return;
    }

    final position = scrollable.position;
    final currentOffset = position.pixels;
    final tracker = _trackerFor(position);

    final targetOffset = viewport
        .getOffsetToReveal(renderObject, alignment.clamp(0.0, 1.0))
        .offset
        .clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    final delta = (targetOffset - currentOffset).abs();
    final tolerance = math.max(
      6.0,
      math.min(position.viewportDimension * 0.03, 18.0),
    );
    if (delta <= tolerance) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (tracker.lastTargetOffset != null &&
        (tracker.lastTargetOffset! - targetOffset).abs() <= tolerance &&
        now - tracker.lastIssuedAtMs <= 120) {
      return;
    }
    tracker.lastTargetOffset = targetOffset;
    tracker.lastIssuedAtMs = now;
    if (preferImmediate || delta < 18) {
      position.jumpTo(targetOffset);
      return;
    }

    position.animateTo(
      targetOffset,
      duration: Duration(
        milliseconds: delta < (position.viewportDimension * 0.35) ? 72 : 96,
      ),
      curve: Curves.easeOutCubic,
    );
  }

  static _EnsureVisibleTracker _trackerFor(ScrollPosition position) =>
      _trackers[position] ??= _EnsureVisibleTracker();

  static int _nextGeneration(ScrollPosition position) {
    final tracker = _trackerFor(position);
    tracker.generation += 1;
    return tracker.generation;
  }
}

class _EnsureVisibleTracker {
  int generation = 0;
  double? lastTargetOffset;
  int lastIssuedAtMs = 0;
}
