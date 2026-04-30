import 'dart:async';
import 'dart:io';

import 'package:flauncher/launcher_update_client.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class UpdatePanelPage extends StatefulWidget {
  static const String routeName = "update_panel";
  final FocusNode? primaryFocusNode;

  const UpdatePanelPage({
    super.key,
    this.primaryFocusNode,
  });

  @override
  State<UpdatePanelPage> createState() => _UpdatePanelPageState();
}

class _UpdatePanelPageState extends State<UpdatePanelPage>
    with WidgetsBindingObserver {
  static const String _summaryDebugLabel = 'update_panel_summary_metrics';

  final LauncherUpdateClient _updateClient = LauncherUpdateClient();

  LauncherUpdateRelease? _latestRelease;
  String _installedVersionLabel = '-';
  String _lastMessage = '';
  String? _downloadedApkPath;
  String? _downloadedAssetName;
  double? _downloadProgress;
  bool _busy = false;
  bool _resumeInstallAfterPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadInstalledVersion());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(context.read<SystemBridgeService>().refreshLite());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        final permissionReady = updateStatus['canRequestPackageInstalls'] == true;
        final adbEnabled = updateStatus['adbEnabled'] == true;
        final latestAsset = _latestRelease?.preferredApkAsset;
        final latestReleaseLabel = _latestRelease?.displayName.trim().isNotEmpty == true
            ? _latestRelease!.displayName
            : localizations.launcherUpdateNotChecked;
        final installerLabel = permissionReady
            ? localizations.launcherUpdatePermissionReady
            : localizations.launcherUpdatePermissionMissing;
        final downloadedLabel =
            _downloadedAssetName ?? localizations.launcherUpdateNoDownloadedApk;

        return ListView(
          key: const PageStorageKey<String>(UpdatePanelPage.routeName),
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            SettingsSummarySection(
              debugLabel: _summaryDebugLabel,
              child: SettingsAdaptiveGrid(
                minChildWidth: 180,
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
                  ),
                  SettingsMetricTile(
                    label: localizations.launcherUpdateDownloadedBuild,
                    value: downloadedLabel,
                    icon: Icons.download_done_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: SettingsAdaptiveGrid(
                minChildWidth: 220,
                maxColumns: 2,
                children: [
                  SettingsActionCard(
                    focusNode: widget.primaryFocusNode,
                    onMoveUpAtBoundary: () =>
                        focusCurrentSettingsNodeByDebugLabel(_summaryDebugLabel),
                    title: localizations.checkLatestRelease,
                    subtitle: _latestRelease == null
                        ? localizations.launcherUpdateCheckSubtitle
                        : latestReleaseLabel,
                    icon: Icons.system_update_alt_outlined,
                    onPressed: _busy ? null : () => _checkLatestRelease(),
                  ),
                  SettingsActionCard(
                    title: localizations.downloadLatestApk,
                    subtitle: latestAsset?.name ??
                        localizations.launcherUpdateCheckBeforeDownload,
                    icon: Icons.download_for_offline_outlined,
                    onPressed: _busy || latestAsset == null
                        ? null
                        : () => _downloadLatestApk(latestAsset),
                  ),
                  SettingsActionCard(
                    title: localizations.installDownloadedApk,
                    subtitle: permissionReady
                        ? downloadedLabel
                        : localizations.launcherUpdatePermissionActionSubtitle,
                    icon: Icons.system_update_alt_outlined,
                    onPressed: _busy || _downloadedApkPath == null
                        ? null
                        : () => _installDownloadedApk(
                              bridge: bridge,
                              openPermissionIfNeeded: true,
                            ),
                  ),
                  SettingsActionCard(
                    title: localizations.grantInstallPermissionViaLocalAdb,
                    subtitle: adbEnabled
                        ? localizations.launcherUpdateLocalAdbSubtitle
                        : localizations.launcherUpdateEnableAdbFirst,
                    icon: Icons.adb_outlined,
                    onPressed: _busy
                        ? null
                        : () => _grantInstallerPermissionViaLocalAdb(
                              bridge: bridge,
                              adbEnabled: adbEnabled,
                            ),
                  ),
                  SettingsActionCard(
                    title: localizations.allowAppInstalls,
                    subtitle: permissionReady
                        ? localizations.launcherUpdatePermissionReady
                        : localizations.launcherUpdatePermissionActionSubtitle,
                    icon: Icons.admin_panel_settings_outlined,
                    onPressed: _busy
                        ? null
                        : () => _openUnknownAppsPermission(
                              bridge,
                              resumeInstallAfterPermission: false,
                            ),
                  ),
                ],
              ),
            ),
            if (_lastMessage.trim().isNotEmpty || _downloadProgress != null) ...[
              const SizedBox(height: 18),
              SettingsSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.launcherUpdateStatusTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_lastMessage.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        _lastMessage,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (_downloadProgress != null) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _downloadProgress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(999),
                        backgroundColor: Colors.white12,
                        color: const Color(0xFF8ACBFF),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations.launcherUpdateDownloadProgress(
                          (_downloadProgress! * 100).round(),
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: _latestRelease == null
                  ? Text(localizations.launcherUpdateEmptyState)
                  : _ReleaseDetailsCard(
                      release: _latestRelease!,
                      installedVersionLabel: _installedVersionLabel,
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
    if (!mounted || !_resumeInstallAfterPermission || _downloadedApkPath == null) {
      return;
    }
    final permissionReady = bridge.updateStatus['canRequestPackageInstalls'] == true;
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
      _lastMessage = localizations.launcherUpdateChecking;
    });
    try {
      final release = await _updateClient.fetchLatestRelease();
      if (!mounted) {
        return;
      }
      setState(() {
        _latestRelease = release;
        _lastMessage = release.preferredApkAsset == null
            ? localizations.launcherUpdateNoApkAsset
            : localizations.launcherUpdateLatestReleaseReady(
                release.displayName.isEmpty ? release.tagName : release.displayName,
              );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastMessage = localizations.launcherUpdateCheckFailed(error.toString());
      });
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
    final downloadUri = asset.downloadUri;
    if (downloadUri == null) {
      setState(() {
        _lastMessage = localizations.launcherUpdateNoApkAsset;
      });
      return;
    }

    setState(() {
      _busy = true;
      _downloadProgress = 0;
      _lastMessage = localizations.launcherUpdateDownloadStarted(asset.name);
    });

    final client = HttpClient();
    IOSink? sink;
    try {
      final request = await client.getUrl(downloadUri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'ATVLauncher/${LauncherUpdateClient.githubOwner}-${LauncherUpdateClient.githubRepo}',
      );
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'GitHub asset download failed with HTTP ${response.statusCode}.',
          uri: downloadUri,
        );
      }

      final updateDirectory = Directory(
        '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}launcher_updates',
      );
      if (!await updateDirectory.exists()) {
        await updateDirectory.create(recursive: true);
      }
      await _deleteOldDownloads(updateDirectory);

      final fileName = _safeFileName(asset.name);
      final outputFile = File(
        '${updateDirectory.path}${Platform.pathSeparator}$fileName',
      );
      sink = outputFile.openWrite();

      final totalBytes = response.contentLength;
      var receivedBytes = 0;
      var lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);
      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (!mounted) {
          continue;
        }
        if (totalBytes > 0) {
          final now = DateTime.now();
          if (now.difference(lastProgressAt).inMilliseconds >= 120 ||
              receivedBytes >= totalBytes) {
            lastProgressAt = now;
            setState(() {
              _downloadProgress = receivedBytes / totalBytes;
            });
          }
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (!mounted) {
        return;
      }
      setState(() {
        _downloadedApkPath = outputFile.path;
        _downloadedAssetName = asset.name;
        _downloadProgress = null;
        _lastMessage = localizations.launcherUpdateDownloadComplete(asset.name);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _downloadProgress = null;
        _lastMessage = localizations.launcherUpdateDownloadFailed(error.toString());
      });
    } finally {
      await sink?.close();
      client.close(force: true);
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
    final opened = await bridge.openSpecificSettingsPage('install_unknown_apps');
    if (!mounted) {
      return;
    }
    setState(() {
      _lastMessage = opened
          ? localizations.launcherUpdatePermissionScreenOpened
          : localizations.launcherUpdatePermissionScreenFailed;
    });
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
                _downloadedAssetName ?? apkPath.split(Platform.pathSeparator).last,
              );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastMessage = localizations.launcherUpdateInstallFailed(error.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _deleteOldDownloads(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File && entry.path.toLowerCase().endsWith('.apk')) {
        try {
          await entry.delete();
        } catch (_) {
          // Best effort cleanup; keep the fresh download path deterministic.
        }
      }
    }
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
}

class _ReleaseDetailsCard extends StatelessWidget {
  final LauncherUpdateRelease release;
  final String installedVersionLabel;

  const _ReleaseDetailsCard({
    required this.release,
    required this.installedVersionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final asset = release.preferredApkAsset;
    final publishedAt = release.publishedAt;
    final matchesInstalled = release.matchesInstalledVersion(installedVersionLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                release.displayName.isEmpty ? release.tagName : release.displayName,
                style: Theme.of(context).textTheme.titleLarge,
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
          ],
        ),
        const SizedBox(height: 14),
        _ReleaseInfoRow(
          label: localizations.launcherUpdateRepoLabel,
          value:
              '${LauncherUpdateClient.githubOwner}/${LauncherUpdateClient.githubRepo}',
        ),
        _ReleaseInfoRow(
          label: localizations.launcherUpdateTagLabel,
          value: release.tagName.isEmpty ? '-' : release.tagName,
        ),
        _ReleaseInfoRow(
          label: localizations.launcherUpdatePublishedAt,
          value: publishedAt == null ? '-' : publishedAt.toString(),
        ),
        _ReleaseInfoRow(
          label: localizations.launcherUpdateAssetLabel,
          value: asset == null
              ? localizations.launcherUpdateNoApkAsset
              : '${asset.name}  •  ${formatUpdateFileSize(asset.sizeBytes)}',
        ),
        if (asset != null)
          _ReleaseInfoRow(
            label: localizations.launcherUpdateDownloadsLabel,
            value: asset.downloadCount.toString(),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 190,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
