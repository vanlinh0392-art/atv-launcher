package com.atv.launcher.systembridge.shared.boot;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import com.atv.launcher.systembridge.shared.service.SystemBridgeCoordinator;

public class BootOrRecoverReceiver extends BroadcastReceiver {
    private static final String TAG = "SystemBridgeCore";

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent != null ? intent.getAction() : "boot";
        Context appContext = context.getApplicationContext();
        PendingResult pendingResult = goAsync();
        Thread worker = new Thread(() -> {
            try {
                if (!SystemBridgeCoordinator.shouldHandleRuntimeTrigger(appContext, action)) {
                    return;
                }
                Log.i(TAG, "Boot/recover trigger accepted: " + action);
                SystemBridgeCoordinator.kickAccessManager(appContext, action);
                SystemBridgeCoordinator.startCore(appContext, action);
                SystemBridgeCoordinator.scheduleWakeBackstop(appContext, action);
            } finally {
                pendingResult.finish();
            }
        }, "systembridge-boot");
        worker.start();
    }
}


