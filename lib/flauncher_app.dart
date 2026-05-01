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

import 'package:flauncher/actions.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/settings/home_layout_panel_page.dart';
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
        return;
      }
    }
    if (benchmark.sequence > _lastHandledBenchmarkSequence) {
      _lastHandledBenchmarkSequence = benchmark.sequence;
      _handleBenchmarkCommand(benchmark);
    }
    final nextSequence = _readHomeSequence(bridgeService);
    if (nextSequence <= _lastHandledHomeSequence) {
      return;
    }
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
    });
  }

  void _handleBenchmarkCommand(_BenchmarkSnapshot benchmark) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final navigator = _navigatorKey.currentState;
      final rootContext = _navigatorKey.currentContext;
      navigator?.popUntil((route) => route.isFirst);
      if (benchmark.action != 'open_launcher_settings' ||
          rootContext == null ||
          !benchmark.bypassSettingsSecurity) {
        return;
      }
      final wallpaperService = rootContext.read<WallpaperService>();
      wallpaperService.cancelPendingHomeVideoStart();
      Future<void>.microtask(() {
        if (!mounted) {
          return;
        }
        showDialog<void>(
          context: rootContext,
          useRootNavigator: true,
          builder: (_) => SettingsPanel(
            selectedRouteOnShell: benchmark.route.isEmpty
                ? HomeLayoutPanelPage.routeName
                : benchmark.route,
            autoFocusDetailOnOpen: benchmark.autoFocusDetail,
            benchmarkSessionId: benchmark.sessionId,
          ),
        ).whenComplete(() {
          if (!mounted || !rootContext.mounted) {
            return;
          }
          wallpaperService.notifyHomeVisibleAndUsable();
        });
      });
    });
  }

  int _readHomeSequence(SystemBridgeService bridgeService) {
    final navigation = bridgeService.status['navigation'];
    final map = navigation is Map ? navigation.cast<String, dynamic>() : null;
    return ((map?['homeSequence'] as num?) ?? 0).toInt();
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
