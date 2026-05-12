package com.atv.launcher.systembridge.shared.access;

import android.accessibilityservice.AccessibilityService;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;

import com.atv.launcher.systembridge.shared.service.SystemBridgeCoordinator;
import com.atv.launcher.systembridge.shared.state.BridgeStateStore;
import com.atv.launcher.systembridge.shared.voice.VoiceSearchLauncher;

public class VoiceBridgeAccessibilityService extends AccessibilityService {
    private static final long DOUBLE_CLICK_TIMEOUT_MS = 600L;
    private static final long LONG_PRESS_TIMEOUT_MS = 600L;
    private static final long SECOND_HOLD_TIMEOUT_MS = 600L;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private BroadcastReceiver wakeReceiver;
    private int pressStage;
    private boolean longPressTriggered;
    private boolean secondHoldTriggered;
    private Runnable longPressRunnable;
    private Runnable secondHoldRunnable;
    private Runnable resetRunnable;

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
    }

    @Override
    public void onInterrupt() {
    }

    @Override
    protected boolean onKeyEvent(KeyEvent event) {
        int keyCode = event.getKeyCode();
        int action = event.getAction();

        if (BridgeStateStore.isLearningMode(this)) {
            if (action != KeyEvent.ACTION_DOWN || event.getRepeatCount() != 0) {
                return true;
            }
            BridgeStateStore.setKeyCode(this, keyCode);
            BridgeStateStore.setLearningMode(this, false);
            return true;
        }

        if (!matchesConfiguredKey(keyCode)) {
            return super.onKeyEvent(event);
        }

        int mode = BridgeStateStore.getMode(this);
        if (mode == BridgeStateStore.MODE_SINGLE) {
            return handleSinglePress(event);
        }
        if (mode == BridgeStateStore.MODE_LONG) {
            return handleLongPress(event);
        }
        if (mode == BridgeStateStore.MODE_DOUBLE_HOLD) {
            return handleSecondPressHold(event);
        }
        return handleDoublePress(event);
    }

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        registerWakeReceiver();
        SystemBridgeCoordinator.startCore(this, "accessibility_connected");
        SystemBridgeCoordinator.scheduleWakeBackstop(this, "accessibility_connected");
    }

    @Override
    public void onDestroy() {
        clearPendingActions();
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

    private boolean matchesConfiguredKey(int keyCode) {
        int targetKeyCode = BridgeStateStore.getKeyCode(this);
        if (targetKeyCode == BridgeStateStore.DEFAULT_KEY_CODE) {
            return BridgeStateStore.isDefaultVoiceKeyCode(keyCode);
        }
        return keyCode == targetKeyCode;
    }

    private boolean handleSinglePress(KeyEvent event) {
        if (event.getAction() == KeyEvent.ACTION_DOWN && event.getRepeatCount() == 0) {
            launchVoice();
        }
        return true;
    }

    private boolean handleDoublePress(KeyEvent event) {
        if (event.getAction() == KeyEvent.ACTION_DOWN && event.getRepeatCount() == 0) {
            if (pressStage == 0) {
                pressStage = 1;
                scheduleReset();
            } else if (pressStage == 1) {
                cancelReset();
                pressStage = 0;
                launchVoice();
            }
            return true;
        }
        return true;
    }

    private boolean handleLongPress(KeyEvent event) {
        if (event.getAction() == KeyEvent.ACTION_DOWN && event.getRepeatCount() == 0) {
            cancelLongPress();
            longPressTriggered = false;
            longPressRunnable = () -> {
                longPressTriggered = true;
                launchVoice();
            };
            handler.postDelayed(longPressRunnable, LONG_PRESS_TIMEOUT_MS);
            return true;
        }
        if (event.getAction() == KeyEvent.ACTION_UP) {
            cancelLongPress();
            longPressTriggered = false;
        }
        return true;
    }

    private boolean handleSecondPressHold(KeyEvent event) {
        int action = event.getAction();
        if (action == KeyEvent.ACTION_DOWN && event.getRepeatCount() == 0) {
            if (pressStage == 0) {
                pressStage = 1;
                scheduleReset();
            } else if (pressStage == 1) {
                cancelReset();
                pressStage = 2;
                secondHoldTriggered = false;
                secondHoldRunnable = () -> {
                    secondHoldTriggered = true;
                    pressStage = 0;
                    launchVoice();
                };
                handler.postDelayed(secondHoldRunnable, SECOND_HOLD_TIMEOUT_MS);
            }
            return true;
        }
        if (action == KeyEvent.ACTION_UP) {
            if (pressStage == 2) {
                cancelSecondHold();
                if (!secondHoldTriggered) {
                    pressStage = 0;
                }
                secondHoldTriggered = false;
            }
            return true;
        }
        return true;
    }

    private void scheduleReset() {
        cancelReset();
        resetRunnable = () -> pressStage = 0;
        handler.postDelayed(resetRunnable, DOUBLE_CLICK_TIMEOUT_MS);
    }

    private void cancelReset() {
        if (resetRunnable != null) {
            handler.removeCallbacks(resetRunnable);
            resetRunnable = null;
        }
    }

    private void cancelLongPress() {
        if (longPressRunnable != null) {
            handler.removeCallbacks(longPressRunnable);
            longPressRunnable = null;
        }
    }

    private void cancelSecondHold() {
        if (secondHoldRunnable != null) {
            handler.removeCallbacks(secondHoldRunnable);
            secondHoldRunnable = null;
        }
    }

    private void clearPendingActions() {
        cancelReset();
        cancelLongPress();
        cancelSecondHold();
        pressStage = 0;
        longPressTriggered = false;
        secondHoldTriggered = false;
    }

    private void launchVoice() {
        VoiceSearchLauncher.launch(this);
    }
}


