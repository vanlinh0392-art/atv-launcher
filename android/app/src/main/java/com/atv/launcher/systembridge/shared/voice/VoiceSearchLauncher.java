package com.atv.launcher.systembridge.shared.voice;

import android.content.Context;
import android.content.Intent;
import android.util.Log;

public final class VoiceSearchLauncher {
    private static final String TAG = "VoiceSearchLauncher";

    private VoiceSearchLauncher() {
    }

    public static boolean launch(Context context) {
        Context appContext = context.getApplicationContext();
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
