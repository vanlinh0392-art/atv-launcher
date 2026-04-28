package com.atv.launcher.systembridge.accessmanager.boot;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.text.TextUtils;
import android.util.Log;

import com.atv.launcher.systembridge.accessmanager.service.AccessibilityGrantCoordinator;

public class RecoveryKickReceiver extends BroadcastReceiver {
    private static final String TAG = "AccessManagerBoot";

    @Override
    public void onReceive(Context context, Intent intent) {
        Context appContext = context.getApplicationContext();
        String requestedReason = intent != null
                ? intent.getStringExtra(AccessibilityGrantCoordinator.EXTRA_REASON)
                : null;
        String kickReason = TextUtils.isEmpty(requestedReason) ? "core_kick" : requestedReason.trim();
        String resolvedReason = "core_kick:" + kickReason;
        if (!AccessibilityGrantCoordinator.shouldHandleStartupTrigger(appContext, resolvedReason)) {
            return;
        }
        Log.i(TAG, "Recovery kick accepted: " + resolvedReason);
        AccessibilityGrantCoordinator.startGuardian(appContext, resolvedReason);
        AccessibilityGrantCoordinator.scheduleWakeBackstop(appContext, resolvedReason);
    }
}


