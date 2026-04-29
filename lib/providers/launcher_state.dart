/*
 * FLauncher
 * Copyright (C) 2021  Oscar Rojas
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

import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../widgets/settings/back_button_actions.dart';
import 'apps_service.dart';

class LauncherState extends ChangeNotifier {
  static const Duration _defaultLauncherRefreshThrottle = Duration(seconds: 2);

  bool _isDefaultLauncher;
  bool _launcherVisible;
  int _lastRefreshAt = 0;
  Future<void>? _refreshFuture;

  bool get isDefaultLauncher => _isDefaultLauncher;
  bool get launcherVisible => _launcherVisible;

  LauncherState()
      : _isDefaultLauncher = false,
        _launcherVisible = true;

  void toggleLauncherVisibility() {
    _launcherVisible = !_launcherVisible;
    notifyListeners();
  }

  Future<void> refresh(AppsService appsService, {bool force = false}) async {
    final inFlightRefresh = _refreshFuture;
    if (inFlightRefresh != null) {
      return inFlightRefresh;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force &&
        _lastRefreshAt != 0 &&
        now - _lastRefreshAt < _defaultLauncherRefreshThrottle.inMilliseconds) {
      return;
    }

    final refreshFuture = _refreshInternal(appsService);
    _refreshFuture = refreshFuture;
    try {
      await refreshFuture;
    } finally {
      if (identical(_refreshFuture, refreshFuture)) {
        _refreshFuture = null;
      }
    }
  }

  Future<void> _refreshInternal(AppsService appsService) async {
    final nextValue = await appsService.isDefaultLauncher();
    _lastRefreshAt = DateTime.now().millisecondsSinceEpoch;
    if (_isDefaultLauncher == nextValue) {
      return;
    }
    _isDefaultLauncher = nextValue;
    notifyListeners();
  }

  void handleBackNavigation(BuildContext context) {
    AppsService appsService = context.read<AppsService>();
    LauncherState launcherState = context.read<LauncherState>();
    SettingsService settingsService = context.read<SettingsService>();

    if (kDebugMode || launcherState.isDefaultLauncher) {
      launcherState.refresh(appsService, force: true);
      String action = settingsService.backButtonAction;

      switch (action) {
        case BACK_BUTTON_ACTION_CLOCK:
          launcherState.toggleLauncherVisibility();
          break;
        case BACK_BUTTON_ACTION_SCREENSAVER:
          appsService.startAmbientMode();
          break;
      }
    } else {
      SystemNavigator.pop();
    }
  }
}
