package com.atv.launcher.systembridge.shared.access;

import android.accessibilityservice.AccessibilityService;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.util.Log;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;

import com.atv.launcher.systembridge.shared.service.SystemBridgeCoordinator;
import com.atv.launcher.systembridge.shared.state.BridgeStateStore;
import com.atv.launcher.systembridge.shared.voice.VoiceKeyHandler;

public class VoiceBridgeAccessibilityService extends AccessibilityService {
    private static final String TAG = "VoiceBridge";

    private final VoiceKeyHandler voiceKeyHandler = new VoiceKeyHandler(TAG, "accessibility");
    private BroadcastReceiver wakeReceiver;

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
    }

    @Override
    public void onInterrupt() {
    }

    @Override
    protected boolean onKeyEvent(KeyEvent event) {
        return voiceKeyHandler.handle(this, event) || super.onKeyEvent(event);
    }

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        Log.i(TAG, "connected process=" + getPackageName()
                + " key=" + BridgeStateStore.getKeyCode(this)
                + " mode=" + BridgeStateStore.getMode(this));
        registerWakeReceiver();
        SystemBridgeCoordinator.startCore(this, "accessibility_connected");
        SystemBridgeCoordinator.scheduleWakeBackstop(this, "accessibility_connected");
    }

    @Override
    public void onDestroy() {
        Log.i(TAG, "destroyed");
        voiceKeyHandler.clearPendingActions();
        unregisterWakeReceiver();
        SystemBridgeCoordinator.startCore(this, "accessibility_destroyed");
        super.onDestroy();
    }

    private void registerWakeReceiver() {
        if (wakeReceiver != null) {
            return;
        }
        wakeReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                String action = intent != null ? intent.getAction() : "wake";
                String resolvedAction = action == null ? "wake" : action;
                String reason = "accessibility_" + resolvedAction;
                if (!SystemBridgeCoordinator.shouldHandleRuntimeTrigger(getApplicationContext(), reason)) {
                    return;
                }
                SystemBridgeCoordinator.startCore(getApplicationContext(), reason);
                SystemBridgeCoordinator.scheduleWakeBackstop(getApplicationContext(), reason);
            }
        };

        IntentFilter filter = new IntentFilter();
        filter.addAction(Intent.ACTION_SCREEN_ON);
        filter.addAction(Intent.ACTION_USER_PRESENT);
        filter.addAction(Intent.ACTION_USER_UNLOCKED);
        filter.addAction(Intent.ACTION_DREAMING_STOPPED);
        filter.addAction("com.xiaomi.mitv.ACTION_SCREEN_ON");
        filter.addAction("com.xiaomi.tv.ACTION_OPEN_CLOSE_SCREEN_SAVER");
        filter.addAction("mitv.action.STR_BOOT_COMPLETED");
        filter.setPriority(999999);

        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(wakeReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            registerReceiver(wakeReceiver, filter);
        }
    }

    private void unregisterWakeReceiver() {
        if (wakeReceiver == null) {
            return;
        }
        try {
            unregisterReceiver(wakeReceiver);
        } catch (Exception ignored) {
        }
        wakeReceiver = null;
    }

}


