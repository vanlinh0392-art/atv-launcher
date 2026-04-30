import 'package:flutter/widgets.dart';

enum HomeAppReorderEventType {
  started,
  moved,
  ended,
}

typedef HomeAppReorderCallback = void Function(
  String categoryName,
  BuildContext itemContext,
  HomeAppReorderEventType eventType, {
  bool committed,
});
