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
import 'package:flauncher/widgets/home_card_metrics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app.dart';
import '../models/category.dart';
import 'category_container_common.dart';

class AppsGrid extends StatelessWidget {
  final Category category;
  final List<App> applications;
  final bool autofocusFirstItem;
  final double rowSpacing;
  final void Function(
    String categoryName,
    BuildContext itemContext,
    int rowIndex,
  )? onApplicationFocused;

  AppsGrid({
    Key? key,
    required this.category,
    required this.applications,
    this.autofocusFirstItem = false,
    this.rowSpacing = homeRowSpacingDefault,
    this.onApplicationFocused,
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

          return GridView.custom(
            primary: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: _buildSliverGridDelegate(metrics),
            padding: const EdgeInsets.symmetric(
              horizontal: homeGridHorizontalPadding / 2,
            ),
            childrenDelegate: SliverChildBuilderDelegate(
              childCount: applications.length,
              findChildIndexCallback: _findChildIndex,
              (context, index) => Align(
                alignment: Alignment.center,
                child: AppCard(
                  key: Key(applications[index].packageName),
                  category: category,
                  application: applications[index],
                  autofocus: autofocusFirstItem && index == 0,
                  onFocused: (itemContext) => onApplicationFocused?.call(
                    category.name,
                    itemContext,
                    index ~/ category.columnsCount,
                  ),
                  onMove: (direction) => _onMove(context, direction, index),
                  onMoveEnd: () => _saveOrder(context),
                ),
              ),
            ),
          );
        },
      );
    }

    return categoryContent;
  }

  int _findChildIndex(Key key) => applications
      .indexWhere((app) => app.packageName == (key as ValueKey<String>).value);

  void _onMove(BuildContext context, AxisDirection direction, int index) {
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
    if (newIndex != null) {
      final appsService = context.read<AppsService>();
      appsService.reorderApplication(category, index, newIndex);
    }
  }

  void _saveOrder(BuildContext context) {
    final appsService = context.read<AppsService>();
    appsService.saveApplicationOrderInCategory(category);
  }

  SliverGridDelegate _buildSliverGridDelegate(HomeCardMetrics metrics) =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: category.columnsCount,
        mainAxisExtent: metrics.slotMainAxisExtent,
        mainAxisSpacing: rowSpacing,
        crossAxisSpacing: homeGridSpacing,
      );
}
