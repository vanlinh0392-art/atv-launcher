import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/weather_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class FakeNetworkService extends ChangeNotifier implements NetworkService {
  bool _hasInternetAccess;

  FakeNetworkService({bool hasInternetAccess = true})
      : _hasInternetAccess = hasInternetAccess;

  @override
  bool get hasInternetAccess => _hasInternetAccess;

  set hasInternetAccess(bool value) {
    if (_hasInternetAccess != value) {
      _hasInternetAccess = value;
      notifyListeners();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.empty();
    SharedPreferences.setMockInitialValues({});
  });

  group('WeatherSnapshot Serialization & Sanity Bounds', () {
    test('toJsonString and fromJsonString work symmetrically', () {
      const snapshot = WeatherSnapshot(
        tempC: 28,
        condition: WeatherCondition.rain,
        cityName: 'Hà Nội',
        isDay: true,
        fetchedAtMs: 1725320000000,
      );

      final jsonStr = snapshot.toJsonString();
      final decoded = WeatherSnapshot.fromJsonString(jsonStr);

      expect(decoded, isNotNull);
      expect(decoded!.tempC, 28);
      expect(decoded.condition, WeatherCondition.rain);
      expect(decoded.cityName, 'Hà Nội');
      expect(decoded.isDay, isTrue);
      expect(decoded.fetchedAtMs, 1725320000000);
    });

    test('sanity bounds clamp extreme temperatures between -60 and 60', () {
      const highTempJson =
          '{"tempC": 150, "condition": "sunny", "cityName": "Sahara", "isDay": true, "fetchedAtMs": 100}';
      final decodedHigh = WeatherSnapshot.fromJsonString(highTempJson);
      expect(decodedHigh!.tempC, 60);

      const lowTempJson =
          '{"tempC": -120, "condition": "snow", "cityName": "Antarctica", "isDay": false, "fetchedAtMs": 100}';
      final decodedLow = WeatherSnapshot.fromJsonString(lowTempJson);
      expect(decodedLow!.tempC, -60);
    });

    test('handles invalid or empty json safely by returning null', () {
      expect(WeatherSnapshot.fromJsonString(null), isNull);
      expect(WeatherSnapshot.fromJsonString(''), isNull);
      expect(WeatherSnapshot.fromJsonString('not-a-json'), isNull);
    });
  });

  group('WMO Code Mapping to Weather Conditions', () {
    test('maps sunny (code 0)', () {
      expect(WeatherService.mapWeatherCodeToCondition(0), WeatherCondition.sunny);
    });

    test('maps cloudy (codes 1, 2)', () {
      expect(WeatherService.mapWeatherCodeToCondition(1), WeatherCondition.cloudy);
      expect(WeatherService.mapWeatherCodeToCondition(2), WeatherCondition.cloudy);
    });

    test('maps overcast / râm (code 3)', () {
      expect(WeatherService.mapWeatherCodeToCondition(3), WeatherCondition.overcast);
    });

    test('maps fog / sương mù (codes 45, 48)', () {
      expect(WeatherService.mapWeatherCodeToCondition(45), WeatherCondition.fog);
      expect(WeatherService.mapWeatherCodeToCondition(48), WeatherCondition.fog);
    });

    test('maps rain / mưa (drizzle, rain, showers)', () {
      final rainCodes = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82];
      for (final code in rainCodes) {
        expect(
          WeatherService.mapWeatherCodeToCondition(code),
          WeatherCondition.rain,
          reason: 'WMO code $code should map to rain',
        );
      }
    });

    test('maps snow / tuyết (codes 71, 73, 75, 77, 85, 86)', () {
      final snowCodes = [71, 73, 75, 77, 85, 86];
      for (final code in snowCodes) {
        expect(
          WeatherService.mapWeatherCodeToCondition(code),
          WeatherCondition.snow,
          reason: 'WMO code $code should map to snow',
        );
      }
    });

    test('maps thunderstorm / dông bão (codes 95, 96, 99)', () {
      expect(WeatherService.mapWeatherCodeToCondition(95), WeatherCondition.thunderstorm);
      expect(WeatherService.mapWeatherCodeToCondition(96), WeatherCondition.thunderstorm);
      expect(WeatherService.mapWeatherCodeToCondition(99), WeatherCondition.thunderstorm);
    });

    test('maps unknown / mã lạ to unknown condition', () {
      expect(WeatherService.mapWeatherCodeToCondition(-1), WeatherCondition.unknown);
      expect(WeatherService.mapWeatherCodeToCondition(4), WeatherCondition.unknown);
      expect(WeatherService.mapWeatherCodeToCondition(999), WeatherCondition.unknown);
    });

    test('verifies semantic colors and icons for each condition', () {
      expect(WeatherCondition.sunny.color, const Color(0xFFFFD54F));
      expect(WeatherCondition.cloudy.color, const Color(0xFF90CAF9));
      expect(WeatherCondition.overcast.color, const Color(0xFF90CAF9));
      expect(WeatherCondition.rain.color, const Color(0xFF4FC3F7));
      expect(WeatherCondition.thunderstorm.color, const Color(0xFFBA68C8));
      expect(WeatherCondition.snow.color, const Color(0xFF80DEEA));
      expect(WeatherCondition.fog.color, const Color(0xFFCFD8DC));
      expect(WeatherCondition.unknown.color, const Color(0xFFB0BEC5));

      // Day / Night icons
      expect(WeatherCondition.sunny.getIcon(isDay: true), Icons.wb_sunny_rounded);
      expect(WeatherCondition.sunny.getIcon(isDay: false), Icons.nightlight_round);
      expect(WeatherCondition.rain.getIcon(isDay: true), Icons.water_drop_rounded);
      expect(WeatherCondition.rain.getIcon(isDay: false), Icons.water_drop_rounded);
      expect(WeatherCondition.thunderstorm.getIcon(), Icons.flash_on_rounded);
      expect(WeatherCondition.unknown.getIcon(), Icons.help_outline_rounded);
    });
  });

  group('Multi-Tier Location Resolution', () {
    test('Tier 1: uses freeipapi.com when available', () async {
      final prefs = await SharedPreferences.getInstance();
      final networkService = FakeNetworkService(hasInternetAccess: true);

      final requestedUris = <Uri>[];
      final weatherService = WeatherService(
        prefs,
        networkService,
        jsonFetcher: (uri, {Duration? timeout}) async {
          requestedUris.add(uri);
          if (uri.host == 'freeipapi.com') {
            return {
              'latitude': 10.8231,
              'longitude': 106.6297,
              'cityName': 'TP. Hồ Chí Minh',
            };
          }
          if (uri.host == 'api.open-meteo.com') {
            return {
              'current': {
                'temperature_2m': 31.8,
                'weather_code': 0,
                'is_day': 1,
              }
            };
          }
          return null;
        },
      );

      await weatherService.fetchWeather(force: true);

      expect(weatherService.snapshot, isNotNull);
      expect(weatherService.snapshot!.cityName, 'TP. Hồ Chí Minh');
      expect(weatherService.snapshot!.tempC, 32);
      expect(weatherService.snapshot!.condition, WeatherCondition.sunny);

      expect(requestedUris.any((u) => u.host == 'freeipapi.com'), isTrue);
      final meteoUri = requestedUris.firstWhere((u) => u.host == 'api.open-meteo.com');
      expect(meteoUri.queryParameters['latitude'], '10.8231');
      expect(meteoUri.queryParameters['longitude'], '106.6297');

      weatherService.dispose();
      networkService.dispose();
    });

    test('Tier 2: falls back to ipwho.is when freeipapi.com fails', () async {
      final prefs = await SharedPreferences.getInstance();
      final networkService = FakeNetworkService(hasInternetAccess: true);

      final requestedUris = <Uri>[];
      final weatherService = WeatherService(
        prefs,
        networkService,
        jsonFetcher: (uri, {Duration? timeout}) async {
          requestedUris.add(uri);
          if (uri.host == 'freeipapi.com') {
            return null; // Tier 1 fails
          }
          if (uri.host == 'ipwho.is') {
            return {
              'success': true,
              'latitude': 16.0544,
              'longitude': 108.2022,
              'city': 'Đà Nẵng',
            };
          }
          if (uri.host == 'api.open-meteo.com') {
            return {
              'current': {
                'temperature_2m': 26.2,
                'weather_code': 61,
                'is_day': 1,
              }
            };
          }
          return null;
        },
      );

      await weatherService.fetchWeather(force: true);

      expect(weatherService.snapshot, isNotNull);
      expect(weatherService.snapshot!.cityName, 'Đà Nẵng');
      expect(weatherService.snapshot!.tempC, 26);
      expect(weatherService.snapshot!.condition, WeatherCondition.rain);

      final meteoUri = requestedUris.firstWhere((u) => u.host == 'api.open-meteo.com');
      expect(meteoUri.queryParameters['latitude'], '16.0544');
      expect(meteoUri.queryParameters['longitude'], '108.2022');

      weatherService.dispose();
      networkService.dispose();
    });

    test('Tier 3 & 4: falls back to Default/Timezone (Hà Nội) when GeoIP APIs fail', () async {
      final prefs = await SharedPreferences.getInstance();
      final networkService = FakeNetworkService(hasInternetAccess: true);

      final requestedUris = <Uri>[];
      final weatherService = WeatherService(
        prefs,
        networkService,
        jsonFetcher: (uri, {Duration? timeout}) async {
          requestedUris.add(uri);
          if (uri.host == 'freeipapi.com' || uri.host == 'ipwho.is') {
            return null; // Both GeoIP tiers fail
          }
          if (uri.host == 'api.open-meteo.com') {
            return {
              'current': {
                'temperature_2m': 24.0,
                'weather_code': 3,
                'is_day': 1,
              }
            };
          }
          return null;
        },
      );

      await weatherService.fetchWeather(force: true);

      expect(weatherService.snapshot, isNotNull);
      expect(weatherService.snapshot!.cityName, 'Hà Nội');
      expect(weatherService.snapshot!.tempC, 24);
      expect(weatherService.snapshot!.condition, WeatherCondition.overcast);

      final meteoUri = requestedUris.firstWhere((u) => u.host == 'api.open-meteo.com');
      expect(meteoUri.queryParameters['latitude'], '21.0285');
      expect(meteoUri.queryParameters['longitude'], '105.8542');

      weatherService.dispose();
      networkService.dispose();
    });
  });

  group('L1 & L2 Cache Behavior', () {
    test('fetches once and uses fresh cache on subsequent calls within TTL', () async {
      final prefs = await SharedPreferences.getInstance();
      final networkService = FakeNetworkService(hasInternetAccess: true);

      int openMeteoCalls = 0;
      final weatherService = WeatherService(
        prefs,
        networkService,
        jsonFetcher: (uri, {Duration? timeout}) async {
          if (uri.host == 'freeipapi.com') {
            return {'latitude': 21.0285, 'longitude': 105.8542, 'cityName': 'Hà Nội'};
          }
          if (uri.host == 'api.open-meteo.com') {
            openMeteoCalls++;
            return {
              'current': {
                'temperature_2m': 29.0,
                'weather_code': 1,
                'is_day': 1,
              }
            };
          }
          return null;
        },
      );

      // Call 1: Fetches from network
      await weatherService.fetchWeather(force: true);
      expect(openMeteoCalls, 1);
      expect(weatherService.snapshot!.tempC, 29);
      expect(weatherService.isCacheFresh, isTrue);

      // L2 cache in SharedPreferences is populated
      final cachedJson = prefs.getString(WeatherService.weatherCacheKey);
      expect(cachedJson, isNotNull);
      expect(cachedJson, contains('Hà Nội'));

      // Call 2: Within TTL without force -> Reads cache, zero network calls!
      await weatherService.fetchWeather(force: false);
      expect(openMeteoCalls, 1, reason: 'Cache is fresh, network call must NOT be triggered');

      weatherService.dispose();
      networkService.dispose();
    });

    test('restores L2 cache into L1 immediately on service instantiation (0ms instant display)', () async {
      final prefs = await SharedPreferences.getInstance();
      const cached = WeatherSnapshot(
        tempC: 30,
        condition: WeatherCondition.sunny,
        cityName: 'Huế',
        isDay: true,
        fetchedAtMs: 1725320000000,
      );
      await prefs.setString(WeatherService.weatherCacheKey, cached.toJsonString());

      final networkService = FakeNetworkService(hasInternetAccess: false);
      final weatherService = WeatherService(prefs, networkService);

      // Immediate L1 availability
      expect(weatherService.snapshot, isNotNull);
      expect(weatherService.snapshot!.tempC, 30);
      expect(weatherService.snapshot!.cityName, 'Huế');
      expect(weatherService.snapshot!.condition, WeatherCondition.sunny);

      weatherService.dispose();
      networkService.dispose();
    });
  });

  group('Single-Flight Request Coalescing', () {
    test('coalesces multiple concurrent fetch requests into a single network call', () async {
      final prefs = await SharedPreferences.getInstance();
      final networkService = FakeNetworkService(hasInternetAccess: true);

      int openMeteoCalls = 0;
      final weatherService = WeatherService(
        prefs,
        networkService,
        jsonFetcher: (uri, {Duration? timeout}) async {
          if (uri.host == 'freeipapi.com') {
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return {'latitude': 21.0285, 'longitude': 105.8542, 'cityName': 'Hà Nội'};
          }
          if (uri.host == 'api.open-meteo.com') {
            openMeteoCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return {
              'current': {
                'temperature_2m': 28.0,
                'weather_code': 2,
                'is_day': 1,
              }
            };
          }
          return null;
        },
      );

      // Dispatch 5 concurrent requests simultaneously
      final futures = List.generate(5, (_) => weatherService.fetchWeather(force: true));
      await Future.wait(futures);

      // Exactly 1 network call executed
      expect(openMeteoCalls, 1, reason: 'Single-flight coalescing must collapse 5 calls into 1');
      expect(weatherService.snapshot, isNotNull);
      expect(weatherService.snapshot!.tempC, 28);
      expect(weatherService.snapshot!.condition, WeatherCondition.cloudy);

      weatherService.dispose();
      networkService.dispose();
    });
  });

  group('Network & Lifecycle Integration', () {
    test('does not fetch weather when network has no internet access', () async {
      final prefs = await SharedPreferences.getInstance();
      final networkService = FakeNetworkService(hasInternetAccess: false);

      int networkCalls = 0;
      final weatherService = WeatherService(
        prefs,
        networkService,
        jsonFetcher: (uri, {Duration? timeout}) async {
          networkCalls++;
          return null;
        },
      );

      await weatherService.fetchWeather(force: true);
      expect(networkCalls, 0);

      weatherService.dispose();
      networkService.dispose();
    });

    test('onAppPause cancels periodic timer, onAppResume restores it', () async {
      final prefs = await SharedPreferences.getInstance();
      final networkService = FakeNetworkService(hasInternetAccess: true);

      final weatherService = WeatherService(
        prefs,
        networkService,
        jsonFetcher: (uri, {Duration? timeout}) async => null,
      );
      expect(weatherService.isPaused, isFalse);

      weatherService.onAppPause();
      expect(weatherService.isPaused, isTrue);

      weatherService.onAppResume();
      expect(weatherService.isPaused, isFalse);

      weatherService.dispose();
      networkService.dispose();
    });
  });

  group('SettingsService Weather Toggle & Backup', () {
    test('showWeatherInStatusBar defaults to true and updates correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      final settingsService = SettingsService(prefs);

      expect(settingsService.showWeatherInStatusBar, isTrue);

      await settingsService.setShowWeatherInStatusBar(false);
      expect(settingsService.showWeatherInStatusBar, isFalse);

      final exported = settingsService.exportSettings();
      expect(exported['showWeatherInStatusBar'], isFalse);

      await settingsService.setShowWeatherInStatusBar(true);
      expect(settingsService.showWeatherInStatusBar, isTrue);

      await settingsService.importSettings(exported);
      expect(settingsService.showWeatherInStatusBar, isFalse);
    });
  });

  group('WeatherService.normalizeCityName & Zero-Trust Sanitization', () {
    test('restores Vietnamese accents for 63 provinces and major cities', () {
      expect(WeatherService.normalizeCityName('Bac Ninh'), 'Bắc Ninh');
      expect(WeatherService.normalizeCityName('Hanoi'), 'Hà Nội');
      expect(WeatherService.normalizeCityName('Ha Noi'), 'Hà Nội');
      expect(WeatherService.normalizeCityName('Ho Chi Minh'), 'TP. Hồ Chí Minh');
      expect(WeatherService.normalizeCityName('Saigon'), 'TP. Hồ Chí Minh');
      expect(WeatherService.normalizeCityName('Da Nang'), 'Đà Nẵng');
      expect(WeatherService.normalizeCityName('Hue'), 'Huế');
      expect(WeatherService.normalizeCityName('Hai Phong'), 'Hải Phòng');
      expect(WeatherService.normalizeCityName('Can Tho'), 'Cần Thơ');
      expect(WeatherService.normalizeCityName('Nha Trang'), 'Nha Trang');
      expect(WeatherService.normalizeCityName('Vung Tau'), 'Vũng Tàu');
      expect(WeatherService.normalizeCityName('Da Lat'), 'Đà Lạt');
      expect(WeatherService.normalizeCityName('Buon Ma Thuot'), 'Buôn Ma Thuột');
      expect(WeatherService.normalizeCityName('Quy Nhon'), 'Quy Nhơn');
      expect(WeatherService.normalizeCityName('Phan Thiet'), 'Phan Thiết');
      expect(WeatherService.normalizeCityName('Ha Long'), 'Hạ Long');
      expect(WeatherService.normalizeCityName('Dak Lak'), 'Đắk Lắk');
    });

    test('strips prefixes and suffixes cleanly', () {
      expect(WeatherService.normalizeCityName('City of Hanoi'), 'Hà Nội');
      expect(WeatherService.normalizeCityName('Bac Ninh Province'), 'Bắc Ninh');
      expect(WeatherService.normalizeCityName('Tinh Bac Ninh'), 'Bắc Ninh');
      expect(WeatherService.normalizeCityName('Thanh pho Da Nang'), 'Đà Nẵng');
      expect(WeatherService.normalizeCityName('Hue City'), 'Huế');
      expect(WeatherService.normalizeCityName('City of Bac Ninh'), 'Bắc Ninh');
      expect(WeatherService.normalizeCityName('Thanh pho Hanoi'), 'Hà Nội');
      expect(WeatherService.normalizeCityName('Hanoi Province'), 'Hà Nội');
      expect(WeatherService.normalizeCityName('Ho Chi Minh Metropolitan area'), 'TP. Hồ Chí Minh');
      expect(WeatherService.normalizeCityName('Thành phố Đà Nẵng City'), 'Đà Nẵng');
    });

    test('Zero-Trust sanitization removes HTML tags, scripts, control & bidi chars', () {
      expect(
        WeatherService.normalizeCityName('<script>alert("xss")</script>Bac Ninh'),
        'Bắc Ninh',
      );
      expect(WeatherService.normalizeCityName('<b>Hanoi</b>'), 'Hà Nội');
      expect(WeatherService.normalizeCityName('<b>Da Nang</b>'), 'Đà Nẵng');
      expect(WeatherService.normalizeCityName('\u200EHa Noi\u200F'), 'Hà Nội');
      expect(WeatherService.normalizeCityName('\x00\x1FBac Ninh\x7F'), 'Bắc Ninh');
      expect(WeatherService.normalizeCityName('\u200E\u200F\u0007Hanoi\u0000'), 'Hà Nội');
    });

    test('clamps unknown string to 30 chars and provides safe fallback for null, empty, hyphen, unknown', () {
      expect(WeatherService.normalizeCityName(null), 'Hà Nội');
      expect(WeatherService.normalizeCityName(''), 'Hà Nội');
      expect(WeatherService.normalizeCityName('   '), 'Hà Nội');
      expect(WeatherService.normalizeCityName('-'), 'Hà Nội');
      expect(WeatherService.normalizeCityName('unknown'), 'Hà Nội');
      expect(WeatherService.normalizeCityName('UNKNOWN'), 'Hà Nội');
      expect(WeatherService.normalizeCityName('null'), 'Hà Nội');
      expect(WeatherService.normalizeCityName('n/a'), 'Hà Nội');
      expect(
        WeatherService.normalizeCityName('A Very Long Unknown City Name Exceeding Thirty Characters'),
        'A Very Long Unknown City Name',
      );
    });
  });

  group('Adaptive Polling & Polling Interval Resolution', () {
    test('resolves 30 mins for severe weather and 60 mins for calm weather', () {
      expect(WeatherService.resolvePollingInterval(WeatherCondition.rain), const Duration(minutes: 30));
      expect(WeatherService.resolvePollingInterval(WeatherCondition.thunderstorm), const Duration(minutes: 30));
      expect(WeatherService.resolvePollingInterval(WeatherCondition.snow), const Duration(minutes: 30));

      expect(WeatherService.resolvePollingInterval(WeatherCondition.sunny), const Duration(minutes: 60));
      expect(WeatherService.resolvePollingInterval(WeatherCondition.cloudy), const Duration(minutes: 60));
      expect(WeatherService.resolvePollingInterval(WeatherCondition.overcast), const Duration(minutes: 60));
      expect(WeatherService.resolvePollingInterval(WeatherCondition.fog), const Duration(minutes: 60));
      expect(WeatherService.resolvePollingInterval(WeatherCondition.unknown), const Duration(minutes: 60));
      expect(WeatherService.resolvePollingInterval(null), const Duration(minutes: 60));
    });

    test('currentPollingInterval defaults to 60 mins when snapshot is null', () async {
      final prefs = await SharedPreferences.getInstance();
      final networkService = FakeNetworkService(hasInternetAccess: false);
      final weatherService = WeatherService(prefs, networkService);

      expect(weatherService.snapshot, isNull);
      expect(weatherService.currentPollingInterval, const Duration(minutes: 60));

      weatherService.dispose();
      networkService.dispose();
    });

    test('currentPollingInterval adapts dynamically to snapshot condition', () async {
      final prefs = await SharedPreferences.getInstance();
      final networkService = FakeNetworkService(hasInternetAccess: true);

      // Rain -> 30 mins
      final rainWeatherService = WeatherService(
        prefs,
        networkService,
        jsonFetcher: (uri, {Duration? timeout}) async {
          if (uri.host == 'freeipapi.com') {
            return {'latitude': 21.0285, 'longitude': 105.8542, 'cityName': 'Hà Nội'};
          }
          if (uri.host == 'api.open-meteo.com') {
            return {
              'current': {
                'temperature_2m': 25.0,
                'weather_code': 61,
                'is_day': 1,
              }
            };
          }
          return null;
        },
      );
      await rainWeatherService.fetchWeather(force: true);
      expect(rainWeatherService.currentPollingInterval, const Duration(minutes: 30));
      rainWeatherService.dispose();

      // Sunny -> 60 mins
      final sunnyWeatherService = WeatherService(
        prefs,
        networkService,
        jsonFetcher: (uri, {Duration? timeout}) async {
          if (uri.host == 'freeipapi.com') {
            return {'latitude': 21.0285, 'longitude': 105.8542, 'cityName': 'Hà Nội'};
          }
          if (uri.host == 'api.open-meteo.com') {
            return {
              'current': {
                'temperature_2m': 30.0,
                'weather_code': 0,
                'is_day': 1,
              }
            };
          }
          return null;
        },
      );
      await sunnyWeatherService.fetchWeather(force: true);
      expect(sunnyWeatherService.currentPollingInterval, const Duration(minutes: 60));
      sunnyWeatherService.dispose();

      networkService.dispose();
    });
  });

  group('Persistent GeoIP Cache & Network Savings', () {
    test('uses cached GeoLocation and bypasses GeoIP network calls on non-forced fetch', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        WeatherService.geoCacheKey,
        '{"latitude": 10.8231, "longitude": 106.6297, "cityName": "TP. Hồ Chí Minh"}',
      );

      final networkService = FakeNetworkService(hasInternetAccess: true);
      int geoIpCalls = 0;
      final weatherService = WeatherService(
        prefs,
        networkService,
        jsonFetcher: (uri, {Duration? timeout}) async {
          if (uri.host == 'freeipapi.com' || uri.host == 'ipwho.is') {
            geoIpCalls++;
            return null;
          }
          if (uri.host == 'api.open-meteo.com') {
            return {
              'current': {
                'temperature_2m': 30.0,
                'weather_code': 0,
                'is_day': 1,
              }
            };
          }
          return null;
        },
      );

      // fetchWeather with force: false
      await weatherService.fetchWeather(force: false);

      expect(geoIpCalls, 0, reason: 'Must use persistent GeoIP cache and make ZERO GeoIP requests');
      expect(weatherService.snapshot!.cityName, 'TP. Hồ Chí Minh');

      weatherService.dispose();
      networkService.dispose();
    });
  });

  group('Silent Fetch & Data Diff Guard', () {
    test('silent fetch does not trigger start loading notify and suppresses notify when data identical', () async {
      final prefs = await SharedPreferences.getInstance();
      final networkService = FakeNetworkService(hasInternetAccess: true);

      final weatherService = WeatherService(
        prefs,
        networkService,
        jsonFetcher: (uri, {Duration? timeout}) async {
          if (uri.host == 'freeipapi.com') {
            return {'latitude': 21.0285, 'longitude': 105.8542, 'cityName': 'Hà Nội'};
          }
          if (uri.host == 'api.open-meteo.com') {
            return {
              'current': {
                'temperature_2m': 28.0,
                'weather_code': 0,
                'is_day': 1,
              }
            };
          }
          return null;
        },
      );

      // Initial manual fetch
      await weatherService.fetchWeather(force: true);
      expect(weatherService.snapshot!.tempC, 28);

      // Now attach listener to count notifications during silent fetch with identical data
      int notifyCount = 0;
      weatherService.addListener(() {
        notifyCount++;
      });

      // Silent fetch with same data
      await weatherService.fetchWeather(force: true, silent: true);

      expect(notifyCount, 0, reason: 'Identical data under silent fetch must produce 0 re-render notifications');

      weatherService.dispose();
      networkService.dispose();
    });
  });
}
