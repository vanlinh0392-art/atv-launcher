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

    private static volatile java.lang.ref.WeakReference<VoiceBridgeAccessibilityService> sServiceRef;
    private static volatile String currentForegroundPackage = "com.atv.launcher";
    private static final java.util.Set<String> IGNORED_PACKAGES = new java.util.HashSet<>(java.util.Arrays.asList(
            "com.android.systemui",
            "com.google.android.inputmethod.latin",
            "android"
    ));
    private final VoiceKeyHandler voiceKeyHandler = new VoiceKeyHandler(TAG, "accessibility");
    private BroadcastReceiver wakeReceiver;

    public static VoiceBridgeAccessibilityService getInstance() {
        return sServiceRef != null ? sServiceRef.get() : null;
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        if (event != null && event.getEventType() == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            CharSequence pkg = event.getPackageName();
            if (pkg != null && pkg.length() > 0) {
                String pkgStr = pkg.toString();
                if (!IGNORED_PACKAGES.contains(pkgStr) && !pkgStr.contains("inputmethod")) {
                    currentForegroundPackage = pkgStr;
                }
            }
        }
    }

    public static boolean isLauncherForeground(Context context) {
        return context.getPackageName().equals(currentForegroundPackage);
    }

    @Override
    public void onInterrupt() {
    }

    @Override
    protected boolean onKeyEvent(KeyEvent event) {
        if (event != null && event.getAction() == KeyEvent.ACTION_DOWN) {
            int keyCode = event.getKeyCode();
            if (keyCode == KeyEvent.KEYCODE_BACK || keyCode == KeyEvent.KEYCODE_HOME) {
                if (com.atv.launcher.systembridge.shared.voice.VoiceFloatingOverlayManager.isOverlayShowing()
                        || com.atv.launcher.systembridge.tts.VietnameseTtsEngine.isSpeakingAny()) {
                    Log.i(TAG, "BACK/HOME intercepted during Voice/TTS active - dismissing voice & stopping TTS");
                    try {
                        com.atv.launcher.systembridge.tts.VietnameseTtsEngine.getInstance(this).stop();
                    } catch (Exception ignored) {}
                    try {
                        com.atv.launcher.systembridge.shared.voice.VoiceFloatingOverlayManager.getInstance(this).dismiss();
                    } catch (Exception ignored) {}
                    try {
                        com.atv.launcher.systembridge.shared.voice.VoiceCaptureTransparentActivity activity =
                                com.atv.launcher.systembridge.shared.voice.VoiceCaptureTransparentActivity.getActiveInstance();
                        if (activity != null) {
                            activity.finish();
                        }
                    } catch (Exception ignored) {}
                    if (keyCode == KeyEvent.KEYCODE_BACK) {
                        return true;
                    }
                }
            }
        }
        return voiceKeyHandler.handle(this, event) || super.onKeyEvent(event);
    }

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        sServiceRef = new java.lang.ref.WeakReference<>(this);
        Log.i(TAG, "connected process=" + getPackageName()
                + " key=" + BridgeStateStore.getKeyCode(this)
                + " mode=" + BridgeStateStore.getMode(this));
        com.atv.launcher.systembridge.shared.voice.VoiceFloatingOverlayManager.setAccessibilityService(this);
        registerWakeReceiver();
        SystemBridgeCoordinator.startCore(this, "accessibility_connected");
        SystemBridgeCoordinator.scheduleWakeBackstop(this, "accessibility_connected");
    }

    @Override
    public boolean onUnbind(Intent intent) {
        cleanupService();
        return super.onUnbind(intent);
    }

    @Override
    public void onDestroy() {
        Log.i(TAG, "destroyed");
        cleanupService();
        SystemBridgeCoordinator.startCore(this, "accessibility_destroyed");
        super.onDestroy();
    }

    private void cleanupService() {
        sServiceRef = null;
        com.atv.launcher.systembridge.shared.voice.VoiceFloatingOverlayManager.setAccessibilityService(null);
        voiceKeyHandler.clearPendingActions();
        unregisterWakeReceiver();
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


