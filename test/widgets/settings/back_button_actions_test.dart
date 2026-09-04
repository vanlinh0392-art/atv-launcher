import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/back_button_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService - Back Button Actions', () {
    test('defaults and updates backButtonLongPressAction correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);

      expect(settings.backButtonAction, BACK_BUTTON_ACTION_NOTHING);
      expect(settings.backButtonLongPressAction, BACK_BUTTON_ACTION_TOGGLE_MUTE);

      await settings.setBackButtonAction(BACK_BUTTON_ACTION_CLOCK);
      expect(settings.backButtonAction, BACK_BUTTON_ACTION_CLOCK);

      await settings.setBackButtonLongPressAction(BACK_BUTTON_ACTION_SLEEP);
      expect(settings.backButtonLongPressAction, BACK_BUTTON_ACTION_SLEEP);
    });

    test('exports and restores backButtonLongPressAction in backup payload', () async {
      SharedPreferences.setMockInitialValues({
        'back_button_action': BACK_BUTTON_ACTION_CLOCK,
        'back_button_long_press_action': BACK_BUTTON_ACTION_SLEEP,
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);

      final backup = settings.toBackupMap();
      expect(backup['backButtonAction'], BACK_BUTTON_ACTION_CLOCK);
      expect(backup['backButtonLongPressAction'], BACK_BUTTON_ACTION_SLEEP);

      SharedPreferences.setMockInitialValues({});
      final restoredPrefs = await SharedPreferences.getInstance();
      final restoredSettings = SettingsService(restoredPrefs);

      await restoredSettings.applyBackupMap(backup);
      expect(restoredSettings.backButtonAction, BACK_BUTTON_ACTION_CLOCK);
      expect(restoredSettings.backButtonLongPressAction, BACK_BUTTON_ACTION_SLEEP);
    });
  });

  group('LauncherState - Action Execution', () {
    testWidgets('handleBackLongPress triggers toggleMute on TOGGLE_MUTE action', (tester) async {
      SharedPreferences.setMockInitialValues({
        'back_button_long_press_action': BACK_BUTTON_ACTION_TOGGLE_MUTE,
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);
      final appsService = MockAppsService();
      final launcherState = LauncherState();

      when(appsService.toggleMute()).thenAnswer((_) async => {'success': true});
      when(appsService.applications).thenReturn([]);
      when(appsService.categories).thenReturn([]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider<AppsService>.value(value: appsService),
            ChangeNotifierProvider.value(value: launcherState),
          ],
          child: Builder(
            builder: (context) {
              return MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => launcherState.handleBackLongPress(context),
                      child: const Text('LongPressBack'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('LongPressBack'));
      await tester.pump();

      verify(appsService.toggleMute()).called(1);
    });

    testWidgets('handleBackSinglePress triggers startAmbientMode on SCREENSAVER action', (tester) async {
      SharedPreferences.setMockInitialValues({
        'back_button_action': BACK_BUTTON_ACTION_SCREENSAVER,
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);
      final appsService = MockAppsService();
      final launcherState = LauncherState();

      when(appsService.startAmbientMode()).thenAnswer((_) async {});
      when(appsService.applications).thenReturn([]);
      when(appsService.categories).thenReturn([]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider<AppsService>.value(value: appsService),
            ChangeNotifierProvider.value(value: launcherState),
          ],
          child: Builder(
            builder: (context) {
              return MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => launcherState.handleBackSinglePress(context),
                      child: const Text('SinglePressBack'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('SinglePressBack'));
      await tester.pump();

      verify(appsService.startAmbientMode()).called(1);
    });
  });
}
