import 'dart:async';

import 'package:flauncher/launcher_update_client.dart';
import 'package:flauncher/providers/launcher_update_session.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class UpdatePanelPage extends StatefulWidget {
  static const String routeName = "update_panel";
  final FocusNode? primaryFocusNode;
  final LauncherUpdateClient? updateClient;
  final LauncherUpdateSession? updateSession;

  const UpdatePanelPage({
    super.key,
    this.primaryFocusNode,
    this.updateClient,
    this.updateSession,
  });

  @override
  State<UpdatePanelPage> createState() => _UpdatePanelPageState();
}

class _UpdatePanelPageState extends State<UpdatePanelPage>
    with WidgetsBindingObserver {
  static const String _statusDebugLabel = 'update_panel_status_section';
  static const String _releaseDetailsDebugLabel =
      'update_panel_release_details';
  static const Color _statusOkColor = Color(0xFF7BE0A5);
  static const Color _statusNeedsActionColor = Color(0xFFFFC970);

  late final LauncherUpdateSession _updateSession;
  late final bool _ownsUpdateSession;
  late final FocusNode _statusFocusNode;
  late final FocusNode _releaseDetailsFocusNode;

  String _installedVersionLabel = '-';

  @override
  void initState() {
    super.initState();
    _ownsUpdateSession =
        widget.updateSession == null && widget.updateClient != null;
    _updateSession = widget.updateSession ??
        (_ownsUpdateSession
            ? LauncherUpdateSession(updateClient: widget.updateClient)
            : LauncherUpdateSession.shared);
    _updateSession.addListener(_handleSessionChanged);
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
        unawaited(_updateSession.initialize());
        unawaited(_loadInstalledVersion());
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateSession.removeListener(_handleSessionChanged);
    if (_ownsUpdateSession) {
      _updateSession.dispose();
    }
    _statusFocusNode.dispose();
    _releaseDetailsFocusNode.dispose();
    super.dispose();
  }

  void _handleSessionChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
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
        final latestAsset = _updateSession.latestReleaseAsset;

        return ListView(
          key: const PageStorageKey<String>(UpdatePanelPage.routeName),
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            SettingsSurfaceCard(
              padding: TvDrawerTokens.surfacePadding,
              child: SettingsAdaptiveGrid(
                spacing: 8,
                runSpacing: TvDrawerTokens.rowSpacing,
                minChildWidth: 520,
                maxColumns: 1,
                children: [
                  _buildUniformActionCard(
                    focusNode: widget.primaryFocusNode,
                    title: localizations.checkLatestRelease,
                    icon: Icons.system_update_alt_outlined,
                    onPressed: _updateSession.busy
                        ? null
                        : () => _checkLatestRelease(),
                  ),
                  _buildUniformActionCard(
                    title: localizations.downloadLatestApk,
                    icon: Icons.download_for_offline_outlined,
                    onPressed: _updateSession.busy || latestAsset == null
                        ? null
                        : () => _downloadLatestApk(latestAsset),
                  ),
                  if (_updateSession.downloadedApkPath != null)
                    _buildUniformActionCard(
                      title: localizations.installDownloadedApk,
                      icon: Icons.system_update_alt_outlined,
                      onPressed: _updateSession.busy
                          ? null
                          : () => _installDownloadedApk(
                                bridge: bridge,
                                openPermissionIfNeeded: true,
                              ),
                    ),
                ],
              ),
            ),
            if (_updateSession.lastMessage.trim().isNotEmpty ||
                _showDownloadProgress) ...[
              const SizedBox(height: TvDrawerTokens.surfaceSpacing),
              _buildStatusSummary(
                context: context,
                localizations: localizations,
              ),
            ],
            const SizedBox(height: TvDrawerTokens.surfaceSpacing),
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
    if (!_updateSession.resumeInstallAfterPermission ||
        _updateSession.downloadedApkPath == null) {
      await bridge.refreshLite();
      return;
    }
    const retryDelays = [
      Duration.zero,
      Duration(milliseconds: 300),
      Duration(milliseconds: 600),
      Duration(milliseconds: 1200),
    ];
    for (final delay in retryDelays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      if (!mounted) {
        return;
      }
      await bridge.refreshLite();
      final permissionReady =
          bridge.updateStatus['canRequestPackageInstalls'] == true;
      if (permissionReady) {
        await _installDownloadedApk(
          bridge: bridge,
          openPermissionIfNeeded: false,
        );
        return;
      }
    }
  }

  Future<void> _checkLatestRelease() async {
    final localizations = AppLocalizations.of(context)!;
    await _updateSession.checkLatestRelease(localizations);
    if (!mounted) {
      return;
    }
    _requestSectionFocus(_statusFocusNode);
  }

  Future<void> _downloadLatestApk(LauncherUpdateAsset asset) async {
    final localizations = AppLocalizations.of(context)!;
    final bridge = context.read<SystemBridgeService>();
    _requestSectionFocus(_statusFocusNode);
    await _updateSession.downloadLatestApk(asset, localizations);
    if (!mounted) {
      return;
    }
    _requestSectionFocus(_statusFocusNode);
    if (_updateSession.downloadedApkPath != null) {
      await _installDownloadedApk(
        bridge: bridge,
        openPermissionIfNeeded: true,
      );
    }
  }

  Future<void> _openUnknownAppsPermission(
    SystemBridgeService bridge, {
    required bool resumeInstallAfterPermission,
  }) async {
    final localizations = AppLocalizations.of(context)!;
    _updateSession.setResumeInstallAfterPermission(
      resumeInstallAfterPermission && _updateSession.downloadedApkPath != null,
    );
    final opened =
        await bridge.openSpecificSettingsPage('install_unknown_apps');
    if (!mounted) {
      return;
    }
    _updateSession.setLastMessage(
      opened
          ? localizations.launcherUpdatePermissionScreenOpened
          : localizations.launcherUpdatePermissionScreenFailed,
    );
    _requestSectionFocus(_statusFocusNode);
  }

  Future<void> _installDownloadedApk({
    required SystemBridgeService bridge,
    required bool openPermissionIfNeeded,
  }) async {
    final localizations = AppLocalizations.of(context)!;
    final apkPath = _updateSession.downloadedApkPath;
    if (apkPath == null) {
      return;
    }
    _updateSession.setBusy(true);
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
      _updateSession.setResumeInstallAfterPermission(false);
      _updateSession.setLastMessage(
        result['message']?.toString().trim().isNotEmpty == true
            ? result['message'].toString()
            : localizations.launcherUpdateInstallLaunched(
                _updateSession.downloadedAssetName ??
                    apkPath.split(RegExp(r'[\\/]')).last,
              ),
      );
      _requestSectionFocus(_statusFocusNode);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _updateSession.setLastMessage(
        localizations.launcherUpdateInstallFailed(error.toString()),
      );
      _requestSectionFocus(_statusFocusNode);
    } finally {
      _updateSession.setBusy(false);
    }
  }

  Widget _buildUniformActionCard({
    FocusNode? focusNode,
    SettingsBoundaryMoveHandler? onMoveUpAtBoundary,
    required String title,
    required IconData icon,
    required Future<void> Function()? onPressed,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TvDrawerTokens.cardMinHeight),
      child: SettingsActionCard(
        focusNode: focusNode,
        onMoveUpAtBoundary: onMoveUpAtBoundary,
        title: title,
        icon: icon,
        focusEmphasis: 1.18,
        onPressed: onPressed,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        titleMaxLines: 1,
        iconSize: 20,
        trailingIconSize: 20,
      ),
    );
  }

  Widget _buildStatusSummary({
    required BuildContext context,
    required AppLocalizations localizations,
  }) {
    final progressLabel = _updateSession.downloadProgress == null
        ? localizations.launcherUpdateDownloadIndeterminate
        : localizations.launcherUpdateDownloadProgress(
            (_updateSession.downloadProgress! * 100).round(),
          );

    return SettingsSurfaceCard(
      padding: TvDrawerTokens.surfacePadding,
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
                      if (_updateSession.lastMessage.trim().isNotEmpty)
                        Text(
                          _updateSession.lastMessage,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      if (_showDownloadProgress) ...[
                        if (_updateSession.lastMessage.trim().isNotEmpty)
                          const SizedBox(height: 10),
                        if ((_updateSession.downloadFileName ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          Text(
                            _updateSession.downloadFileName!,
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
                          value: _updateSession.downloadProgress,
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

  bool get _showDownloadProgress => _updateSession.showDownloadProgress;

  void _requestSectionFocus(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !node.canRequestFocus || node.context == null) {
        return;
      }
      node.requestFocus();
    });
  }

  String _resolveDeviceAbiSummary(AppLocalizations localizations) {
    final deviceAbis = _updateSession.deviceAbis;
    if (deviceAbis.isEmpty) {
      return localizations.launcherUpdateAbiUnavailable;
    }
    return deviceAbis.join(', ');
  }

  String? _resolveAbiWarningMessage(AppLocalizations localizations) {
    if (_updateSession.abiResolutionDegraded) {
      return localizations.launcherUpdateAbiFallbackMessage;
    }
    if (_updateSession.abiResolutionPending) {
      return localizations.launcherUpdateAbiResolving;
    }
    return null;
  }

  String _resolveDownloadBytesLabel(AppLocalizations localizations) {
    final downloaded = formatUpdateFileSize(_updateSession.downloadedBytes);
    if (_updateSession.downloadTotalBytes > 0) {
      return localizations.launcherUpdateDownloadBytesProgress(
        downloaded,
        formatUpdateFileSize(_updateSession.downloadTotalBytes),
      );
    }
    return localizations.launcherUpdateDownloadBytesReceived(downloaded);
  }

  Widget _buildReleaseDetails(
    BuildContext context,
    AppLocalizations localizations,
    bool permissionReady,
  ) {
    if (!_updateSession.hasCheckedOfficialRelease) {
      return Text(localizations.launcherUpdateEmptyState);
    }
    if (_updateSession.latestRelease == null) {
      return Text(
        localizations.launcherUpdateNoOfficialRelease,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Colors.white70),
      );
    }
    return _ReleaseDetailsCard(
      release: _updateSession.latestRelease!,
      asset: _updateSession.latestReleaseAsset,
      installedVersionLabel: _installedVersionLabel,
      permissionReady: permissionReady,
      deviceAbiSummary: _resolveDeviceAbiSummary(localizations),
      abiWarningMessage: _resolveAbiWarningMessage(localizations),
    );
  }
}

class _ReleaseDetailsCard extends StatelessWidget {
  final LauncherUpdateRelease release;
  final LauncherUpdateAsset? asset;
  final String installedVersionLabel;
  final bool permissionReady;
  final String deviceAbiSummary;
  final String? abiWarningMessage;

  const _ReleaseDetailsCard({
    required this.release,
    required this.asset,
    required this.installedVersionLabel,
    required this.permissionReady,
    required this.deviceAbiSummary,
    required this.abiWarningMessage,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final selectedAsset = asset;
    final publishedAt = release.publishedAt;
    final uploadedAt = selectedAsset?.uploadedAt ?? publishedAt;
    final matchesInstalled =
        release.matchesInstalledVersion(installedVersionLabel);
    final permissionColor = permissionReady
        ? _UpdatePanelPageState._statusOkColor
        : _UpdatePanelPageState._statusNeedsActionColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              release.displayName.isEmpty
                  ? release.tagName
                  : release.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              release.tagName.isEmpty ? '-' : release.tagName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                SettingsStatusChip(
                  label: matchesInstalled
                      ? localizations.launcherUpdateInstalledChip
                      : localizations.launcherUpdateLatestChip,
                  color: matchesInstalled
                      ? const Color(0xFF7BE0A5)
                      : const Color(0xFF8CCBFF),
                ),
                SettingsStatusChip(
                  label: permissionReady
                      ? localizations.launcherUpdatePermissionReady
                      : localizations.launcherUpdatePermissionMissing,
                  color: permissionColor,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _ReleaseMetaChip(
              label: localizations.launcherUpdateTagLabel,
              value: release.tagName.isEmpty ? '-' : release.tagName,
            ),
            _ReleaseMetaChip(
              label: localizations.launcherUpdateUploadedAt,
              value: _formatUpdateDateTime(context, uploadedAt),
            ),
            _ReleaseMetaChip(
              label: localizations.launcherUpdateDeviceAbiLabel,
              value: deviceAbiSummary,
            ),
            if (selectedAsset != null)
              _ReleaseMetaChip(
                label: localizations.launcherUpdateSizeLabel,
                value: formatUpdateFileSize(selectedAsset.sizeBytes),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _ReleaseInfoRow(
          label: localizations.launcherUpdateAssetLabel,
          value: selectedAsset == null
              ? localizations.launcherUpdateNoApkAsset
              : '${selectedAsset.name} | ${formatUpdateFileSize(selectedAsset.sizeBytes)}',
        ),
        if ((abiWarningMessage ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            abiWarningMessage!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: const Color(0xFFFFD17A)),
          ),
        ],
        if (release.body.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            localizations.launcherUpdateReleaseNotes,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            release.body.trim(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
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
      constraints: const BoxConstraints(minWidth: 156),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
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
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(
        '$label: $value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white60,
            ),
      ),
    );
  }
}


