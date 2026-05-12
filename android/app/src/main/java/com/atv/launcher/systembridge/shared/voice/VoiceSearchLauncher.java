package com.atv.launcher.systembridge.shared.voice;

import android.content.Context;
import android.content.Intent;

public final class VoiceSearchLauncher {
    private VoiceSearchLauncher() {
    }

    public static boolean launch(Context context) {
        Context appContext = context.getApplicationContext();
        Intent webSearch = new Intent("android.speech.action.WEB_SEARCH")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        if (tryStart(appContext, webSearch)) {
            return true;
        }

        Intent assist = new Intent(Intent.ACTION_ASSIST)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        if (tryStart(appContext, assist)) {
            return true;
        }

        Intent voiceCommand = new Intent(Intent.ACTION_VOICE_COMMAND)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        return tryStart(appContext, voiceCommand);
    }

    private static boolean tryStart(Context context, Intent intent) {
        if (intent == null) {
            return false;
        }
        try {
            context.startActivity(intent);
            return true;
        } catch (Exception ignored) {
            return false;
        }
    }
}
