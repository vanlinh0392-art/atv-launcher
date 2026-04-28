import 'dart:async';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/foundation.dart';

class SystemBridgeService extends ChangeNotifier {
  final FLauncherChannel _channel;
  StreamSubscription<dynamic>? _systemSubscription;

  Map<String, dynamic> _status = const {};
  Map<String, dynamic> _accessibilitySnapshot = const {};
  String _diagnosticsReport = '';
  bool _initialized = false;

  bool get initialized => _initialized;
  Map<String, dynamic> get status => _status;
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
  Map<String, dynamic> get fileAccessStatus =>
      _nestedMap(_status['fileAccess']);
  Map<String, dynamic> get backupStatus => _nestedMap(_status['backup']);
  Map<String, dynamic> get accessibilitySnapshot => _accessibilitySnapshot;
  List<Map<String, dynamic>> get accessibilityApps =>
      ((_accessibilitySnapshot['apps'] as List?) ?? const [])
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList(growable: false);
  String get diagnosticsReport => _diagnosticsReport;

  SystemBridgeService(this._channel) {
    _init();
  }

  Future<void> _init() async {
    await refresh();
    _systemSubscription = _channel.addSystemChangedListener((event) {
      _status = event;
      notifyListeners();
    });
  }

  Future<void> refresh() async {
    _status = await _channel.getSystemBridgeStatus();
    _diagnosticsReport = _status['diagnosticsReport']?.toString() ??
        await _channel.getDiagnosticsReport();
    _initialized = true;
    notifyListeners();
  }

  Future<void> refreshAccessibilitySnapshot() async {
    _accessibilitySnapshot = await _channel.getAccessibilityManagerSnapshot();
    notifyListeners();
  }

  Future<void> refreshDiagnostics() async {
    _diagnosticsReport = await _channel.getDiagnosticsReport();
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
    await refresh();
    return result;
  }

  Future<Map<String, dynamic>> setVoiceInterceptEnabled(bool enabled) async {
    final result = await _channel.setVoiceInterceptEnabled(enabled);
    await refresh();
    return result;
  }

  Future<Map<String, dynamic>> startKeyLearning() async {
    final result = await _channel.startKeyLearning();
    await refresh();
    return result;
  }

  Future<Map<String, dynamic>> resetVoiceMapping() async {
    final result = await _channel.resetVoiceMapping();
    await refresh();
    return result;
  }

  Future<Map<String, dynamic>> testVoiceSearch() async =>
      _channel.testVoiceSearch();

  Future<void> openAccessibilitySettings() async =>
      _channel.openAccessibilitySettings();

  Future<bool> openSpecificSettingsPage(String page) async =>
      _channel.openSpecificAndroidSettingsPage(page);

  Future<Map<String, dynamic>> repairAccessibility() async {
    final result = await _channel.repairAccessibility();
    await refresh();
    await refreshAccessibilitySnapshot();
    return result;
  }

  Future<Map<String, dynamic>> grantWriteSecureSettingsWithLocalAdb() async {
    final result = await _channel.grantWriteSecureSettingsWithLocalAdb();
    await refresh();
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
    await refresh();
    return result;
  }

  Future<Map<String, dynamic>> setAdbEnabledNow(bool enabled) async {
    final result = await _channel.setAdbEnabledNow(enabled);
    await refresh();
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
    await refresh();
    await refreshAccessibilitySnapshot();
    return result;
  }

  Future<Map<String, dynamic>> setManagedAccessibility(
      String packageName, bool enabled) async {
    final result = await _channel.setManagedAccessibility(packageName, enabled);
    await refreshAccessibilitySnapshot();
    await refresh();
    return result;
  }

  Future<Map<String, dynamic>> applyDensity(int density) async {
    final result = await _channel.applyDensity(density);
    await refresh();
    return result;
  }

  Future<Map<String, dynamic>> resetDensity() async {
    final result = await _channel.resetDensity();
    await refresh();
    return result;
  }

  Future<Map<String, dynamic>> applyPrivateDns({
    required String mode,
    String? host,
  }) async {
    final result = await _channel.applyPrivateDns(mode: mode, host: host);
    await refresh();
    return result;
  }

  Future<Map<String, dynamic>> resetPrivateDns() async {
    final result = await _channel.resetPrivateDns();
    await refresh();
    return result;
  }

  Future<Map<String, dynamic>> getFileAccessStatus() async {
    final result = await _channel.getFileAccessStatus();
    await refresh();
    return result;
  }

  Future<Map<String, dynamic>> requestMediaReadPermission() async {
    final result = await _channel.requestMediaReadPermission();
    await refresh();
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
    await refresh();
    return result;
  }

  Future<Map<String, dynamic>> importSettingsBackup() async {
    final result = await _channel.importSettingsBackup();
    await refresh();
    return result;
  }

  Future<Map<String, dynamic>> previewBackup() async =>
      _channel.previewBackup();

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
    await refresh();
    return result;
  }

  static Map<String, dynamic> _nestedMap(dynamic value) =>
      value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};

  @override
  void dispose() {
    _systemSubscription?.cancel();
    super.dispose();
  }
}
