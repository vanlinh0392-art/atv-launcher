import 'dart:convert';

import 'package:flauncher/models/launcher_backup_payload.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/providers/search_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class BackupRestorePanelPage extends StatefulWidget {
  static const String routeName = "backup_restore_panel";
  final FocusNode? primaryFocusNode;

  const BackupRestorePanelPage({
    super.key,
    this.primaryFocusNode,
  });

  @override
  State<BackupRestorePanelPage> createState() => _BackupRestorePanelPageState();
}

class _BackupRestorePanelPageState extends State<BackupRestorePanelPage> {
  static const String _summaryDebugLabel = 'backup_restore_summary_metrics';
  Map<String, dynamic>? _preview;
  String _previewName = '';
  String _lastMessage = '';
  bool _busy = false;
  List<Map<String, dynamic>> _localBackups = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocalBackups();
    });
  }

  Future<void> _loadLocalBackups() async {
    try {
      final bridge = context.read<SystemBridgeService>();
      final List<Map<String, dynamic>> list = await bridge.getLocalBackups();
      setState(() {
        _localBackups = list;
      });
    } catch (e) {
      debugPrint("Error loading local backups: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();

    return ListView(
      key: const PageStorageKey<String>(BackupRestorePanelPage.routeName),
      children: [
        SettingsSummarySection(
          debugLabel: _summaryDebugLabel,
          child: SettingsMetricsGrid(
            minChildWidth: 188,
            maxColumns: 3,
            children: [
              SettingsMetricTile(
                label: localizations.lastExport,
                value: settings.backupLastExportName.isEmpty
                    ? '-'
                    : settings.backupLastExportName,
                icon: Icons.upload_file_outlined,
              ),
              SettingsMetricTile(
                label: localizations.lastImport,
                value: settings.backupLastImportName.isEmpty
                    ? '-'
                    : settings.backupLastImportName,
                icon: Icons.download_for_offline_outlined,
              ),
              SettingsMetricTile(
                label: localizations.lastRestore,
                value: settings.backupLastRestoreAt <= 0
                    ? '-'
                    : DateTime.fromMillisecondsSinceEpoch(
                            settings.backupLastRestoreAt)
                        .toLocal()
                        .toString(),
                icon: Icons.history_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SettingsSurfaceCard(
          child: SettingsAdaptiveGrid(
            minChildWidth: 230,
            maxColumns: 2,
            forceSingleColumn: false,
            children: [
              SettingsActionCard(
                focusNode: widget.primaryFocusNode,
                onMoveUpAtBoundary: () =>
                    focusCurrentSettingsNodeByDebugLabel(_summaryDebugLabel),
                title: localizations.exportBackup,
                subtitle: localizations.lastExport,
                icon: Icons.save_alt,
                onPressed: _busy ? null : () => _exportBackup(context),
              ),
              SettingsActionCard(
                onMoveUpAtBoundary: () =>
                    focusCurrentSettingsNodeByDebugLabel(_summaryDebugLabel),
                title: localizations.previewBackup,
                subtitle: localizations.selectedBackup,
                icon: Icons.preview_outlined,
                onPressed: _busy ? null : () => _previewBackup(context),
              ),
              SettingsActionCard(
                title: localizations.restoreLauncherOnly,
                subtitle: localizations.lastRestore,
                icon: Icons.restore_page_outlined,
                onPressed: _busy || _preview == null
                    ? null
                    : () => _applyBackup(context, applySystemSettings: false),
              ),
              SettingsActionCard(
                title: localizations.restoreWithSystemSettings,
                subtitle: localizations.lastImport,
                icon: Icons.settings_backup_restore_outlined,
                onPressed: _busy || _preview == null
                    ? null
                    : () => _applyBackup(context, applySystemSettings: true),
              ),
            ],
          ),
        ),
        if (_lastMessage.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(_lastMessage, style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: 18),
        Text(
          "Bản sao lưu cục bộ",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SettingsSurfaceCard(
          padding: const EdgeInsets.all(10),
          child: _localBackups.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      "Chưa có bản sao lưu nào trong bộ nhớ thiết bị.",
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _localBackups.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final item = _localBackups[index];
                    final name = item['name']?.toString() ?? '';
                    final isAuto = name.startsWith('atv-launcher-auto-backup-');
                    final date = DateTime.fromMillisecondsSinceEpoch(
                      (item['lastModified'] as num? ?? 0).toInt(),
                    ).toLocal().toString().substring(0, 19);
                    final size = ((item['size'] as num? ?? 0) / 1024).toStringAsFixed(1);
                    final isSelected = _previewName == name;
                    
                    return EnsureVisible(
                      alignment: EnsureVisible.settingsAlignment,
                      settleFrameCount: 1,
                      preferImmediate: true,
                      child: Focus(
                        onKeyEvent: (node, event) {
                          if (event is! KeyDownEvent) {
                            return KeyEventResult.ignored;
                          }
                          if (isSettingsActivateKey(event.logicalKey)) {
                            if (!_busy) _previewLocalBackup(name);
                            return KeyEventResult.handled;
                          }
                          final direction = event.logicalKey == LogicalKeyboardKey.arrowUp
                              ? TraversalDirection.up
                              : event.logicalKey == LogicalKeyboardKey.arrowDown
                                  ? TraversalDirection.down
                                  : null;
                          if (direction != null) {
                            if (!moveSettingsVerticalFocus(
                              direction: direction,
                              localNodes: <FocusNode>[node],
                            )) {
                              node.focusInDirection(direction);
                            }
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Builder(
                          builder: (context) {
                            final focused = Focus.of(context).hasFocus;
                            return SettingsFocusFrame(
                              padding: EdgeInsets.zero,
                              variant: SettingsFocusFrameVariant.rowOnly,
                              focused: focused,
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                onTap: _busy ? null : () => _previewLocalBackup(name),
                                leading: Icon(
                                  isAuto ? Icons.auto_mode_outlined : Icons.settings_backup_restore,
                                  color: isSelected ? Colors.cyanAccent : Colors.white70,
                                ),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    color: isSelected ? Colors.cyanAccent : Colors.white,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  "$date  -  $size KB ${isAuto ? '(Tự động)' : '(Thủ công)'}",
                                  style: const TextStyle(color: Colors.white54),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.preview_outlined, color: Colors.cyan),
                                      tooltip: "Xem trước",
                                      onPressed: _busy ? null : () => _previewLocalBackup(name),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      tooltip: "Xóa",
                                      onPressed: _busy ? null : () => _deleteLocalBackup(name),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 18),
        SettingsSurfaceCard(
          child: _preview == null
              ? Text(localizations.backupPreviewEmptyState)
              : _BackupPreview(
                  name: _previewName,
                  preview: _preview!,
                ),
        ),
      ],
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    setState(() => _busy = true);
    try {
      final bridge = context.read<SystemBridgeService>();
      final payload = await _buildBackupPayload(context);
      final json = const JsonEncoder.withIndent('  ').convert(payload);
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final result = await bridge.exportSettingsBackup(
        fileName: 'atv-launcher-backup-$timestamp.json',
        content: json,
      );
      if (!mounted) return;
      if (result['cancelled'] != true) {
        await context.read<SettingsService>().setBackupLastExportName(
              result['displayName']?.toString() ?? '',
            );
      }
      final localizations = AppLocalizations.of(context)!;
      final exportPath = result['path']?.toString() ?? '';
      setState(() {
        _lastMessage = result['cancelled'] == true
            ? localizations.backupExportCancelled
            : localizations.backupExportedTo(
                  result['displayName']?.toString() ??
                      localizations.selectedBackup,
                ) +
                (exportPath.trim().isEmpty ? '' : '\n$exportPath');
      });
      await _loadLocalBackups();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lastMessage =
            AppLocalizations.of(context)!.backupExportFailed(error.toString());
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _previewBackup(BuildContext context) async {
    setState(() => _busy = true);
    try {
      final bridge = context.read<SystemBridgeService>();
      final result = await bridge.previewBackup();
      if (!mounted) return;

      if (result['cancelled'] == true) {
        setState(() {
          _lastMessage = AppLocalizations.of(context)!.backupPreviewCancelled;
        });
        return;
      }

      final preview = _parseBackupPreview(result['content']?.toString() ?? '');
      final localizations = AppLocalizations.of(context)!;
      setState(() {
        _preview = preview;
        _previewName = result['displayName']?.toString() ?? '';
        _lastMessage = localizations.backupPreviewLoadedFrom(_previewName);
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _previewName = '';
        _lastMessage = _localizedBackupFormatMessage(context, error);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _previewName = '';
        _lastMessage =
            AppLocalizations.of(context)!.backupPreviewFailed(error.toString());
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _applyBackup(
    BuildContext context, {
    required bool applySystemSettings,
  }) async {
    if (_preview == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final settings = context.read<SettingsService>();
      final appsService = context.read<AppsService>();
      final bridge = context.read<SystemBridgeService>();
      final security = context.read<ProfileSecurityService>();
      final search = context.read<SearchService>();
      final wallpaper = context.read<WallpaperService>();
      final preview = LauncherBackupPayload.validateMap(_preview!);
      final settingsMap =
          (preview['settings'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
      final launcherLayout =
          (preview['launcherLayout'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
      final systemBridge =
          (preview['systemBridge'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
      final profileSecurity =
          (preview['profileSecurity'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
      final searchMap = (preview['search'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final hadOwnerPin = security.hasPin;

      final layoutResult = await appsService.restoreLayoutBackup(
        _mergeLegacyHiddenPackages(
          launcherLayout,
          profileSecurity,
        ),
      );
      if (layoutResult['success'] != true) {
        throw FormatException(
          LauncherBackupPayload.errorInvalidStructure,
        );
      }
      await settings.applyBackupMap(settingsMap);
      await security.applyBackupMap(profileSecurity);
      await search.applyBackupMap(searchMap);
      await wallpaper.restoreFromSettings();

      final restoreNotes = <String>[];
      final unresolvedPackages =
          ((layoutResult['unresolvedPackages'] as List?) ?? const [])
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList(growable: false);
      final preservedPackages =
          ((layoutResult['preservedPackages'] as List?) ?? const [])
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList(growable: false);

      if (applySystemSettings) {
        await _applySystemBackup(context, systemBridge, restoreNotes);
      }

      final localizations = AppLocalizations.of(context)!;
      if (preservedPackages.isNotEmpty) {
        restoreNotes.add(
          localizations.restorePreservedCurrentApps(preservedPackages.length),
        );
      }
      if (!hadOwnerPin && !security.hasPin && profileSecurity.isNotEmpty) {
        restoreNotes.add(localizations.backupOwnerPinNotRestoredNotice);
      }
      final summary = unresolvedPackages.isEmpty
          ? localizations.restoreCompleted
          : localizations
              .restoreCompletedWithMissingApps(unresolvedPackages.length);
      final restoredAt = DateTime.now().millisecondsSinceEpoch;
      await settings.setBackupLastImportName(_previewName);
      await settings.setBackupLastRestoreSummary(summary);
      await settings.setBackupLastRestoreAt(restoredAt);
      await bridge.recordBackupRestoreResult(
        importName: _previewName,
        summary: summary,
        restoredAt: restoredAt,
      );

      if (!mounted) return;
      setState(() {
        _lastMessage = [
          summary,
          ...restoreNotes.where((note) => note.trim().isNotEmpty),
          if (unresolvedPackages.isNotEmpty)
            localizations.missingAppsList(unresolvedPackages.join(', ')),
        ].join('\n');
      });
      await _loadLocalBackups();
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _lastMessage = _localizedBackupFormatMessage(context, error);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lastMessage =
            AppLocalizations.of(context)!.backupRestoreFailed(error.toString());
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _previewLocalBackup(String fileName) async {
    setState(() => _busy = true);
    try {
      final bridge = context.read<SystemBridgeService>();
      final content = await bridge.readLocalBackup(fileName);
      if (!mounted) return;

      final preview = _parseBackupPreview(content);
      final localizations = AppLocalizations.of(context)!;
      setState(() {
        _preview = preview;
        _previewName = fileName;
        _lastMessage = localizations.backupPreviewLoadedFrom(fileName);
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _previewName = '';
        _lastMessage = _localizedBackupFormatMessage(context, error);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _previewName = '';
        _lastMessage = AppLocalizations.of(context)!.backupPreviewFailed(error.toString());
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteLocalBackup(String fileName) async {
    setState(() => _busy = true);
    try {
      final bridge = context.read<SystemBridgeService>();
      final success = await bridge.deleteLocalBackup(fileName);
      if (success) {
        await _loadLocalBackups();
        if (_previewName == fileName) {
          setState(() {
            _preview = null;
            _previewName = '';
          });
        }
      }
    } catch (e) {
      debugPrint("Error deleting backup: $e");
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<Map<String, dynamic>> _buildBackupPayload(BuildContext context) async {
    final bridge = context.read<SystemBridgeService>();
    await bridge.refreshAccessibilitySnapshot();
    await bridge.refresh();

    final settings = context.read<SettingsService>();
    final appsService = context.read<AppsService>();
    final security = context.read<ProfileSecurityService>();
    final search = context.read<SearchService>();
    final managedPackages = bridge.accessibilityApps
        .where((app) => app['managed'] == true)
        .map((app) => app['packageName']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    return <String, dynamic>{
      'version': LauncherBackupPayload.currentVersion,
      'schema': LauncherBackupPayload.schemaId,
      'packageName': bridge.provisioningStatus['packageName']?.toString() ??
          'com.atv.launcher',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'settings': settings.toBackupMap(),
      'launcherLayout': appsService.exportLayoutBackup(),
      'profileSecurity': security.toBackupMap(),
      'search': search.toBackupMap(),
      'systemBridge': <String, dynamic>{
        'voice': <String, dynamic>{
          'mode': bridge.voiceStatus['mode'],
          'keyCode': bridge.voiceStatus['keyCode'],
          'interceptEnabled': bridge.voiceStatus['interceptEnabled'],
        },
        'accessibility': <String, dynamic>{
          'managedPackages': managedPackages,
        },
        'adbAutomation': <String, dynamic>{
          'policy': bridge.adbAutomationStatus['policy'],
          'disableOnSleep': bridge.adbAutomationStatus['disableOnSleep'],
        },
        'density': <String, dynamic>{
          'overrideDensity': bridge.densityStatus['overrideDensity'],
        },
        'privateDns': <String, dynamic>{
          'mode': bridge.privateDnsStatus['mode'],
          'specifier': bridge.privateDnsStatus['specifier'],
        },
      },
    };
  }

  Future<void> _applySystemBackup(
    BuildContext context,
    Map<String, dynamic> systemBridge,
    List<String> restoreNotes,
  ) async {
    final bridge = context.read<SystemBridgeService>();
    final voice = (systemBridge['voice'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final accessibility =
        (systemBridge['accessibility'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final adbAutomation =
        (systemBridge['adbAutomation'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final density =
        (systemBridge['density'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final privateDns =
        (systemBridge['privateDns'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    await _runSystemRestoreStep(
      context,
      restoreNotes,
      successNote: AppLocalizations.of(context)!.voiceModeRestored,
      failurePrefix: AppLocalizations.of(context)!.voiceModeRestoreFailedPrefix,
      action: () async {
        final result = await bridge.setVoiceMode(
          mode: (voice['mode'] as num?)?.toInt(),
          keyCode: (voice['keyCode'] as num?)?.toInt(),
          interceptEnabled: voice['interceptEnabled'] as bool?,
        );
        return result['success'] != false
            ? null
            : result['message']?.toString();
      },
    );

    final policy = adbAutomation['policy']?.toString();
    if (policy != null && policy.isNotEmpty) {
      await _runSystemRestoreStep(
        context,
        restoreNotes,
        successNote: AppLocalizations.of(context)!.adbAutomationRestored,
        failurePrefix:
            AppLocalizations.of(context)!.adbAutomationRestoreFailedPrefix,
        action: () async {
          final result = await bridge.setAdbAutomationPolicy(
            policy: policy,
            disableOnSleep: adbAutomation['disableOnSleep'] == true,
          );
          return result['success'] != false
              ? null
              : result['message']?.toString();
        },
      );
    }

    final overrideDensity = (density['overrideDensity'] as num?)?.toInt();
    if (overrideDensity != null && overrideDensity > 0) {
      await _runSystemRestoreStep(
        context,
        restoreNotes,
        successNote: AppLocalizations.of(context)!.densityOverrideRestored,
        failurePrefix: AppLocalizations.of(context)!.densityRestoreFailedPrefix,
        action: () async {
          final result = await bridge.applyDensity(overrideDensity);
          return result['success'] != false
              ? null
              : result['message']?.toString();
        },
      );
    }

    final dnsMode = privateDns['mode']?.toString();
    final dnsHost = privateDns['specifier']?.toString();
    if (dnsMode != null && dnsMode.isNotEmpty) {
      await _runSystemRestoreStep(
        context,
        restoreNotes,
        successNote: AppLocalizations.of(context)!.privateDnsRestored,
        failurePrefix:
            AppLocalizations.of(context)!.privateDnsRestoreFailedPrefix,
        action: () async {
          final result =
              dnsMode == 'opportunistic' && (dnsHost == null || dnsHost.isEmpty)
                  ? await bridge.resetPrivateDns()
                  : await bridge.applyPrivateDns(mode: dnsMode, host: dnsHost);
          return result['success'] != false
              ? null
              : result['message']?.toString();
        },
      );
    }

    await bridge.refreshAccessibilitySnapshot();
    final currentManaged = bridge.accessibilityApps
        .where((app) => app['managed'] == true)
        .map((app) => app['packageName']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
    final targetManaged =
        ((accessibility['managedPackages'] as List?) ?? const [])
            .map((item) => item.toString())
            .where((value) => value.isNotEmpty)
            .toSet();

    for (final packageName in currentManaged.difference(targetManaged)) {
      await _runSystemRestoreStep(
        context,
        restoreNotes,
        successNote: '',
        failurePrefix: AppLocalizations.of(context)!
            .accessibilityCleanupFailed(packageName),
        action: () async {
          final result =
              await bridge.setManagedAccessibility(packageName, false);
          return result['success'] != false
              ? null
              : result['message']?.toString();
        },
      );
    }
    for (final packageName in targetManaged.difference(currentManaged)) {
      await _runSystemRestoreStep(
        context,
        restoreNotes,
        successNote: '',
        failurePrefix: AppLocalizations.of(context)!
            .accessibilityRestoreFailed(packageName),
        action: () async {
          final result =
              await bridge.setManagedAccessibility(packageName, true);
          return result['success'] != false
              ? null
              : result['message']?.toString();
        },
      );
    }
    if (targetManaged.isNotEmpty || currentManaged.isNotEmpty) {
      restoreNotes
          .add(AppLocalizations.of(context)!.managedAccessibilityReconciled);
    }
  }

  Map<String, dynamic> _parseBackupPreview(String rawContent) {
    return LauncherBackupPayload.decodeAndValidate(rawContent);
  }

  Future<void> _runSystemRestoreStep(
    BuildContext context,
    List<String> restoreNotes, {
    required String successNote,
    required String failurePrefix,
    required Future<String?> Function() action,
  }) async {
    try {
      final failureMessage = await action();
      if (failureMessage != null && failureMessage.trim().isNotEmpty) {
        restoreNotes.add(_withFailureMessage(
          context,
          failurePrefix,
          failureMessage,
        ));
        return;
      }
      if (successNote.isNotEmpty) {
        restoreNotes.add(successNote);
      }
    } catch (error) {
      restoreNotes.add(_withFailureMessage(
        context,
        failurePrefix,
        error.toString(),
      ));
    }
  }

  String _withFailureMessage(
    BuildContext context,
    String prefix,
    String detail,
  ) {
    final value = detail.trim();
    if (value.isEmpty) {
      return prefix;
    }
    return AppLocalizations.of(context)!.restoreFailureLine(prefix, value);
  }

  String _localizedBackupFormatMessage(
    BuildContext context,
    FormatException error,
  ) {
    final localizations = AppLocalizations.of(context)!;
    switch (error.message) {
      case LauncherBackupPayload.errorEmpty:
        return localizations.backupEmptyFileError;
      case LauncherBackupPayload.errorInvalidJson:
        return localizations.backupInvalidJsonError;
      case LauncherBackupPayload.errorInvalidSignature:
        return localizations.backupInvalidSignatureError;
      case LauncherBackupPayload.errorInvalidStructure:
        return localizations.backupInvalidStructureError;
      default:
        return localizations.backupPreviewFailed(error.message);
    }
  }

  Map<String, dynamic> _mergeLegacyHiddenPackages(
    Map<String, dynamic> launcherLayout,
    Map<String, dynamic> profileSecurity,
  ) {
    final merged = Map<String, dynamic>.from(launcherLayout);
    final hiddenPackages = <String>{
      ...((launcherLayout['hiddenPackages'] as List?) ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty),
    };
    final profiles = (profileSecurity['profiles'] as List?) ?? const [];
    for (final rawProfile in profiles) {
      if (rawProfile is! Map) {
        continue;
      }
      final profile = rawProfile.cast<String, dynamic>();
      hiddenPackages.addAll(
        ((profile['hiddenPackages'] as List?) ?? const [])
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty),
      );
    }
    merged['hiddenPackages'] = hiddenPackages.toList(growable: false);
    return merged;
  }
}

class _BackupPreview extends StatelessWidget {
  final String name;
  final Map<String, dynamic> preview;

  const _BackupPreview({
    required this.name,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final launcherLayout =
        (preview['launcherLayout'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final sections = ((launcherLayout['sections'] as List?) ?? const []);
    final systemBridge =
        (preview['systemBridge'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final accessibility =
        (systemBridge['accessibility'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final managedPackages =
        ((accessibility['managedPackages'] as List?) ?? const []);
    final profileSecurity =
        (preview['profileSecurity'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final search = (preview['search'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final profiles = ((profileSecurity['profiles'] as List?) ?? const []);
    final recentQueries = ((search['recentQueries'] as List?) ?? const []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isEmpty ? localizations.selectedBackup : name,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SettingsStatusChip(
              label: localizations.backupVersionChip(
                '${preview['version'] ?? '-'}',
              ),
              color: const Color(0xFF8CCBFF),
            ),
            SettingsStatusChip(
              label: localizations.backupSectionsChip(sections.length),
              color: const Color(0xFF7BE0A5),
            ),
            SettingsStatusChip(
              label: localizations
                  .backupManagedPackagesChip(managedPackages.length),
              color: const Color(0xFFFFC970),
            ),
            SettingsStatusChip(
              label: localizations.backupProfilesChip(profiles.length),
              color: const Color(0xFFB79CFF),
            ),
            SettingsStatusChip(
              label: localizations.backupSearchChip(recentQueries.length),
              color: const Color(0xFF7BE0A5),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          const JsonEncoder.withIndent('  ').convert(preview),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.86),
                height: 1.4,
              ),
        ),
      ],
    );
  }
}
