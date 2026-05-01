import 'dart:io';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/launcher_update_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';

class LauncherUpdateSession extends ChangeNotifier {
  LauncherUpdateSession({
    LauncherUpdateClient? updateClient,
    FLauncherChannel? launcherChannel,
  })  : _updateClient = updateClient ?? LauncherUpdateClient(),
        _launcherChannel = launcherChannel ?? FLauncherChannel();

  static final LauncherUpdateSession shared = LauncherUpdateSession();

  final LauncherUpdateClient _updateClient;
  final FLauncherChannel _launcherChannel;

  bool _initialized = false;
  Future<void>? _initializing;

  LauncherUpdateRelease? _latestRelease;
  bool _hasCheckedOfficialRelease = false;
  String _lastMessage = '';
  String? _downloadedApkPath;
  String? _downloadedAssetName;
  String? _downloadFileName;
  int _downloadedBytes = 0;
  int _downloadTotalBytes = 0;
  double? _downloadProgress;
  int _downloadedApkCount = 0;
  bool _busy = false;
  bool _resumeInstallAfterPermission = false;
  List<String> _deviceAbis = const <String>[];

  LauncherUpdateRelease? get latestRelease => _latestRelease;
  LauncherUpdateAsset? get latestReleaseAsset {
    final release = _latestRelease;
    if (release == null) {
      return null;
    }
    if (_deviceAbis.isEmpty) {
      return release.preferredApkAsset;
    }
    return release.preferredApkAssetFor(_deviceAbis);
  }

  bool get hasCheckedOfficialRelease => _hasCheckedOfficialRelease;
  String get lastMessage => _lastMessage;
  String? get downloadedApkPath => _downloadedApkPath;
  String? get downloadedAssetName => _downloadedAssetName;
  String? get downloadFileName => _downloadFileName;
  int get downloadedBytes => _downloadedBytes;
  int get downloadTotalBytes => _downloadTotalBytes;
  double? get downloadProgress => _downloadProgress;
  int get downloadedApkCount => _downloadedApkCount;
  bool get busy => _busy;
  bool get resumeInstallAfterPermission => _resumeInstallAfterPermission;
  List<String> get deviceAbis => List<String>.unmodifiable(_deviceAbis);

  bool get showDownloadProgress =>
      (_downloadFileName ?? '').trim().isNotEmpty && _busy;

  Future<void> initialize() {
    if (_initialized) {
      return Future<void>.value();
    }
    return _initializing ??= Future.wait<void>([
      _refreshDownloadedArtifactsInternal(),
      _loadSupportedAbisInternal(),
    ]).whenComplete(() {
      _initialized = true;
      _initializing = null;
    });
  }

  Future<void> checkLatestRelease(AppLocalizations localizations) async {
    _busy = true;
    _hasCheckedOfficialRelease = false;
    _latestRelease = null;
    _lastMessage = localizations.launcherUpdateChecking;
    notifyListeners();
    try {
      final release = await _updateClient.fetchLatestOfficialRelease();
      _hasCheckedOfficialRelease = true;
      _latestRelease = release;
      _lastMessage = release == null
          ? localizations.launcherUpdateNoOfficialRelease
          : localizations.launcherUpdateLatestReleaseReady(
              release.displayName.isEmpty
                  ? release.tagName
                  : release.displayName,
            );
      notifyListeners();
    } catch (error) {
      _lastMessage = localizations.launcherUpdateCheckFailed(error.toString());
      notifyListeners();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> downloadLatestApk(
    LauncherUpdateAsset asset,
    AppLocalizations localizations,
  ) async {
    _busy = true;
    _downloadFileName = asset.name;
    _downloadProgress = 0;
    _downloadedBytes = 0;
    _downloadTotalBytes = asset.sizeBytes;
    _lastMessage = localizations.launcherUpdateDownloadStarted(asset.name);
    notifyListeners();
    try {
      final updateDirectory = await _getUpdateDirectory();
      if (!await updateDirectory.exists()) {
        await updateDirectory.create(recursive: true);
      }
      await _deleteOldDownloads(updateDirectory);

      final fileName = _safeFileName(asset.name);
      final outputFile = File(
        '${updateDirectory.path}${Platform.pathSeparator}$fileName',
      );
      final downloadedApk = await _updateClient.downloadApkAsset(
        asset: asset,
        destinationFile: outputFile,
        onProgress: _handleDownloadProgress,
      );

      await _refreshDownloadedArtifactsInternal();
      _downloadFileName = null;
      _downloadedBytes = 0;
      _downloadTotalBytes = 0;
      _downloadProgress = null;
      _lastMessage =
          localizations.launcherUpdateDownloadComplete(downloadedApk.fileName);
      notifyListeners();
    } catch (error) {
      _downloadFileName = null;
      _downloadedBytes = 0;
      _downloadTotalBytes = 0;
      _downloadProgress = null;
      _lastMessage =
          localizations.launcherUpdateDownloadFailed(error.toString());
      notifyListeners();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> clearDownloadedApks(AppLocalizations localizations) async {
    _busy = true;
    _lastMessage = localizations.launcherUpdateCleanupWorking;
    notifyListeners();
    try {
      final removed = await _deleteOldDownloads(await _getUpdateDirectory());
      await _refreshDownloadedArtifactsInternal();
      _lastMessage = removed > 0
          ? localizations.launcherUpdateCleanupComplete(removed)
          : localizations.launcherUpdateCleanupEmpty;
      notifyListeners();
    } catch (error) {
      _lastMessage =
          localizations.launcherUpdateCleanupFailed(error.toString());
      notifyListeners();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> refreshDownloadedArtifacts() async {
    await _refreshDownloadedArtifactsInternal();
  }

  void setBusy(bool value) {
    if (_busy == value) {
      return;
    }
    _busy = value;
    notifyListeners();
  }

  void setLastMessage(String value) {
    if (_lastMessage == value) {
      return;
    }
    _lastMessage = value;
    notifyListeners();
  }

  void setResumeInstallAfterPermission(bool value) {
    if (_resumeInstallAfterPermission == value) {
      return;
    }
    _resumeInstallAfterPermission = value;
    notifyListeners();
  }

  Future<void> _refreshDownloadedArtifactsInternal() async {
    final directory = await _getUpdateDirectory();
    if (!await directory.exists()) {
      _downloadedApkCount = 0;
      _downloadedApkPath = null;
      _downloadedAssetName = null;
      notifyListeners();
      return;
    }

    final files = <File>[];
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File && entry.path.toLowerCase().endsWith('.apk')) {
        files.add(entry);
      }
    }
    files.sort(
      (left, right) => right.statSync().modified.compareTo(
            left.statSync().modified,
          ),
    );
    final newestFile = files.isEmpty ? null : files.first;
    _downloadedApkCount = files.length;
    _downloadedApkPath = newestFile?.path;
    _downloadedAssetName = newestFile == null
        ? null
        : newestFile.path.split(Platform.pathSeparator).last;
    notifyListeners();
  }

  Future<void> _loadSupportedAbisInternal() async {
    try {
      final supportedAbis = await _launcherChannel.getSupportedAbis();
      if (listEquals(_deviceAbis, supportedAbis)) {
        return;
      }
      _deviceAbis = supportedAbis;
      notifyListeners();
    } catch (_) {
      if (_deviceAbis.isEmpty) {
        return;
      }
      _deviceAbis = const <String>[];
      notifyListeners();
    }
  }

  Future<Directory> _getUpdateDirectory() async => Directory(
        '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}launcher_updates',
      );

  Future<int> _deleteOldDownloads(Directory directory) async {
    if (!await directory.exists()) {
      return 0;
    }
    var removedCount = 0;
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File && entry.path.toLowerCase().endsWith('.apk')) {
        try {
          await entry.delete();
          removedCount += 1;
        } catch (_) {
          // Keep cleanup best-effort to avoid blocking a newer download.
        }
      }
    }
    return removedCount;
  }

  String _safeFileName(String rawName) {
    final trimmed = rawName.trim();
    const fallback = 'atv-launcher-update.apk';
    if (trimmed.isEmpty) {
      return fallback;
    }
    final sanitized = trimmed.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return sanitized.isEmpty ? fallback : sanitized;
  }

  void _handleDownloadProgress(LauncherUpdateDownloadProgress progress) {
    _downloadFileName = progress.fileName;
    _downloadedBytes = progress.receivedBytes;
    _downloadTotalBytes = progress.totalBytes;
    _downloadProgress = progress.fraction;
    notifyListeners();
  }
}
