package com.atv.launcher.systembridge.shared.voice;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import android.view.KeyEvent;

import com.atv.launcher.systembridge.shared.state.BridgeStateStore;

public final class VoiceKeyHandler {
    private static final long DOUBLE_CLICK_TIMEOUT_MS = 600L;
    private static final long LONG_PRESS_TIMEOUT_MS = 600L;
    private static final long SECOND_HOLD_TIMEOUT_MS = 600L;
    private static final long DOUBLE_TAP_WINDOW_MS = 500L;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private final String tag;
    private final String source;
    private int pressStage;
    private boolean longPressTriggered;
    private boolean secondHoldTriggered;
    private long lastTapUpTime;
    private boolean isSecondPressIgnored;
    private Runnable longPressRunnable;
    private Runnable secondHoldRunnable;
    private Runnable resetRunnable;

    public VoiceKeyHandler(String tag, String source) {
        this.tag = tag;
        this.source = source;
    }

    public boolean handle(Context context, KeyEvent event) {
        int keyCode = event.getKeyCode();
        int action = event.getAction();
        int repeatCount = event.getRepeatCount();

        if (BridgeStateStore.isLearningMode(context)) {
            if (action != KeyEvent.ACTION_DOWN || repeatCount != 0) {
                return true;
            }
            Log.i(tag, source + " learned_key code=" + keyCode);
            BridgeStateStore.setKeyCode(context, keyCode);
            BridgeStateStore.setLearningMode(context, false);
            String name = getKeyFriendlyName(keyCode);
            String msg = "Đã học xong phím " + name;
            try {
                com.atv.launcher.systembridge.tts.VietnameseTtsEngine.getInstance(context).speak(context, msg, null);
                VoiceFloatingOverlayManager.getInstance(context).updateSubtitle(msg, 0xFF00E5FF);
                VoiceFloatingOverlayManager.getInstance(context).scheduleDismiss(2200);
            } catch (Exception ignored) {}
            return true;
        }

        if (!matchesConfiguredKey(context, keyCode)) {
            if (action == KeyEvent.ACTION_DOWN && repeatCount == 0) {
                Log.i(tag, source + " ignored_key code=" + keyCode
                        + " target=" + BridgeStateStore.getKeyCode(context));
            }
            return false;
        }

        int mode = BridgeStateStore.getMode(context);
        if (action == KeyEvent.ACTION_DOWN && repeatCount == 0) {
            Log.i(tag, source + " matched_key code=" + keyCode + " mode=" + mode);
        }
        if (mode == BridgeStateStore.MODE_SINGLE) {
            return handleSinglePress(context, event);
        }
        if (mode == BridgeStateStore.MODE_LONG) {
            return handleLongPress(context, event);
        }
        if (mode == BridgeStateStore.MODE_DOUBLE_HOLD) {
            return handleSecondPressHold(context, event);
        }
        return handleDoublePress(context, event);
    }

    public void clearPendingActions() {
        cancelReset();
        cancelLongPress();
        cancelSecondHold();
        pressStage = 0;
        longPressTriggered = false;
        secondHoldTriggered = false;
        lastTapUpTime = 0L;
        isSecondPressIgnored = false;
    }

    private boolean matchesConfiguredKey(Context context, int keyCode) {
        int targetKeyCode = BridgeStateStore.getKeyCode(context);
        if (targetKeyCode == BridgeStateStore.DEFAULT_KEY_CODE) {
            return BridgeStateStore.isDefaultVoiceKeyCode(keyCode);
        }
        return keyCode == targetKeyCode;
    }

    private boolean handleSinglePress(Context context, KeyEvent event) {
        if (event.getAction() == KeyEvent.ACTION_DOWN && event.getRepeatCount() == 0) {
            Log.i(tag, source + " single_press_launch");
            launchVoice(context);
        }
        return true;
    }

    private boolean handleDoublePress(Context context, KeyEvent event) {
        if (event.getAction() == KeyEvent.ACTION_DOWN && event.getRepeatCount() == 0) {
            if (pressStage == 0) {
                pressStage = 1;
                scheduleReset();
            } else if (pressStage == 1) {
                cancelReset();
                pressStage = 0;
                Log.i(tag, source + " double_press_launch");
                launchVoice(context);
            }
            return true;
        }
        return true;
    }

    private boolean handleLongPress(Context context, KeyEvent event) {
        int action = event.getAction();
        if (action == KeyEvent.ACTION_DOWN && event.getRepeatCount() == 0) {
            cancelLongPress();
            long now = SystemClock.uptimeMillis();
            if (now - lastTapUpTime < DOUBLE_TAP_WINDOW_MS) {
                // Nhấn 2 lần liên tiếp, giữ ở lần 2: Không gọi Voice AI, nhường cho Katniss/Hệ thống
                isSecondPressIgnored = true;
                Log.i(tag, source + " ignored_second_press_hold (reserved for Katniss/System)");
                return false;
            }

            isSecondPressIgnored = false;
            longPressTriggered = false;
            longPressRunnable = () -> {
                longPressTriggered = true;
                Log.i(tag, source + " long_press_launch");
                launchVoice(context);
            };
            handler.postDelayed(longPressRunnable, LONG_PRESS_TIMEOUT_MS);
            return true;
        }
        if (action == KeyEvent.ACTION_UP) {
            cancelLongPress();
            if (!longPressTriggered && !isSecondPressIgnored) {
                lastTapUpTime = SystemClock.uptimeMillis();
            } else {
                lastTapUpTime = 0L;
            }
            longPressTriggered = false;
            isSecondPressIgnored = false;
            return true;
        }
        return true;
    }

    private boolean handleSecondPressHold(Context context, KeyEvent event) {
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
                    Log.i(tag, source + " double_hold_launch");
                    launchVoice(context);
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

    private void launchVoice(Context context) {
        boolean launched = VoiceSearchLauncher.launch(context);
        Log.i(tag, source + " launch_result success=" + launched);
    }

    public static String getKeyFriendlyName(int keyCode) {
        switch (keyCode) {
            case 231: return "Trợ lý Giọng nói (Mic 231)";
            case 84: return "Tìm kiếm (Search 84)";
            case 219: return "Assist (219)";
            case 3: return "Phím Home";
            case 23: return "Phím OK / Center";
            case 82: return "Phím Menu";
            case 170: return "Phím TV / Live / Source";
            case 259: return "Phím Help Sony (259)";
            case 183: return "Phím Màu Đỏ (Red 183)";
            case 184: return "Phím Màu Xanh Lá (Green 184)";
            case 185: return "Phím Màu Vàng (Yellow 185)";
            case 186: return "Phím Màu Xanh Dương (Blue 186)";
            case 187: return "Phím Đa nhiệm (App Switch 187)";
            case 188: return "Phím Bookmark / Custom 1 (188)";
            case 222: return "Phím Audio Track (222)";
            case 229: return "Phím Last Channel (229)";
            case 4: return "Phím Back";
            default: return "KeyCode " + keyCode;
        }
    }
}
