import 'package:flauncher/providers/search_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class VoiceSearchPanelPage extends StatelessWidget {
  static const String routeName = "voice_search_panel";

  const VoiceSearchPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Consumer2<SystemBridgeService, SearchService>(
      builder: (context, bridgeService, searchService, _) {
        final status = bridgeService.voiceStatus;
        final mode = (status['mode'] as num?)?.toInt() ?? 0;
        final keyCode = status['keyCode']?.toString() ?? '0';
        final interceptEnabled = status['interceptEnabled'] == true;

        return ListView(
          key: const PageStorageKey<String>(VoiceSearchPanelPage.routeName),
          children: [
            SettingsAdaptiveGrid(
              children: [
                SettingsMetricTile(
                  label: localizations.voiceModeLabel,
                  value: localizedVoiceMode(localizations, mode),
                  icon: Icons.mic_none_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.keyCodeLabel,
                  value: keyCode,
                  icon: Icons.keyboard_outlined,
                ),
                SettingsMetricTile(
                  label: localizations.accessibilityLabel,
                  value: localizedBridgeHealth(
                    localizations,
                    status['health']?.toString() ?? '',
                  ),
                  icon: Icons.health_and_safety_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RoundedSwitchListTile(
                    value: interceptEnabled,
                    onChanged: bridgeService.setVoiceInterceptEnabled,
                    title: Text(localizations.interceptRemoteVoiceKey),
                    secondary: const Icon(Icons.hearing_outlined),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.tune),
                    title: Text(localizations.pressMode),
                    subtitle: Text(localizedVoiceMode(localizations, mode)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showModePicker(context, bridgeService, mode),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.key_outlined),
                    title: Text(localizations.defaultProfile),
                    subtitle:
                        Text(status['defaultKeySummary']?.toString() ?? '-'),
                  ),
                  if (status['learningMode'] == true)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.sensors_outlined,
                          color: Color(0xFFFFC970)),
                      title: Text(localizations.learningModeActive),
                      subtitle: Text(localizations.learningModeHint),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final result =
                              await searchService.startSpeechRecognizer();
                          if (!context.mounted) {
                            return;
                          }
                          final String message;
                          final text = result['text']?.toString() ?? '';
                          if (text.trim().isNotEmpty) {
                            message = localizations.speechCapturedMessage(text);
                          } else {
                            message = result['message']?.toString() ??
                                localizations.speechCaptureNoTextMessage;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        },
                        icon: const Icon(Icons.mic_none_outlined),
                        label: Text(localizations.testSpeechCaptureAction),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SettingsSurfaceCard(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => bridgeService.startKeyLearning(),
                    icon: const Icon(Icons.sensors_outlined),
                    label: Text(localizations.learnRemoteKey),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async => _showResult(
                      context,
                      await bridgeService.testVoiceSearch(),
                    ),
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text(localizations.testVoiceLaunch),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => bridgeService.resetVoiceMapping(),
                    icon: const Icon(Icons.restart_alt),
                    label: Text(localizations.resetXiaomiDefault),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async => _showResult(
                      context,
                      await bridgeService.repairAccessibility(),
                    ),
                    icon: const Icon(Icons.build_circle_outlined),
                    label: Text(localizations.repairAccessibility),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => bridgeService.openAccessibilitySettings(),
                    icon: const Icon(Icons.settings_accessibility),
                    label: Text(localizations.openAccessibilitySettings),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showModePicker(
    BuildContext context,
    SystemBridgeService bridgeService,
    int currentMode,
  ) async {
    final selectedMode = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.voiceModeLabel),
        children: [
          _VoiceModeOption(
            value: 0,
            label: AppLocalizations.of(context)!.voiceModeDoublePress,
          ),
          _VoiceModeOption(
            value: 1,
            label: AppLocalizations.of(context)!.voiceModeSinglePress,
          ),
          _VoiceModeOption(
            value: 2,
            label: AppLocalizations.of(context)!.voiceModeLongPress,
          ),
          _VoiceModeOption(
            value: 3,
            label: AppLocalizations.of(context)!.voiceModeDoublePressHold,
          ),
        ],
      ),
    );

    if (selectedMode != null && selectedMode != currentMode) {
      await bridgeService.setVoiceMode(mode: selectedMode);
    }
  }

  void _showResult(BuildContext context, Map<String, dynamic> result) {
    if (!context.mounted) {
      return;
    }
    final message = result['message']?.toString() ??
        AppLocalizations.of(context)!.actionCompleted;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _VoiceModeOption extends StatelessWidget {
  final int value;
  final String label;

  const _VoiceModeOption({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => SimpleDialogOption(
        onPressed: () => Navigator.of(context).pop(value),
        child: Text(label),
      );
}
