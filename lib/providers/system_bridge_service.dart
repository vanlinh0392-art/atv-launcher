import 'dart:async';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionsSnapshot {
  final String health;
  final int missingRequiredCount;
  final int missingRecommendedCount;
  final int missingOptionalCount;
  final List<Map<String, dynamic>> requirements;
  final List<String> commands;
  final bool autoGrantAdbOnWake;
  final bool autoProvisionAdbPermissions;
  final Map<String, dynamic> raw;

  const PermissionsSnapshot({
    this.health = 'missing_required',
    this.missingRequiredCount = 0,
    this.missingRecommendedCount = 0,
    this.missingOptionalCount = 0,
    this.requirements = const [],
    this.commands = const [],
    this.autoGrantAdbOnWake = true,
    this.autoProvisionAdbPermissions = true,
    this.raw = const {},
  });

  factory PermissionsSnapshot.fromMap(
    Map<String, dynamic> map, {
    bool autoGrantAdbOnWake = true,
    bool autoProvisionAdbPermissions = true,
  }) {
    final effectiveAutoGrant = map['autoGrantAdbOnWake'] as bool? ??
        map['autoProvisionAdbPermissions'] as bool? ??
        autoGrantAdbOnWake;
    final effectiveAutoProvision =
        map['autoProvisionAdbPermissions'] as bool? ??
            map['autoGrantAdbOnWake'] as bool? ??
            autoProvisionAdbPermissions;
    return PermissionsSnapshot(
      health: map['health']?.toString() ?? 'missing_required',
      missingRequiredCount:
          ((map['missingRequiredCount'] as num?) ?? 0).toInt(),
      missingRecommendedCount:
          ((map['missingRecommendedCount'] as num?) ?? 0).toInt(),
      missingOptionalCount:
          ((map['missingOptionalCount'] as num?) ?? 0).toInt(),
      requirements: ((map['requirements'] as List?) ?? const [])
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList(growable: false),
      commands: ((map['commands'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      autoGrantAdbOnWake: effectiveAutoGrant,
      autoProvisionAdbPermissions: effectiveAutoProvision,
      raw: map,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PermissionsSnapshot &&
        other.health == health &&
        other.missingRequiredCount == missingRequiredCount &&
        other.missingRecommendedCount == missingRecommendedCount &&
        other.missingOptionalCount == missingOptionalCount &&
        other.autoGrantAdbOnWake == autoGrantAdbOnWake &&
        other.autoProvisionAdbPermissions == autoProvisionAdbPermissions &&
        mapEquals(other.raw, raw);
  }

  @override
  int get hashCode => Object.hash(
        health,
        missingRequiredCount,
        missingRecommendedCount,
        missingOptionalCount,
        autoGrantAdbOnWake,
        autoProvisionAdbPermissions,
      );
}

class SystemBridgeService extends ChangeNotifier {
  static const String autoGrantAdbPrefKey =
      'launcher_pref_auto_grant_adb_permissions';

  final FLauncherChannel _channel;
  final SharedPreferences? _prefs;
  StreamSubscription<dynamic>? _systemSubscription;

  Map<String, dynamic> _status = const {};
  Map<String, dynamic> _accessibilitySnapshot = const {};
  PermissionsSnapshot _permissionsSnapshot = const PermissionsSnapshot();
  String _diagnosticsReport = '';
  bool _initialized = false;
  bool _autoGrantAdbOnWake = true;

  bool get initialized => _initialized;
  bool get autoGrantAdbOnWake => _autoGrantAdbOnWake;
  bool get autoProvisionAdbPermissions => _autoGrantAdbOnWake;
  PermissionsSnapshot get permissionsSnapshot => _permissionsSnapshot;
  Map<String, dynamic> get status => _status;
  Map<String, dynamic> get navigationStatus =>
      _nestedMap(_status['navigation']);
  Map<String, dynamic> get voiceStatus => _nestedMap(_status['voice']);
  Map<String, dynamic> get systemCoreStatus =>
      _nestedMap(_status['systemCore']);
  Map<String, dynamic> get adbAutomationStatus =>
      _nestedMap(_status['adbAutomation']);
  Map<String, dynamic> get homeGuardStatus => _nestedMap(_status['homeGuard']);
  Map<String, dynamic> get densityStatus => _nestedMap(_status['density']);
  Map<String, dynamic> get privateDnsStatus =>
      _nestedMap(_status['privateDns']);
  Map<String, dynamic> get wallpaperStatus => _nestedMap(_status['wallpaper']);
  Map<String, dynamic> get provisioningStatus =>
      _nestedMap(_status['provisioning']);
  Map<String, dynamic> get updateStatus => _nestedMap(_status['updates']);
  Map<String, dynamic> get memoryStatus => _nestedMap(_status['memory']);
  Map<String, dynamic> get fileAccessStatus =>
      _nestedMap(_status['fileAccess']);
  Map<String, dynamic> get backupStatus => _nestedMap(_status['backup']);
  Map<String, dynamic> get accessibilitySnapshot => _accessibilitySnapshot;
  List<Map<String, dynamic>> get accessibilityApps =>
      ((_accessibilitySnapshot['apps'] as List?) ?? const [])
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList(growable: false);
  String get diagnosticsReport => _diagnosticsReport;

  SystemBridgeService(this._channel, [this._prefs]) {
    _init();
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await _getPrefs();
      if (prefs.containsKey(autoGrantAdbPrefKey)) {
        _autoGrantAdbOnWake = prefs.getBool(autoGrantAdbPrefKey) ?? true;
      }
    } catch (_) {}
  }

  Future<void> _persistAutoGrantPreference(bool value) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(autoGrantAdbPrefKey, value);
    } catch (_) {}
  }

  Future<void> setAutoGrantAdbOnWake(bool value) async {
    if (_autoGrantAdbOnWake == value) return;
    _autoGrantAdbOnWake = value;
    await _persistAutoGrantPreference(value);
    _updatePermissionsSnapshot();
    notifyListeners();
  }

  Future<void> setAutoProvisionAdbPermissions(bool value) =>
      setAutoGrantAdbOnWake(value);

  void _updatePermissionsSnapshot() {
    _permissionsSnapshot = PermissionsSnapshot.fromMap(
      provisioningStatus,
      autoGrantAdbOnWake: _autoGrantAdbOnWake,
      autoProvisionAdbPermissions: _autoGrantAdbOnWake,
    );
  }

  Future<void> _init() async {
    await _loadPreferences();
    await refreshLite();
    _systemSubscription = _channel.addSystemChangedListener((event) {
      if (_applyStatusSnapshot(event)) {
        notifyListeners();
      }
    });
  }

  Future<void> refresh() async => refreshLite();

  Future<void> refreshLite() async {
    final changed =
        _applyStatusSnapshot(await _channel.getSystemBridgeStatusLite());
    final initializedChanged = !_initialized;
    _initialized = true;
    if (changed || initializedChanged) {
      notifyListeners();
    }
  }

  Future<void> refreshFull() async {
    final changed =
        _applyStatusSnapshot(await _channel.getSystemBridgeStatus());
    final initializedChanged = !_initialized;
    _initialized = true;
    if (changed || initializedChanged) {
      notifyListeners();
    }
  }

  Future<void> refreshAccessibilitySnapshot({bool includeApps = true}) async {
    final nextSnapshot = await _channel.getAccessibilityManagerSnapshot(includeApps: includeApps);
    if (_deepEquals(_accessibilitySnapshot, nextSnapshot)) {
      return;
    }
    _accessibilitySnapshot = nextSnapshot;
    notifyListeners();
  }

  Future<void> refreshDiagnostics() async {
    final nextReport = await _channel.getDiagnosticsReport();
    final statusChanged = _applyStatusSnapshot(<String, dynamic>{
      'diagnosticsReport': nextReport,
    });
    if (_diagnosticsReport == nextReport && !statusChanged) {
      return;
    }
    _diagnosticsReport = nextReport;
    notifyListeners();
  }

  Future<Map<String, dynamic>> setVoiceMode({
    int? mode,
    int? keyCode,
    bool? interceptEnabled,
  }) async {
    final result = await _channel.setVoiceMode(
      mode: mode,
      keyCode: keyCode,
      interceptEnabled: interceptEnabled,
    );
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> setVoiceInterceptEnabled(bool enabled) async {
    final result = await _channel.setVoiceInterceptEnabled(enabled);
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> startKeyLearning() async {
    final result = await _channel.startKeyLearning();
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> resetVoiceMapping() async {
    final result = await _channel.resetVoiceMapping();
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> testVoiceSearch() => _channel.testVoiceSearch();

  Future<Map<String, dynamic>> getVoiceSubtitleConfig() =>
      _channel.getVoiceSubtitleConfig();

  Future<bool> setVoiceSubtitleConfig({int? size, int? color}) =>
      _channel.setVoiceSubtitleConfig(size: size, color: color);

  Future<Map<String, dynamic>> setTtsEngine(String engine) =>
      _channel.setTtsEngine(engine);

  Future<Map<String, dynamic>> getTtsEngine() =>
      _channel.getTtsEngine();

  Future<bool> testTtsVoice([String? text]) =>
      _channel.testTtsVoice(text);

  Future<void> openAccessibilitySettings() async =>
      _channel.openAccessibilitySettings();

  Future<bool> openSpecificSettingsPage(String page) async =>
      _channel.openSpecificAndroidSettingsPage(page);

  Future<Map<String, dynamic>> repairAccessibility() async {
    final result = await _channel.repairAccessibility();
    await refreshLite();
    await refreshAccessibilitySnapshot();
    return result;
  }

  Future<Map<String, dynamic>> grantWriteSecureSettingsWithLocalAdb() async {
    final result = await _channel.grantWriteSecureSettingsWithLocalAdb();
    await refreshLite();
    await refreshAccessibilitySnapshot();
    return result;
  }

  Future<Map<String, dynamic>> setAdbAutomationPolicy({
    required String policy,
    required bool disableOnSleep,
  }) async {
    final result = await _channel.setAdbAutomationPolicy(
      policy: policy,
      disableOnSleep: disableOnSleep,
    );
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> setAdbEnabledNow(bool enabled) async {
    final result = await _channel.setAdbEnabledNow(enabled);
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> runProvisioningAction({
    required String action,
    String? suggestedPolicy,
  }) async {
    final result = await _channel.runProvisioningAction(
      action: action,
      suggestedPolicy: suggestedPolicy,
    );
    await refreshLite();
    await refreshAccessibilitySnapshot();
    return result;
  }

  Future<Map<String, dynamic>> setManagedAccessibility(
      String packageName, bool enabled) async {
    final result = await _channel.setManagedAccessibility(packageName, enabled);
    await refreshAccessibilitySnapshot();
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> applyDensity(int density) async {
    final result = await _channel.applyDensity(density);
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> resetDensity() async {
    final result = await _channel.resetDensity();
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> applyPrivateDns({
    required String mode,
    String? host,
  }) async {
    final result = await _channel.applyPrivateDns(mode: mode, host: host);
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> resetPrivateDns() async {
    final result = await _channel.resetPrivateDns();
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> getFileAccessStatus() async {
    final result = await _channel.getFileAccessStatus();
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> requestMediaReadPermission() async {
    final result = await _channel.requestMediaReadPermission();
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> prepareLauncherUpdateInstall() async {
    final result = await _channel.prepareLauncherUpdateInstall();
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> installDownloadedApk(String filePath) async {
    final result = await _channel.installDownloadedApk(filePath);
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> browseLocalVideoLibrary({
    String? bucketId,
  }) =>
      _channel.browseLocalVideoLibrary(bucketId: bucketId);

  Future<Map<String, dynamic>> exportSettingsBackup({
    required String fileName,
    required String content,
  }) async {
    final result = await _channel.exportSettingsBackup(
      fileName: fileName,
      content: content,
    );
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> importSettingsBackup() async {
    final result = await _channel.importSettingsBackup();
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> previewBackup() async =>
      _channel.previewBackup();

  Future<List<Map<String, dynamic>>> getLocalBackups() => _channel.getLocalBackups();
  Future<String> readLocalBackup(String fileName) => _channel.readLocalBackup(fileName);
  Future<bool> deleteLocalBackup(String fileName) => _channel.deleteLocalBackup(fileName);

  Future<Map<String, dynamic>> disableGoogleKatniss() async {
    final result = await _channel.disableGoogleKatniss();
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> enableGoogleKatniss() async {
    final result = await _channel.enableGoogleKatniss();
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> updateDynamicFreeAiModels() async {
    final result = await _channel.updateDynamicFreeAiModels();
    await refreshLite();
    return result;
  }

  Future<Map<String, dynamic>> recordBackupRestoreResult({
    required String importName,
    required String summary,
    required int restoredAt,
  }) async {
    final result = await _channel.recordBackupRestoreResult(
      importName: importName,
      summary: summary,
      restoredAt: restoredAt,
    );
    await refreshLite();
    return result;
  }

  static Map<String, dynamic> _nestedMap(dynamic value) =>
      value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};

  bool _applyStatusSnapshot(Map<String, dynamic> snapshot) {
    final incomingProvisioning = snapshot['provisioning'];
    var prefChanged = false;
    if (incomingProvisioning is Map) {
      final incomingAutoGrant =
          incomingProvisioning['autoGrantAdbOnWake'] as bool? ??
              incomingProvisioning['autoProvisionAdbPermissions'] as bool?;
      if (incomingAutoGrant != null && incomingAutoGrant != _autoGrantAdbOnWake) {
        _autoGrantAdbOnWake = incomingAutoGrant;
        _persistAutoGrantPreference(incomingAutoGrant);
        prefChanged = true;
      }
    }

    final snapshotKind = snapshot['snapshotKind']?.toString();
    final changed = snapshotKind == null
        ? _applyDeltaSnapshot(snapshot)
        : _applyFullSnapshot(snapshot);
    _updatePermissionsSnapshot();

    final diagnosticsReport = snapshot['diagnosticsReport']?.toString();
    if (diagnosticsReport != null &&
        diagnosticsReport.isNotEmpty &&
        diagnosticsReport != _diagnosticsReport) {
      _diagnosticsReport = diagnosticsReport;
      return true;
    }
    return changed || prefChanged;
  }

  bool _applyFullSnapshot(Map<String, dynamic> snapshot) {
    final merged = _mergeStatusMaps(_status, snapshot);
    final changed = !_deepEquals(_status, merged);
    _status = merged;
    return changed;
  }

  bool _applyDeltaSnapshot(Map<String, dynamic> snapshot) {
    if (snapshot.isEmpty) {
      return false;
    }
    final merged = _mergeDeltaMap(_status, snapshot);
    if (identical(merged, _status)) {
      return false;
    }
    _status = merged;
    return true;
  }

  static Map<String, dynamic> _mergeStatusMaps(
    Map<String, dynamic> current,
    Map<String, dynamic> update,
  ) {
    if (current.isEmpty) {
      return Map<String, dynamic>.from(update);
    }

    final merged = Map<String, dynamic>.from(current);
    update.forEach((key, value) {
      final existingValue = merged[key];
      if (existingValue is Map && value is Map) {
        merged[key] = _mergeStatusMaps(
          existingValue.cast<String, dynamic>(),
          value.cast<String, dynamic>(),
        );
      } else {
        merged[key] = value;
      }
    });
    return merged;
  }

  static dynamic _normalizeValue(dynamic val) {
    if (val is Map) {
      return val.map((k, v) => MapEntry(k.toString(), _normalizeValue(v)));
    }
    if (val is List) {
      return val.map(_normalizeValue).toList();
    }
    return val;
  }

  static Map<String, dynamic> _mergeDeltaMap(
    Map<String, dynamic> current,
    Map<String, dynamic> update,
  ) {
    Map<String, dynamic>? merged;
    update.forEach((key, value) {
      final normalizedValue = _normalizeValue(value);
      final existingValue = current[key];
      if (existingValue is Map && normalizedValue is Map) {
        final mergedChild = _mergeDeltaMap(
          existingValue.cast<String, dynamic>(),
          normalizedValue.cast<String, dynamic>(),
        );
        if (!_deepEquals(mergedChild, existingValue)) {
          merged ??= Map<String, dynamic>.from(current);
          merged![key] = mergedChild;
        }
        return;
      }
      if (_deepEquals(existingValue, normalizedValue)) {
        return;
      }
      merged ??= Map<String, dynamic>.from(current);
      merged![key] = normalizedValue;
    });
    return merged ?? current;
  }

  static bool _deepEquals(dynamic left, dynamic right) {
    if (identical(left, right)) {
      return true;
    }
    if (left is Map && right is Map) {
      if (left.length != right.length) {
        return false;
      }
      for (final key in left.keys) {
        if (!right.containsKey(key) || !_deepEquals(left[key], right[key])) {
          return false;
        }
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) {
        return false;
      }
      for (var index = 0; index < left.length; index += 1) {
        if (!_deepEquals(left[index], right[index])) {
          return false;
        }
      }
      return true;
    }
    return left == right;
  }

  @override
  void dispose() {
    _systemSubscription?.cancel();
    super.dispose();
  }
}
