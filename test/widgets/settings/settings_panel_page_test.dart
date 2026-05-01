import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/providers/search_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/settings/accessibility_manager_panel_page.dart';
import 'package:flauncher/widgets/settings/permissions_panel_page.dart';
import 'package:flauncher/widgets/settings/profiles_security_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flauncher/widgets/settings/settings_panel_page.dart';
import 'package:flauncher/widgets/settings/voice_search_panel_page.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks.mocks.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('shows master-detail settings shell', (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    expect(find.text('ATV Launcher Settings'), findsOneWidget);
    expect(find.text('Control Center'), findsOneWidget);
    expect(find.text('Home & Layout'), findsOneWidget);
  });

  testWidgets('switches to Wallpaper & Media section from the rail',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await tester.tap(find.text('Wallpaper & Media').first);
    await tester.pumpAndSettle();

    expect(find.text('Wallpaper & Media'), findsOneWidget);
    expect(find.text('Source selection'), findsOneWidget);
    expect(find.text('Single video'), findsOneWidget);
  });

  testWidgets('switches to Permissions & Provisioning section from the rail',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permissions & Provisioning').first);
    await tester.pumpAndSettle();

    expect(find.text('Provisioning Wizard'), findsAtLeastNWidgets(1));
    expect(find.text('Grant via local ADB'), findsOneWidget);
  });

  testWidgets(
      'quick grant attempts provisioning first, then shows ADB guidance',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();
    when(
      bridgeService.runProvisioningAction(
        action: anyNamed('action'),
        suggestedPolicy: anyNamed('suggestedPolicy'),
      ),
    ).thenAnswer((_) async => const <String, dynamic>{
          'success': false,
          'requiresAdbSetup': true,
          'message':
              'ADB is disabled. Enable Developer options and retry the local ADB grant.',
        });

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permissions & Provisioning').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('permissions_quick_grant_button')));
    await tester.pumpAndSettle();

    verify(
      bridgeService.runProvisioningAction(
        action: 'grant_all_local_adb',
        suggestedPolicy: 'adb_and_wifi',
      ),
    ).called(1);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Open developer options'), findsWidgets);
  });

  testWidgets(
      'quick grant shows local ADB authorization guidance when auth is pending',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService(
      provisioningStatus: const <String, dynamic>{
        'requirements': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'adb_enabled', 'granted': true},
        ],
        'commands': <String>[],
      },
    );
    when(
      bridgeService.runProvisioningAction(
        action: anyNamed('action'),
        suggestedPolicy: anyNamed('suggestedPolicy'),
      ),
    ).thenAnswer((_) async => const <String, dynamic>{
          'success': false,
          'requiresAdbAuthorization': true,
          'message':
              'Local ADB is waiting for authorization. If the TV shows an ADB prompt for unknown@unknown, allow it and try again.',
        });

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permissions & Provisioning').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('permissions_quick_grant_button')));
    await tester.pumpAndSettle();

    verify(
      bridgeService.runProvisioningAction(
        action: 'grant_all_local_adb',
        suggestedPolicy: 'adb_and_wifi',
      ),
    ).called(1);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Approve local ADB on TV'), findsOneWidget);
    expect(
      find.text(
        'If the TV shows an ADB prompt for unknown@unknown, choose Allow and run Grant via local ADB again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('quick grant runs local ADB provisioning when ADB is enabled',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService(
      provisioningStatus: const <String, dynamic>{
        'requirements': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'adb_enabled', 'granted': true},
          <String, dynamic>{'name': 'adb_wifi_enabled', 'granted': false},
        ],
        'commands': <String>[],
      },
    );
    when(
      bridgeService.runProvisioningAction(
        action: anyNamed('action'),
        suggestedPolicy: anyNamed('suggestedPolicy'),
      ),
    ).thenAnswer((_) async => const <String, dynamic>{
          'success': true,
          'message': 'Provisioned',
        });

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permissions & Provisioning').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('permissions_quick_grant_button')));
    await tester.pumpAndSettle();

    verify(
      bridgeService.runProvisioningAction(
        action: 'grant_all_local_adb',
        suggestedPolicy: 'adb_and_wifi',
      ),
    ).called(1);
  });

  testWidgets(
      'permissions advanced section stays collapsed until explicitly expanded',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService(
      provisioningStatus: const <String, dynamic>{
        'health': 'missing_required',
        'missingRequiredCount': 1,
        'missingRecommendedCount': 0,
        'requirements': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'adb_enabled', 'granted': true},
          <String, dynamic>{'name': 'overlay', 'granted': false},
        ],
        'commands': <String>[
          'adb shell pm grant com.atv.launcher android.permission.TEST_PERMISSION',
        ],
      },
    );

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permissions & Provisioning').first);
    await tester.pumpAndSettle();

    final permissionsPageFinder = find.byKey(
      const PageStorageKey<String>(PermissionsPanelPage.routeName),
    );
    final permissionsScrollableFinder = find.descendant(
      of: permissionsPageFinder,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('permissions_advanced_toggle')),
      260,
      scrollable: permissionsScrollableFinder,
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('permissions_advanced_toggle')), findsOneWidget);
    final advancedToggleFrame = tester.widget<SettingsFocusFrame>(
      find.descendant(
        of: find.byKey(const Key('permissions_advanced_toggle')),
        matching: find.byType(SettingsFocusFrame),
      ),
    );
    expect(advancedToggleFrame.variant, SettingsFocusFrameVariant.rowOnly);
    expect(
      find.text(
        'adb shell pm grant com.atv.launcher android.permission.TEST_PERMISSION',
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('permissions_advanced_toggle')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'adb shell pm grant com.atv.launcher android.permission.TEST_PERMISSION',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'permissions advanced requirements become focusable and scroll with DPAD',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService(
      provisioningStatus: const <String, dynamic>{
        'health': 'missing_required',
        'missingRequiredCount': 4,
        'missingRecommendedCount': 2,
        'requirements': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'android.permission.WRITE_SECURE_SETTINGS',
            'granted': false,
            'importance': 'required',
          },
          <String, dynamic>{
            'name': 'adb_enabled',
            'granted': false,
            'importance': 'required',
          },
          <String, dynamic>{
            'name': 'adb_wifi_enabled',
            'granted': false,
            'importance': 'recommended',
          },
          <String, dynamic>{
            'name': 'request_install_packages',
            'granted': false,
            'importance': 'recommended',
          },
          <String, dynamic>{
            'name': 'ignore_battery_optimizations',
            'granted': false,
            'importance': 'required',
          },
          <String, dynamic>{
            'name': 'device_owner',
            'granted': false,
            'importance': 'optional',
          },
          <String, dynamic>{
            'name': 'android.permission.WRITE_SETTINGS',
            'granted': true,
            'importance': 'required',
          },
          <String, dynamic>{
            'name': 'android.permission.SYSTEM_ALERT_WINDOW',
            'granted': true,
            'importance': 'required',
          },
          <String, dynamic>{
            'name': 'android.permission.READ_MEDIA_VIDEO',
            'granted': true,
            'importance': 'recommended',
          },
          <String, dynamic>{
            'name': 'post_notifications',
            'granted': true,
            'importance': 'optional',
          },
        ],
        'commands': <String>[],
      },
    );

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permissions & Provisioning').first);
    await tester.pumpAndSettle();

    final permissionsPageFinder = find.byKey(
      const PageStorageKey<String>(PermissionsPanelPage.routeName),
    );
    final permissionsScrollableFinder = find.descendant(
      of: permissionsPageFinder,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('permissions_advanced_toggle')),
      260,
      scrollable: permissionsScrollableFinder,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('permissions_advanced_toggle')));
    await tester.pumpAndSettle();

    final advancedToggleFocus = tester
        .widgetList<Focus>(
          find.descendant(
            of: find.byKey(const Key('permissions_advanced_toggle')),
            matching: find.byType(Focus),
          ),
        )
        .firstWhere((focus) =>
            focus.focusNode?.debugLabel == 'permissions_advanced_toggle');
    advancedToggleFocus.focusNode!.requestFocus();
    await tester.pumpAndSettle();

    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'permissions_advanced_toggle',
    );

    final scrollableState =
        tester.state<ScrollableState>(permissionsScrollableFinder);
    final initialPixels = scrollableState.position.pixels;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('permission_requirement_'),
    );

    for (var i = 0; i < 5; i += 1) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }

    expect(scrollableState.position.pixels, greaterThan(initialPixels));
  });

  testWidgets(
      'permissions route surfaces missing requirement names with importance colors',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService(
      provisioningStatus: const <String, dynamic>{
        'health': 'missing_required',
        'missingRequiredCount': 1,
        'missingRecommendedCount': 1,
        'missingOptionalCount': 1,
        'requirements': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'android.permission.WRITE_SECURE_SETTINGS',
            'granted': false,
            'importance': 'required',
          },
          <String, dynamic>{
            'name': 'request_install_packages',
            'granted': false,
            'importance': 'recommended',
          },
          <String, dynamic>{
            'name': 'device_owner',
            'granted': false,
            'importance': 'optional',
          },
        ],
        'commands': <String>[],
      },
    );

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await _enterRouteDetailByTap(
      tester,
      'Permissions & Provisioning',
      railDragOffset: -720,
    );

    expect(find.text('Missing permissions and setup items'), findsOneWidget);

    final requiredChipFinder = find.byWidgetPredicate(
      (widget) =>
          widget is SettingsStatusChip &&
          widget.label == 'WRITE_SECURE_SETTINGS',
    );
    final recommendedChipFinder = find.byWidgetPredicate(
      (widget) =>
          widget is SettingsStatusChip &&
          widget.label == 'Install unknown apps',
    );
    final optionalChipFinder = find.byWidgetPredicate(
      (widget) =>
          widget is SettingsStatusChip && widget.label == 'Device owner',
    );

    expect(requiredChipFinder, findsOneWidget);
    expect(recommendedChipFinder, findsOneWidget);
    expect(optionalChipFinder, findsOneWidget);
    expect(
      tester.widget<SettingsStatusChip>(requiredChipFinder).color,
      const Color(0xFFFF8A80),
    );
    expect(
      tester.widget<SettingsStatusChip>(recommendedChipFinder).color,
      const Color(0xFFFFC970),
    );
    expect(
      tester.widget<SettingsStatusChip>(optionalChipFinder).color,
      const Color(0xFF8CCBFF),
    );
  });

  testWidgets('keeps rail focused on open and enters detail on RIGHT',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    expect(find.text('App language'), findsAtLeastNWidgets(1));
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      contains('settings_rail_0'),
    );
    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isFalse,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('home_layout_target_appLocale_option_2'),
    );
    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isTrue,
    );

    for (var index = 0; index < 5; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      final label = tester.binding.focusManager.primaryFocus?.debugLabel ?? '';
      if (label.contains('settings_rail_0')) {
        break;
      }
    }

    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('settings_rail_0'),
    );
    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isFalse,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.text('Source selection'), findsOneWidget);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      contains('settings_rail_1'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'wallpaper_primary_source_action',
    );
    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isTrue,
    );

    for (var index = 0; index < 2; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      final highlighted = tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted;
      if (!highlighted) {
        break;
      }
    }
    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isFalse,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(find.text('Home & Layout'), findsAtLeastNWidgets(1));
    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isFalse,
    );
  });

  testWidgets(
      'moving down the rail does not auto-enter detail on profiles route',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    when(appsService.applications).thenReturn(const []);
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(
      find.byType(ProfilesSecurityPanelPage, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('settings_rail_3'),
    );
    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isFalse,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(
      find.byType(AccessibilityManagerPanelPage, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('settings_rail_4'),
    );
    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isFalse,
    );
  });

  testWidgets('enters Diagnostics with refresh button focused', (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diagnostics').first);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('diagnostics_refresh_button')), findsOneWidget);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'diagnostics_primary_refresh',
    );
    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isTrue,
    );
  });

  testWidgets('enters Display / DPI with Apply button focused', (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Display / DPI').first);
    await tester.pumpAndSettle();
    expect(find.text('Current DPI'), findsOneWidget);

    await tester.tap(find.text('Display / DPI').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('density_apply_button')), findsOneWidget);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'density_primary_apply',
    );
    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isTrue,
    );
  });

  testWidgets('enters Voice Search with press mode focused', (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await _enterRouteDetailByTap(tester, 'Voice & Search');

    expect(find.byKey(const Key('voice_search_mode_selector')), findsOneWidget);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('voice_search_primary_mode_option_0'),
    );
  });

  testWidgets('enters Private DNS with hostname action focused',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await _enterRouteDetailByTap(
      tester,
      'Network / Private DNS',
      railDragOffset: -620,
    );

    expect(find.text('Private DNS hostname'), findsOneWidget);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'private_dns_primary_hostname_action',
    );
  });

  testWidgets('enters Permissions with quick grant focused', (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await _enterRouteDetailByTap(
      tester,
      'Permissions & Provisioning',
      railDragOffset: -720,
    );

    expect(
      find.byKey(const Key('permissions_quick_grant_button')),
      findsOneWidget,
    );
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'permissions_primary_quick_grant',
    );
  });

  testWidgets('permissions actions stay reachable with vertical DPAD',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await _enterRouteDetailByTap(
      tester,
      'Permissions & Provisioning',
      railDragOffset: -720,
    );

    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'permissions_primary_quick_grant',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('Open_developer_options'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('Grant_media_access'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('Battery_access'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('Grant_media_access'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('Open_developer_options'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('permissions_primary_quick_grant'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('permissions_summary_header'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      anyOf(
        contains('permissions_summary_metrics'),
        contains('settings_metric_'),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'permissions_primary_quick_grant',
    );
  });

  testWidgets('accessibility managed apps stay reachable with vertical DPAD',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final primaryFocusNode =
        FocusNode(debugLabel: 'accessibility_primary_toggle_apps');
    addTearDown(primaryFocusNode.dispose);
    final bridgeService = _mockBridgeService(
      accessibilitySnapshot: const <String, dynamic>{
        'writeSecureSettingsGranted': true,
        'accessibilityMasterEnabled': true,
        'managedPackageCount': 3,
        'lastVerifyResult': 'ok',
        'apps': <Map<String, dynamic>>[
          <String, dynamic>{
            'label': 'Demo App 1',
            'packageName': 'com.demo.one',
            'hasAccessibilityService': true,
            'accessibilityEnabled': true,
            'managed': true,
          },
          <String, dynamic>{
            'label': 'Demo App 2',
            'packageName': 'com.demo.two',
            'hasAccessibilityService': true,
            'accessibilityEnabled': false,
            'managed': false,
          },
        ],
      },
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<SystemBridgeService>.value(
            value: bridgeService,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AccessibilityManagerPanelPage(
              primaryFocusNode: primaryFocusNode,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    primaryFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'accessibility_primary_toggle_apps',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('accessibility_managed_app_com.demo.one'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('accessibility_managed_app_com.demo.two'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('accessibility_managed_app_com.demo.one'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('settings_action_Open_accessibility_settings'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('settings_action_Repair'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      anyOf(
        contains('accessibility_summary_metrics'),
        contains('settings_metric_'),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'settings_action_Repair',
    );
  });

  testWidgets('enters Backup & Restore with export action focused',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await _enterRouteDetailByTap(
      tester,
      'Backup & Restore',
      railDragOffset: -820,
    );

    expect(find.text('Export backup'), findsOneWidget);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'backup_restore_primary_export',
    );
  });

  testWidgets(
      'Wallpaper source actions support horizontal DPAD movement and activation',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();
    final primaryFocusNode = FocusNode(
      debugLabel: 'wallpaper_primary_source_action',
    );
    addTearDown(primaryFocusNode.dispose);

    when(wallpaperService.pickImageWallpaper()).thenAnswer((_) async {});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<WallpaperService>.value(
            value: wallpaperService,
          ),
          ChangeNotifierProvider<SystemBridgeService>.value(
            value: bridgeService,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: WallpaperPanelPage(primaryFocusNode: primaryFocusNode),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    primaryFocusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'wallpaper_primary_source_action',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('settings_action_Picture'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    verify(wallpaperService.pickImageWallpaper()).called(1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'wallpaper_primary_source_action',
    );
  });

  testWidgets(
      'wallpaper action grids keep LEFT and RIGHT inside the detail pane across wrapped rows',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await _enterRouteDetailByTap(tester, 'Wallpaper & Media');

    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'wallpaper_primary_source_action',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('settings_action_Single_video'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('settings_action_Pick_multiple_videos'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('settings_action_Single_video'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('settings_action_Pick_folder'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('settings_action_Browse_TV_storage'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('settings_action_Pick_folder'),
    );

    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isTrue,
    );
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      isNot(contains('settings_rail_')),
    );
  });

  testWidgets(
      'Vietnamese wallpaper source grid keeps LEFT and UP inside the detail pane',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
      locale: const Locale('vi'),
    );

    await _enterRouteDetailByTap(tester, 'Hình nền & Media');

    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'wallpaper_primary_source_action',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('Ảnh'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'wallpaper_primary_source_action',
    );
    expect(
      tester
          .widget<SettingsSurfaceCard>(
            find.byKey(const Key('settings_detail_pane_card')),
          )
          .highlighted,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      anyOf(
        contains('wallpaper_summary_metrics'),
        contains('settings_metric_'),
      ),
    );
  });

  testWidgets(
      'settings panel suppresses wallpaper playback while mounted and releases on close',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    when(wallpaperService.setSettingsPlaybackSuppressed(true))
        .thenAnswer((_) async {});
    when(wallpaperService.setSettingsPlaybackSuppressed(false))
        .thenAnswer((_) async {});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<AppsService>.value(value: appsService),
          ChangeNotifierProvider<WallpaperService>.value(
            value: wallpaperService,
          ),
          ChangeNotifierProvider<SystemBridgeService>.value(
            value: bridgeService,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsPanel(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    verify(wallpaperService.setSettingsPlaybackSuppressed(true)).called(1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    verify(wallpaperService.setSettingsPlaybackSuppressed(false)).called(1);
  });

  testWidgets('accessibility action buttons keep uniform size', (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final bridgeService = _mockBridgeService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<SystemBridgeService>.value(
            value: bridgeService,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: AccessibilityManagerPanelPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Size sizeForLabel(String label) => tester.getSize(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(SettingsFocusFrame),
          ),
        );

    final repairSize = sizeForLabel('Repair');
    final grantSize = sizeForLabel('Grant WSS via local ADB');
    final openSettingsSize = sizeForLabel('Open accessibility settings');
    final showSize = sizeForLabel('Show managed accessibility apps');

    expect(repairSize.width, equals(grantSize.width));
    expect(repairSize.width, equals(openSettingsSize.width));
    expect(repairSize.width, equals(showSize.width));
    expect(repairSize.height, equals(grantSize.height));
    expect(repairSize.height, equals(openSettingsSize.height));
    expect(repairSize.height, equals(showSize.height));
    expect(tester.takeException(), isNull);
  });

  testWidgets('voice action buttons keep uniform size', (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final bridgeService = _mockBridgeService();
    final channel = MockFLauncherChannel();
    final searchService = SearchService(
      await SharedPreferences.getInstance(),
      channel,
    );

    when(channel.startSpeechRecognizer()).thenAnswer(
      (_) async => const <String, dynamic>{'text': 'hello'},
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<SystemBridgeService>.value(
            value: bridgeService,
          ),
          ChangeNotifierProvider<SearchService>.value(value: searchService),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: VoiceSearchPanelPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Size sizeForLabel(String label) => tester.getSize(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(SettingsFocusFrame),
          ),
        );

    final captureSize = sizeForLabel('Test speech capture');
    final learnSize = sizeForLabel('Learn remote key');
    final launchSize = sizeForLabel('Test voice launch');
    final resetSize = sizeForLabel('Reset Xiaomi default');
    final repairSize = sizeForLabel('Repair accessibility');
    final openSettingsSize = sizeForLabel('Open accessibility settings');

    expect(captureSize.width, equals(learnSize.width));
    expect(learnSize.width, equals(launchSize.width));
    expect(learnSize.width, equals(resetSize.width));
    expect(learnSize.width, equals(repairSize.width));
    expect(learnSize.width, equals(openSettingsSize.width));
    expect(captureSize.height, equals(learnSize.height));
    expect(learnSize.height, equals(launchSize.height));
    expect(learnSize.height, equals(resetSize.height));
    expect(learnSize.height, equals(repairSize.height));
    expect(learnSize.height, equals(openSettingsSize.height));
  });

  testWidgets(
      'voice search page adapts Vietnamese action card content without overflow',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final bridgeService = _mockBridgeService();
    final channel = MockFLauncherChannel();
    final searchService = SearchService(
      await SharedPreferences.getInstance(),
      channel,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<SystemBridgeService>.value(
            value: bridgeService,
          ),
          ChangeNotifierProvider<SearchService>.value(value: searchService),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: VoiceSearchPanelPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'mounts only the current detail page and keeps wallpaper scroll context',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    expect(
      find.byType(WallpaperPanelPage, skipOffstage: false),
      findsNothing,
    );

    await tester.tap(find.text('Wallpaper & Media').first);
    await tester.pumpAndSettle();

    expect(
      find.byType(WallpaperPanelPage, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byType(PermissionsPanelPage, skipOffstage: false),
      findsNothing,
    );

    final wallpaperPageFinder = find.byKey(
      const PageStorageKey<String>(WallpaperPanelPage.routeName),
    );
    final wallpaperScrollableFinder = find.descendant(
      of: wallpaperPageFinder,
      matching: find.byType(Scrollable),
    );
    final wallpaperScrollableState =
        tester.state<ScrollableState>(wallpaperScrollableFinder);
    final wallpaperTargetPixels =
        (wallpaperScrollableState.position.maxScrollExtent * 0.6)
            .clamp(120.0, 320.0)
            .toDouble();
    expect(wallpaperScrollableState.position.maxScrollExtent, greaterThan(0));
    wallpaperScrollableState.position.jumpTo(wallpaperTargetPixels);
    await tester.pumpAndSettle();
    final initialPixels = wallpaperScrollableState.position.pixels;
    expect(initialPixels, greaterThan(0));

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permissions & Provisioning').first);
    await tester.pumpAndSettle();

    expect(
      find.byType(WallpaperPanelPage, skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byType(PermissionsPanelPage, skipOffstage: false),
      findsOneWidget,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallpaper & Media').first);
    await tester.pumpAndSettle();

    final restoredPixels = tester
        .state<ScrollableState>(wallpaperScrollableFinder)
        .position
        .pixels;
    expect(restoredPixels, greaterThan(0));
    expect(restoredPixels, greaterThan(initialPixels * 0.35));

    expect(
      find.byType(WallpaperPanelPage, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byType(PermissionsPanelPage, skipOffstage: false),
      findsNothing,
    );
  });
}

Future<void> _pumpSettingsPanel(
  WidgetTester tester, {
  required SettingsService settings,
  required AppsService appsService,
  required WallpaperService wallpaperService,
  required SystemBridgeService bridgeService,
  ProfileSecurityService? securityService,
  SearchService? searchService,
  Locale locale = const Locale('en'),
}) async {
  final effectiveSecurityService = securityService ??
      ProfileSecurityService(await SharedPreferences.getInstance());
  final effectiveSearchService = searchService ??
      SearchService(
        await SharedPreferences.getInstance(),
        MockFLauncherChannel(),
      );
  if (appsService is MockAppsService) {
    when(appsService.homeReorderModeEnabled).thenReturn(false);
  }
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        ChangeNotifierProvider<AppsService>.value(value: appsService),
        ChangeNotifierProvider<WallpaperService>.value(value: wallpaperService),
        ChangeNotifierProvider<SystemBridgeService>.value(value: bridgeService),
        ChangeNotifierProvider<ProfileSecurityService>.value(
          value: effectiveSecurityService,
        ),
        ChangeNotifierProvider<SearchService>.value(
          value: effectiveSearchService,
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SettingsPanelPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterRouteDetailByTap(
  WidgetTester tester,
  String routeLabel, {
  double? railDragOffset,
}) async {
  final railFinder = find.byKey(
    const PageStorageKey<String>('settings_destination_rail'),
  );
  final railRouteFinder = find.descendant(
    of: railFinder,
    matching: find.text(routeLabel),
  );
  if (railDragOffset != null) {
    await tester.drag(railFinder, Offset(0, railDragOffset));
    await tester.pumpAndSettle();
  }
  await tester.tap(railRouteFinder.first);
  await tester.pumpAndSettle();
  await tester.tap(railRouteFinder.first);
  await tester.pumpAndSettle();
}

MockWallpaperService _mockWallpaperService() {
  final wallpaperService = MockWallpaperService();
  when(wallpaperService.wallpaperMode).thenReturn('gradient');
  when(wallpaperService.videoSourceType).thenReturn('single_file');
  when(wallpaperService.videoUris).thenReturn(const <String>[]);
  when(wallpaperService.wallpaperAssetUri).thenReturn('');
  when(wallpaperService.videoFolderName).thenReturn('');
  when(wallpaperService.isVideoMode).thenReturn(false);
  when(wallpaperService.videoBlockedByPerformanceMode).thenReturn(false);
  when(wallpaperService.videoAdvanceMode).thenReturn('on_completion');
  when(wallpaperService.videoRepeatCountPerItem).thenReturn(3);
  when(wallpaperService.videoOrderMode).thenReturn('sequential');
  when(wallpaperService.videoSwitchIntervalSeconds).thenReturn(30);
  when(wallpaperService.videoPlaylistLoop).thenReturn(true);
  when(wallpaperService.videoLoop).thenReturn(true);
  when(wallpaperService.videoMute).thenReturn(true);
  when(wallpaperService.videoAutoResume).thenReturn(true);
  when(wallpaperService.videoFit).thenReturn('center-crop');
  when(wallpaperService.videoBlur).thenReturn('off');
  when(wallpaperService.videoDimPercent).thenReturn(15);
  when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
  when(wallpaperService.pickImageWallpaper()).thenAnswer((_) async {});
  when(wallpaperService.pickVideoWallpaper()).thenAnswer((_) async {});
  when(wallpaperService.pickVideoWallpaperFilesSaf()).thenAnswer((_) async {});
  when(wallpaperService.pickVideoWallpaperFolderSaf()).thenAnswer((_) async {});
  when(wallpaperService.setVideoRepeatCountPerItem(any))
      .thenAnswer((_) async {});
  when(wallpaperService.setSettingsPlaybackSuppressed(true))
      .thenAnswer((_) async {});
  when(wallpaperService.setSettingsPlaybackSuppressed(false))
      .thenAnswer((_) async {});
  return wallpaperService;
}

MockSystemBridgeService _mockBridgeService({
  Map<String, dynamic>? provisioningStatus,
  Map<String, dynamic>? accessibilitySnapshot,
}) {
  final bridgeService = MockSystemBridgeService();
  when(bridgeService.diagnosticsReport).thenReturn('bridge ok');
  when(bridgeService.adbAutomationStatus)
      .thenReturn(const <String, dynamic>{'policy': 'adb_and_wifi'});
  when(bridgeService.systemCoreStatus)
      .thenReturn(const <String, dynamic>{'coreServiceHealth': 'healthy'});
  when(bridgeService.densityStatus).thenReturn(const <String, dynamic>{
    'currentDensity': 320,
    'factoryDensity': 320,
    'overrideDensity': '-',
    'executionPath': 'wm density',
  });
  when(bridgeService.voiceStatus).thenReturn(const <String, dynamic>{
    'mode': 0,
    'keyCode': 231,
    'health': 'healthy',
    'interceptEnabled': true,
    'defaultKeySummary': 'Double press voice key',
    'learningMode': false,
  });
  when(bridgeService.privateDnsStatus).thenReturn(const <String, dynamic>{
    'selectedHost': 'dns.adguard.com',
    'effectiveMode': 'hostname',
    'specifier': 'dns.adguard.com',
    'hasWriteSecureSettings': true,
  });
  when(bridgeService.accessibilitySnapshot).thenReturn(
    accessibilitySnapshot ??
        const <String, dynamic>{
          'writeSecureSettingsGranted': true,
          'accessibilityMasterEnabled': true,
          'managedPackageCount': 1,
          'lastVerifyResult': 'ok',
          'apps': <Map<String, dynamic>>[],
        },
  );
  when(bridgeService.refreshFull()).thenAnswer((_) async {});
  when(bridgeService.refreshAccessibilitySnapshot()).thenAnswer((_) async {});
  when(bridgeService.setVoiceInterceptEnabled(any)).thenAnswer(
    (_) async => const <String, dynamic>{},
  );
  when(bridgeService.startKeyLearning()).thenAnswer(
    (_) async => const <String, dynamic>{'message': 'ok'},
  );
  when(bridgeService.testVoiceSearch()).thenAnswer(
    (_) async => const <String, dynamic>{'message': 'ok'},
  );
  when(bridgeService.resetVoiceMapping()).thenAnswer(
    (_) async => const <String, dynamic>{'message': 'ok'},
  );
  when(
    bridgeService.runProvisioningAction(
      action: anyNamed('action'),
      suggestedPolicy: anyNamed('suggestedPolicy'),
    ),
  ).thenAnswer((_) async => const <String, dynamic>{'success': true});
  when(bridgeService.openAccessibilitySettings()).thenAnswer((_) async {});
  when(bridgeService.fileAccessStatus)
      .thenReturn(const <String, dynamic>{'hasMediaPermission': true});
  when(bridgeService.provisioningStatus).thenReturn(
    provisioningStatus ??
        const <String, dynamic>{
          'requirements': <Map<String, dynamic>>[],
          'commands': <String>[],
          'wizardSteps': <String>['Enable developer options', 'Run local ADB'],
        },
  );
  return bridgeService;
}

Future<SettingsService> _createSettingsService() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return SettingsService(await SharedPreferences.getInstance());
}

void _prepareView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
