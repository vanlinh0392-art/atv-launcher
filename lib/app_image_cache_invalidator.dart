import 'package:flutter/foundation.dart';

class AppImageCacheInvalidator extends ChangeNotifier {
  AppImageCacheInvalidator._();

  static final AppImageCacheInvalidator instance = AppImageCacheInvalidator._();

  int _revision = 0;
  String? _packageName;

  int get revision => _revision;
  String? get packageName => _packageName;

  void invalidate(String? packageName) {
    _packageName = packageName;
    _revision += 1;
    notifyListeners();
  }
}
