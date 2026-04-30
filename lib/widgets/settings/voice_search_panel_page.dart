import 'package:flauncher/providers/search_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class VoiceSearchPanelPage extends StatelessWidget {
  static const String routeName = "voice_search_panel";
  final FocusNode? primaryFocusNode;

  const VoiceSearchPanelPage({
    super.key,
    this.primaryFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    Widget actionCard({
      required String title,
      String? subtitle,
      required IconData icon,
      required Future<void> Function()? onPressed,
    }) =>
        SizedBox(
          height: 88,
          child: SettingsActionCard(
            title: title,
            subtitle: subtitle,
            icon: icon,
            onPressed: onPressed,
            focusEmphasis: 1.32,
          ),
        );

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
                  SettingsChoiceCard<int>(
                    focusNode: primaryFocusNode,
                    selectorKey: const Key('voice_search_mode_selector'),
                    optionKeyPrefix: 'voice_search_mode_option',
                    title: localizations.pressMode,
                    subtitle: localizations.settingsDestinationVoiceSubtitle,
                    icon: Icons.tune,
                    value: mode,
                    options: <SettingsChoiceOption<int>>[
                      SettingsChoiceOption<int>(
                        value: 0,
                        label: localizations.voiceModeDoublePress,
                      ),
                      SettingsChoiceOption<int>(
                        value: 1,
                        label: localizations.voiceModeSinglePress,
                      ),
                      SettingsChoiceOption<int>(
                        value: 2,
                        label: localizations.voiceModeLongPress,
                      ),
                      SettingsChoiceOption<int>(
                        value: 3,
                        label: localizations.voiceModeDoublePressHold,
                      ),
                    ],
                    valueLabelBuilder: (value) =>
                        localizedVoiceMode(localizations, value),
                    onChanged: (value) async {
                      await bridgeService.setVoiceMode(mode: value);
                    },
                  ),
                  const SizedBox(height: 12),
                  RoundedSwitchListTile(
                    value: interceptEnabled,
                    onChanged: bridgeService.setVoiceInterceptEnabled,
                    title: Text(
                      localizations.interceptRemoteVoiceKey,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    secondary: const Icon(Icons.hearing_outlined),
                  ),
                  const SizedBox(height: 10),
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
            SettingsSurfaceCard(
              child: SettingsAdaptiveGrid(
                spacing: 12,
                runSpacing: 12,
                minChildWidth: 240,
                maxColumns: 2,
                children: [
                  actionCard(
                    title: localizations.testSpeechCaptureAction,
                    icon: Icons.mic_none_outlined,
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
                  ),
                  actionCard(
                    title: localizations.learnRemoteKey,
                    icon: Icons.sensors_outlined,
                    onPressed: () async {
                      await bridgeService.startKeyLearning();
                    },
                  ),
                  actionCard(
                    title: localizations.testVoiceLaunch,
                    icon: Icons.play_circle_outline,
                    onPressed: () async => _showResult(
                      context,
                      await bridgeService.testVoiceSearch(),
                    ),
                  ),
                  actionCard(
                    title: localizations.resetXiaomiDefault,
                    icon: Icons.restart_alt,
                    onPressed: () async {
                      await bridgeService.resetVoiceMapping();
                    },
                  ),
                  actionCard(
                    title: localizations.repairAccessibility,
                    icon: Icons.build_circle_outlined,
                    onPressed: () async => _showResult(
                      context,
                      await bridgeService.repairAccessibility(),
                    ),
                  ),
                  actionCard(
                    title: localizations.openAccessibilitySettings,
                    icon: Icons.settings_accessibility,
                    onPressed: () async {
                      bridgeService.openAccessibilitySettings();
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
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
