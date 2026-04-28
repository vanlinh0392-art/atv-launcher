import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/gradient_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                    child: _WallpaperStepperSettingCard(
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
                const SizedBox(height: 10),
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
                const SizedBox(height: 10),
                _WallpaperStepperSettingCard(
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

class _WallpaperStepperSettingCard extends StatefulWidget {
  final Key? selectorKey;
  final String? buttonKeyPrefix;
  final String title;
  final String subtitle;
  final IconData icon;
  final int value;
  final int minimum;
  final int maximum;
  final int step;
  final String Function(int value) valueLabelBuilder;
  final ValueChanged<int>? onChanged;

  const _WallpaperStepperSettingCard({
    this.selectorKey,
    this.buttonKeyPrefix,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.step,
    required this.valueLabelBuilder,
    required this.onChanged,
  });

  @override
  State<_WallpaperStepperSettingCard> createState() =>
      _WallpaperStepperSettingCardState();
}

class _WallpaperStepperSettingCardState
    extends State<_WallpaperStepperSettingCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final canDecrease =
        widget.onChanged != null && widget.value > widget.minimum;
    final canIncrease =
        widget.onChanged != null && widget.value < widget.maximum;

    return EnsureVisible(
      alignment: 0.12,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _shiftValue(-widget.step),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _shiftValue(widget.step),
        },
        child: FocusableActionDetector(
          onShowFocusHighlight: (value) {
            if (_focused != value) {
              setState(() => _focused = value);
            }
          },
          child: SettingsFocusFrame(
            key: widget.selectorKey,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _focused ? 1 : 0.96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(widget.icon, color: Colors.white70),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ExcludeFocus(
                        child: FilledButton.tonal(
                          onPressed:
                              canDecrease ? () => _shiftValue(-widget.step) : null,
                          key: widget.buttonKeyPrefix == null
                              ? null
                              : ValueKey<String>(
                                  '${widget.buttonKeyPrefix}_decrease',
                                ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Icon(Icons.remove),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Text(
                            widget.valueLabelBuilder(widget.value),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ExcludeFocus(
                        child: FilledButton.tonal(
                          onPressed:
                              canIncrease ? () => _shiftValue(widget.step) : null,
                          key: widget.buttonKeyPrefix == null
                              ? null
                              : ValueKey<String>(
                                  '${widget.buttonKeyPrefix}_increase',
                                ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _shiftValue(int delta) {
    if (widget.onChanged == null) {
      return;
    }
    final next = (widget.value + delta).clamp(widget.minimum, widget.maximum);
    if (next != widget.value) {
      widget.onChanged!(next);
    }
  }
}
