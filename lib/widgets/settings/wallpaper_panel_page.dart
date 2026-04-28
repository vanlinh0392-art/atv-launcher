import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/settings/gradient_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class WallpaperPanelPage extends StatelessWidget {
  static const String routeName = "wallpaper_panel";

  const WallpaperPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Consumer2<WallpaperService, SystemBridgeService>(
      builder: (context, wallpaperService, bridgeService, _) => ListView(
        key: const PageStorageKey<String>(WallpaperPanelPage.routeName),
        children: [
          SettingsAdaptiveGrid(
            children: [
              SettingsMetricTile(
                label: localizations.modeSettingLabel,
                value: localizedWallpaperMode(
                  localizations,
                  wallpaperService.wallpaperMode,
                ),
                icon: Icons.wallpaper_outlined,
              ),
              SettingsMetricTile(
                label: localizations.sourceLabel,
                value: localizedVideoSourceType(
                  localizations,
                  wallpaperService.videoSourceType,
                ),
                icon: Icons.video_library_outlined,
              ),
              SettingsMetricTile(
                label: localizations.mediaAccess,
                value:
                    bridgeService.fileAccessStatus['hasMediaPermission'] == true
                        ? localizations.grantedLabel
                        : localizations.missingLabel,
                icon: Icons.folder_open_outlined,
              ),
              SettingsMetricTile(
                label: localizations.playlistSize,
                value: wallpaperService.videoUris.length.toString(),
                icon: Icons.playlist_play_outlined,
              ),
            ],
          ),
          if (bridgeService.fileAccessStatus['hasMediaPermission'] != true) ...[
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: Row(
                children: [
                  const Icon(Icons.folder_off_outlined,
                      color: Color(0xFFFFC970)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localizations.grantVideoLibraryAccessHint,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _requestMediaPermission(context, bridgeService),
                    icon: const Icon(Icons.perm_media_outlined),
                    label: Text(localizations.grantAccess),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          SettingsSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(localizations.sourceSelectionTitle,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context)
                          .pushNamed(GradientPanelPage.routeName),
                      icon: const Icon(Icons.gradient),
                      label: Text(localizations.gradient),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => wallpaperService.pickImageWallpaper(),
                      icon: const Icon(Icons.image_outlined),
                      label: Text(localizations.picture),
                    ),
                    FilledButton.icon(
                      onPressed: () => wallpaperService.pickVideoWallpaper(),
                      icon: const Icon(Icons.movie_outlined),
                      label: Text(localizations.singleVideo),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          wallpaperService.pickVideoWallpaperFilesSaf(),
                      icon: const Icon(Icons.video_collection_outlined),
                      label: Text(localizations.pickMultipleVideos),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          wallpaperService.pickVideoWallpaperFolderSaf(),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: Text(localizations.pickFolder),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          _browseLocalLibrary(context, wallpaperService),
                      icon: const Icon(Icons.sd_storage_outlined),
                      label: Text(localizations.browseTvStorage),
                    ),
                  ],
                ),
                if (wallpaperService.wallpaperAssetUri.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    wallpaperService.wallpaperAssetUri,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
                if (wallpaperService.videoFolderName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    localizations
                        .folderNameLabel(wallpaperService.videoFolderName),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          SettingsSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(localizations.playlistBehaviourTitle,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(
                      label: Text(localizations.sequentialOrder),
                      selected: wallpaperService.videoOrderMode == 'sequential',
                      onSelected: (_) =>
                          wallpaperService.setVideoOrderMode('sequential'),
                    ),
                    ChoiceChip(
                      label: Text(localizations.shuffleOrder),
                      selected: wallpaperService.videoOrderMode == 'shuffle',
                      onSelected: (_) =>
                          wallpaperService.setVideoOrderMode('shuffle'),
                    ),
                    ChoiceChip(
                      label: Text(localizations.onCompletion),
                      selected:
                          wallpaperService.videoAdvanceMode == 'on_completion',
                      onSelected: (_) =>
                          wallpaperService.setVideoAdvanceMode('on_completion'),
                    ),
                    ChoiceChip(
                      label: Text(localizations.fixedInterval),
                      selected:
                          wallpaperService.videoAdvanceMode == 'fixed_interval',
                      onSelected: (_) => wallpaperService
                          .setVideoAdvanceMode('fixed_interval'),
                    ),
                  ],
                ),
                SwitchListTile(
                  value: wallpaperService.videoPlaylistLoop,
                  onChanged: wallpaperService.isVideoMode
                      ? wallpaperService.setVideoPlaylistLoop
                      : null,
                  title: Text(localizations.loopPlaylist),
                ),
                if (wallpaperService.videoAdvanceMode == 'fixed_interval')
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(localizations.switchIntervalSeconds(
                      wallpaperService.videoSwitchIntervalSeconds,
                    )),
                    subtitle: Slider(
                      value: wallpaperService.videoSwitchIntervalSeconds
                          .toDouble(),
                      min: 5,
                      max: 300,
                      divisions: 59,
                      label: '${wallpaperService.videoSwitchIntervalSeconds}s',
                      onChanged: wallpaperService.isVideoMode
                          ? (value) => wallpaperService
                              .setVideoSwitchIntervalSeconds(value.round())
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SettingsSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(localizations.playbackAppearanceTitle,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: wallpaperService.videoLoop,
                  onChanged: wallpaperService.isVideoMode
                      ? wallpaperService.setVideoLoop
                      : null,
                  title: Text(localizations.loopSingleVideo),
                ),
                SwitchListTile(
                  value: wallpaperService.videoMute,
                  onChanged: wallpaperService.isVideoMode
                      ? wallpaperService.setVideoMute
                      : null,
                  title: Text(localizations.muteVideo),
                ),
                SwitchListTile(
                  value: wallpaperService.videoAutoResume,
                  onChanged: wallpaperService.isVideoMode
                      ? wallpaperService.setVideoAutoResume
                      : null,
                  title: Text(localizations.autoResumeOnHome),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.crop),
                  title: Text(localizations.videoFitLabel),
                  subtitle: Text(
                    localizedVideoFit(localizations, wallpaperService.videoFit),
                  ),
                  onTap: wallpaperService.isVideoMode
                      ? () => _showSimplePicker(
                            context,
                            title: localizations.videoFitLabel,
                            options: const ['center-crop', 'fit', 'fill'],
                            currentValue: wallpaperService.videoFit,
                            onSelected: wallpaperService.setVideoFit,
                          )
                      : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.blur_on_outlined),
                  title: Text(localizations.videoBlurLabel),
                  subtitle: Text(
                    localizedVideoBlur(
                        localizations, wallpaperService.videoBlur),
                  ),
                  onTap: wallpaperService.isVideoMode
                      ? () => _showSimplePicker(
                            context,
                            title: localizations.videoBlurLabel,
                            options: const ['off', 'low', 'medium', 'high'],
                            currentValue: wallpaperService.videoBlur,
                            onSelected: wallpaperService.setVideoBlur,
                          )
                      : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(localizations
                      .dimOverlayPercent(wallpaperService.videoDimPercent)),
                  subtitle: Slider(
                    value: wallpaperService.videoDimPercent.toDouble(),
                    max: 100,
                    min: 0,
                    divisions: 20,
                    label: '${wallpaperService.videoDimPercent}%',
                    onChanged: wallpaperService.isVideoMode
                        ? (value) =>
                            wallpaperService.setVideoDimPercent(value.round())
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _browseLocalLibrary(
    BuildContext context,
    WallpaperService wallpaperService,
  ) async {
    final localizations = AppLocalizations.of(context)!;
    final library = await wallpaperService.browseLocalVideoLibrary();
    if (context.mounted && library['hasMediaPermission'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.mediaPermissionMissingUseSaf)),
      );
      return;
    }

    final selection = await showDialog<_LibrarySelection>(
      context: context,
      builder: (context) => _VideoLibraryDialog(snapshot: library),
    );
    if (selection == null) {
      return;
    }
    await wallpaperService.applyLibrarySelection(
      uris: selection.uris,
      sourceType: selection.sourceType,
      folderBucketId: selection.bucketId,
      folderName: selection.folderName,
    );
  }

  Future<void> _showSimplePicker(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String currentValue,
    required Future<void> Function(String value) onSelected,
  }) async {
    final localizations = AppLocalizations.of(context)!;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: options
            .map(
              (option) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(option),
                child: Text(
                  option == currentValue
                      ? '${_localizedOption(localizations, option)} (${localizations.currentLabel})'
                      : _localizedOption(localizations, option),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );

    if (selected != null) {
      await onSelected(selected);
    }
  }

  Future<void> _requestMediaPermission(
    BuildContext context,
    SystemBridgeService bridgeService,
  ) async {
    final localizations = AppLocalizations.of(context)!;
    final result = await bridgeService.requestMediaReadPermission();
    if (!context.mounted) {
      return;
    }
    final granted = result['granted'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? localizations.videoLibraryAccessGranted
              : (result['message']?.toString() ??
                  localizations.videoLibraryAccessNotGranted),
        ),
      ),
    );
  }

  String _localizedOption(AppLocalizations localizations, String option) {
    switch (option) {
      case 'fit':
        return localizations.videoFitFit;
      case 'fill':
        return localizations.videoFitFill;
      case 'center-crop':
        return localizations.videoFitCenterCrop;
      case 'low':
        return localizations.videoBlurLow;
      case 'medium':
        return localizations.videoBlurMedium;
      case 'high':
        return localizations.videoBlurHigh;
      case 'off':
        return localizations.videoBlurOff;
      default:
        return option;
    }
  }
}

class _VideoLibraryDialog extends StatelessWidget {
  final Map<String, dynamic> snapshot;

  const _VideoLibraryDialog({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final folders = ((snapshot['folders'] as List?) ?? const [])
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList(growable: false);
    final videos = ((snapshot['videos'] as List?) ?? const [])
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList(growable: false);

    return Dialog(
      child: SizedBox(
        width: 760,
        height: 520,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localizations.browseTvStorageTitle,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text(
                localizations.browseTvStorageDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(localizations.foldersLabel,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView.builder(
                              itemCount: folders.length,
                              itemBuilder: (context, index) {
                                final folder = folders[index];
                                return ListTile(
                                  title: Text(folder['name']?.toString() ??
                                      localizations.genericFolder),
                                  subtitle: Text(localizations.videoCount(
                                    ((folder['count'] as num?) ?? 0).toInt(),
                                  )),
                                  onTap: () async {
                                    final wallpaper =
                                        context.read<WallpaperService>();
                                    final folderSnapshot =
                                        await wallpaper.browseLocalVideoLibrary(
                                      bucketId: folder['bucketId']?.toString(),
                                    );
                                    final uris =
                                        ((folderSnapshot['videos'] as List?) ??
                                                const [])
                                            .map((item) => (item as Map)
                                                .cast<String, dynamic>())
                                            .map((item) =>
                                                item['uri']?.toString() ?? '')
                                            .where((item) => item.isNotEmpty)
                                            .toList(growable: false);
                                    if (context.mounted) {
                                      Navigator.of(context).pop(
                                        _LibrarySelection(
                                          sourceType: 'folder_playlist',
                                          uris: uris,
                                          bucketId:
                                              folder['bucketId']?.toString() ??
                                                  '',
                                          folderName:
                                              folder['name']?.toString() ?? '',
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(localizations.recentVideos,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView.builder(
                              itemCount: videos.length.clamp(0, 20).toInt(),
                              itemBuilder: (context, index) {
                                final video = videos[index];
                                return ListTile(
                                  title: Text(
                                      video['displayName']?.toString() ??
                                          localizations.genericVideo),
                                  subtitle: Text(
                                      video['bucketName']?.toString() ?? ''),
                                  onTap: () => Navigator.of(context).pop(
                                    _LibrarySelection(
                                      sourceType: 'single_file',
                                      uris: [video['uri']?.toString() ?? ''],
                                      bucketId:
                                          video['bucketId']?.toString() ?? '',
                                      folderName:
                                          video['bucketName']?.toString() ?? '',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibrarySelection {
  final String sourceType;
  final List<String> uris;
  final String bucketId;
  final String folderName;

  const _LibrarySelection({
    required this.sourceType,
    required this.uris,
    required this.bucketId,
    required this.folderName,
  });
}
