import 'package:flauncher/flauncher_app.dart';
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
