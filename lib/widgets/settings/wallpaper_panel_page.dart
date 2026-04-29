import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/gradient_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
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
        padding: const EdgeInsets.only(bottom: 16),
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
                SettingsAdaptiveGrid(
                  minChildWidth: 230,
                  maxColumns: 3,
                  children: [
                    SettingsActionCard(
                      title: localizations.gradient,
                      icon: Icons.gradient,
                      onPressed: () async {
                        Navigator.of(context).pushNamed(
                          GradientPanelPage.routeName,
                        );
                      },
                    ),
                    SettingsActionCard(
                      title: localizations.picture,
                      icon: Icons.image_outlined,
                      onPressed: () async {
                        await wallpaperService.pickImageWallpaper();
                      },
                    ),
                    SettingsActionCard(
                      title: localizations.singleVideo,
                      icon: Icons.movie_outlined,
                      onPressed: () async {
                        await wallpaperService.pickVideoWallpaper();
                      },
                    ),
                    SettingsActionCard(
                      title: localizations.pickMultipleVideos,
                      icon: Icons.video_collection_outlined,
                      onPressed: () async {
                        await wallpaperService.pickVideoWallpaperFilesSaf();
                      },
                    ),
                    SettingsActionCard(
                      title: localizations.pickFolder,
                      icon: Icons.folder_open_outlined,
                      onPressed: () async {
                        await wallpaperService.pickVideoWallpaperFolderSaf();
                      },
                    ),
                    SettingsActionCard(
                      title: localizations.browseTvStorage,
                      icon: Icons.sd_storage_outlined,
                      onPressed: () async {
                        await _browseLocalLibrary(context, wallpaperService);
                      },
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
                SettingsChoiceCard<String>(
                  selectorKey: const Key('wallpaper_order_mode_selector'),
                  optionKeyPrefix: 'wallpaper_order_mode_option',
                  title: localizations.sourceLabel,
                  subtitle: localizations.playlistBehaviourTitle,
                  icon: Icons.playlist_play_outlined,
                  value: wallpaperService.videoOrderMode,
                  options: <SettingsChoiceOption<String>>[
                    SettingsChoiceOption<String>(
                      value: 'sequential',
                      label: localizations.sequentialOrder,
                    ),
                    SettingsChoiceOption<String>(
                      value: 'shuffle',
                      label: localizations.shuffleOrder,
                    ),
                  ],
                  valueLabelBuilder: (value) => localizedVideoOrderMode(
                    localizations,
                    value,
                  ),
                  onChanged: wallpaperService.setVideoOrderMode,
                ),
                const SizedBox(height: 10),
                SettingsChoiceCard<String>(
                  selectorKey: const Key('wallpaper_advance_mode_selector'),
                  optionKeyPrefix: 'wallpaper_advance_mode_option',
                  title: localizations.playlistBehaviourTitle,
                  subtitle: localizations.fixedInterval,
                  icon: Icons.schedule_outlined,
                  value: wallpaperService.videoAdvanceMode,
                  options: <SettingsChoiceOption<String>>[
                    SettingsChoiceOption<String>(
                      value: 'on_completion',
                      label: localizations.onCompletion,
                    ),
                    SettingsChoiceOption<String>(
                      value: 'fixed_interval',
                      label: localizations.fixedInterval,
                    ),
                  ],
                  valueLabelBuilder: (value) => localizedVideoAdvanceMode(
                    localizations,
                    value,
                  ),
                  onChanged: wallpaperService.setVideoAdvanceMode,
                ),
                const SizedBox(height: 10),
                RoundedSwitchListTile(
                  value: wallpaperService.videoPlaylistLoop,
                  onChanged: wallpaperService.isVideoMode
                      ? wallpaperService.setVideoPlaylistLoop
                      : null,
                  title: Text(
                    localizations.loopPlaylist,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  secondary: const Icon(Icons.repeat_outlined),
                ),
                if (wallpaperService.videoAdvanceMode == 'fixed_interval')
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SettingsStepperCard(
                      selectorKey:
                          const Key('video_switch_interval_seconds_stepper'),
                      buttonKeyPrefix: 'video_switch_interval_seconds',
                      title: localizations.switchIntervalSeconds(
                        wallpaperService.videoSwitchIntervalSeconds,
                      ),
                      subtitle: localizations.fixedInterval,
                      icon: Icons.timer_outlined,
                      value: wallpaperService.videoSwitchIntervalSeconds,
                      valueLabelBuilder: (value) => '${value}s',
                      minimum: 5,
                      maximum: 300,
                      step: 5,
                      onChanged: wallpaperService.isVideoMode
                          ? wallpaperService.setVideoSwitchIntervalSeconds
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
                RoundedSwitchListTile(
                  value: wallpaperService.videoLoop,
                  onChanged: wallpaperService.isVideoMode
                      ? wallpaperService.setVideoLoop
                      : null,
                  title: Text(
                    localizations.loopSingleVideo,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  secondary: const Icon(Icons.loop_outlined),
                ),
                const SizedBox(height: 10),
                RoundedSwitchListTile(
                  value: wallpaperService.videoMute,
                  onChanged: wallpaperService.isVideoMode
                      ? wallpaperService.setVideoMute
                      : null,
                  title: Text(
                    localizations.muteVideo,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  secondary: const Icon(Icons.volume_off_outlined),
                ),
                const SizedBox(height: 10),
                RoundedSwitchListTile(
                  value: wallpaperService.videoAutoResume,
                  onChanged: wallpaperService.isVideoMode
                      ? wallpaperService.setVideoAutoResume
                      : null,
                  title: Text(
                    localizations.autoResumeOnHome,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  secondary: const Icon(Icons.home_max_outlined),
                ),
                const SizedBox(height: 10),
                SettingsChoiceCard<String>(
                  selectorKey: const Key('wallpaper_video_fit_selector'),
                  optionKeyPrefix: 'wallpaper_video_fit_option',
                  title: localizations.videoFitLabel,
                  subtitle: localizations.playbackAppearanceTitle,
                  icon: Icons.crop,
                  value: wallpaperService.videoFit,
                  options: <SettingsChoiceOption<String>>[
                    SettingsChoiceOption<String>(
                      value: 'center-crop',
                      label: localizations.videoFitCenterCrop,
                    ),
                    SettingsChoiceOption<String>(
                      value: 'fit',
                      label: localizations.videoFitFit,
                    ),
                    SettingsChoiceOption<String>(
                      value: 'fill',
                      label: localizations.videoFitFill,
                    ),
                  ],
                  valueLabelBuilder: (value) =>
                      localizedVideoFit(localizations, value),
                  onChanged: wallpaperService.setVideoFit,
                ),
                const SizedBox(height: 10),
                SettingsChoiceCard<String>(
                  selectorKey: const Key('wallpaper_video_blur_selector'),
                  optionKeyPrefix: 'wallpaper_video_blur_option',
                  title: localizations.videoBlurLabel,
                  subtitle: localizations.playbackAppearanceTitle,
                  icon: Icons.blur_on_outlined,
                  value: wallpaperService.videoBlur,
                  options: <SettingsChoiceOption<String>>[
                    SettingsChoiceOption<String>(
                      value: 'off',
                      label: localizations.videoBlurOff,
                    ),
                    SettingsChoiceOption<String>(
                      value: 'low',
                      label: localizations.videoBlurLow,
                    ),
                    SettingsChoiceOption<String>(
                      value: 'medium',
                      label: localizations.videoBlurMedium,
                    ),
                    SettingsChoiceOption<String>(
                      value: 'high',
                      label: localizations.videoBlurHigh,
                    ),
                  ],
                  valueLabelBuilder: (value) =>
                      localizedVideoBlur(localizations, value),
                  onChanged: wallpaperService.setVideoBlur,
                ),
                const SizedBox(height: 10),
                SettingsStepperCard(
                  selectorKey: const Key('video_dim_percent_stepper'),
                  buttonKeyPrefix: 'video_dim_percent',
                  title: localizations
                      .dimOverlayPercent(wallpaperService.videoDimPercent),
                  subtitle: localizations.playbackAppearanceTitle,
                  icon: Icons.dark_mode_outlined,
                  value: wallpaperService.videoDimPercent,
                  valueLabelBuilder: (value) => '${value}%',
                  minimum: 0,
                  maximum: 100,
                  step: 5,
                  onChanged: wallpaperService.isVideoMode
                      ? wallpaperService.setVideoDimPercent
                      : null,
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
                                return EnsureVisible(
                                  alignment: 0.12,
                                  child: ListTile(
                                    title: Text(folder['name']?.toString() ??
                                        localizations.genericFolder),
                                    subtitle: Text(localizations.videoCount(
                                      ((folder['count'] as num?) ?? 0).toInt(),
                                    )),
                                    onTap: () async {
                                      final wallpaper =
                                          context.read<WallpaperService>();
                                      final folderSnapshot = await wallpaper
                                          .browseLocalVideoLibrary(
                                        bucketId:
                                            folder['bucketId']?.toString(),
                                      );
                                      final uris = ((folderSnapshot['videos']
                                                  as List?) ??
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
                                            bucketId: folder['bucketId']
                                                    ?.toString() ??
                                                '',
                                            folderName:
                                                folder['name']?.toString() ??
                                                    '',
                                          ),
                                        );
                                      }
                                    },
                                  ),
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
                                return EnsureVisible(
                                  alignment: 0.12,
                                  child: ListTile(
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
                                            video['bucketName']?.toString() ??
                                                '',
                                      ),
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
