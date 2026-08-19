import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SmartVoiceDispatcher is defined with full TV channel and app dispatch capabilities', () {
    final dispatcherFile = File(
      'android/app/src/main/java/com/atv/launcher/systembridge/shared/voice/SmartVoiceDispatcher.java',
    );
    expect(dispatcherFile.existsSync(), isTrue);

    final content = dispatcherFile.readAsStringSync();
    expect(content, contains('class SmartVoiceDispatcher'));
    expect(content, contains('com.xemtv.app'));
    expect(content, contains('com.xemtv.app.ACTION_VIEW_CHANNEL'));
    expect(content, contains('SearchableActivity'));
    expect(content, contains('extractTvChannel'));
    expect(content, contains('extractAppQuery'));
    expect(content, contains('launchMediaSearch'));
    expect(content, contains('stripAccents'));
    expect(content, contains('COMMON_APP_ALIASES'));
  });

  test('VoiceSearchLauncher integrates with SmartVoiceDispatcher', () {
    final launcherFile = File(
      'android/app/src/main/java/com/atv/launcher/systembridge/shared/voice/VoiceSearchLauncher.java',
    );
    final content = launcherFile.readAsStringSync();
    expect(content, contains('launchWithQuery'));
    expect(content, contains('SmartVoiceDispatcher.dispatch'));
  });

  test('VietnameseTextPreprocessor and VietnameseTtsEngine are defined with 3-tier fallback', () {
    final preprocessorFile = File(
      'android/app/src/main/java/com/atv/launcher/systembridge/tts/VietnameseTextPreprocessor.java',
    );
    expect(preprocessorFile.existsSync(), isTrue);
    final prepContent = preprocessorFile.readAsStringSync();
    expect(prepContent, contains('preprocessForSpeech'));
    expect(prepContent, contains('replaceChannelNames'));
    expect(prepContent, contains('replaceAbbreviations'));
    expect(prepContent, contains('splitIntoSentences'));

    final ttsEngineFile = File(
      'android/app/src/main/java/com/atv/launcher/systembridge/tts/VietnameseTtsEngine.java',
    );
    expect(ttsEngineFile.existsSync(), isTrue);
    final ttsContent = ttsEngineFile.readAsStringSync();
    expect(ttsContent, contains('tryEdgeTts'));
    expect(ttsContent, contains('tryNativeTts'));
    expect(ttsContent, contains('VOICE_HOAI_MY'));
    expect(ttsContent, contains('TIER1_TIMEOUT_MS'));
  });

  test('AiVoiceAssistantClient connects Multi-Model AI with multi-layer key obfuscation and alternating fallback', () {
    final aiClientFile = File(
      'android/app/src/main/java/com/atv/launcher/systembridge/ai/AiVoiceAssistantClient.java',
    );
    expect(aiClientFile.existsSync(), isTrue);
    final aiContent = aiClientFile.readAsStringSync();
    expect(aiContent, contains('isQuestionOrConversation'));
    expect(aiContent, contains('askAi'));
    expect(aiContent, contains('OPENROUTER_ENDPOINT'));
    expect(aiContent, contains('NVIDIA_ENDPOINT'));
    expect(aiContent, contains('FALLBACK_MODELS'));
    expect(aiContent, contains('meta/llama-3.1-8b-instruct'));
    expect(aiContent, contains('google/gemma-4-31b-it'));
    expect(aiContent, contains('google/diffusiongemma-26b-a4b-it'));
    expect(aiContent, contains('meta/llama-3.2-11b-vision-instruct'));
    expect(aiContent, contains('nvidia/nemotron-3.5-lightning:free'));
    expect(aiContent, contains('google/gemma-4-31b-it:free'));
    expect(aiContent, contains('google/gemma-4-26b-a4b-it:free'));
    expect(aiContent, contains('openai/gpt-oss-20b:free'));
    expect(aiContent, contains('GEMINI_API_URL'));
    expect(aiContent, contains('resolveKey'));
  });

  test('AppIndexStore is defined with multi-tier fuzzy matching and persistent cache', () {
    final storeFile = File(
      'android/app/src/main/java/com/atv/launcher/systembridge/shared/appindex/AppIndexStore.java',
    );
    expect(storeFile.existsSync(), isTrue);
    final storeContent = storeFile.readAsStringSync();
    expect(storeContent, contains('class AppIndexStore'));
    expect(storeContent, contains('AppEntry'));
    expect(storeContent, contains('findBestMatch'));
    expect(storeContent, contains('syncApps'));
    expect(storeContent, contains('generateAliases'));
    expect(storeContent, contains('computeLevenshteinDistance'));
    expect(storeContent, contains('stripAccents'));
  });
}

