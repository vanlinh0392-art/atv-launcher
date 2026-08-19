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

  test('AiVoiceAssistantClient connects OpenRouter / LLM Q&A with 8-model alternating fallback', () {
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
    expect(aiContent, contains('google/gemini-2.0-flash-exp:free'));
    expect(aiContent, contains('meta/llama-3.1-8b-instruct'));
    expect(aiContent, contains('meta-llama/llama-3.3-70b-instruct'));
    expect(aiContent, contains('mistralai/mistral-large-2-instruct'));
    expect(aiContent, contains('deepseek/deepseek-chat'));
    expect(aiContent, contains('nvidia/llama-3.1-nemotron-70b-instruct'));
    expect(aiContent, contains('mistralai/mistral-7b-instruct:free'));
    expect(aiContent, contains('qwen/qwen2.5-7b-instruct'));
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

