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
  static const String _summaryDebugLabel = 'update_panel_summary_metrics';
  static const String _statusDebugLabel = 'update_panel_status_section';
  static const String _releaseDetailsDebugLabel =
      'update_panel_release_details';
  static const double _actionCardHeight = 60;
  static const Color _statusOkColor = Color(0xFF7BE0A5);
  static const Color _statusNeedsActionColor = Color(0xFFFFC970);
  static const Color _statusInfoColor = Color(0xFF8CCBFF);

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
        final adbEnabled = updateStatus['adbEnabled'] == true;
        final latestAsset = _updateSession.latestRelease?.preferredApkAsset;
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
                minChildWidth: 520,
                maxColumns: 1,
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
                    onPressed: _updateSession.busy
                        ? null
                        : () => _checkLatestRelease(),
                  ),
                  _buildUniformActionCard(
                    title: localizations.downloadLatestApk,
                    subtitle: downloadCardSubtitle,
                    icon: Icons.download_for_offline_outlined,
                    onPressed: _updateSession.busy || latestAsset == null
                        ? null
                        : () => _downloadLatestApk(latestAsset),
                  ),
                  _buildUniformActionCard(
                    title: localizations.installDownloadedApk,
                    subtitle: installCardSubtitle,
                    icon: Icons.system_update_alt_outlined,
                    onPressed: _updateSession.busy ||
                            _updateSession.downloadedApkPath == null
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
                    onPressed: _updateSession.busy
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
                    onPressed: _updateSession.busy
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
                    onPressed: _updateSession.busy ||
                            _updateSession.downloadedApkCount == 0
                        ? null
                        : _clearDownloadedApks,
                  ),
                ],
              ),
            ),
            if (_updateSession.lastMessage.trim().isNotEmpty ||
                _showDownloadProgress) ...[
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
        !_updateSession.resumeInstallAfterPermission ||
        _updateSession.downloadedApkPath == null) {
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
    await _updateSession.checkLatestRelease(localizations);
    if (!mounted) {
      return;
    }
    _requestSectionFocus(_statusFocusNode);
  }

  Future<void> _downloadLatestApk(LauncherUpdateAsset asset) async {
    final localizations = AppLocalizations.of(context)!;
    _requestSectionFocus(_statusFocusNode);
    await _updateSession.downloadLatestApk(asset, localizations);
    if (!mounted) {
      return;
    }
    _requestSectionFocus(_statusFocusNode);
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
      _updateSession.setLastMessage(localizations.launcherUpdateEnableAdbFirst);
      return;
    }

    _updateSession.setBusy(true);
    try {
      final result = await bridge.prepareLauncherUpdateInstall();
      if (!mounted) {
        return;
      }
      _updateSession.setLastMessage(
        result['message']?.toString().trim().isNotEmpty == true
            ? result['message'].toString()
            : localizations.launcherUpdateLocalAdbFallbackResult,
      );
      _requestSectionFocus(_statusFocusNode);
    } finally {
      _updateSession.setBusy(false);
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

  Future<void> _clearDownloadedApks() async {
    final localizations = AppLocalizations.of(context)!;
    await _updateSession.clearDownloadedApks(localizations);
    if (!mounted) {
      return;
    }
    _requestSectionFocus(_statusFocusNode);
  }

  String _resolveLatestAssetSizeLabel(
    AppLocalizations localizations,
    LauncherUpdateAsset? asset,
  ) {
    if (!_updateSession.hasCheckedOfficialRelease) {
      return localizations.launcherUpdateNotChecked;
    }
    if (_updateSession.latestRelease == null) {
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        titleMaxLines: 1,
        subtitleMaxLines: 1,
        titleSubtitleSpacing: 1,
        iconSize: 20,
        trailingIconSize: 20,
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
    if (_updateSession.downloadedApkCount > 0) {
      chips.add(
        SettingsStatusChip(
          label: downloadedLabel,
          color: _statusInfoColor,
        ),
      );
    }
    if (_updateSession.latestRelease?.preferredApkAsset != null) {
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
    final progressLabel = _updateSession.downloadProgress == null
        ? localizations.launcherUpdateDownloadIndeterminate
        : localizations.launcherUpdateDownloadProgress(
            (_updateSession.downloadProgress! * 100).round(),
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

  String _resolveLatestReleaseLabel(AppLocalizations localizations) {
    if (_updateSession.latestRelease?.displayName.trim().isNotEmpty == true) {
      return _updateSession.latestRelease!.displayName;
    }
    if (_updateSession.hasCheckedOfficialRelease) {
      return localizations.launcherUpdateNoOfficialRelease;
    }
    return localizations.launcherUpdateNotChecked;
  }

  String _resolveOverviewChipLabel(AppLocalizations localizations) {
    if (!_updateSession.hasCheckedOfficialRelease) {
      return localizations.launcherUpdateNotChecked;
    }
    if (_updateSession.latestRelease == null) {
      return localizations.launcherUpdateNoOfficialRelease;
    }
    return _updateSession.latestRelease!.matchesInstalledVersion(
          _installedVersionLabel,
        )
        ? localizations.launcherUpdateInstalledChip
        : localizations.launcherUpdateLatestChip;
  }

  Color _resolveOverviewChipColor() {
    if (!_updateSession.hasCheckedOfficialRelease) {
      return _statusInfoColor;
    }
    if (_updateSession.latestRelease == null) {
      return _statusNeedsActionColor;
    }
    return _updateSession.latestRelease!.matchesInstalledVersion(
          _installedVersionLabel,
        )
        ? _statusOkColor
        : _statusInfoColor;
  }

  String _resolveCheckCardSubtitle(
    AppLocalizations localizations,
    String latestReleaseLabel,
  ) {
    if (!_updateSession.hasCheckedOfficialRelease) {
      return localizations.launcherUpdateNotChecked;
    }
    return latestReleaseLabel;
  }

  String _resolveDownloadCardSubtitle(
    BuildContext context,
    AppLocalizations localizations,
    LauncherUpdateAsset? asset,
  ) {
    if (!_updateSession.hasCheckedOfficialRelease) {
      return localizations.launcherUpdateNotChecked;
    }
    if (_updateSession.latestRelease == null || asset == null) {
      return localizations.launcherUpdateNoOfficialRelease;
    }
    return '${formatUpdateFileSize(asset.sizeBytes)} | ${_formatUpdateDateTime(context, asset.uploadedAt, includeTime: false)}';
  }

  String _resolveInstallCardSubtitle(
    AppLocalizations localizations,
    bool permissionReady,
    String downloadedLabel,
  ) {
    if (_updateSession.downloadedApkPath == null) {
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
    final downloaded = formatUpdateFileSize(_updateSession.downloadedBytes);
    if (_updateSession.downloadTotalBytes > 0) {
      return localizations.launcherUpdateDownloadBytesProgress(
        downloaded,
        formatUpdateFileSize(_updateSession.downloadTotalBytes),
      );
    }
    return localizations.launcherUpdateDownloadBytesReceived(downloaded);
  }

  String _resolveDownloadedLabel(AppLocalizations localizations) {
    if (_updateSession.downloadedApkCount <= 0) {
      return localizations.launcherUpdateNoDownloadedApk;
    }
    if (_updateSession.downloadedApkCount == 1 &&
        (_updateSession.downloadedAssetName ?? '').isNotEmpty) {
      return _updateSession.downloadedAssetName!;
    }
    return localizations.launcherUpdateDownloadedCount(
      _updateSession.downloadedApkCount,
    );
  }

  String _resolveCleanupCardSubtitle(AppLocalizations localizations) {
    if (_updateSession.downloadedApkCount <= 0) {
      return localizations.launcherUpdateNoDownloadedApk;
    }
    return localizations.launcherUpdateDownloadedCount(
      _updateSession.downloadedApkCount,
    );
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
        const SizedBox(height: 8),
        _ReleaseInfoRow(
          label: localizations.launcherUpdateAssetLabel,
          value: asset == null
              ? localizations.launcherUpdateNoApkAsset
              : '${asset.name} | ${formatUpdateFileSize(asset.sizeBytes)}',
        ),
        if (release.body.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            localizations.launcherUpdateReleaseNotes,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            release.body.trim(),
            maxLines: 7,
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
