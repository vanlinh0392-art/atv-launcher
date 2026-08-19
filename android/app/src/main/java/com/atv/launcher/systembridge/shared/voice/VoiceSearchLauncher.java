package com.atv.launcher.systembridge.shared.voice;

import android.content.Context;
import android.content.Intent;
import android.speech.RecognizerIntent;
import android.text.TextUtils;
import android.util.Log;

import java.util.Map;

public final class VoiceSearchLauncher {
    private static final String TAG = "VoiceSearchLauncher";
    public static final String ACTION_VOICE_CAPTURE = "com.atv.launcher.ACTION_VOICE_CAPTURE";

    private VoiceSearchLauncher() {
    }

    public static boolean launchWithQuery(Context context, String query) {
        if (TextUtils.isEmpty(query)) {
            return launch(context);
        }
        Map<String, Object> result = SmartVoiceDispatcher.dispatch(context, query);
        return Boolean.TRUE.equals(result.get("success"));
    }

    public static boolean launch(Context context) {
        Context appContext = context.getApplicationContext();

        // 1. Ưu tiên số 1: Floating Overlay trong suốt qua WindowManager (100% Không nháy màn hình, Không chuyển Activity)
        try {
            VoiceFloatingOverlayManager.getInstance(appContext).showAndListen();
            Log.i(TAG, "started VoiceFloatingOverlayManager in foreground (0% flicker)");
            return true;
        } catch (Exception e) {
            Log.w(TAG, "VoiceFloatingOverlayManager failed, falling back to activity", e);
        }

        // 2. Dự phòng: Khởi chạy VoiceCaptureTransparentActivity
        try {
            Intent transparentVoice = new Intent(context, VoiceCaptureTransparentActivity.class)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_NO_ANIMATION);
            if (tryStart(context, transparentVoice)) {
                Log.i(TAG, "started VoiceCaptureTransparentActivity fallback");
                return true;
            }
        } catch (Exception e) {
            Log.w(TAG, "VoiceCaptureTransparentActivity launch failed", e);
        }

        // 3. Dự phòng: Kích hoạt MainActivity thu âm nội bộ
        Intent internalVoice = new Intent(ACTION_VOICE_CAPTURE)
                .setClassName(appContext.getPackageName(), "com.atv.launcher.MainActivity")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        if (tryStart(appContext, internalVoice)) {
            Log.i(TAG, "started FLauncher internal voice capture");
            return true;
        }

        // 3. Dự phòng: RecognizerIntent chuẩn tiếng Việt
        Intent speechIntent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE, "vi-VN")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        if (tryStart(appContext, speechIntent)) {
            Log.i(TAG, "started RecognizerIntent.ACTION_RECOGNIZE_SPEECH");
            return true;
        }

        // 4. Fallback hệ thống
        Intent webSearch = new Intent("android.speech.action.WEB_SEARCH")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        if (tryStart(appContext, webSearch)) {
            Log.i(TAG, "started android.speech.action.WEB_SEARCH");
            return true;
        }

        Intent assist = new Intent(Intent.ACTION_ASSIST)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        if (tryStart(appContext, assist)) {
            Log.i(TAG, "started " + Intent.ACTION_ASSIST);
            return true;
        }

        Intent voiceCommand = new Intent(Intent.ACTION_VOICE_COMMAND)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        boolean started = tryStart(appContext, voiceCommand);
        if (started) {
            Log.i(TAG, "started " + Intent.ACTION_VOICE_COMMAND);
        }
        return started;
    }

    private static boolean tryStart(Context context, Intent intent) {
        if (intent == null) {
            return false;
        }
        try {
            context.startActivity(intent);
            return true;
        } catch (Exception exception) {
            Log.w(TAG, "start failed action=" + intent.getAction(), exception);
            return false;
        }
    }
}
