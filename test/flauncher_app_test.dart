import 'package:flauncher/flauncher_app.dart';
import 'package:flauncher/flauncher.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/providers/search_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/settings/permissions_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks.mocks.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('applies locale overrides immediately', (tester) async {
    final settings = await _createSettingsService();
    final security = await _createProfileSecurityService();
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final bridgeService = MockSystemBridgeService();
    final channel = MockFLauncherChannel();
    final searchService = await _createSearchService(channel);

    when(appsService.initialized).thenReturn(true);
    when(appsService.homeReorderModeEnabled).thenReturn(false);
    when(appsService.launcherSections).thenReturn(const <LauncherSection>[]);
    when(appsService.isDefaultLauncher()).thenAnswer((_) async => true);
    when(wallpaperService.wallpaperMode).thenReturn('gradient');
    when(wallpaperService.wallpaper).thenReturn(null);
    when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
    when(wallpaperService.isVideoMode).thenReturn(false);
    when(wallpaperService.videoTextureId).thenReturn(null);
    when(wallpaperService.videoFit).thenReturn('center-crop');
    when(wallpaperService.videoBlur).thenReturn('off');
    when(wallpaperService.videoDimPercent).thenReturn(15);
    when(bridgeService.initialized).thenReturn(true);
    when(bridgeService.wallpaperStatus).thenReturn(const <String, dynamic>{});
    when(bridgeService.status).thenReturn(const <String, dynamic>{
      'memory': <String, dynamic>{},
      'provisioning': <String, dynamic>{},
    });
    when(bridgeService.provisioningStatus).thenReturn(const <String, dynamic>{
      'health': 'healthy',
      'requirements': <Map<String, dynamic>>[],
      'missingRequiredCount': 0,
      'missingRecommendedCount': 0,
    });
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WallpaperService>.value(
              value: wallpaperService),
          ChangeNotifierProvider<AppsService>.value(value: appsService),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<ProfileSecurityService>.value(value: security),
          ChangeNotifierProvider<SystemBridgeService>.value(
              value: bridgeService),
          ChangeNotifierProvider<SearchService>.value(value: searchService),
          ChangeNotifierProvider(create: (_) => LauncherState()),
          ChangeNotifierProvider(create: (_) => NetworkService(channel)),
        ],
        child: const FLauncherApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(_materialApp(tester).locale, const Locale('vi'));

    await settings.setAppLocaleMode(SettingsService.appLocaleEnglish);
    await tester.pumpAndSettle();
    expect(_materialApp(tester).locale, const Locale('en'));

    await settings.setAppLocaleMode(SettingsService.appLocaleVietnamese);
    await tester.pumpAndSettle();
    expect(_materialApp(tester).locale, const Locale('vi'));

    await settings.setAppLocaleMode(SettingsService.appLocaleSystem);
    await tester.pumpAndSettle();
    expect(_materialApp(tester).locale, isNull);
  });

  testWidgets(
      'fresh install with ADB disabled shows onboarding once and persists after OK',
      (tester) async {
    final settings = await _createSettingsService();
    final security = await _createProfileSecurityService();
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final bridgeService = MockSystemBridgeService();
    final channel = MockFLauncherChannel();
    final searchService = await _createSearchService(channel);
    final provisioningStatus = _buildProvisioningStatus(adbEnabled: false);

    when(appsService.initialized).thenReturn(true);
    when(appsService.homeReorderModeEnabled).thenReturn(false);
    when(appsService.launcherSections).thenReturn(const <LauncherSection>[]);
    when(appsService.isDefaultLauncher()).thenAnswer((_) async => true);
    when(bridgeService.initialized).thenReturn(true);
    when(bridgeService.wallpaperStatus).thenReturn(const <String, dynamic>{});
    when(bridgeService.status).thenReturn(<String, dynamic>{
      'memory': const <String, dynamic>{},
      'navigation': const <String, dynamic>{'homeSequence': 0, 'reason': ''},
      'provisioning': provisioningStatus,
      'install': _buildInstallStatus(freshInstall: true),
    });
    when(bridgeService.provisioningStatus).thenReturn(provisioningStatus);
    when(
      bridgeService.runProvisioningAction(
        action: anyNamed('action'),
        suggestedPolicy: anyNamed('suggestedPolicy'),
      ),
    ).thenAnswer((_) async => const <String, dynamic>{'success': true});
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});

    await _pumpLauncherApp(
      tester,
      settings: settings,
      security: security,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
      searchService: searchService,
      channel: channel,
    );

    expect(
        find.text(
            'Hãy bật ADB để launcher hoạt động đủ chức năng, sau đó quay lại menu cấp quyền ADB local'),
        findsOneWidget);

    final okLabel = MaterialLocalizations.of(
      tester.element(find.byType(AlertDialog)),
    ).okButtonLabel;
    await tester.tap(find.text(okLabel));
    await tester.pumpAndSettle();

    expect(settings.adbLocalOnboardingHandled, isTrue);
    verify(
      bridgeService.runProvisioningAction(
        action: 'open_development',
        suggestedPolicy: null,
      ),
    ).called(1);
    expect(
      find.text(
        'Hãy bật ADB để launcher hoạt động đủ chức năng, sau đó quay lại menu cấp quyền ADB local',
      ),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await _pumpLauncherApp(
      tester,
      settings: settings,
      security: security,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
      searchService: searchService,
      channel: channel,
    );

    expect(
      find.text(
        'Hãy bật ADB để launcher hoạt động đủ chức năng, sau đó quay lại menu cấp quyền ADB local',
      ),
      findsNothing,
    );
  });

  testWidgets('fresh install with ADB enabled skips onboarding',
      (tester) async {
    final settings = await _createSettingsService();
    final security = await _createProfileSecurityService();
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final bridgeService = MockSystemBridgeService();
    final channel = MockFLauncherChannel();
    final searchService = await _createSearchService(channel);
    final provisioningStatus = _buildProvisioningStatus(adbEnabled: true);

    when(appsService.initialized).thenReturn(true);
    when(appsService.homeReorderModeEnabled).thenReturn(false);
    when(appsService.launcherSections).thenReturn(const <LauncherSection>[]);
    when(appsService.isDefaultLauncher()).thenAnswer((_) async => true);
    when(bridgeService.initialized).thenReturn(true);
    when(bridgeService.wallpaperStatus).thenReturn(const <String, dynamic>{});
    when(bridgeService.status).thenReturn(<String, dynamic>{
      'memory': const <String, dynamic>{},
      'navigation': const <String, dynamic>{'homeSequence': 0, 'reason': ''},
      'provisioning': provisioningStatus,
      'install': _buildInstallStatus(freshInstall: true),
    });
    when(bridgeService.provisioningStatus).thenReturn(provisioningStatus);
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});

    await _pumpLauncherApp(
      tester,
      settings: settings,
      security: security,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
      searchService: searchService,
      channel: channel,
    );

    expect(
        find.text(
            'Hãy bật ADB để launcher hoạt động đủ chức năng, sau đó quay lại menu cấp quyền ADB local'),
        findsNothing);
  });

  testWidgets('existing install skips onboarding even if ADB is disabled',
      (tester) async {
    final settings = await _createSettingsService();
    final security = await _createProfileSecurityService();
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final bridgeService = MockSystemBridgeService();
    final channel = MockFLauncherChannel();
    final searchService = await _createSearchService(channel);
    final provisioningStatus = _buildProvisioningStatus(adbEnabled: false);

    when(appsService.initialized).thenReturn(true);
    when(appsService.homeReorderModeEnabled).thenReturn(false);
    when(appsService.launcherSections).thenReturn(const <LauncherSection>[]);
    when(appsService.isDefaultLauncher()).thenAnswer((_) async => true);
    when(bridgeService.initialized).thenReturn(true);
    when(bridgeService.wallpaperStatus).thenReturn(const <String, dynamic>{});
    when(bridgeService.status).thenReturn(<String, dynamic>{
      'memory': const <String, dynamic>{},
      'navigation': const <String, dynamic>{'homeSequence': 0, 'reason': ''},
      'provisioning': provisioningStatus,
      'install': _buildInstallStatus(freshInstall: false),
    });
    when(bridgeService.provisioningStatus).thenReturn(provisioningStatus);
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});

    await _pumpLauncherApp(
      tester,
      settings: settings,
      security: security,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
      searchService: searchService,
      channel: channel,
    );

    expect(
        find.text(
            'Hãy bật ADB để launcher hoạt động đủ chức năng, sau đó quay lại menu cấp quyền ADB local'),
        findsNothing);
  });

  testWidgets(
      'failed developer options open shows fallback and can open permissions panel',
      (tester) async {
    final settings = await _createSettingsService();
    final security = await _createProfileSecurityService();
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final bridgeService = MockSystemBridgeService();
    final channel = MockFLauncherChannel();
    final searchService = await _createSearchService(channel);
    final provisioningStatus = _buildProvisioningStatus(adbEnabled: false);

    when(appsService.initialized).thenReturn(true);
    when(appsService.homeReorderModeEnabled).thenReturn(false);
    when(appsService.launcherSections).thenReturn(const <LauncherSection>[]);
    when(appsService.isDefaultLauncher()).thenAnswer((_) async => true);
    when(bridgeService.initialized).thenReturn(true);
    when(bridgeService.wallpaperStatus).thenReturn(const <String, dynamic>{});
    when(bridgeService.status).thenReturn(<String, dynamic>{
      'memory': const <String, dynamic>{},
      'navigation': const <String, dynamic>{'homeSequence': 0, 'reason': ''},
      'provisioning': provisioningStatus,
      'install': _buildInstallStatus(freshInstall: true),
    });
    when(bridgeService.provisioningStatus).thenReturn(provisioningStatus);
    when(
      bridgeService.runProvisioningAction(
        action: anyNamed('action'),
        suggestedPolicy: anyNamed('suggestedPolicy'),
      ),
    ).thenAnswer((_) async => const <String, dynamic>{
          'success': false,
          'message': 'Developer options could not be opened.',
        });
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});

    await _pumpLauncherApp(
      tester,
      settings: settings,
      security: security,
      appsService: appsService,
      wallpaperService: wallpaperService,
      bridgeService: bridgeService,
      searchService: searchService,
      channel: channel,
    );

    final okLabel = MaterialLocalizations.of(
      tester.element(find.byType(AlertDialog)),
    ).okButtonLabel;
    await tester.tap(find.text(okLabel));
    await tester.pumpAndSettle();

    expect(
      find.text('Không thể mở thẳng tùy chọn nhà phát triển'),
      findsOneWidget,
    );

    await tester.tap(find.text('Mở menu cấp quyền ADB local'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPanel), findsOneWidget);
    expect(
      find.byType(PermissionsPanelPage, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets(
      'home re-entry closes launcher overlays when navigation homeSequence changes',
      (tester) async {
    final settings = await _createSettingsService();
    final security = await _createProfileSecurityService();
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final channel = MockFLauncherChannel();

    when(appsService.initialized).thenReturn(true);
    when(appsService.homeReorderModeEnabled).thenReturn(false);
    when(appsService.launcherSections).thenReturn(const <LauncherSection>[]);
    when(appsService.isDefaultLauncher()).thenAnswer((_) async => true);
    when(wallpaperService.wallpaperMode).thenReturn('gradient');
    when(wallpaperService.wallpaper).thenReturn(null);
    when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
    when(wallpaperService.isVideoMode).thenReturn(false);
    when(wallpaperService.videoTextureId).thenReturn(null);
    when(wallpaperService.videoFit).thenReturn('center-crop');
    when(wallpaperService.videoBlur).thenReturn('off');
    when(wallpaperService.videoDimPercent).thenReturn(15);
    when(channel.getSystemBridgeStatusLite()).thenAnswer(
      (_) async => <String, dynamic>{
        'memory': <String, dynamic>{},
        'provisioning': <String, dynamic>{
          'health': 'healthy',
          'requirements': <Map<String, dynamic>>[],
          'missingRequiredCount': 0,
          'missingRecommendedCount': 0,
        },
        'navigation': <String, dynamic>{
          'homeSequence': 0,
          'reason': '',
        },
      },
    );
    when(channel.addSystemChangedListener(any)).thenAnswer(
      (_) => const Stream<dynamic>.empty().listen((_) {}),
    );
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});
    final bridgeService = SystemBridgeService(channel);
    final searchService = await _createSearchService(channel);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WallpaperService>.value(
              value: wallpaperService),
          ChangeNotifierProvider<AppsService>.value(value: appsService),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<ProfileSecurityService>.value(value: security),
          ChangeNotifierProvider<SystemBridgeService>.value(
              value: bridgeService),
          ChangeNotifierProvider<SearchService>.value(value: searchService),
          ChangeNotifierProvider(create: (_) => LauncherState()),
          ChangeNotifierProvider(create: (_) => NetworkService(channel)),
        ],
        child: const FLauncherApp(),
      ),
    );
    await tester.pumpAndSettle();

    final launcherContext = tester.element(find.byType(FLauncher));
    showDialog<void>(
      context: launcherContext,
      builder: (_) => const AlertDialog(
        title: Text('Overlay'),
        content: Text('Visible'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Overlay'), findsOneWidget);

    when(channel.getSystemBridgeStatusLite()).thenAnswer(
      (_) async => <String, dynamic>{
        'navigation': <String, dynamic>{
          'homeSequence': 1,
          'reason': 'home_reentry',
        },
      },
    );

    await bridgeService.refreshLite();
    await tester.pumpAndSettle();

    expect(find.text('Overlay'), findsNothing);
  });

  testWidgets(
      'benchmark command opens and closes launcher settings on requested shell route',
      (tester) async {
    final settings = await _createSettingsService();
    final security = await _createProfileSecurityService();
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final channel = MockFLauncherChannel();
    final searchService = await _createSearchService(channel);
    var bridgeStatus = <String, dynamic>{
      'memory': <String, dynamic>{},
      'provisioning': <String, dynamic>{
        'health': 'healthy',
        'requirements': <Map<String, dynamic>>[],
        'missingRequiredCount': 0,
        'missingRecommendedCount': 0,
      },
      'navigation': <String, dynamic>{
        'homeSequence': 0,
        'reason': '',
      },
      'benchmarkCommand': <String, dynamic>{
        'sequence': 0,
        'action': '',
        'route': '',
        'sessionId': '',
        'autoFocusDetail': false,
        'bypassSettingsSecurity': false,
      },
    };

    when(appsService.initialized).thenReturn(true);
    when(appsService.homeReorderModeEnabled).thenReturn(false);
    when(appsService.launcherSections).thenReturn(const <LauncherSection>[]);
    when(appsService.isDefaultLauncher()).thenAnswer((_) async => true);
    when(wallpaperService.wallpaperMode).thenReturn('gradient');
    when(wallpaperService.wallpaper).thenReturn(null);
    when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
    when(wallpaperService.isVideoMode).thenReturn(false);
    when(wallpaperService.videoTextureId).thenReturn(null);
    when(wallpaperService.videoFit).thenReturn('center-crop');
    when(wallpaperService.videoBlur).thenReturn('off');
    when(wallpaperService.videoDimPercent).thenReturn(15);
    when(wallpaperService.setSettingsPlaybackSuppressed(true))
        .thenAnswer((_) async {});
    when(wallpaperService.setSettingsPlaybackSuppressed(false))
        .thenAnswer((_) async {});
    when(channel.getSystemBridgeStatusLite())
        .thenAnswer((_) async => bridgeStatus);
    when(channel.addSystemChangedListener(any)).thenAnswer(
      (_) => const Stream<dynamic>.empty().listen((_) {}),
    );
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});
    final bridgeService = SystemBridgeService(channel);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WallpaperService>.value(
              value: wallpaperService),
          ChangeNotifierProvider<AppsService>.value(value: appsService),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<ProfileSecurityService>.value(value: security),
          ChangeNotifierProvider<SystemBridgeService>.value(
              value: bridgeService),
          ChangeNotifierProvider<SearchService>.value(value: searchService),
          ChangeNotifierProvider(create: (_) => LauncherState()),
          ChangeNotifierProvider(create: (_) => NetworkService(channel)),
        ],
        child: const FLauncherApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPanel), findsNothing);

    bridgeStatus = <String, dynamic>{
      ...bridgeStatus,
      'benchmarkCommand': <String, dynamic>{
        'sequence': 1,
        'action': 'open_launcher_settings',
        'route': WallpaperPanelPage.routeName,
        'sessionId': 'bench-1',
        'autoFocusDetail': true,
        'bypassSettingsSecurity': true,
      },
    };

    await bridgeService.refreshLite();
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPanel), findsOneWidget);
    expect(find.byType(WallpaperPanelPage), findsOneWidget);

    bridgeStatus = <String, dynamic>{
      ...bridgeStatus,
      'benchmarkCommand': <String, dynamic>{
        'sequence': 2,
        'action': 'close_launcher_settings',
        'route': WallpaperPanelPage.routeName,
        'sessionId': 'bench-1',
        'autoFocusDetail': true,
        'bypassSettingsSecurity': true,
      },
    };

    await bridgeService.refreshLite();
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPanel), findsNothing);
  });

  testWidgets(
      'initial benchmark snapshot opens launcher settings on cold start',
      (tester) async {
    final settings = await _createSettingsService();
    final security = await _createProfileSecurityService();
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final channel = MockFLauncherChannel();
    final searchService = await _createSearchService(channel);

    when(appsService.initialized).thenReturn(true);
    when(appsService.homeReorderModeEnabled).thenReturn(false);
    when(appsService.launcherSections).thenReturn(const <LauncherSection>[]);
    when(appsService.isDefaultLauncher()).thenAnswer((_) async => true);
    when(wallpaperService.wallpaperMode).thenReturn('gradient');
    when(wallpaperService.wallpaper).thenReturn(null);
    when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
    when(wallpaperService.isVideoMode).thenReturn(false);
    when(wallpaperService.videoTextureId).thenReturn(null);
    when(wallpaperService.videoFit).thenReturn('center-crop');
    when(wallpaperService.videoBlur).thenReturn('off');
    when(wallpaperService.videoDimPercent).thenReturn(15);
    when(wallpaperService.setSettingsPlaybackSuppressed(true))
        .thenAnswer((_) async {});
    when(wallpaperService.setSettingsPlaybackSuppressed(false))
        .thenAnswer((_) async {});
    when(channel.getSystemBridgeStatusLite()).thenAnswer(
      (_) async => <String, dynamic>{
        'memory': <String, dynamic>{},
        'provisioning': <String, dynamic>{
          'health': 'healthy',
          'requirements': <Map<String, dynamic>>[],
          'missingRequiredCount': 0,
          'missingRecommendedCount': 0,
        },
        'navigation': <String, dynamic>{
          'homeSequence': 0,
          'reason': '',
        },
        'benchmarkCommand': <String, dynamic>{
          'sequence': 7,
          'action': 'open_launcher_settings',
          'route': WallpaperPanelPage.routeName,
          'sessionId': 'cold-start-bench',
          'autoFocusDetail': true,
          'bypassSettingsSecurity': true,
        },
      },
    );
    when(channel.addSystemChangedListener(any)).thenAnswer(
      (_) => const Stream<dynamic>.empty().listen((_) {}),
    );
    when(channel.addNetworkChangedListener(any)).thenReturn(null);
    when(channel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});
    final bridgeService = SystemBridgeService(channel);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WallpaperService>.value(
              value: wallpaperService),
          ChangeNotifierProvider<AppsService>.value(value: appsService),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<ProfileSecurityService>.value(value: security),
          ChangeNotifierProvider<SystemBridgeService>.value(
              value: bridgeService),
          ChangeNotifierProvider<SearchService>.value(value: searchService),
          ChangeNotifierProvider(create: (_) => LauncherState()),
          ChangeNotifierProvider(create: (_) => NetworkService(channel)),
        ],
        child: const FLauncherApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPanel), findsOneWidget);
    expect(find.byType(WallpaperPanelPage), findsOneWidget);
  });
}

MaterialApp _materialApp(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp));

Future<void> _pumpLauncherApp(
  WidgetTester tester, {
  required SettingsService settings,
  required ProfileSecurityService security,
  required AppsService appsService,
  required WallpaperService wallpaperService,
  required SystemBridgeService bridgeService,
  required SearchService searchService,
  required FLauncherChannel channel,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WallpaperService>.value(value: wallpaperService),
        ChangeNotifierProvider<AppsService>.value(value: appsService),
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        ChangeNotifierProvider<ProfileSecurityService>.value(value: security),
        ChangeNotifierProvider<SystemBridgeService>.value(value: bridgeService),
        ChangeNotifierProvider<SearchService>.value(value: searchService),
        ChangeNotifierProvider(create: (_) => LauncherState()),
        ChangeNotifierProvider(create: (_) => NetworkService(channel)),
      ],
      child: const FLauncherApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _buildProvisioningStatus({required bool adbEnabled}) {
  return <String, dynamic>{
    'health': adbEnabled ? 'healthy' : 'recommended_missing',
    'requirements': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': 'adb_enabled',
        'granted': adbEnabled,
        'importance': 'optional',
      },
    ],
    'missingRequiredCount': 0,
    'missingRecommendedCount': 0,
  };
}

Map<String, dynamic> _buildInstallStatus({required bool freshInstall}) {
  return <String, dynamic>{
    'firstInstallTime': 1000,
    'lastUpdateTime': freshInstall ? 1500 : 1000 + 61000,
  };
}

Future<SettingsService> _createSettingsService() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return SettingsService(await SharedPreferences.getInstance());
}

Future<ProfileSecurityService> _createProfileSecurityService() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return ProfileSecurityService(await SharedPreferences.getInstance());
}

Future<SearchService> _createSearchService(MockFLauncherChannel channel) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return SearchService(await SharedPreferences.getInstance(), channel);
}

void _stubWallpaperService(MockWallpaperService wallpaperService) {
  when(wallpaperService.wallpaperMode).thenReturn('gradient');
  when(wallpaperService.wallpaper).thenReturn(null);
  when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
  when(wallpaperService.isVideoMode).thenReturn(false);
  when(wallpaperService.videoBlockedByPerformanceMode).thenReturn(false);
  when(wallpaperService.videoTextureId).thenReturn(null);
  when(wallpaperService.videoFit).thenReturn('center-crop');
  when(wallpaperService.videoBlur).thenReturn('off');
  when(wallpaperService.videoDimPercent).thenReturn(15);
  when(wallpaperService.videoSourceType).thenReturn('single_file');
  when(wallpaperService.videoUris).thenReturn(const <String>[]);
  when(wallpaperService.wallpaperAssetUri).thenReturn('');
  when(wallpaperService.videoFolderName).thenReturn('');
  when(wallpaperService.videoAdvanceMode).thenReturn('on_completion');
  when(wallpaperService.videoRepeatCountPerItem).thenReturn(3);
  when(wallpaperService.videoOrderMode).thenReturn('sequential');
  when(wallpaperService.videoSwitchIntervalSeconds).thenReturn(30);
  when(wallpaperService.videoPlaylistLoop).thenReturn(true);
  when(wallpaperService.videoLoop).thenReturn(true);
  when(wallpaperService.videoMute).thenReturn(true);
  when(wallpaperService.videoAutoResume).thenReturn(true);
  when(wallpaperService.setSettingsPlaybackSuppressed(true))
      .thenAnswer((_) async {});
  when(wallpaperService.setSettingsPlaybackSuppressed(false))
      .thenAnswer((_) async {});
  when(wallpaperService.cancelPendingHomeVideoStart()).thenReturn(null);
  when(wallpaperService.notifyHomeVisibleAndUsable()).thenReturn(null);
}
