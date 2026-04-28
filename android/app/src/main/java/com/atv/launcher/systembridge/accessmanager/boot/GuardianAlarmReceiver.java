package com.atv.launcher.systembridge.accessmanager.boot;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import com.atv.launcher.systembridge.accessmanager.service.AccessibilityGrantCoordinator;

public class GuardianAlarmReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        String reason = intent != null
                ? intent.getStringExtra(AccessibilityGrantCoordinator.EXTRA_REASON)
                : null;
        AccessibilityGrantCoordinator.startGuardian(context, reason == null ? "alarm" : reason);
    }
}


