import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/weather_service.dart';
import 'package:flauncher/widgets/focus_aware_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.mocks.dart';

class FakeSettingsService extends ChangeNotifier implements SettingsService {
  bool _showRamInStatusBar = true;
  bool _showWeatherInStatusBar = true;
  bool _autoHideAppBarEnabled = false;
  int _homeDockGlassIntensityPercent = 20;
  bool _showDateInStatusBar = true;
  bool _showTimeInStatusBar = true;
  String _dateFormat = 'dd/MM';
  String _timeFormat = 'HH:mm';
  int _statusBarClockScalePercent = 100;

  @override
  bool get showRamInStatusBar => _showRamInStatusBar;
  set showRamInStatusBar(bool v) {
    _showRamInStatusBar = v;
    notifyListeners();
  }

  @override
  bool get showWeatherInStatusBar => _showWeatherInStatusBar;
  set showWeatherInStatusBar(bool v) {
    _showWeatherInStatusBar = v;
    notifyListeners();
  }

  @override
  bool get autoHideAppBarEnabled => _autoHideAppBarEnabled;

  @override
  int get homeDockGlassIntensityPercent => _homeDockGlassIntensityPercent;

  @override
  bool get showDateInStatusBar => _showDateInStatusBar;

  @override
  bool get showTimeInStatusBar => _showTimeInStatusBar;

  @override
  String get dateFormat => _dateFormat;

  @override
  String get timeFormat => _timeFormat;

  @override
  int get statusBarClockScalePercent => _statusBarClockScalePercent;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNetworkService extends ChangeNotifier implements NetworkService {
  @override
  bool get hasInternetAccess => true;

  @override
  NetworkType get networkType => NetworkType.Wifi;

  @override
  int get wirelessNetworkSignalLevel => 4;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeWeatherService extends ChangeNotifier implements WeatherService {
  WeatherSnapshot? _snapshot;

  FakeWeatherService([this._snapshot]);

  @override
  WeatherSnapshot? get snapshot => _snapshot;

  set snapshot(WeatherSnapshot? value) {
    _snapshot = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    Provider.debugCheckInvalidValueType = null;
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget createTestWidget({
    required Size screenSize,
    required FakeSettingsService settings,
    required MockAppsService apps,
    required MockSystemBridgeService bridge,
    required WeatherService weather,
    NetworkService? network,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        Provider<AppsService>.value(value: apps),
        Provider<SystemBridgeService>.value(value: bridge),
        ChangeNotifierProvider<WeatherService>.value(value: weather),
        ChangeNotifierProvider<NetworkService>.value(
          value: network ?? FakeNetworkService(),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            appBar: FocusAwareAppBar(),
          ),
        ),
      ),
    );
  }

  void setupBridgeAndAppsMocks({
    required MockAppsService apps,
    required MockSystemBridgeService bridge,
  }) {
    when(apps.homeReorderModeEnabled).thenReturn(false);

    when(bridge.memoryStatus).thenReturn(<String, dynamic>{
      'availBytes': 11811160064,
      'totalBytes': 137438953472,
      'lowMemory': false,
    });
    when(bridge.provisioningStatus).thenReturn(const <String, dynamic>{
      'health': 'healthy',
      'missingRequiredCount': 0,
      'missingRecommendedCount': 0,
      'requirements': <Map<String, dynamic>>[],
    });
  }

  group('FocusAwareAppBar leadingWidth adaptive calculations', () {
    testWidgets('1080p screen: verifies 4 states of leadingWidth',
        (tester) async {
      const size1080p = Size(1920, 1080);
      tester.view.physicalSize = size1080p;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = FakeSettingsService();
      final apps = MockAppsService();
      final bridge = MockSystemBridgeService();
      final weather = FakeWeatherService(const WeatherSnapshot(
        tempC: 28,
        condition: WeatherCondition.sunny,
        cityName: 'Hà Nội',
        isDay: true,
        fetchedAtMs: 1725320000000,
      ));
      setupBridgeAndAppsMocks(apps: apps, bridge: bridge);

      // State 1: Both ON (RAM + Weather) -> regular width = 318.0
      settings.showRamInStatusBar = true;
      settings.showWeatherInStatusBar = true;
      await tester.pumpWidget(createTestWidget(
        screenSize: size1080p,
        settings: settings,
        apps: apps,
        bridge: bridge,
        weather: weather,
      ));
      await tester.pumpAndSettle();

      AppBar appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leadingWidth, 318.0,
          reason: 'Both ON on 1080p should have leadingWidth 318.0');

      // State 2: Only RAM ON -> regular width = 142.0
      settings.showRamInStatusBar = true;
      settings.showWeatherInStatusBar = false;
      await tester.pumpWidget(createTestWidget(
        screenSize: size1080p,
        settings: settings,
        apps: apps,
        bridge: bridge,
        weather: weather,
      ));
      await tester.pumpAndSettle();

      appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leadingWidth, 142.0,
          reason: 'Only RAM ON on 1080p should have leadingWidth 142.0');

      // State 3: Only Weather ON -> regular width = 184.0
      settings.showRamInStatusBar = false;
      settings.showWeatherInStatusBar = true;
      await tester.pumpWidget(createTestWidget(
        screenSize: size1080p,
        settings: settings,
        apps: apps,
        bridge: bridge,
        weather: weather,
      ));
      await tester.pumpAndSettle();

      appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leadingWidth, 184.0,
          reason: 'Only Weather ON on 1080p should have leadingWidth 184.0');

      // State 4: Both OFF -> minimal width = 18.0
      settings.showRamInStatusBar = false;
      settings.showWeatherInStatusBar = false;
      await tester.pumpWidget(createTestWidget(
        screenSize: size1080p,
        settings: settings,
        apps: apps,
        bridge: bridge,
        weather: weather,
      ));
      await tester.pumpAndSettle();

      appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leadingWidth, 18.0,
          reason: 'Both OFF should have leadingWidth 18.0');
    });

    testWidgets('Compact screen: verifies 4 states of leadingWidth',
        (tester) async {
      const sizeCompact = Size(960, 720);
      tester.view.physicalSize = sizeCompact;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = FakeSettingsService();
      final apps = MockAppsService();
      final bridge = MockSystemBridgeService();
      final weather = FakeWeatherService(const WeatherSnapshot(
        tempC: 25,
        condition: WeatherCondition.rain,
        cityName: 'Đà Nẵng',
        isDay: true,
        fetchedAtMs: 1725320000000,
      ));
      setupBridgeAndAppsMocks(apps: apps, bridge: bridge);

      // State 1: Both ON -> compact width = 292.0
      settings.showRamInStatusBar = true;
      settings.showWeatherInStatusBar = true;
      await tester.pumpWidget(createTestWidget(
        screenSize: sizeCompact,
        settings: settings,
        apps: apps,
        bridge: bridge,
        weather: weather,
      ));
      await tester.pumpAndSettle();

      AppBar appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leadingWidth, 292.0,
          reason: 'Both ON on compact should have leadingWidth 292.0');

      // State 2: Only RAM ON -> compact width = 128.0
      settings.showRamInStatusBar = true;
      settings.showWeatherInStatusBar = false;
      await tester.pumpWidget(createTestWidget(
        screenSize: sizeCompact,
        settings: settings,
        apps: apps,
        bridge: bridge,
        weather: weather,
      ));
      await tester.pumpAndSettle();

      appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leadingWidth, 128.0,
          reason: 'Only RAM ON on compact should have leadingWidth 128.0');

      // State 3: Only Weather ON -> compact width = 172.0
      settings.showRamInStatusBar = false;
      settings.showWeatherInStatusBar = true;
      await tester.pumpWidget(createTestWidget(
        screenSize: sizeCompact,
        settings: settings,
        apps: apps,
        bridge: bridge,
        weather: weather,
      ));
      await tester.pumpAndSettle();

      appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leadingWidth, 172.0,
          reason: 'Only Weather ON on compact should have leadingWidth 172.0');

      // State 4: Both OFF -> minimal width = 18.0
      settings.showRamInStatusBar = false;
      settings.showWeatherInStatusBar = false;
      await tester.pumpWidget(createTestWidget(
        screenSize: sizeCompact,
        settings: settings,
        apps: apps,
        bridge: bridge,
        weather: weather,
      ));
      await tester.pumpAndSettle();

      appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leadingWidth, 18.0,
          reason: 'Both OFF should have leadingWidth 18.0');
    });
  });

  group('WeatherStatusChip Rendering & Visuals', () {
    testWidgets('renders weather icon, temperature text and semantics correctly',
        (tester) async {
      const size1080p = Size(1920, 1080);
      tester.view.physicalSize = size1080p;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = FakeSettingsService();
      final apps = MockAppsService();
      final bridge = MockSystemBridgeService();
      final weather = FakeWeatherService(const WeatherSnapshot(
        tempC: 28,
        condition: WeatherCondition.sunny,
        cityName: 'Hà Nội',
        isDay: true,
        fetchedAtMs: 1725320000000,
      ));
      setupBridgeAndAppsMocks(apps: apps, bridge: bridge);

      settings.showRamInStatusBar = true;
      settings.showWeatherInStatusBar = true;

      await tester.pumpWidget(createTestWidget(
        screenSize: size1080p,
        settings: settings,
        apps: apps,
        bridge: bridge,
        weather: weather,
      ));
      await tester.pumpAndSettle();

      // Temperature text
      expect(find.text('28°C'), findsOneWidget);

      // Icon for sunny
      expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);

      // Semantics label
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Hà Nội, 28°C',
        ),
        findsOneWidget,
      );

      // Verify night icon variation when isDay is false
      weather.snapshot = const WeatherSnapshot(
        tempC: 22,
        condition: WeatherCondition.sunny,
        cityName: 'Hà Nội',
        isDay: false,
        fetchedAtMs: 1725320000000,
      );
      await tester.pumpAndSettle();

      expect(find.text('22°C'), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
    });

    testWidgets('renders elements in correct order: City Name (X) < Weather Icon (X) < Temperature (X)',
        (tester) async {
      const size1080p = Size(1920, 1080);
      tester.view.physicalSize = size1080p;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = FakeSettingsService();
      final apps = MockAppsService();
      final bridge = MockSystemBridgeService();
      final weather = FakeWeatherService(const WeatherSnapshot(
        tempC: 28,
        condition: WeatherCondition.sunny,
        cityName: 'Hà Nội',
        isDay: true,
        fetchedAtMs: 1725320000000,
      ));
      setupBridgeAndAppsMocks(apps: apps, bridge: bridge);

      settings.showRamInStatusBar = true;
      settings.showWeatherInStatusBar = true;

      await tester.pumpWidget(createTestWidget(
        screenSize: size1080p,
        settings: settings,
        apps: apps,
        bridge: bridge,
        weather: weather,
      ));
      await tester.pumpAndSettle();

      final cityFinder = find.text('Hà Nội');
      final iconFinder = find.byIcon(Icons.wb_sunny_rounded);
      final tempFinder = find.text('28°C');

      expect(cityFinder, findsOneWidget);
      expect(iconFinder, findsOneWidget);
      expect(tempFinder, findsOneWidget);

      final cityX = tester.getTopLeft(cityFinder).dx;
      final iconX = tester.getTopLeft(iconFinder).dx;
      final tempX = tester.getTopLeft(tempFinder).dx;

      expect(cityX < iconX, isTrue,
          reason: 'City Name X ($cityX) must be strictly less than Weather Icon X ($iconX)');
      expect(iconX < tempX, isTrue,
          reason: 'Weather Icon X ($iconX) must be strictly less than Temperature X ($tempX)');
    });

    testWidgets('renders placeholder capsule when snapshot is null',
        (tester) async {
      const size1080p = Size(1920, 1080);
      tester.view.physicalSize = size1080p;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = FakeSettingsService();
      final apps = MockAppsService();
      final bridge = MockSystemBridgeService();
      final weather = FakeWeatherService(null);
      setupBridgeAndAppsMocks(apps: apps, bridge: bridge);

      settings.showRamInStatusBar = false;
      settings.showWeatherInStatusBar = true;

      await tester.pumpWidget(createTestWidget(
        screenSize: size1080p,
        settings: settings,
        apps: apps,
        bridge: bridge,
        weather: weather,
      ));
      await tester.pumpAndSettle();

      // Temperature text should NOT be present
      expect(find.textContaining('°C'), findsNothing);
      // But AppBar leading is still allocated
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leadingWidth, 184.0);
    });
  });

  group('Overflow Prevention & Layout Safety', () {
    testWidgets('zero RenderFlex overflow with long city name on 1080p, 720p, 540p screens',
        (tester) async {
      final settings = FakeSettingsService();
      final apps = MockAppsService();
      final bridge = MockSystemBridgeService();
      final weather = FakeWeatherService(const WeatherSnapshot(
        tempC: 32,
        condition: WeatherCondition.rain,
        cityName: 'Thành phố Hồ Chí Minh',
        isDay: true,
        fetchedAtMs: 1725320000000,
      ));
      setupBridgeAndAppsMocks(apps: apps, bridge: bridge);

      settings.showRamInStatusBar = true;
      settings.showWeatherInStatusBar = true;

      final testScreens = [
        const Size(1920, 1080), // 1080p Standard
        const Size(1280, 720),  // 720p HD
        const Size(960, 540),   // Compact qHD
      ];

      for (final screen in testScreens) {
        tester.view.physicalSize = screen;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(
          screenSize: screen,
          settings: settings,
          apps: apps,
          bridge: bridge,
          weather: weather,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Should not throw overflow with long city name on ${screen.width}x${screen.height}');
        expect(find.text('32°C'), findsOneWidget);
        expect(find.text('Thành phố Hồ Chí Minh'), findsOneWidget);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('zero RenderFlex overflow on 1080p and compact screens with all elements enabled',
        (tester) async {
      final settings = FakeSettingsService();
      final apps = MockAppsService();
      final bridge = MockSystemBridgeService();
      final weather = FakeWeatherService(const WeatherSnapshot(
        tempC: -15,
        condition: WeatherCondition.thunderstorm,
        cityName: 'Lào Cai',
        isDay: true,
        fetchedAtMs: 1725320000000,
      ));
      setupBridgeAndAppsMocks(apps: apps, bridge: bridge);

      settings.showRamInStatusBar = true;
      settings.showWeatherInStatusBar = true;

      final testScreens = [
        const Size(1920, 1080), // 1080p Standard
        const Size(1280, 720),  // 720p HD
        const Size(960, 540),   // Compact qHD
      ];

      for (final screen in testScreens) {
        tester.view.physicalSize = screen;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(
          screenSize: screen,
          settings: settings,
          apps: apps,
          bridge: bridge,
          weather: weather,
        ));
        await tester.pumpAndSettle();

        // Check for any Flutter error or overflow
        expect(tester.takeException(), isNull,
            reason: 'Should not throw layout exceptions on ${screen.width}x${screen.height}');
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
