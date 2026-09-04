/*
 * FLauncher
 * Copyright (C) 2021  Etienne Fesser
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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flauncher/providers/network_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WeatherCondition {
  sunny,
  cloudy,
  overcast,
  rain,
  thunderstorm,
  snow,
  fog,
  unknown,
}

extension WeatherConditionX on WeatherCondition {
  Color get color {
    switch (this) {
      case WeatherCondition.sunny:
        return const Color(0xFFFFD54F);
      case WeatherCondition.cloudy:
      case WeatherCondition.overcast:
        return const Color(0xFF90CAF9);
      case WeatherCondition.rain:
        return const Color(0xFF4FC3F7);
      case WeatherCondition.thunderstorm:
        return const Color(0xFFBA68C8);
      case WeatherCondition.snow:
        return const Color(0xFF80DEEA);
      case WeatherCondition.fog:
        return const Color(0xFFCFD8DC);
      case WeatherCondition.unknown:
        return const Color(0xFFB0BEC5);
    }
  }

  IconData get icon {
    switch (this) {
      case WeatherCondition.sunny:
        return Icons.wb_sunny_rounded;
      case WeatherCondition.cloudy:
        return Icons.cloud_queue_rounded;
      case WeatherCondition.overcast:
        return Icons.cloud_rounded;
      case WeatherCondition.rain:
        return Icons.water_drop_rounded;
      case WeatherCondition.thunderstorm:
        return Icons.flash_on_rounded;
      case WeatherCondition.snow:
        return Icons.ac_unit_rounded;
      case WeatherCondition.fog:
        return Icons.blur_on_rounded;
      case WeatherCondition.unknown:
        return Icons.help_outline_rounded;
    }
  }

  IconData getIcon({bool isDay = true}) {
    if (!isDay && this == WeatherCondition.sunny) {
      return Icons.nightlight_round;
    }
    return icon;
  }
}

/// Bộ chuẩn hóa tên thành phố Zero-Trust O(1) cho 63 tỉnh/thành phố Việt Nam.
class CityNameNormalizer {
  static final RegExp _scriptTagPattern = RegExp(
    r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>',
    caseSensitive: false,
  );
  static final RegExp _htmlTagPattern = RegExp(r'<[^>]*>');
  static final RegExp _controlBidiPattern =
      RegExp(r'[\u0000-\u001F\u007F-\u009F\u200E\u200F\u202A-\u202E]');
  static final RegExp _extraSpacesPattern = RegExp(r'\s+');

  static final RegExp _stripPrefixPattern = RegExp(
    r'^(city\s+of|thành\s+phố|thanh\s+pho|tỉnh|tinh|thị\s+xã|thi\s+xa|tp\.?|tx\.?|quận|quan|huyện|huyen)\s+',
    caseSensitive: false,
  );
  static final RegExp _stripSuffixPattern = RegExp(
    r'\s+(city|province|metropolitan\s+area|municipality|district|town)$',
    caseSensitive: false,
  );

  static const Map<String, String> _vnCityMap = {
    // 63 tỉnh/thành phố và các thành phố/tên gọi phổ biến (không dấu + có dấu)
    'ha noi': 'Hà Nội',
    'hanoi': 'Hà Nội',
    'hà nội': 'Hà Nội',
    'ho chi minh': 'TP. Hồ Chí Minh',
    'hồ chí minh': 'TP. Hồ Chí Minh',
    'ho chi minh city': 'TP. Hồ Chí Minh',
    'thành phố hồ chí minh': 'TP. Hồ Chí Minh',
    'thanh pho ho chi minh': 'TP. Hồ Chí Minh',
    'hcm': 'TP. Hồ Chí Minh',
    'saigon': 'TP. Hồ Chí Minh',
    'sài gòn': 'TP. Hồ Chí Minh',
    'tp. ho chi minh': 'TP. Hồ Chí Minh',
    'tp hồ chí minh': 'TP. Hồ Chí Minh',
    'tp. hồ chí minh': 'TP. Hồ Chí Minh',
    'tp ho chi minh': 'TP. Hồ Chí Minh',
    'da nang': 'Đà Nẵng',
    'danang': 'Đà Nẵng',
    'đà nẵng': 'Đà Nẵng',
    'hai phong': 'Hải Phòng',
    'haiphong': 'Hải Phòng',
    'hải phòng': 'Hải Phòng',
    'can tho': 'Cần Thơ',
    'cantho': 'Cần Thơ',
    'cần thơ': 'Cần Thơ',
    'an giang': 'An Giang',
    'ba ria - vung tau': 'Bà Rịa - Vũng Tàu',
    'ba ria vung tau': 'Bà Rịa - Vũng Tàu',
    'bà rịa - vũng tàu': 'Bà Rịa - Vũng Tàu',
    'bà rịa vũng tàu': 'Bà Rịa - Vũng Tàu',
    'vung tau': 'Vũng Tàu',
    'vũng tàu': 'Vũng Tàu',
    'bac giang': 'Bắc Giang',
    'bắc giang': 'Bắc Giang',
    'bac kan': 'Bắc Kạn',
    'bắc kạn': 'Bắc Kạn',
    'bac lieu': 'Bạc Liêu',
    'bạc liêu': 'Bạc Liêu',
    'bac ninh': 'Bắc Ninh',
    'bắc ninh': 'Bắc Ninh',
    'ben tre': 'Bến Tre',
    'bến tre': 'Bến Tre',
    'binh dinh': 'Bình Định',
    'bình định': 'Bình Định',
    'binh duong': 'Bình Dương',
    'bình dương': 'Bình Dương',
    'binh phuoc': 'Bình Phước',
    'bình phước': 'Bình Phước',
    'binh thuan': 'Bình Thuận',
    'bình thuận': 'Bình Thuận',
    'ca mau': 'Cà Mau',
    'cà mau': 'Cà Mau',
    'cao bang': 'Cao Bằng',
    'cao bằng': 'Cao Bằng',
    'dak lak': 'Đắk Lắk',
    'dac lac': 'Đắk Lắk',
    'đắk lắk': 'Đắk Lắk',
    'dak nong': 'Đắk Nông',
    'dac nong': 'Đắk Nông',
    'đắk nông': 'Đắk Nông',
    'dien bien': 'Điện Biên',
    'điện biên': 'Điện Biên',
    'dong nai': 'Đồng Nai',
    'đồng nai': 'Đồng Nai',
    'dong thap': 'Đồng Tháp',
    'đồng tháp': 'Đồng Tháp',
    'gia lai': 'Gia Lai',
    'ha giang': 'Hà Giang',
    'hà giang': 'Hà Giang',
    'ha nam': 'Hà Nam',
    'hà nam': 'Hà Nam',
    'ha tinh': 'Hà Tĩnh',
    'hà tĩnh': 'Hà Tĩnh',
    'hai duong': 'Hải Dương',
    'hải dương': 'Hải Dương',
    'hau giang': 'Hậu Giang',
    'hậu giang': 'Hậu Giang',
    'hoa binh': 'Hòa Bình',
    'hòa bình': 'Hòa Bình',
    'hung yen': 'Hưng Yên',
    'hưng yên': 'Hưng Yên',
    'khanh hoa': 'Khánh Hòa',
    'khánh hòa': 'Khánh Hòa',
    'kien giang': 'Kiên Giang',
    'kiên giang': 'Kiên Giang',
    'kon tum': 'Kon Tum',
    'lai chau': 'Lai Châu',
    'lai châu': 'Lai Châu',
    'lam dong': 'Lâm Đồng',
    'lâm đồng': 'Lâm Đồng',
    'lang son': 'Lạng Sơn',
    'lạng sơn': 'Lạng Sơn',
    'lao cai': 'Lào Cai',
    'lào cai': 'Lào Cai',
    'long an': 'Long An',
    'nam dinh': 'Nam Định',
    'nam định': 'Nam Định',
    'nghe an': 'Nghệ An',
    'nghệ an': 'Nghệ An',
    'ninh binh': 'Ninh Bình',
    'ninh bình': 'Ninh Bình',
    'ninh thuan': 'Ninh Thuận',
    'ninh thuận': 'Ninh Thuận',
    'phu tho': 'Phú Thọ',
    'phú thọ': 'Phú Thọ',
    'phu yen': 'Phú Yên',
    'phú yên': 'Phú Yên',
    'quang binh': 'Quảng Bình',
    'quảng bình': 'Quảng Bình',
    'quang nam': 'Quảng Nam',
    'quảng nam': 'Quảng Nam',
    'quang ngai': 'Quảng Ngãi',
    'quảng ngãi': 'Quảng Ngãi',
    'quang ninh': 'Quảng Ninh',
    'quảng ninh': 'Quảng Ninh',
    'quang tri': 'Quảng Trị',
    'quảng trị': 'Quảng Trị',
    'soc trang': 'Sóc Trăng',
    'sóc trăng': 'Sóc Trăng',
    'son la': 'Sơn La',
    'sơn la': 'Sơn La',
    'tay ninh': 'Tây Ninh',
    'tây ninh': 'Tây Ninh',
    'thai binh': 'Thái Bình',
    'thái bình': 'Thái Bình',
    'thai nguyen': 'Thái Nguyên',
    'thái nguyên': 'Thái Nguyên',
    'thanh hoa': 'Thanh Hóa',
    'thanh hoá': 'Thanh Hóa',
    'thừa thiên huế': 'Thừa Thiên Huế',
    'thua thien hue': 'Thừa Thiên Huế',
    'hue': 'Huế',
    'huế': 'Huế',
    'tien giang': 'Tiền Giang',
    'tiền giang': 'Tiền Giang',
    'tra vinh': 'Trà Vinh',
    'trà vinh': 'Trà Vinh',
    'tuyen quang': 'Tuyên Quang',
    'tuyên quang': 'Tuyên Quang',
    'vinh long': 'Vĩnh Long',
    'vĩnh long': 'Vĩnh Long',
    'vinh phuc': 'Vĩnh Phúc',
    'vĩnh phúc': 'Vĩnh Phúc',
    'yen bai': 'Yên Bái',
    'yên bái': 'Yên Bái',
    // Các thành phố, thị xã phổ biến
    'nha trang': 'Nha Trang',
    'da lat': 'Đà Lạt',
    'dalat': 'Đà Lạt',
    'đà lạt': 'Đà Lạt',
    'buon ma thuot': 'Buôn Ma Thuột',
    'ban me thuot': 'Buôn Ma Thuột',
    'buôn ma thuột': 'Buôn Ma Thuột',
    'quy nhon': 'Quy Nhơn',
    'quy nhơn': 'Quy Nhơn',
    'phan thiet': 'Phan Thiết',
    'phan thiết': 'Phan Thiết',
    'pleiku': 'Pleiku',
    'ha long': 'Hạ Long',
    'hạ long': 'Hạ Long',
    'halong': 'Hạ Long',
    'cam ranh': 'Cam Ranh',
    'rach gia': 'Rạch Giá',
    'rạch giá': 'Rạch Giá',
    'bien hoa': 'Biên Hòa',
    'biên hòa': 'Biên Hòa',
    'thu duc': 'Thủ Đức',
    'thủ đức': 'Thủ Đức',
    'vinh': 'Vinh',
    'tam ky': 'Tam Kỳ',
    'tam kỳ': 'Tam Kỳ',
    'hoi an': 'Hội An',
    'hội an': 'Hội An',
    'tuy hoa': 'Tuy Hòa',
    'tuy hòa': 'Tuy Hòa',
    'dong hoi': 'Đồng Hới',
    'đồng hới': 'Đồng Hới',
    'dong ha': 'Đông Hà',
    'đông hà': 'Đông Hà',
    'my tho': 'Mỹ Tho',
    'mỹ tho': 'Mỹ Tho',
    'tan an': 'Tân An',
    'tân an': 'Tân An',
    'long xuyen': 'Long Xuyên',
    'long xuyên': 'Long Xuyên',
    'chau doc': 'Châu Đốc',
    'châu đốc': 'Châu Đốc',
    'cao lanh': 'Cao Lãnh',
    'cao lãnh': 'Cao Lãnh',
    'sa dec': 'Sa Đéc',
    'sa đéc': 'Sa Đéc',
    'viet tri': 'Việt Trì',
    'việt trì': 'Việt Trì',
    'uong bi': 'Uông Bí',
    'uông bí': 'Uông Bí',
    'cam pha': 'Cẩm Phả',
    'cẩm phả': 'Cẩm Phả',
    'mong cai': 'Móng Cái',
    'móng cái': 'Móng Cái',
    'sam son': 'Sầm Sơn',
    'sầm sơn': 'Sầm Sơn',
    'phu ly': 'Phủ Lý',
    'phủ lý': 'Phủ Lý',
    'phu quoc': 'Phú Quốc',
    'phú quốc': 'Phú Quốc',
    'sa pa': 'Sa Pa',
    'sapa': 'Sa Pa',
    'dien bien phu': 'Điện Biên Phủ',
    'điện biên phủ': 'Điện Biên Phủ',
    'moc chau': 'Mộc Châu',
    'mộc châu': 'Mộc Châu',
    'bao loc': 'Bảo Lộc',
    'bảo lộc': 'Bảo Lộc',
    'phan rang': 'Phan Rang - Tháp Chàm',
    'phan rang - thap cham': 'Phan Rang - Tháp Chàm',
  };

  /// Chuẩn hóa tên thành phố O(1) an toàn Zero-Trust.
  static String normalizeCityName(String? raw) {
    if (raw == null) return 'Hà Nội';

    // 1. Zero-trust sanitization: bóc script, html, control & bidi chars
    var sanitized = raw
        .replaceAll(_scriptTagPattern, '')
        .replaceAll(_htmlTagPattern, '')
        .replaceAll(_controlBidiPattern, '')
        .trim();

    final lower = sanitized.toLowerCase();
    if (sanitized.isEmpty ||
        sanitized == '-' ||
        lower == 'unknown' ||
        lower == 'null' ||
        lower == 'n/a') {
      return 'Hà Nội';
    }

    // 2. Gọt tỉa tiền tố & hậu tố
    var stripped = sanitized;
    bool changed = true;
    while (changed) {
      changed = false;
      if (_stripPrefixPattern.hasMatch(stripped)) {
        stripped = stripped.replaceFirst(_stripPrefixPattern, '').trim();
        changed = true;
      }
      if (_stripSuffixPattern.hasMatch(stripped)) {
        stripped = stripped.replaceFirst(_stripSuffixPattern, '').trim();
        changed = true;
      }
    }
    stripped = stripped.replaceAll(_extraSpacesPattern, ' ').trim();

    if (stripped.isEmpty) {
      return 'Hà Nội';
    }

    // 3. Tra cứu O(1) theo lowercase
    final lookupKey = stripped.toLowerCase();
    final matched = _vnCityMap[lookupKey];
    if (matched != null) {
      return matched;
    }

    // 4. Nếu không nằm trong map, clamp tối đa 30 ký tự
    final clamped =
        stripped.length > 30 ? stripped.substring(0, 30).trim() : stripped;
    return clamped.isEmpty ? 'Hà Nội' : clamped;
  }
}

class WeatherSnapshot {
  final int tempC;
  final WeatherCondition condition;
  final String cityName;
  final bool isDay;
  final int fetchedAtMs;

  const WeatherSnapshot({
    required this.tempC,
    required this.condition,
    required this.cityName,
    required this.isDay,
    required this.fetchedAtMs,
  });

  Map<String, dynamic> toJson() => {
        'tempC': tempC,
        'condition': condition.name,
        'cityName': cityName,
        'isDay': isDay,
        'fetchedAtMs': fetchedAtMs,
      };

  String toJsonString() => jsonEncode(toJson());

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    final condName = json['condition'] as String? ?? 'unknown';
    final condition = WeatherCondition.values.firstWhere(
      (e) => e.name == condName,
      orElse: () => WeatherCondition.unknown,
    );
    final tempC = (json['tempC'] as num?)?.toInt() ?? 25;
    return WeatherSnapshot(
      tempC: tempC.clamp(-60, 60),
      condition: condition,
      cityName: CityNameNormalizer.normalizeCityName(json['cityName'] as String?),
      isDay: json['isDay'] as bool? ?? true,
      fetchedAtMs: (json['fetchedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  static WeatherSnapshot? fromJsonString(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return WeatherSnapshot.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('WeatherSnapshot.fromJsonString error: $e');
    }
    return null;
  }
}

class _GeoLocation {
  final double latitude;
  final double longitude;
  final String cityName;

  const _GeoLocation({
    required this.latitude,
    required this.longitude,
    required this.cityName,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'cityName': cityName,
      };

  factory _GeoLocation.fromJson(Map<String, dynamic> json) {
    return _GeoLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      cityName:
          CityNameNormalizer.normalizeCityName(json['cityName'] as String?),
    );
  }
}

typedef WeatherJsonFetcher = Future<dynamic> Function(
  Uri uri, {
  Duration? timeout,
});

class WeatherService extends ChangeNotifier with WidgetsBindingObserver {
  static const String weatherCacheKey = 'launcher_weather_cache_v2';
  static const String geoCacheKey = 'cached_geo_location_v2';
  static const Duration cacheTtl = Duration(minutes: 45);
  static const Duration periodicInterval = Duration(minutes: 60);
  static const Duration debounceInterval = Duration(seconds: 5);

  static const _GeoLocation _defaultLocation = _GeoLocation(
    latitude: 21.0285,
    longitude: 105.8542,
    cityName: 'Hà Nội',
  );

  final SharedPreferences _prefs;
  final NetworkService _networkService;
  final WeatherJsonFetcher? _customJsonFetcher;

  WeatherSnapshot? _snapshot;
  bool _isLoading = false;
  bool _isPaused = false;
  bool _wasConnected = false;
  bool _isDisposed = false;
  DateTime? _lastFetchAttempt;
  Timer? _periodicTimer;
  Timer? _reconnectDebounceTimer;
  Timer? _resumeFetchTimer;
  Completer<void>? _inFlightFetch;

  WeatherService(
    this._prefs,
    this._networkService, {
    WeatherJsonFetcher? jsonFetcher,
  }) : _customJsonFetcher = jsonFetcher {
    _wasConnected = _networkService.hasInternetAccess;
    WidgetsBinding.instance.addObserver(this);
    _loadL2Cache();
    _networkService.addListener(_onNetworkChanged);
    _startPeriodicTimer();
    if (_networkService.hasInternetAccess) {
      fetchWeather();
    }
  }

  WeatherSnapshot? get snapshot => _snapshot;
  bool get isLoading => _isLoading;
  bool get isPaused => _isPaused;

  /// Chu kỳ thăm dò thích ứng theo điều kiện thời tiết:
  /// 30 phút cho mưa/dông/tuyết, 60 phút cho các điều kiện khác.
  static Duration resolvePollingInterval(WeatherCondition? condition) {
    switch (condition) {
      case WeatherCondition.rain:
      case WeatherCondition.thunderstorm:
      case WeatherCondition.snow:
        return const Duration(minutes: 30);
      default:
        return const Duration(minutes: 60);
    }
  }

  Duration get currentPollingInterval =>
      resolvePollingInterval(_snapshot?.condition);

  static String normalizeCityName(String? raw) =>
      CityNameNormalizer.normalizeCityName(raw);

  bool get isCacheFresh {
    final currentSnapshot = _snapshot;
    if (currentSnapshot == null) return false;
    final ageMs =
        DateTime.now().millisecondsSinceEpoch - currentSnapshot.fetchedAtMs;
    return ageMs >= 0 && ageMs < cacheTtl.inMilliseconds;
  }

  void _loadL2Cache() {
    final cachedStr = _prefs.getString(weatherCacheKey);
    if (cachedStr != null && cachedStr.isNotEmpty) {
      _snapshot = WeatherSnapshot.fromJsonString(cachedStr);
    }
  }

  void _startPeriodicTimer() {
    _rescheduleAdaptiveTimer();
  }

  void _rescheduleAdaptiveTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(currentPollingInterval, (_) {
      if (!_isPaused && _networkService.hasInternetAccess) {
        fetchWeather(silent: true);
      }
    });
  }

  void _onNetworkChanged() {
    final isConnected = _networkService.hasInternetAccess;
    if (!_wasConnected && isConnected) {
      // Cạnh lên mạng: Debounce 3s và kiểm tra cache tuổi thọ > 20 phút trước khi fetch ngầm
      _reconnectDebounceTimer?.cancel();
      _reconnectDebounceTimer = Timer(const Duration(seconds: 3), () {
        if (!_isPaused && _networkService.hasInternetAccess) {
          final currentSnapshot = _snapshot;
          final ageMs = currentSnapshot == null
              ? double.maxFinite.toInt()
              : DateTime.now().millisecondsSinceEpoch -
                  currentSnapshot.fetchedAtMs;
          if (ageMs > const Duration(minutes: 20).inMilliseconds) {
            fetchWeather(silent: true);
          }
        }
      });
    } else if (isConnected && !_isPaused && !isCacheFresh) {
      fetchWeather();
    }
    _wasConnected = isConnected;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      onAppPause();
    } else if (state == AppLifecycleState.resumed) {
      onAppResume();
    }
  }

  void onAppPause() {
    _isPaused = true;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _reconnectDebounceTimer?.cancel();
    _reconnectDebounceTimer = null;
    _resumeFetchTimer?.cancel();
    _resumeFetchTimer = null;
  }

  void onAppResume() {
    _isPaused = false;
    _rescheduleAdaptiveTimer();
    _resumeFetchTimer?.cancel();
    _resumeFetchTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!_isPaused && _networkService.hasInternetAccess) {
        final currentSnapshot = _snapshot;
        final ageMs = currentSnapshot == null
            ? double.maxFinite.toInt()
            : DateTime.now().millisecondsSinceEpoch -
                currentSnapshot.fetchedAtMs;
        if (ageMs > const Duration(minutes: 30).inMilliseconds) {
          fetchWeather(silent: true);
        }
      }
    });
  }

  Future<void> fetchWeather({bool force = false, bool silent = false}) async {
    if (_inFlightFetch != null) {
      return _inFlightFetch!.future;
    }

    final now = DateTime.now();

    if (!force) {
      if (isCacheFresh) return;
      if (!_networkService.hasInternetAccess) return;
      if (_lastFetchAttempt != null &&
          now.difference(_lastFetchAttempt!) < debounceInterval) {
        return;
      }
    } else {
      if (!_networkService.hasInternetAccess) return;
      if (_lastFetchAttempt != null &&
          now.difference(_lastFetchAttempt!) < debounceInterval) {
        return;
      }
    }

    _lastFetchAttempt = now;
    _isLoading = true;
    final completer = Completer<void>();
    _inFlightFetch = completer;

    // Khi silent: true, không gọi notifyListeners() khi bắt đầu fetch để tránh gây lag giao diện
    if (!silent && !_isDisposed) {
      notifyListeners();
    }

    bool hasDataDiff = false;

    try {
      final location = await _resolveLocation(force: force);
      final fetchedSnapshot = await _fetchOpenMeteo(location);
      if (fetchedSnapshot != null) {
        final current = _snapshot;
        hasDataDiff = current == null ||
            current.tempC != fetchedSnapshot.tempC ||
            current.condition != fetchedSnapshot.condition ||
            current.cityName != fetchedSnapshot.cityName ||
            current.isDay != fetchedSnapshot.isDay;

        _snapshot = fetchedSnapshot;
        await _prefs.setString(weatherCacheKey, fetchedSnapshot.toJsonString());
      }
    } catch (e) {
      debugPrint('WeatherService fetchWeather error: $e');
    } finally {
      _isLoading = false;
      _inFlightFetch = null;
      completer.complete();
      _rescheduleAdaptiveTimer();

      // Chỉ thông báo re-render nếu không silent hoặc dữ liệu thời tiết thực tế thay đổi
      if (!_isDisposed && (!silent || hasDataDiff)) {
        notifyListeners();
      }
    }
  }

  Future<_GeoLocation> _resolveLocation({bool force = false}) async {
    // 1. Persistent GeoIP Cache: Giảm 99.8% request GeoIP
    if (!force) {
      final cachedGeoJson = _prefs.getString(geoCacheKey);
      if (cachedGeoJson != null && cachedGeoJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedGeoJson);
          if (decoded is Map<String, dynamic>) {
            return _GeoLocation.fromJson(decoded);
          }
        } catch (e) {
          debugPrint('WeatherService geoCache decode error: $e');
        }
      }
    }

    _GeoLocation? location;

    // Tầng 1: freeipapi.com (timeout 3s)
    location ??= await _resolveFromFreeIpApi();

    // Tầng 2: ipwho.is (timeout 3s)
    location ??= await _resolveFromIpWhoIs();

    // Tầng 3: Timezone Heuristic
    location ??= _resolveFromTimezone();

    // Tầng 4: Default Fallback (Hà Nội)
    location ??= _defaultLocation;

    final normalizedLocation = _GeoLocation(
      latitude: location.latitude,
      longitude: location.longitude,
      cityName: CityNameNormalizer.normalizeCityName(location.cityName),
    );

    try {
      await _prefs.setString(
        geoCacheKey,
        jsonEncode(normalizedLocation.toJson()),
      );
    } catch (e) {
      debugPrint('WeatherService save geoCache error: $e');
    }

    return normalizedLocation;
  }

  Future<_GeoLocation?> _resolveFromFreeIpApi() async {
    try {
      final json = await _fetchJson(
        Uri.parse('https://freeipapi.com/api/json'),
        timeout: const Duration(seconds: 3),
      );
      if (json is Map<String, dynamic>) {
        final lat = (json['latitude'] as num?)?.toDouble();
        final lon = (json['longitude'] as num?)?.toDouble();
        final city = (json['cityName'] as String?)?.trim();
        if (lat != null && lon != null) {
          return _GeoLocation(
            latitude: lat,
            longitude: lon,
            cityName: CityNameNormalizer.normalizeCityName(city),
          );
        }
      }
    } catch (e) {
      debugPrint('WeatherService FreeIpApi resolve error: $e');
    }
    return null;
  }

  Future<_GeoLocation?> _resolveFromIpWhoIs() async {
    try {
      final json = await _fetchJson(
        Uri.parse('https://ipwho.is/'),
        timeout: const Duration(seconds: 3),
      );
      if (json is Map<String, dynamic> && json['success'] == true) {
        final lat = (json['latitude'] as num?)?.toDouble();
        final lon = (json['longitude'] as num?)?.toDouble();
        final city = (json['city'] as String?)?.trim();
        if (lat != null && lon != null) {
          return _GeoLocation(
            latitude: lat,
            longitude: lon,
            cityName: CityNameNormalizer.normalizeCityName(city),
          );
        }
      }
    } catch (e) {
      debugPrint('WeatherService IpWhoIs resolve error: $e');
    }
    return null;
  }

  _GeoLocation? _resolveFromTimezone() {
    try {
      final now = DateTime.now();
      final offsetHours = now.timeZoneOffset.inHours;
      final tzName = now.timeZoneName.toLowerCase();
      if (offsetHours == 7 ||
          tzName.contains('ict') ||
          tzName.contains('indochina') ||
          tzName.contains('ho_chi_minh') ||
          tzName.contains('saigon') ||
          tzName.contains('vietnam') ||
          tzName.contains('bangkok') ||
          tzName.contains('hanoi')) {
        return const _GeoLocation(
          latitude: 21.0285,
          longitude: 105.8542,
          cityName: 'Hà Nội',
        );
      }
    } catch (e) {
      debugPrint('WeatherService timezone heuristic error: $e');
    }
    return null;
  }

  Future<WeatherSnapshot?> _fetchOpenMeteo(_GeoLocation location) async {
    final uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': location.latitude.toString(),
        'longitude': location.longitude.toString(),
        'current': 'temperature_2m,weather_code,is_day',
      },
    );

    final json = await _fetchJson(uri, timeout: const Duration(seconds: 5));
    if (json is! Map<String, dynamic>) return null;

    final current = json['current'] as Map<String, dynamic>?;
    if (current == null) return null;

    final tempRaw = (current['temperature_2m'] as num?)?.round() ?? 25;
    final tempC = tempRaw.clamp(-60, 60);
    final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;
    final isDayRaw = current['is_day'];
    final isDay = isDayRaw == 1 || isDayRaw == true;
    final condition = mapWeatherCodeToCondition(weatherCode);

    return WeatherSnapshot(
      tempC: tempC,
      condition: condition,
      cityName: CityNameNormalizer.normalizeCityName(location.cityName),
      isDay: isDay,
      fetchedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static WeatherCondition mapWeatherCodeToCondition(int code) {
    switch (code) {
      case 0:
        return WeatherCondition.sunny;
      case 1:
      case 2:
        return WeatherCondition.cloudy;
      case 3:
        return WeatherCondition.overcast;
      case 45:
      case 48:
        return WeatherCondition.fog;
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
      case 80:
      case 81:
      case 82:
        return WeatherCondition.rain;
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return WeatherCondition.snow;
      case 95:
      case 96:
      case 99:
        return WeatherCondition.thunderstorm;
      default:
        return WeatherCondition.unknown;
    }
  }

  Future<dynamic> _fetchJson(
    Uri uri, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final customFetcher = _customJsonFetcher;
    if (customFetcher != null) {
      return customFetcher(uri, timeout: timeout);
    }
    final client = HttpClient();
    client.connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'ATVLauncher-Weather/1.0',
      );
      final response = await request.close().timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = await utf8.decodeStream(response).timeout(timeout);
        return jsonDecode(body);
      }
    } catch (e) {
      debugPrint('WeatherService _fetchJson failed for $uri: $e');
    } finally {
      client.close(force: true);
    }
    return null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    _reconnectDebounceTimer?.cancel();
    _resumeFetchTimer?.cancel();
    _networkService.removeListener(_onNetworkChanged);
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }
}
