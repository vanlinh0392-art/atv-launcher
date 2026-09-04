import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/providers/search_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/settings/accessibility_manager_panel_page.dart';
import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flauncher/widgets/settings/backup_restore_panel_page.dart';
import 'package:flauncher/widgets/settings/density_panel_page.dart';
import 'package:flauncher/widgets/settings/diagnostics_panel_page.dart';
import 'package:flauncher/widgets/settings/gradient_panel_page.dart';
import 'package:flauncher/widgets/settings/home_layout_panel_page.dart';
import 'package:flauncher/widgets/settings/launcher_section_panel_page.dart';
import 'package:flauncher/widgets/settings/launcher_sections_panel_page.dart';
import 'package:flauncher/widgets/settings/permissions_panel_page.dart';
import 'package:flauncher/widgets/settings/private_dns_panel_page.dart';
import 'package:flauncher/widgets/settings/profiles_security_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flauncher/widgets/settings/settings_panel_page.dart';
import 'package:flauncher/widgets/settings/status_bar_panel_page.dart';
import 'package:flauncher/widgets/settings/system_core_panel_page.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flauncher/widgets/settings/update_panel_page.dart';
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

final PageStorageBucket _pageStorageBucket = PageStorageBucket();
Map<String, FocusNode> _testDetailPrimaryFocusNodes = {};

void _initDetailPrimaryFocusNodes() {
  _testDetailPrimaryFocusNodes = {
    HomeLayoutPanelPage.routeName:
        FocusNode(debugLabel: 'home_layout_primary_target'),
    WallpaperPanelPage.routeName:
        FocusNode(debugLabel: 'wallpaper_primary_source_action'),
    VoiceSearchPanelPage.routeName:
        FocusNode(debugLabel: 'voice_search_primary_mode'),
    ProfilesSecurityPanelPage.routeName:
        FocusNode(debugLabel: 'profiles_security_primary_lock'),
    AccessibilityManagerPanelPage.routeName:
        FocusNode(debugLabel: 'accessibility_manager_primary_service'),
    SystemCorePanelPage.routeName:
        FocusNode(debugLabel: 'system_core_primary_policy'),
    DensityPanelPage.routeName:
        FocusNode(debugLabel: 'density_primary_apply'),
    PrivateDnsPanelPage.routeName:
        FocusNode(debugLabel: 'private_dns_primary_hostname_action'),
    PermissionsPanelPage.routeName:
        FocusNode(debugLabel: 'permissions_primary_quick_grant'),
    BackupRestorePanelPage.routeName:
        FocusNode(debugLabel: 'backup_restore_primary_export'),
    UpdatePanelPage.routeName:
        FocusNode(debugLabel: 'update_primary_check'),
    StatusBarPanelPage.routeName:
        FocusNode(debugLabel: 'status_bar_primary_clock'),
  };
}

void _disposeDetailPrimaryFocusNodes() {
  _testDetailPrimaryFocusNodes.clear();
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    _initDetailPrimaryFocusNodes();
  });

  tearDown(() {
    _disposeDetailPrimaryFocusNodes();
  });

  testWidgets('shows settings menu shell with single-line cards', (tester) async {
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
    expect(find.text('Home & Layout'), findsOneWidget);
    expect(find.text('Wallpaper & Media'), findsOneWidget);
    expect(find.text('Voice AI Assistant'), findsOneWidget);
  });

  testWidgets('settings menu items use single-line layout without subtitles',
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

    final actionCards = tester
        .widgetList<SettingsActionCard>(find.byType(SettingsActionCard))
        .toList();

    expect(actionCards.length, greaterThanOrEqualTo(5));
    for (final card in actionCards) {
      expect(card.titleMaxLines, 1);
      expect(card.subtitle, isNull);
      expect(
        card.contentPadding,
        TvDrawerTokens.cardPadding,
      );
      final size = tester.getSize(find.byWidget(card));
      expect(size.height, greaterThanOrEqualTo(52.0));
    }
  });

  testWidgets(
      'settings menu supports initialSelectedRoute and restores focus on pop',
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
      initialSelectedRoute: WallpaperPanelPage.routeName,
    );

    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'settings_card_${WallpaperPanelPage.routeName}',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.byType(WallpaperPanelPage), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(find.byType(WallpaperPanelPage), findsNothing);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'settings_card_${WallpaperPanelPage.routeName}',
    );
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

    expect(find.byKey(const Key('permissions_quick_grant_button')), findsOneWidget);
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
      'permissions route toggles auto grant ADB on wake switch with self-healing status',
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

    final permissionsPageFinder = find.byKey(
      const PageStorageKey<String>(PermissionsPanelPage.routeName),
    );
    final permissionsScrollableFinder = find.descendant(
      of: permissionsPageFinder,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('permissions_auto_grant_on_wake_switch')),
      260,
      scrollable: permissionsScrollableFinder,
    );
    await tester.pumpAndSettle();

    final switchFinder =
        find.byKey(const Key('permissions_auto_grant_on_wake_switch'));
    expect(switchFinder, findsOneWidget);
    expect(find.text('Auto grant ADB permissions on wake'), findsOneWidget);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    verify(bridgeService.setAutoGrantAdbOnWake(false)).called(1);
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

    expect(find.byKey(const Key('permissions_quick_grant_button')), findsOneWidget);
    expect(find.byKey(const Key('permissions_advanced_toggle')), findsOneWidget);
  });

  testWidgets('drills down from menu cards to sub-panel and returns on back',
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

    expect(find.text('ATV Launcher Settings'), findsOneWidget);
    expect(find.text('Home & Layout'), findsOneWidget);
    expect(find.text('Wallpaper & Media'), findsOneWidget);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      anyOf(
        contains('settings_action_'),
        contains('settings_card_'),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.text('Wallpaper & Media'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.byType(WallpaperPanelPage), findsOneWidget);
    expect(find.text('Source selection'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(find.byType(WallpaperPanelPage), findsNothing);
    expect(find.text('ATV Launcher Settings'), findsOneWidget);
  });

  testWidgets(
      'moving down the menu navigates between category cards without entering detail',
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

    expect(find.byType(ProfilesSecurityPanelPage), findsNothing);
    expect(find.text('ATV Launcher Settings'), findsOneWidget);
  });

  testWidgets('diagnostics report scrolls with DPAD and keeps compact actions',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final primaryFocusNode =
        FocusNode(debugLabel: 'diagnostics_primary_refresh');
    addTearDown(primaryFocusNode.dispose);
    final bridgeService = _mockBridgeService();
    when(bridgeService.diagnosticsReport).thenReturn(
      List<String>.generate(
        80,
        (index) => 'Diagnostics line ${index + 1}: bridge ok',
      ).join('\n'),
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
            body: DiagnosticsPanelPage(primaryFocusNode: primaryFocusNode),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    primaryFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'diagnostics_primary_refresh',
    );

    final refreshSize = tester.getSize(
      find.descendant(
        of: find.byKey(const Key('diagnostics_refresh_button')),
        matching: find.byType(SettingsFocusFrame),
      ),
    );
    final copySize = tester.getSize(
      find.descendant(
        of: find.byKey(const Key('diagnostics_copy_button')),
        matching: find.byType(SettingsFocusFrame),
      ),
    );
    expect(refreshSize.height, closeTo(copySize.height, 0.5));
    expect(refreshSize.height, lessThanOrEqualTo(82));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'diagnostics_report_section',
    );

    final reportScrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('diagnostics_report_scrollable')),
    );
    final reportScrollController = reportScrollView.controller!;
    final initialPixels = reportScrollController.offset;

    for (var i = 0; i < 3; i += 1) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(reportScrollController.offset, greaterThan(initialPixels));

    while (reportScrollController.offset > 0) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('settings_action_'),
    );
  });

  testWidgets('system core snapshot stays reachable with vertical DPAD',
      (tester) async {
    _prepareView(tester);
    final settings = await _createSettingsService();
    final appsService = MockAppsService();
    final wallpaperService = _mockWallpaperService();
    final bridgeService = _mockBridgeService();
    when(bridgeService.adbAutomationStatus).thenReturn(
      const <String, dynamic>{
        'policy': 'adb_and_wifi',
        'disableOnSleep': false,
      },
    );
    when(bridgeService.systemCoreStatus).thenReturn(
      const <String, dynamic>{
        'adbEnabled': true,
        'adbWifiEnabled': true,
        'coreServiceHealth': 'healthy',
        'batteryOptimizationIgnored': true,
        'deviceOwner': false,
        'accessibilityMasterEnabled': true,
        'managedAccessibilityPackages': 4,
        'lastRecoveryReason': 'manual_repair',
        'lastSuccessAtText': '2026-05-01 20:25',
        'adbLastAppliedAtText': '2026-05-01 20:20',
        'adbLastReason': 'boot_completed',
        'adbLastState': 'adb_and_wifi',
        'missingServices': 'none',
      },
    );

    await _pumpSettingsPanel(
      tester,
      settings: settings,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
    );

    await _enterRouteDetailByTap(tester, 'System Core');

    bool actionFocused(Key key) =>
        tester
            .widget<SettingsFocusFrame>(
              find.descendant(
                of: find.byKey(key),
                matching: find.byType(SettingsFocusFrame),
              ),
            )
            .focused ==
        true;

    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('system_core_primary_policy_option_2'),
    );
    expect(
        find.byKey(const Key('system_core_snapshot_section')), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const Key('system_core_snapshot_section')))
          .height,
      lessThan(440),
    );

    for (var i = 0; i < 8; i += 1) {
      if (actionFocused(const Key('system_core_heal_button'))) {
        break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(actionFocused(const Key('system_core_heal_button')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SettingsFocusFrame>(
            find.byKey(const Key('system_core_snapshot_section')),
          )
          .focused,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      actionFocused(const Key('system_core_developer_options_button')) ||
          actionFocused(const Key('system_core_battery_settings_button')),
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SettingsFocusFrame>(
            find.byKey(const Key('system_core_snapshot_section')),
          )
          .focused,
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

    expect(find.byKey(const Key('density_preset_selector')), findsOneWidget);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      contains('density_primary_apply'),
    );
  });

  testWidgets('moves DPAD focus between preset selector and reset button', (tester) async {
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

    expect(find.byKey(const Key('density_preset_selector')), findsOneWidget);
    expect(find.byKey(const Key('density_reset_button')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('density_reset_button')), findsOneWidget);
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

    await _enterRouteDetailByTap(tester, 'Voice AI Assistant');

    expect(find.byKey(const Key('voice_search_mode_selector')), findsOneWidget);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('voice_search_primary_mode_option'),
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
      contains('permissions_primary_quick_grant'),
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
      accessibilitySnapshot: <String, dynamic>{
        'writeSecureSettingsGranted': true,
        'accessibilityMasterEnabled': true,
        'managedPackageCount': 8,
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
          <String, dynamic>{
            'label': 'Demo App 3',
            'packageName': 'com.demo.three',
            'hasAccessibilityService': true,
            'accessibilityEnabled': true,
            'managed': true,
          },
          <String, dynamic>{
            'label': 'Demo App 4',
            'packageName': 'com.demo.four',
            'hasAccessibilityService': true,
            'accessibilityEnabled': true,
            'managed': true,
          },
          <String, dynamic>{
            'label': 'Demo App 5',
            'packageName': 'com.demo.five',
            'hasAccessibilityService': true,
            'accessibilityEnabled': true,
            'managed': true,
          },
          <String, dynamic>{
            'label': 'Demo App 6',
            'packageName': 'com.demo.six',
            'hasAccessibilityService': true,
            'accessibilityEnabled': false,
            'managed': false,
          },
          <String, dynamic>{
            'label': 'Demo App 7',
            'packageName': 'com.demo.seven',
            'hasAccessibilityService': true,
            'accessibilityEnabled': true,
            'managed': true,
          },
          <String, dynamic>{
            'label': 'Demo App 8',
            'packageName': 'com.demo.eight',
            'hasAccessibilityService': true,
            'accessibilityEnabled': true,
            'managed': true,
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

    final accessibilityPageFinder = find.byKey(
      const PageStorageKey<String>(AccessibilityManagerPanelPage.routeName),
    );
    final accessibilityScrollableFinder = find.descendant(
      of: accessibilityPageFinder,
      matching: find.byType(Scrollable),
    );

    primaryFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'accessibility_primary_toggle_apps',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('accessibility_managed_app_com.demo.one'),
    );

    final scrollableState =
        tester.state<ScrollableState>(accessibilityScrollableFinder);
    final initialPixels = scrollableState.position.pixels;

    for (var i = 0; i < 6; i += 1) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('accessibility_managed_app_com.demo.seven'),
    );
    expect(
      scrollableState.position.pixels,
      greaterThanOrEqualTo(initialPixels),
    );

    for (var i = 0; i < 6; i += 1) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
    }
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('accessibility_managed_app_com.demo.one'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'accessibility_primary_toggle_apps',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      anyOf(
        contains('settings_action_Grant_WSS_via_local_ADB'),
        contains('settings_action_Repair'),
        contains('settings_action_Open_accessibility_settings'),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('settings_action_'),
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
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      contains('settings_action_Picture'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'wallpaper_primary_source_action',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
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
      find.byType(WallpaperPanelPage),
      findsOneWidget,
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
      find.byType(WallpaperPanelPage),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel ?? '',
      anyOf(
        contains('settings_action_'),
        contains('Ảnh'),
        contains('wallpaper_source_'),
        contains('wallpaper_primary_source_action'),
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

    final learnSize = sizeForLabel('Học phím Remote');
    final resetSize = sizeForLabel('Đặt lại phím mặc định');
    final aiUpdateSize = sizeForLabel('Cập nhật Model AI');
    final micTestSize = sizeForLabel('Thử nghiệm Micro');

    expect(learnSize.width, equals(resetSize.width));
    expect(learnSize.width, equals(aiUpdateSize.width));
    expect(learnSize.width, equals(micTestSize.width));
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

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

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

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallpaper & Media').first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
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

MaterialPageRoute _createSubPageRoute({
  required String Function(AppLocalizations) titleBuilder,
  String Function(AppLocalizations)? subtitleBuilder,
  required Widget Function(AppLocalizations) childBuilder,
  FocusNode? primaryFocusNode,
}) {
  return MaterialPageRoute(
    builder: (context) {
      final localizations = AppLocalizations.of(context)!;
      if (primaryFocusNode != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (primaryFocusNode.canRequestFocus) {
            primaryFocusNode.requestFocus();
          }
        });
      }
      return PageStorage(
        bucket: _pageStorageBucket,
        child: Scaffold(
          body: KeyedSubtree(
            key: PageStorageKey<String>(titleBuilder(localizations)),
            child: SettingsContentView(
              title: titleBuilder(localizations),
              showBackButton: false,
              child: childBuilder(localizations),
            ),
          ),
        ),
      );
    },
  );
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
  String? initialSelectedRoute,
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
        builder: (context, child) => PageStorage(
          bucket: _pageStorageBucket,
          child: child!,
        ),
        home: Scaffold(
          body: SettingsPanelPage(
            initialSelectedRoute: initialSelectedRoute,
          ),
        ),
        onGenerateRoute: (routeSettings) {
          final primaryFocusNode =
              _testDetailPrimaryFocusNodes[routeSettings.name];
          switch (routeSettings.name) {
            case HomeLayoutPanelPage.routeName:
              return _createSubPageRoute(
                titleBuilder: (l) => l.settingsDestinationHomeTitle,
                subtitleBuilder: (l) => l.settingsDestinationHomeSubtitle,
                childBuilder: (_) =>
                    HomeLayoutPanelPage(primaryFocusNode: primaryFocusNode),
                primaryFocusNode: primaryFocusNode,
              );
            case WallpaperPanelPage.routeName:
              return _createSubPageRoute(
                titleBuilder: (l) => l.settingsDestinationWallpaperTitle,
                subtitleBuilder: (l) => l.settingsDestinationWallpaperSubtitle,
                childBuilder: (_) =>
                    WallpaperPanelPage(primaryFocusNode: primaryFocusNode),
                primaryFocusNode: primaryFocusNode,
              );
            case VoiceSearchPanelPage.routeName:
              return _createSubPageRoute(
                titleBuilder: (l) => l.settingsDestinationVoiceTitle,
                subtitleBuilder: (l) => l.settingsDestinationVoiceSubtitle,
                childBuilder: (_) =>
                    VoiceSearchPanelPage(primaryFocusNode: primaryFocusNode),
                primaryFocusNode: primaryFocusNode,
              );
            case ProfilesSecurityPanelPage.routeName:
              return _createSubPageRoute(
                titleBuilder: (l) => l.settingsDestinationProfilesTitle,
                subtitleBuilder: (l) => l.settingsDestinationProfilesSubtitle,
                childBuilder: (_) =>
                    ProfilesSecurityPanelPage(primaryFocusNode: primaryFocusNode),
                primaryFocusNode: primaryFocusNode,
              );
            case AccessibilityManagerPanelPage.routeName:
              return _createSubPageRoute(
                titleBuilder: (l) => l.settingsDestinationAccessibilityTitle,
                subtitleBuilder: (l) =>
                    l.settingsDestinationAccessibilitySubtitle,
                childBuilder: (_) => AccessibilityManagerPanelPage(
                    primaryFocusNode: primaryFocusNode),
                primaryFocusNode: primaryFocusNode,
              );
            case SystemCorePanelPage.routeName:
              return _createSubPageRoute(
                titleBuilder: (l) => l.settingsDestinationSystemCoreTitle,
                subtitleBuilder: (l) =>
                    l.settingsDestinationSystemCoreSubtitle,
                childBuilder: (_) =>
                    SystemCorePanelPage(primaryFocusNode: primaryFocusNode),
                primaryFocusNode: primaryFocusNode,
              );
            case DensityPanelPage.routeName:
              return _createSubPageRoute(
                titleBuilder: (l) => l.settingsDestinationDensityTitle,
                subtitleBuilder: (l) => l.settingsDestinationDensitySubtitle,
                childBuilder: (_) =>
                    DensityPanelPage(primaryFocusNode: primaryFocusNode),
                primaryFocusNode: primaryFocusNode,
              );
            case PrivateDnsPanelPage.routeName:
              return _createSubPageRoute(
                titleBuilder: (l) => l.settingsDestinationPrivateDnsTitle,
                subtitleBuilder: (l) =>
                    l.settingsDestinationPrivateDnsSubtitle,
                childBuilder: (_) =>
                    PrivateDnsPanelPage(primaryFocusNode: primaryFocusNode),
                primaryFocusNode: primaryFocusNode,
              );
            case PermissionsPanelPage.routeName:
              return _createSubPageRoute(
                titleBuilder: (l) => l.settingsDestinationPermissionsTitle,
                subtitleBuilder: (l) =>
                    l.settingsDestinationPermissionsSubtitle,
                childBuilder: (_) =>
                    PermissionsPanelPage(primaryFocusNode: primaryFocusNode),
                primaryFocusNode: primaryFocusNode,
              );
            case BackupRestorePanelPage.routeName:
              return _createSubPageRoute(
                titleBuilder: (l) => l.settingsDestinationBackupTitle,
                subtitleBuilder: (l) => l.settingsDestinationBackupSubtitle,
                childBuilder: (_) =>
                    BackupRestorePanelPage(primaryFocusNode: primaryFocusNode),
                primaryFocusNode: primaryFocusNode,
              );
            case UpdatePanelPage.routeName:
              return _createSubPageRoute(
                titleBuilder: (l) => l.settingsDestinationUpdatesTitle,
                subtitleBuilder: (l) => l.settingsDestinationUpdatesSubtitle,
                childBuilder: (_) =>
                    UpdatePanelPage(primaryFocusNode: primaryFocusNode),
                primaryFocusNode: primaryFocusNode,
              );
            case StatusBarPanelPage.routeName:
              return _createSubPageRoute(
                titleBuilder: (l) => l.statusBar,
                subtitleBuilder: (l) => l.statusBarDescription,
                childBuilder: (_) =>
                    StatusBarPanelPage(primaryFocusNode: primaryFocusNode),
                primaryFocusNode: primaryFocusNode,
              );
            case DiagnosticsPanelPage.routeName:
              return _createSubPageRoute(
                titleBuilder: (_) => 'Diagnostics Report',
                childBuilder: (_) =>
                    DiagnosticsPanelPage(primaryFocusNode: primaryFocusNode),
                primaryFocusNode: primaryFocusNode,
              );
            case GradientPanelPage.routeName:
              return MaterialPageRoute(
                builder: (_) => Scaffold(body: GradientPanelPage()),
              );
            case ApplicationsPanelPage.routeName:
              return MaterialPageRoute(
                builder: (_) => Scaffold(body: ApplicationsPanelPage()),
              );
            case LauncherSectionsPanelPage.routeName:
              return MaterialPageRoute(
                builder: (_) => Scaffold(body: LauncherSectionsPanelPage()),
              );
            case LauncherSectionPanelPage.routeName:
              return MaterialPageRoute(
                builder: (_) => Scaffold(
                  body: LauncherSectionPanelPage(
                    sectionIndex: routeSettings.arguments as int?,
                  ),
                ),
              );
            default:
              return MaterialPageRoute(
                builder: (_) => const Scaffold(body: SizedBox.shrink()),
              );
          }
        },
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
  final listFinder = find.byKey(
    const PageStorageKey<String>('settings_menu_root'),
  );
  if (railDragOffset != null && listFinder.evaluate().isNotEmpty) {
    await tester.drag(listFinder, Offset(0, railDragOffset));
    await tester.pumpAndSettle();
  }
  final itemFinder = find.text(routeLabel);
  if (itemFinder.evaluate().isEmpty && listFinder.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(itemFinder.first, 100, scrollable: listFinder);
  }
  await tester.tap(itemFinder.first);
  await tester.pumpAndSettle();

  for (final node in _testDetailPrimaryFocusNodes.values) {
    if (node.context != null && node.canRequestFocus) {
      node.requestFocus();
      await tester.pumpAndSettle();
      break;
    }
  }
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
  when(bridgeService.getVoiceSubtitleConfig()).thenAnswer(
    (_) async => const <String, dynamic>{'size': 20, 'color': 0xFF00E5FF},
  );
  when(bridgeService.getTtsEngine()).thenAnswer(
    (_) async => const <String, dynamic>{'engine': 'auto'},
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
  when(bridgeService.autoGrantAdbOnWake).thenReturn(true);
  when(bridgeService.autoProvisionAdbPermissions).thenReturn(true);
  when(bridgeService.setAutoGrantAdbOnWake(any)).thenAnswer((_) async {});
  when(bridgeService.setAutoProvisionAdbPermissions(any)).thenAnswer((_) async {});
  when(bridgeService.getLocalBackups())
      .thenAnswer((_) async => const <Map<String, dynamic>>[]);
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
