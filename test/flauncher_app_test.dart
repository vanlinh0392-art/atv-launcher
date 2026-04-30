import 'package:flauncher/flauncher_app.dart';
import 'package:flauncher/flauncher.dart';
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
      'home re-entry closes launcher overlays when navigation homeSequence changes',
      (tester) async {
    final settings = await _createSettingsService();
    final security = await _createProfileSecurityService();
    final appsService = MockAppsService();
    final wallpaperService = MockWallpaperService();
    _stubWallpaperService(wallpaperService);
    final channel = MockFLauncherChannel();

    when(appsService.initialized).thenReturn(true);
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
}
