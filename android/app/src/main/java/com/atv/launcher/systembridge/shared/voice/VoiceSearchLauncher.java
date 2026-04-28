package com.atv.launcher.systembridge.shared.voice;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.text.TextUtils;

import java.util.List;

public final class VoiceSearchLauncher {
    private static final String GOOGLE_APP_PACKAGE = "com.google.android.googlequicksearchbox";

    private VoiceSearchLauncher() {
    }

    public static boolean launch(Context context) {
        Context appContext = context.getApplicationContext();
        Intent googleVoiceIntent = resolveGoogleVoiceIntent(appContext);
        if (tryStart(appContext, googleVoiceIntent)) {
            return true;
        }

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

    private static Intent resolveGoogleVoiceIntent(Context context) {
        PackageManager packageManager = context.getPackageManager();
        Intent webSearch = new Intent("android.speech.action.WEB_SEARCH");
        List<ResolveInfo> resolveInfos = packageManager.queryIntentActivities(webSearch, 0);
        if (resolveInfos == null) {
            return null;
        }
        for (ResolveInfo resolveInfo : resolveInfos) {
            if (resolveInfo == null || resolveInfo.activityInfo == null) {
                continue;
            }
            if (!TextUtils.equals(resolveInfo.activityInfo.packageName, GOOGLE_APP_PACKAGE)) {
                continue;
            }
            Intent intent = new Intent(webSearch)
                    .setComponent(new ComponentName(
                            resolveInfo.activityInfo.packageName,
                            resolveInfo.activityInfo.name
                    ))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            return intent;
        }
        return null;
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
