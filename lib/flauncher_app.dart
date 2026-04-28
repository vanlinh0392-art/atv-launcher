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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'flauncher.dart';

class FLauncherApp extends StatelessWidget {
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

  const FLauncherApp();

  @override
  Widget build(BuildContext context) {
    AppsService appsService = context.read<AppsService>();
    LauncherState launcherState = context.read<LauncherState>();
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
    launcherState.refresh(appsService);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5AA9FF),
      brightness: Brightness.dark,
      surface: const Color(0xFF0E1A29),
      primary: const Color(0xFF5AA9FF),
      secondary: const Color(0xFF8BE0B7),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
