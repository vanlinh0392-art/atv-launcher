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

import 'dart:math';

import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flauncher/widgets/category_container_common.dart';
import 'package:flauncher/widgets/home_card_metrics.dart';
import 'package:flauncher/widgets/home_reorder.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app.dart';
import '../models/category.dart';

class CategoryRow extends StatelessWidget {
  static const String _slotKeyPrefix = 'category_row_slot:';

  final Category category;
  final List<App> applications;
  final bool autofocusFirstItem;
  final bool deferVerticalNavigationToParent;
  final Set<String> eagerImagePackageNames;
  final int imageWarmupSequence;
  final double rowSpacing;
  final void Function(
    String categoryName,
    BuildContext itemContext,
    int rowIndex,
  )? onApplicationFocused;
  final HomeAppReorderCallback? onApplicationReorder;

  CategoryRow({
    Key? key,
    required this.category,
    required this.applications,
    this.autofocusFirstItem = false,
    this.deferVerticalNavigationToParent = false,
    this.eagerImagePackageNames = const <String>{},
    this.imageWarmupSequence = 0,
    this.rowSpacing = homeRowSpacingDefault,
    this.onApplicationFocused,
    this.onApplicationReorder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget categoryContent;
    if (applications.isEmpty) {
      categoryContent = categoryContainerEmptyState(context);
    } else {
      categoryContent = LayoutBuilder(
        builder: (context, constraints) {
          final metrics = HomeCardMetrics.resolve(
            maxWidth: constraints.maxWidth,
            columnsCount: category.columnsCount,
            rowHeight: category.rowHeight,
            rowSpacing: rowSpacing,
          );
          final rowCount = (applications.length / category.columnsCount).ceil();
          final contentHeight = (rowCount * metrics.slotMainAxisExtent) +
              ((rowCount - 1) * rowSpacing);

          return SizedBox(
            height: contentHeight,
            child: RepaintBoundary(
              child: GridView.custom(
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: _buildSliverGridDelegate(metrics),
                padding: const EdgeInsets.symmetric(
                  horizontal: homeGridHorizontalPadding / 2,
                ),
                childrenDelegate: SliverChildBuilderDelegate(
                  childCount: applications.length,
                  findChildIndexCallback: _findChildIndex,
                  (context, index) => Align(
                    key: ValueKey<String>(
                      _slotKeyForPackage(applications[index].packageName),
                    ),
                    alignment: Alignment.center,
                    child: AppCard(
                      key: Key(applications[index].packageName),
                      focusId: _focusIdForPackage(
                        applications[index].packageName,
                      ),
                      category: category,
                      application: applications[index],
                      autofocus: autofocusFirstItem && index == 0,
                      eagerImageLoad: eagerImagePackageNames
                          .contains(applications[index].packageName),
                      imageWarmupSequence: imageWarmupSequence,
                      onFocused: (itemContext) {
                        _prefetchAround(context, index);
                        onApplicationFocused?.call(
                          category.name,
                          itemContext,
                          index ~/ category.columnsCount,
                        );
                      },
                      onMoveStart: (itemContext) =>
                          _onMoveStart(context, itemContext),
                      onMove: (itemContext, direction) =>
                          _onMove(context, itemContext, direction, index),
                      onMoveEnd: (itemContext, committed) =>
                          _onMoveEnd(context, itemContext, committed),
                      onNavigate: (direction) =>
                          _onNavigate(context, direction, index),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return categoryContent;
  }

  int _findChildIndex(Key key) => applications.indexWhere(
        (app) =>
            _slotKeyForPackage(app.packageName) ==
            (key as ValueKey<String>).value,
      );

  static String _slotKeyForPackage(String packageName) =>
      '$_slotKeyPrefix$packageName';

  String _focusIdForPackage(String packageName) =>
      'category:${category.id}:$packageName';

  bool _onNavigate(
    BuildContext context,
    AxisDirection direction,
    int index,
  ) {
    if (deferVerticalNavigationToParent &&
        (direction == AxisDirection.up || direction == AxisDirection.down)) {
      return false;
    }
    final targetIndex = _targetIndexForDirection(direction, index);
    if (targetIndex == null) {
      return false;
    }
    final targetPackageName = applications[targetIndex].packageName;
    AppCard.prefetchAppImages(
      context,
      [targetPackageName],
      priority: true,
    );
    _prefetchAround(context, targetIndex);
    return AppCard.requestFocusForId(_focusIdForPackage(targetPackageName));
  }

  int? _targetIndexForDirection(AxisDirection direction, int index) {
    final columnsCount = category.columnsCount;
    if (columnsCount <= 0 || index < 0 || index >= applications.length) {
      return null;
    }
    final column = index % columnsCount;
    final row = index ~/ columnsCount;
    final lastRow = (applications.length - 1) ~/ columnsCount;

    switch (direction) {
      case AxisDirection.left:
        return column > 0 ? index - 1 : null;
      case AxisDirection.right:
        return column < columnsCount - 1 && index < applications.length - 1
            ? index + 1
            : null;
      case AxisDirection.up:
        return row > 0 ? index - columnsCount : null;
      case AxisDirection.down:
        return row < lastRow
            ? min(index + columnsCount, applications.length - 1)
            : null;
    }
  }

  void _prefetchAround(BuildContext context, int index) {
    final indexes = <int>{
      index - 1,
      index + 1,
      index - category.columnsCount,
      index + category.columnsCount,
    }..removeWhere(
        (candidate) => candidate < 0 || candidate >= applications.length);
    if (indexes.isEmpty) {
      return;
    }
    AppCard.prefetchAppImages(
      context,
      indexes.map((candidate) => applications[candidate].packageName),
      priority: false,
    );
  }

  bool _onMoveStart(BuildContext context, BuildContext itemContext) {
    final appsService = context.read<AppsService>();
    final started = appsService.beginApplicationReorderSession(category);
    if (started) {
      onApplicationReorder?.call(
        category.name,
        itemContext,
        HomeAppReorderEventType.started,
      );
    }
    return started;
  }

  bool _onMove(
    BuildContext context,
    BuildContext itemContext,
    AxisDirection direction,
    int index,
  ) {
    final currentRow = (index / category.columnsCount).floor();
    final totalRows =
        ((applications.length - 1) / category.columnsCount).floor();

    int? newIndex;
    switch (direction) {
      case AxisDirection.up:
        if (currentRow > 0) {
          newIndex = index - category.columnsCount;
        }
        break;
      case AxisDirection.right:
        if (index < applications.length - 1) {
          newIndex = index + 1;
        }
        break;
      case AxisDirection.down:
        if (currentRow < totalRows) {
          newIndex =
              min(index + category.columnsCount, applications.length - 1);
        }
        break;
      case AxisDirection.left:
        if (index > 0) {
          newIndex = index - 1;
        }
        break;
    }

    if (newIndex == null) {
      return false;
    }

    final appsService = context.read<AppsService>();
    final moved = appsService.reorderApplication(category, index, newIndex);
    if (moved) {
      onApplicationReorder?.call(
        category.name,
        itemContext,
        HomeAppReorderEventType.moved,
      );
    }
    return moved;
  }

  Future<void> _onMoveEnd(
    BuildContext context,
    BuildContext itemContext,
    bool committed,
  ) async {
    final appsService = context.read<AppsService>();
    if (committed) {
      await appsService.commitApplicationReorderSession(category);
    } else {
      await appsService.cancelApplicationReorderSession(category);
      appsService.setHomeReorderModeEnabled(false);
    }
    if (!context.mounted) {
      return;
    }
    onApplicationReorder?.call(
      category.name,
      itemContext,
      HomeAppReorderEventType.ended,
      committed: committed,
    );
  }

  SliverGridDelegate _buildSliverGridDelegate(HomeCardMetrics metrics) =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: category.columnsCount,
        mainAxisExtent: metrics.slotMainAxisExtent,
        mainAxisSpacing: rowSpacing,
        crossAxisSpacing: homeGridSpacing,
      );
}
