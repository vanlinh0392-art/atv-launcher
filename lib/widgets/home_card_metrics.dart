import 'dart:math' as math;

import 'package:flauncher/models/category.dart';

const double homeDockScrollTopPadding = 12.0;
const double homeDockScrollBottomPadding = 12.0;
const double homeRowSpacingDefault = 8.0;
const double homeCategorySectionGap = 16.0;
const double homeGridHorizontalPadding = 32.0;
const double homeGridSpacing = 16.0;
const double homeCardAspectRatio = 16 / 9;
const double homeDockVerticalOffset = 14.0;

class HomeCardMetrics {
  final double slotCrossAxisExtent;
  final double slotMainAxisExtent;
  final double rowStride;

  const HomeCardMetrics({
    required this.slotCrossAxisExtent,
    required this.slotMainAxisExtent,
    required this.rowStride,
  });

  factory HomeCardMetrics.resolve({
    required double maxWidth,
    required int columnsCount,
    required int rowHeight,
    double rowSpacing = homeRowSpacingDefault,
  }) {
    final normalizedColumns = columnsCount.clamp(1, 12);
    final contentWidth = math.max(0.0, maxWidth - homeGridHorizontalPadding);
    final spacedWidth = math.max(
      0.0,
      contentWidth - (homeGridSpacing * (normalizedColumns - 1)),
    );
    final slotCrossAxisExtent = spacedWidth / normalizedColumns;
    final slotMainAxisExtent = math.max(
      rowHeight.toDouble(),
      slotCrossAxisExtent / homeCardAspectRatio,
    );
    return HomeCardMetrics(
      slotCrossAxisExtent: slotCrossAxisExtent,
      slotMainAxisExtent: slotMainAxisExtent,
      rowStride: slotMainAxisExtent + rowSpacing,
    );
  }

  double dockHeightForRows({
    required int rows,
    required double maxHeight,
    double rowSpacing = homeRowSpacingDefault,
  }) {
    final normalizedRows = rows.clamp(1, 4);
    final targetHeight = homeDockScrollTopPadding +
        homeDockScrollBottomPadding +
        (normalizedRows * slotMainAxisExtent) +
        ((normalizedRows - 1) * rowSpacing);
    final minimumHeight = homeDockScrollTopPadding +
        homeDockScrollBottomPadding +
        slotMainAxisExtent;
    return targetHeight.clamp(minimumHeight, maxHeight).toDouble();
  }
}

HomeCardMetrics resolveHomeCardMetricsForSections(
  List<LauncherSection> sections,
  double maxWidth, {
  String? preferredCategoryName,
  double rowSpacing = homeRowSpacingDefault,
}) {
  Category? category;

  if (preferredCategoryName != null &&
      preferredCategoryName.trim().isNotEmpty) {
    for (final section in sections) {
      if (section is Category && section.name == preferredCategoryName) {
        category = section;
        break;
      }
    }
  }

  category ??= sections.whereType<Category>().cast<Category?>().firstWhere(
        (section) => section != null,
        orElse: () => null,
      );

  return HomeCardMetrics.resolve(
    maxWidth: maxWidth,
    columnsCount: category?.columnsCount ?? Category.ColumnsCount,
    rowHeight: category?.rowHeight ?? Category.RowHeight,
    rowSpacing: rowSpacing,
  );
}
