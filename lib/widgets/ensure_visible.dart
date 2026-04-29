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

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class EnsureVisible extends StatelessWidget {
  final Widget child;
  final double alignment;

  const EnsureVisible({Key? key, required this.child, this.alignment = 0.0})
      : super(key: key);

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        onFocusChange: (focused) {
          if (focused) {
            ensureVisible(
              context,
              alignment: alignment,
            );
          }
        },
        child: child,
      );

  static void ensureVisible(
    BuildContext context, {
    double alignment = 0.0,
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
    final leadingOffset = viewport.getOffsetToReveal(renderObject, 0).offset;
    final trailingOffset = viewport.getOffsetToReveal(renderObject, 1).offset;
    final currentOffset = position.pixels;
    final viewportEnd = currentOffset + position.viewportDimension;
    final alreadyVisible = leadingOffset >= currentOffset + 1 &&
        trailingOffset <= viewportEnd - 1;
    if (alreadyVisible) {
      return;
    }

    final targetOffset = viewport
        .getOffsetToReveal(renderObject, alignment.clamp(0.0, 1.0))
        .offset
        .clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    final delta = (targetOffset - currentOffset).abs();
    if (delta < 1) {
      return;
    }
    if (delta < 18) {
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
}
