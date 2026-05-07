/*
 * FLauncher
 * Copyright (C) 2021  Ã‰tienne Fesser
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

import 'package:flauncher/actions.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/settings/home_layout_panel_page.dart';
import 'package:flauncher/widgets/settings/permissions_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'flauncher.dart';

class FLauncherApp extends StatefulWidget {
  const FLauncherApp({super.key});

  @override
  State<FLauncherApp> createState() => _FLauncherAppState();
}

class _FLauncherAppState extends State<FLauncherApp>
    with WidgetsBindingObserver {
  static const int _freshInstallWindowMs = 60000;
  static const PrioritizedIntents _backIntents =
      PrioritizedIntents(orderedIntents: [DismissIntent(), BackIntent()]);

  static const MaterialColor _swatch = MaterialColor(0xFF011526, <int, Color>{
    50: Color(0xFF36A0FA),
    100: Color(0xFF067BDE),
    200: Color(0xFF045CA7),
    300: Color(0xFF033662),
    400: Color(0xFF022544),
    500: Color(0xFF011526),
    600: Color(0xFF000508),
    700: Color(0xFF000000),
    800: Color(0xFF000000),
    900: Color(0xFF000000),
  });

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  SystemBridgeService? _systemBridgeService;
  int _lastHandledHomeSequence = 0;
  int _lastHandledBenchmarkSequence = 0;
  bool _bridgeSnapshotPrimed = false;
  bool _adbOnboardingCheckScheduled = false;
  bool _adbOnboardingVisible = false;
  bool _adbOnboardingHandledThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDefaultLauncherState(force: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextBridgeService = context.read<SystemBridgeService>();
    if (identical(_systemBridgeService, nextBridgeService)) {
      return;
    }
    final initialBenchmark = _readBenchmarkCommand(nextBridgeService);
    _systemBridgeService?.removeListener(_handleSystemBridgeChanged);
    _systemBridgeService = nextBridgeService;
    _lastHandledHomeSequence = _readHomeSequence(nextBridgeService);
    _lastHandledBenchmarkSequence = initialBenchmark.sequence;
    _bridgeSnapshotPrimed = nextBridgeService.initialized;
    _systemBridgeService?.addListener(_handleSystemBridgeChanged);
    if (nextBridgeService.initialized &&
        initialBenchmark.sequence > 0 &&
        initialBenchmark.action.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(_systemBridgeService, nextBridgeService)) {
          return;
        }
        _handleBenchmarkCommand(initialBenchmark);
      });
    } else if (nextBridgeService.initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(_systemBridgeService, nextBridgeService)) {
          return;
        }
        _scheduleAdbLocalOnboardingCheck();
      });
    }
  }

  @override
  void dispose() {
    _systemBridgeService?.removeListener(_handleSystemBridgeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDefaultLauncherState();
      _scheduleAdbLocalOnboardingCheck();
    }
  }

  void _refreshDefaultLauncherState({bool force = false}) {
    if (!mounted) {
      return;
    }
    final appsService = context.read<AppsService>();
    context.read<LauncherState>().refresh(appsService, force: force);
  }

  void _handleSystemBridgeChanged() {
    final bridgeService = _systemBridgeService;
    if (bridgeService == null) {
      return;
    }
    final benchmark = _readBenchmarkCommand(bridgeService);
    if (!_bridgeSnapshotPrimed && bridgeService.initialized) {
      _lastHandledHomeSequence = _readHomeSequence(bridgeService);
      _bridgeSnapshotPrimed = true;
      if (benchmark.sequence <= 0 || benchmark.action.isEmpty) {
        _lastHandledBenchmarkSequence = benchmark.sequence;
      }
    }
    if (benchmark.sequence > _lastHandledBenchmarkSequence) {
      _lastHandledBenchmarkSequence = benchmark.sequence;
      _handleBenchmarkCommand(benchmark);
    }
    final nextSequence = _readHomeSequence(bridgeService);
    if (nextSequence > _lastHandledHomeSequence) {
      _lastHandledHomeSequence = nextSequence;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final navigator = _navigatorKey.currentState;
        if (navigator == null) {
          return;
        }
        navigator.popUntil((route) => route.isFirst);
        _scheduleAdbLocalOnboardingCheck();
      });
      return;
    }
    _scheduleAdbLocalOnboardingCheck();
  }

  void _handleBenchmarkCommand(_BenchmarkSnapshot benchmark) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Future<void>.microtask(() async {
        if (!mounted) {
          return;
        }
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        if (benchmark.action != 'open_launcher_settings' ||
            !benchmark.bypassSettingsSecurity) {
          _scheduleAdbLocalOnboardingCheck();
          return;
        }
        await _showLauncherSettingsPanel(
          selectedRouteOnShell: benchmark.route.isEmpty
              ? HomeLayoutPanelPage.routeName
              : benchmark.route,
          autoFocusDetailOnOpen: benchmark.autoFocusDetail,
          benchmarkSessionId: benchmark.sessionId,
        );
      });
    });
  }

  void _scheduleAdbLocalOnboardingCheck() {
    if (!mounted ||
        _adbOnboardingCheckScheduled ||
        _adbOnboardingVisible ||
        _adbOnboardingHandledThisSession) {
      return;
    }
    _adbOnboardingCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _adbOnboardingCheckScheduled = false;
      if (!mounted) {
        return;
      }
      await _maybeShowAdbLocalOnboarding();
    });
  }

  Future<void> _maybeShowAdbLocalOnboarding() async {
    if (!mounted || _adbOnboardingVisible || _adbOnboardingHandledThisSession) {
      return;
    }
    final bridgeService = _systemBridgeService;
    final rootContext = _navigatorKey.currentContext;
    final navigator = _navigatorKey.currentState;
    if (bridgeService == null || rootContext == null || navigator == null) {
      return;
    }
    final settingsService = rootContext.read<SettingsService>();
    if (!_shouldShowAdbLocalOnboarding(bridgeService, settingsService) ||
        navigator.canPop()) {
      return;
    }
    _adbOnboardingVisible = true;
    final acknowledged = await _showAdbLocalOnboardingDialog(rootContext);
    _adbOnboardingVisible = false;
    if (!mounted || !rootContext.mounted || acknowledged != true) {
      return;
    }
    _adbOnboardingHandledThisSession = true;
    await settingsService.setAdbLocalOnboardingHandled(true);
    if (!mounted || !rootContext.mounted) {
      return;
    }
    final result =
        await bridgeService.runProvisioningAction(action: 'open_development');
    if (!mounted || !rootContext.mounted || result['success'] == true) {
      return;
    }
    await _showAdbLocalOnboardingFallbackDialog(rootContext);
  }

  bool _shouldShowAdbLocalOnboarding(
    SystemBridgeService bridgeService,
    SettingsService settingsService,
  ) {
    if (!bridgeService.initialized ||
        settingsService.adbLocalOnboardingHandled) {
      return false;
    }
    if (!_isFreshInstall(_readInstallStatus(bridgeService.status))) {
      return false;
    }
    return _isAdbDisabled(bridgeService.provisioningStatus);
  }

  Map<String, dynamic> _readInstallStatus(Map<String, dynamic> status) {
    final raw = status['install'];
    return raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{};
  }

  bool _isFreshInstall(Map<String, dynamic> installStatus) {
    final firstInstallTime =
        ((installStatus['firstInstallTime'] as num?) ?? 0).toInt();
    final lastUpdateTime =
        ((installStatus['lastUpdateTime'] as num?) ?? 0).toInt();
    if (firstInstallTime <= 0 ||
        lastUpdateTime <= 0 ||
        lastUpdateTime < firstInstallTime) {
      return false;
    }
    return lastUpdateTime - firstInstallTime <= _freshInstallWindowMs;
  }

  bool _isAdbDisabled(Map<String, dynamic> provisioningStatus) {
    final requirements = provisioningStatus['requirements'];
    if (requirements is! List) {
      return false;
    }
    for (final requirement in requirements) {
      if (requirement is! Map) {
        continue;
      }
      final item = requirement.cast<String, dynamic>();
      if (item['name']?.toString() == 'adb_enabled') {
        return item['granted'] != true;
      }
    }
    return false;
  }

  Future<bool?> _showAdbLocalOnboardingDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final okLabel = MaterialLocalizations.of(context).okButtonLabel;
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(localizations.adbLocalOnboardingTitle),
          content: Text(localizations.adbLocalOnboardingMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(okLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdbLocalOnboardingFallbackDialog(
    BuildContext context,
  ) async {
    final localizations = AppLocalizations.of(context)!;
    final action = await showDialog<_AdbLocalOnboardingFallbackAction>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.adbLocalOnboardingFallbackTitle),
        content: Text(localizations.adbLocalOnboardingFallbackMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              _AdbLocalOnboardingFallbackAction.later,
            ),
            child: Text(localizations.adbLocalOnboardingLater),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              _AdbLocalOnboardingFallbackAction.systemSettings,
            ),
            child: Text(localizations.systemSettings),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              _AdbLocalOnboardingFallbackAction.permissionsPanel,
            ),
            child: Text(localizations.adbLocalOnboardingOpenPermissionsPanel),
          ),
        ],
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _AdbLocalOnboardingFallbackAction.systemSettings:
        await _systemBridgeService?.openSpecificSettingsPage('system');
        break;
      case _AdbLocalOnboardingFallbackAction.permissionsPanel:
        await _showLauncherSettingsPanel(
          selectedRouteOnShell: PermissionsPanelPage.routeName,
          autoFocusDetailOnOpen: true,
        );
        break;
      case _AdbLocalOnboardingFallbackAction.later:
        break;
    }
  }

  Future<void> _showLauncherSettingsPanel({
    String? selectedRouteOnShell,
    bool autoFocusDetailOnOpen = false,
    String? benchmarkSessionId,
  }) async {
    final rootContext = _navigatorKey.currentContext;
    if (rootContext == null || !mounted) {
      return;
    }
    final wallpaperService = rootContext.read<WallpaperService>();
    wallpaperService.cancelPendingHomeVideoStart();
    await showDialog<void>(
      context: rootContext,
      useRootNavigator: true,
      builder: (_) => SettingsPanel(
        selectedRouteOnShell: selectedRouteOnShell,
        autoFocusDetailOnOpen: autoFocusDetailOnOpen,
        benchmarkSessionId: benchmarkSessionId,
      ),
    );
    if (!mounted || !rootContext.mounted) {
      return;
    }
    wallpaperService.notifyHomeVisibleAndUsable();
    _scheduleAdbLocalOnboardingCheck();
  }

  int _readHomeSequence(SystemBridgeService bridgeService) {
    final navigation = bridgeService.navigationStatus;
    return ((navigation['homeSequence'] as num?) ?? 0).toInt();
  }

  _BenchmarkSnapshot _readBenchmarkCommand(
    SystemBridgeService bridgeService,
  ) {
    final raw = bridgeService.status['benchmarkCommand'];
    final map = raw is Map ? raw.cast<String, dynamic>() : null;
    return (
      sequence: ((map?['sequence'] as num?) ?? 0).toInt(),
      action: map?['action']?.toString() ?? '',
      route: map?['route']?.toString() ?? '',
      sessionId: map?['sessionId']?.toString() ?? '',
      autoFocusDetail: map?['autoFocusDetail'] == true,
      bypassSettingsSecurity: map?['bypassSettingsSecurity'] == true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Locale? locale = context.select<SettingsService, Locale?>((service) {
      switch (service.appLocaleMode) {
        case SettingsService.appLocaleEnglish:
          return const Locale('en');
        case SettingsService.appLocaleVietnamese:
          return const Locale('vi');
        default:
          return null;
      }
    });

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5AA9FF),
      brightness: Brightness.dark,
      surface: const Color(0xFF0E1A29),
      primary: const Color(0xFF5AA9FF),
      secondary: const Color(0xFF8BE0B7),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      locale: locale,
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.escape): _backIntents,
        const SingleActivator(LogicalKeyboardKey.gameButtonB): _backIntents,
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent()
      },
      actions: {
        ...WidgetsApp.defaultActions,
        BackIntent: BackAction(context),
        DirectionalFocusIntent: SoundFeedbackDirectionalFocusAction(context)
      },
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        primarySwatch: _swatch,
        cardColor: const Color(0xFF13263B),
        canvasColor: const Color(0xFF13263B),
        dialogBackgroundColor: const Color(0xFF0E1A29),
        scaffoldBackgroundColor: const Color(0xFF0E1A29),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2A6BD8),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: Colors.white70,
        ),
        appBarTheme: const AppBarTheme(
            elevation: 0, backgroundColor: Colors.transparent),
        typography: Typography.material2018(),
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white)),
          labelStyle: Typography.material2018().white.bodyMedium,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionColor: _swatch[200],
          selectionHandleColor: _swatch[200],
        ),
      ),
      home: Builder(
          builder: (context) => PopScope(
              canPop: false,
              child: FLauncher(),
              onPopInvokedWithResult: (didPop, _) {
                LauncherState launcherState = context.read<LauncherState>();
                launcherState.handleBackNavigation(context);
              })),
    );
  }
}

typedef _BenchmarkSnapshot = ({
  int sequence,
  String action,
  String route,
  String sessionId,
  bool autoFocusDetail,
  bool bypassSettingsSecurity,
});

enum _AdbLocalOnboardingFallbackAction {
  systemSettings,
  permissionsPanel,
  later,
}
