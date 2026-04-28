package com.atv.launcher.systembridge.accessmanager.boot;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;

import com.atv.launcher.systembridge.accessmanager.service.AccessibilityGrantCoordinator;

public class PackageChangeReceiver extends BroadcastReceiver {
    private static final String TAG = "AccessManagerBoot";

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent != null ? intent.getAction() : "package_changed";
        Uri data = intent != null ? intent.getData() : null;
        String packageName = data != null ? data.getSchemeSpecificPart() : "";
        String reason = packageName == null || packageName.isEmpty()
                ? action
                : action + ":" + packageName;
        Context appContext = context.getApplicationContext();
        if (!AccessibilityGrantCoordinator.shouldHandleStartupTrigger(appContext, reason)) {
            return;
        }
        Log.i(TAG, "Package trigger accepted: " + reason);
        AccessibilityGrantCoordinator.startGuardian(appContext, reason);
        AccessibilityGrantCoordinator.scheduleWakeBackstop(appContext, reason);
    }
}


