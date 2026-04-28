package com.atv.launcher.systembridge.accessmanager.boot;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import com.atv.launcher.systembridge.accessmanager.service.AccessibilityGrantCoordinator;

public class BootReceiver extends BroadcastReceiver {
    private static final String TAG = "AccessManagerBoot";

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent != null ? intent.getAction() : "boot";
        Context appContext = context.getApplicationContext();
        if (!AccessibilityGrantCoordinator.shouldHandleStartupTrigger(appContext, action)) {
            return;
        }
        Log.i(TAG, "Boot trigger accepted: " + action);
        AccessibilityGrantCoordinator.startGuardian(appContext, action);
        AccessibilityGrantCoordinator.scheduleWakeBackstop(appContext, action);
    }
}


