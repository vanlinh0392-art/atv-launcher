import 'dart:async';
import 'dart:io';

import 'package:flauncher/launcher_update_client.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class UpdatePanelPage extends StatefulWidget {
  static const String routeName = "update_panel";
  final FocusNode? primaryFocusNode;
  final LauncherUpdateClient? updateClient;

  const UpdatePanelPage({
    super.key,
    this.primaryFocusNode,
    this.updateClient,
  });

  @override
  State<UpdatePanelPage> createState() => _UpdatePanelPageState();
}

class _UpdatePanelPageState extends State<UpdatePanelPage>
    with WidgetsBindingObserver {
  static const String _summaryDebugLabel = 'update_panel_summary_metrics';
  static const String _statusDebugLabel = 'update_panel_status_section';
  static const String _releaseDetailsDebugLabel =
      'update_panel_release_details';
  static const double _actionCardHeight = 108;
  static const Color _statusOkColor = Color(0xFF7BE0A5);
  static const Color _statusNeedsActionColor = Color(0xFFFFC970);
  static const Color _statusInfoColor = Color(0xFF8CCBFF);

  late final LauncherUpdateClient _updateClient;
  late final FocusNode _statusFocusNode;
  late final FocusNode _releaseDetailsFocusNode;

  LauncherUpdateRelease? _latestRelease;
  bool _hasCheckedOfficialRelease = false;
  String _installedVersionLabel = '-';
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

  @override
  void initState() {
    super.initState();
    _updateClient = widget.updateClient ?? LauncherUpdateClient();
    _statusFocusNode = FocusNode(debugLabel: _statusDebugLabel);
    _releaseDetailsFocusNode = FocusNode(debugLabel: _releaseDetailsDebugLabel);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(context.read<SystemBridgeService>().refreshLite());
      Future<void>.delayed(Duration.zero, () {
        if (!mounted) {
          return;
        }
        unawaited(_loadInstalledVersion());
        unawaited(_refreshDownloadedArtifacts());
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusFocusNode.dispose();
    _releaseDetailsFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleResumed());
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final bridge = context.read<SystemBridgeService>();

    return Selector<SystemBridgeService, Map<String, dynamic>>(
      selector: (_, service) => service.updateStatus,
      builder: (context, updateStatus, _) {
        final permissionReady =
            updateStatus['canRequestPackageInstalls'] == true;
        final adbEnabled = updateStatus['adbEnabled'] == true;
        final latestAsset = _latestRelease?.preferredApkAsset;
        final latestAssetSizeLabel = _resolveLatestAssetSizeLabel(
          localizations,
          latestAsset,
        );
        final latestReleaseLabel = _resolveLatestReleaseLabel(localizations);
        final installerLabel = permissionReady
            ? localizations.launcherUpdatePermissionReady
            : localizations.launcherUpdatePermissionMissing;
        final downloadedLabel = _resolveDownloadedLabel(localizations);
        final checkCardSubtitle = _resolveCheckCardSubtitle(
          localizations,
          latestReleaseLabel,
        );
        final downloadCardSubtitle = _resolveDownloadCardSubtitle(
          context,
          localizations,
          latestAsset,
        );
        final installCardSubtitle = _resolveInstallCardSubtitle(
          localizations,
          permissionReady,
          downloadedLabel,
        );
        final localAdbCardSubtitle = _resolveLocalAdbCardSubtitle(
          localizations,
          adbEnabled,
        );
        final installsCardSubtitle = permissionReady
            ? localizations.launcherUpdatePermissionReady
            : localizations.launcherUpdatePermissionMissing;
        final cleanupCardSubtitle = _resolveCleanupCardSubtitle(
          localizations,
        );

        return ListView(
          key: const PageStorageKey<String>(UpdatePanelPage.routeName),
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _buildOverviewSummary(
              localizations: localizations,
              latestReleaseLabel: latestReleaseLabel,
              latestAssetSizeLabel: latestAssetSizeLabel,
              installerLabel: installerLabel,
              downloadedLabel: downloadedLabel,
              permissionReady: permissionReady,
            ),
            const SizedBox(height: 14),
            SettingsSurfaceCard(
              padding: const EdgeInsets.all(12),
              child: SettingsAdaptiveGrid(
                spacing: 8,
                runSpacing: 8,
                minChildWidth: 240,
                maxColumns: 2,
                children: [
                  _buildUniformActionCard(
                    focusNode: widget.primaryFocusNode,
                    onMoveUpAtBoundary: () =>
                        focusCurrentSettingsNodeByDebugLabel(
                      _summaryDebugLabel,
                    ),
                    title: localizations.checkLatestRelease,
                    subtitle: checkCardSubtitle,
                    icon: Icons.system_update_alt_outlined,
                    onPressed: _busy ? null : () => _checkLatestRelease(),
                  ),
                  _buildUniformActionCard(
                    title: localizations.downloadLatestApk,
                    subtitle: downloadCardSubtitle,
                    icon: Icons.download_for_offline_outlined,
                    onPressed: _busy || latestAsset == null
                        ? null
                        : () => _downloadLatestApk(latestAsset),
                  ),
                  _buildUniformActionCard(
                    title: localizations.installDownloadedApk,
                    subtitle: installCardSubtitle,
                    icon: Icons.system_update_alt_outlined,
                    onPressed: _busy || _downloadedApkPath == null
                        ? null
                        : () => _installDownloadedApk(
                              bridge: bridge,
                              openPermissionIfNeeded: true,
                            ),
                  ),
                  _buildUniformActionCard(
                    title: localizations.grantInstallPermissionViaLocalAdb,
                    subtitle: localAdbCardSubtitle,
                    icon: Icons.adb_outlined,
                    onPressed: _busy
                        ? null
                        : () => _grantInstallerPermissionViaLocalAdb(
                              bridge: bridge,
                              adbEnabled: adbEnabled,
                            ),
                  ),
                  _buildUniformActionCard(
                    title: localizations.allowAppInstalls,
                    subtitle: installsCardSubtitle,
                    icon: Icons.admin_panel_settings_outlined,
                    onPressed: _busy
                        ? null
                        : () => _openUnknownAppsPermission(
                              bridge,
                              resumeInstallAfterPermission: false,
                            ),
                  ),
                  _buildUniformActionCard(
                    title: localizations.cleanupDownloadedApks,
                    subtitle: cleanupCardSubtitle,
                    icon: Icons.delete_sweep_outlined,
                    onPressed: _busy || _downloadedApkCount == 0
                        ? null
                        : _clearDownloadedApks,
                  ),
                ],
              ),
            ),
            if (_lastMessage.trim().isNotEmpty || _showDownloadProgress) ...[
              const SizedBox(height: 14),
              _buildStatusSummary(
                context: context,
                localizations: localizations,
              ),
            ],
            const SizedBox(height: 14),
            SettingsSurfaceCard(
              child: SettingsSummarySection(
                debugLabel: _releaseDetailsDebugLabel,
                focusNode: _releaseDetailsFocusNode,
                child: _buildReleaseDetails(
                  context,
                  localizations,
                  permissionReady,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadInstalledVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      final buildNumber = packageInfo.buildNumber.trim();
      _installedVersionLabel = buildNumber.isEmpty
          ? packageInfo.version
          : '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _handleResumed() async {
    if (!mounted) {
      return;
    }
    final bridge = context.read<SystemBridgeService>();
    await bridge.refreshLite();
    if (!mounted ||
        !_resumeInstallAfterPermission ||
        _downloadedApkPath == null) {
      return;
    }
    final permissionReady =
        bridge.updateStatus['canRequestPackageInstalls'] == true;
    if (!permissionReady) {
      return;
    }
    await _installDownloadedApk(
      bridge: bridge,
      openPermissionIfNeeded: false,
    );
  }

  Future<void> _checkLatestRelease() async {
    final localizations = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _hasCheckedOfficialRelease = false;
      _latestRelease = null;
      _lastMessage = localizations.launcherUpdateChecking;
    });
    try {
      final release = await _updateClient.fetchLatestOfficialRelease();
      if (!mounted) {
        return;
      }
      setState(() {
        _hasCheckedOfficialRelease = true;
        _latestRelease = release;
        _lastMessage = release == null
            ? localizations.launcherUpdateNoOfficialRelease
            : localizations.launcherUpdateLatestReleaseReady(
                release.displayName.isEmpty
                    ? release.tagName
                    : release.displayName,
              );
      });
      _requestSectionFocus(
        release == null ? _statusFocusNode : _releaseDetailsFocusNode,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastMessage =
            localizations.launcherUpdateCheckFailed(error.toString());
      });
      _requestSectionFocus(_statusFocusNode);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _downloadLatestApk(LauncherUpdateAsset asset) async {
    final localizations = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _downloadFileName = asset.name;
      _downloadProgress = 0;
      _downloadedBytes = 0;
      _downloadTotalBytes = asset.sizeBytes;
      _lastMessage = localizations.launcherUpdateDownloadStarted(asset.name);
    });
    _requestSectionFocus(_statusFocusNode);
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

      if (!mounted) {
        return;
      }
      await _refreshDownloadedArtifacts();
      if (!mounted) {
        return;
      }
      setState(() {
        _downloadFileName = null;
        _downloadedBytes = 0;
        _downloadTotalBytes = 0;
        _downloadProgress = null;
        _lastMessage = localizations
            .launcherUpdateDownloadComplete(downloadedApk.fileName);
      });
      _requestSectionFocus(_statusFocusNode);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _downloadFileName = null;
        _downloadedBytes = 0;
        _downloadTotalBytes = 0;
        _downloadProgress = null;
        _lastMessage =
            localizations.launcherUpdateDownloadFailed(error.toString());
      });
      _requestSectionFocus(_statusFocusNode);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _grantInstallerPermissionViaLocalAdb({
    required SystemBridgeService bridge,
    required bool adbEnabled,
  }) async {
    final localizations = AppLocalizations.of(context)!;
    if (!adbEnabled) {
      await bridge.openSpecificSettingsPage('development');
      if (!mounted) {
        return;
      }
      setState(() {
        _lastMessage = localizations.launcherUpdateEnableAdbFirst;
      });
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      final result = await bridge.prepareLauncherUpdateInstall();
      if (!mounted) {
        return;
      }
      setState(() {
        _lastMessage = result['message']?.toString().trim().isNotEmpty == true
            ? result['message'].toString()
            : localizations.launcherUpdateLocalAdbFallbackResult;
      });
      _requestSectionFocus(_statusFocusNode);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _openUnknownAppsPermission(
    SystemBridgeService bridge, {
    required bool resumeInstallAfterPermission,
  }) async {
    final localizations = AppLocalizations.of(context)!;
    _resumeInstallAfterPermission =
        resumeInstallAfterPermission && _downloadedApkPath != null;
    final opened =
        await bridge.openSpecificSettingsPage('install_unknown_apps');
    if (!mounted) {
      return;
    }
    setState(() {
      _lastMessage = opened
          ? localizations.launcherUpdatePermissionScreenOpened
          : localizations.launcherUpdatePermissionScreenFailed;
    });
    _requestSectionFocus(_statusFocusNode);
  }

  Future<void> _installDownloadedApk({
    required SystemBridgeService bridge,
    required bool openPermissionIfNeeded,
  }) async {
    final localizations = AppLocalizations.of(context)!;
    final apkPath = _downloadedApkPath;
    if (apkPath == null) {
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      final result = await bridge.installDownloadedApk(apkPath);
      if (!mounted) {
        return;
      }
      final needsPermission = result['needsPermission'] == true;
      if (needsPermission && openPermissionIfNeeded) {
        await _openUnknownAppsPermission(
          bridge,
          resumeInstallAfterPermission: true,
        );
        return;
      }
      setState(() {
        _resumeInstallAfterPermission = false;
        _lastMessage = result['message']?.toString().trim().isNotEmpty == true
            ? result['message'].toString()
            : localizations.launcherUpdateInstallLaunched(
                _downloadedAssetName ??
                    apkPath.split(Platform.pathSeparator).last,
              );
      });
      _requestSectionFocus(_statusFocusNode);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastMessage =
            localizations.launcherUpdateInstallFailed(error.toString());
      });
      _requestSectionFocus(_statusFocusNode);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _clearDownloadedApks() async {
    final localizations = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _lastMessage = localizations.launcherUpdateCleanupWorking;
    });
    try {
      final removed = await _deleteOldDownloads(await _getUpdateDirectory());
      await _refreshDownloadedArtifacts();
      if (!mounted) {
        return;
      }
      setState(() {
        _lastMessage = removed > 0
            ? localizations.launcherUpdateCleanupComplete(removed)
            : localizations.launcherUpdateCleanupEmpty;
      });
      _requestSectionFocus(_statusFocusNode);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastMessage =
            localizations.launcherUpdateCleanupFailed(error.toString());
      });
      _requestSectionFocus(_statusFocusNode);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

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
          // Best effort cleanup; keep the fresh download path deterministic.
        }
      }
    }
    return removedCount;
  }

  String _safeFileName(String rawName) {
    final trimmed = rawName.trim();
    final fallback = 'atv-launcher-update.apk';
    if (trimmed.isEmpty) {
      return fallback;
    }
    final sanitized = trimmed.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return sanitized.isEmpty ? fallback : sanitized;
  }

  String _resolveLatestAssetSizeLabel(
    AppLocalizations localizations,
    LauncherUpdateAsset? asset,
  ) {
    if (!_hasCheckedOfficialRelease) {
      return localizations.launcherUpdateNotChecked;
    }
    if (_latestRelease == null) {
      return localizations.launcherUpdateNoOfficialRelease;
    }
    if (asset == null) {
      return localizations.launcherUpdateNoApkAsset;
    }
    return formatUpdateFileSize(asset.sizeBytes);
  }

  Widget _buildUniformActionCard({
    FocusNode? focusNode,
    SettingsBoundaryMoveHandler? onMoveUpAtBoundary,
    required String title,
    required String subtitle,
    required IconData icon,
    required Future<void> Function()? onPressed,
  }) {
    return SizedBox(
      height: _actionCardHeight,
      child: SettingsActionCard(
        focusNode: focusNode,
        onMoveUpAtBoundary: onMoveUpAtBoundary,
        title: title,
        subtitle: subtitle,
        icon: icon,
        focusEmphasis: 1.18,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildOverviewSummary({
    required AppLocalizations localizations,
    required String latestReleaseLabel,
    required String latestAssetSizeLabel,
    required String installerLabel,
    required String downloadedLabel,
    required bool permissionReady,
  }) {
    final chips = <Widget>[
      SettingsStatusChip(
        label: _resolveOverviewChipLabel(localizations),
        color: _resolveOverviewChipColor(),
      ),
      SettingsStatusChip(
        label: installerLabel,
        color: permissionReady ? _statusOkColor : _statusNeedsActionColor,
      ),
    ];
    if (_downloadedApkCount > 0) {
      chips.add(
        SettingsStatusChip(
          label: downloadedLabel,
          color: _statusInfoColor,
        ),
      );
    }
    if (_latestRelease?.preferredApkAsset != null) {
      chips.add(
        SettingsStatusChip(
          label: latestAssetSizeLabel,
          color: const Color(0xFFC6A6FF),
        ),
      );
    }

    return SettingsSummarySection(
      debugLabel: _summaryDebugLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips,
          ),
          const SizedBox(height: 12),
          SettingsMetricsGrid(
            minChildWidth: 188,
            maxColumns: 4,
            children: [
              SettingsMetricTile(
                label: localizations.launcherUpdateInstalledVersion,
                value: _installedVersionLabel,
                icon: Icons.info_outline,
              ),
              SettingsMetricTile(
                label: localizations.launcherUpdateLatestRelease,
                value: latestReleaseLabel,
                icon: Icons.system_update_outlined,
              ),
              SettingsMetricTile(
                label: localizations.launcherUpdateInstallerPermission,
                value: installerLabel,
                icon: permissionReady
                    ? Icons.verified_user_outlined
                    : Icons.warning_amber_outlined,
                accentColor:
                    permissionReady ? _statusOkColor : _statusNeedsActionColor,
              ),
              SettingsMetricTile(
                label: localizations.launcherUpdateDownloadedBuild,
                value: downloadedLabel,
                icon: Icons.download_done_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSummary({
    required BuildContext context,
    required AppLocalizations localizations,
  }) {
    final progressLabel = _downloadProgress == null
        ? localizations.launcherUpdateDownloadIndeterminate
        : localizations.launcherUpdateDownloadProgress(
            (_downloadProgress! * 100).round(),
          );

    return SettingsSurfaceCard(
      padding: const EdgeInsets.all(10),
      child: SettingsSummarySection(
        debugLabel: _statusDebugLabel,
        focusNode: _statusFocusNode,
        focusEmphasis: 1.16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _showDownloadProgress
                      ? Icons.downloading_outlined
                      : Icons.info_outline,
                  color: Colors.white.withOpacity(0.92),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_lastMessage.trim().isNotEmpty)
                        Text(
                          _lastMessage,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      if (_showDownloadProgress) ...[
                        if (_lastMessage.trim().isNotEmpty)
                          const SizedBox(height: 10),
                        if ((_downloadFileName ?? '').trim().isNotEmpty) ...[
                          Text(
                            _downloadFileName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withOpacity(0.92),
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        LinearProgressIndicator(
                          value: _downloadProgress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(999),
                          backgroundColor: Colors.white12,
                          color: const Color(0xFF8ACBFF),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _resolveDownloadBytesLabel(localizations),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              progressLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _showDownloadProgress =>
      (_downloadFileName ?? '').trim().isNotEmpty && _busy;

  Future<Directory> _getUpdateDirectory() async => Directory(
        '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}launcher_updates',
      );

  Future<void> _refreshDownloadedArtifacts() async {
    final directory = await _getUpdateDirectory();
    if (!await directory.exists()) {
      if (!mounted) {
        return;
      }
      setState(() {
        _downloadedApkCount = 0;
        _downloadedApkPath = null;
        _downloadedAssetName = null;
      });
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
    if (!mounted) {
      return;
    }
    setState(() {
      _downloadedApkCount = files.length;
      _downloadedApkPath = newestFile?.path;
      _downloadedAssetName = newestFile == null
          ? null
          : newestFile.path.split(Platform.pathSeparator).last;
    });
  }

  void _handleDownloadProgress(LauncherUpdateDownloadProgress progress) {
    if (!mounted) {
      return;
    }
    setState(() {
      _downloadFileName = progress.fileName;
      _downloadedBytes = progress.receivedBytes;
      _downloadTotalBytes = progress.totalBytes;
      _downloadProgress = progress.fraction;
    });
  }

  void _requestSectionFocus(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !node.canRequestFocus || node.context == null) {
        return;
      }
      node.requestFocus();
    });
  }

  String _resolveLatestReleaseLabel(AppLocalizations localizations) {
    if (_latestRelease?.displayName.trim().isNotEmpty == true) {
      return _latestRelease!.displayName;
    }
    if (_hasCheckedOfficialRelease) {
      return localizations.launcherUpdateNoOfficialRelease;
    }
    return localizations.launcherUpdateNotChecked;
  }

  String _resolveOverviewChipLabel(AppLocalizations localizations) {
    if (!_hasCheckedOfficialRelease) {
      return localizations.launcherUpdateNotChecked;
    }
    if (_latestRelease == null) {
      return localizations.launcherUpdateNoOfficialRelease;
    }
    return _latestRelease!.matchesInstalledVersion(_installedVersionLabel)
        ? localizations.launcherUpdateInstalledChip
        : localizations.launcherUpdateLatestChip;
  }

  Color _resolveOverviewChipColor() {
    if (!_hasCheckedOfficialRelease) {
      return _statusInfoColor;
    }
    if (_latestRelease == null) {
      return _statusNeedsActionColor;
    }
    return _latestRelease!.matchesInstalledVersion(_installedVersionLabel)
        ? _statusOkColor
        : _statusInfoColor;
  }

  String _resolveCheckCardSubtitle(
    AppLocalizations localizations,
    String latestReleaseLabel,
  ) {
    if (!_hasCheckedOfficialRelease) {
      return localizations.launcherUpdateNotChecked;
    }
    return latestReleaseLabel;
  }

  String _resolveDownloadCardSubtitle(
    BuildContext context,
    AppLocalizations localizations,
    LauncherUpdateAsset? asset,
  ) {
    if (!_hasCheckedOfficialRelease) {
      return localizations.launcherUpdateNotChecked;
    }
    if (_latestRelease == null || asset == null) {
      return localizations.launcherUpdateNoOfficialRelease;
    }
    return '${formatUpdateFileSize(asset.sizeBytes)} | ${_formatUpdateDateTime(context, asset.uploadedAt, includeTime: false)}';
  }

  String _resolveInstallCardSubtitle(
    AppLocalizations localizations,
    bool permissionReady,
    String downloadedLabel,
  ) {
    if (_downloadedApkPath == null) {
      return localizations.launcherUpdateNoDownloadedApk;
    }
    if (!permissionReady) {
      return localizations.launcherUpdatePermissionMissing;
    }
    return downloadedLabel;
  }

  String _resolveLocalAdbCardSubtitle(
    AppLocalizations localizations,
    bool adbEnabled,
  ) {
    if (!adbEnabled) {
      return localizations.launcherUpdateEnableAdbFirst;
    }
    return '127.0.0.1:5555';
  }

  String _resolveDownloadBytesLabel(AppLocalizations localizations) {
    final downloaded = formatUpdateFileSize(_downloadedBytes);
    if (_downloadTotalBytes > 0) {
      return localizations.launcherUpdateDownloadBytesProgress(
        downloaded,
        formatUpdateFileSize(_downloadTotalBytes),
      );
    }
    return localizations.launcherUpdateDownloadBytesReceived(downloaded);
  }

  String _resolveDownloadedLabel(AppLocalizations localizations) {
    if (_downloadedApkCount <= 0) {
      return localizations.launcherUpdateNoDownloadedApk;
    }
    if (_downloadedApkCount == 1 && (_downloadedAssetName ?? '').isNotEmpty) {
      return _downloadedAssetName!;
    }
    return localizations.launcherUpdateDownloadedCount(_downloadedApkCount);
  }

  String _resolveCleanupCardSubtitle(AppLocalizations localizations) {
    if (_downloadedApkCount <= 0) {
      return localizations.launcherUpdateNoDownloadedApk;
    }
    return localizations.launcherUpdateDownloadedCount(_downloadedApkCount);
  }

  Widget _buildReleaseDetails(
    BuildContext context,
    AppLocalizations localizations,
    bool permissionReady,
  ) {
    if (!_hasCheckedOfficialRelease) {
      return Text(localizations.launcherUpdateEmptyState);
    }
    if (_latestRelease == null) {
      return Text(
        localizations.launcherUpdateNoOfficialRelease,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Colors.white70),
      );
    }
    return _ReleaseDetailsCard(
      release: _latestRelease!,
      installedVersionLabel: _installedVersionLabel,
      permissionReady: permissionReady,
    );
  }
}

class _ReleaseDetailsCard extends StatelessWidget {
  final LauncherUpdateRelease release;
  final String installedVersionLabel;
  final bool permissionReady;

  const _ReleaseDetailsCard({
    required this.release,
    required this.installedVersionLabel,
    required this.permissionReady,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final asset = release.preferredApkAsset;
    final publishedAt = release.publishedAt;
    final uploadedAt = asset?.uploadedAt ?? publishedAt;
    final matchesInstalled =
        release.matchesInstalledVersion(installedVersionLabel);
    final permissionColor = permissionReady
        ? _UpdatePanelPageState._statusOkColor
        : _UpdatePanelPageState._statusNeedsActionColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    release.displayName.isEmpty
                        ? release.tagName
                        : release.displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${LauncherUpdateClient.githubOwner}/${LauncherUpdateClient.githubRepo}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            SettingsStatusChip(
              label: matchesInstalled
                  ? localizations.launcherUpdateInstalledChip
                  : localizations.launcherUpdateLatestChip,
              color: matchesInstalled
                  ? const Color(0xFF7BE0A5)
                  : const Color(0xFF8CCBFF),
            ),
            const SizedBox(width: 10),
            SettingsStatusChip(
              label: permissionReady
                  ? localizations.launcherUpdatePermissionReady
                  : localizations.launcherUpdatePermissionMissing,
              color: permissionColor,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ReleaseMetaChip(
              label: localizations.launcherUpdateTagLabel,
              value: release.tagName.isEmpty ? '-' : release.tagName,
            ),
            _ReleaseMetaChip(
              label: localizations.launcherUpdatePublishedAt,
              value: _formatUpdateDateTime(context, publishedAt),
            ),
            _ReleaseMetaChip(
              label: localizations.launcherUpdateUploadedAt,
              value: _formatUpdateDateTime(context, uploadedAt),
            ),
            if (asset != null)
              _ReleaseMetaChip(
                label: localizations.launcherUpdateSizeLabel,
                value: formatUpdateFileSize(asset.sizeBytes),
              ),
            if (asset != null)
              _ReleaseMetaChip(
                label: localizations.launcherUpdateDownloadsLabel,
                value: asset.downloadCount.toString(),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _ReleaseInfoRow(
          label: localizations.launcherUpdateAssetLabel,
          value: asset == null
              ? localizations.launcherUpdateNoApkAsset
              : '${asset.name} | ${formatUpdateFileSize(asset.sizeBytes)}',
        ),
        if (release.body.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            localizations.launcherUpdateReleaseNotes,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            release.body.trim(),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white70),
          ),
        ],
      ],
    );
  }
}

class _ReleaseMetaChip extends StatelessWidget {
  final String label;
  final String value;

  const _ReleaseMetaChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

String _formatUpdateDateTime(
  BuildContext context,
  DateTime? value, {
  bool includeTime = true,
}) {
  if (value == null) {
    return '-';
  }
  final localeName = Localizations.localeOf(context).toLanguageTag();
  final dateFormat = includeTime
      ? DateFormat.yMd(localeName).add_Hm()
      : DateFormat.yMd(localeName);
  return dateFormat.format(value);
}

class _ReleaseInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReleaseInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
