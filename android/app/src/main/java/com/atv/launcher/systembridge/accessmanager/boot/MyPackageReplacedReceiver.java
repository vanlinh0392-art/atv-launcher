package com.atv.launcher.systembridge.accessmanager.boot;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import com.atv.launcher.systembridge.accessmanager.service.AccessibilityGrantCoordinator;

public class MyPackageReplacedReceiver extends BroadcastReceiver {
    private static final String TAG = "AccessManagerBoot";

    @Override
    public void onReceive(Context context, Intent intent) {
        Context appContext = context.getApplicationContext();
        String reason = "my_package_replaced";
        if (!AccessibilityGrantCoordinator.shouldHandleStartupTrigger(appContext, reason)) {
            return;
        }
        Log.i(TAG, "Package replaced trigger accepted");
        AccessibilityGrantCoordinator.startGuardian(appContext, reason);
        AccessibilityGrantCoordinator.scheduleWakeBackstop(appContext, reason);
    }
}


