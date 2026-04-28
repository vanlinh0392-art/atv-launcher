package com.atv.launcher.systembridge.shared.boot;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import com.atv.launcher.systembridge.shared.service.SystemBridgeCoordinator;

public class HealAlarmReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        String reason = intent != null ? intent.getStringExtra(SystemBridgeCoordinator.EXTRA_REASON) : null;
        SystemBridgeCoordinator.startCore(context, reason == null ? "alarm" : reason);
    }
}



