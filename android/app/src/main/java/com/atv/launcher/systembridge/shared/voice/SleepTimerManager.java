package com.atv.launcher.systembridge.shared.voice;

import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.atv.launcher.systembridge.shared.access.VoiceBridgeAccessibilityService;

public final class SleepTimerManager {
    private static final String TAG = "SleepTimerManager";
    private static final Handler timerHandler = new Handler(Looper.getMainLooper());
    private static Runnable sleepRunnable = null;
    private static long targetSleepTimeMillis = 0L;
    private static int scheduledMinutes = 0;

    private SleepTimerManager() {
    }

    public static synchronized boolean setSleepTimer(Context context, int minutes) {
        if (minutes <= 0 || minutes > 720) {
            cancelSleepTimer(context);
            return false;
        }

        cancelSleepTimer(context);
        scheduledMinutes = minutes;
        targetSleepTimeMillis = System.currentTimeMillis() + (minutes * 60L * 1000L);

        final Context appContext = context.getApplicationContext();
        sleepRunnable = () -> {
            Log.i(TAG, "Sleep timer expired! Executing TV Sleep / Standby action...");
            performSleep(appContext);
            cancelSleepTimer(appContext);
        };

        timerHandler.postDelayed(sleepRunnable, minutes * 60L * 1000L);
        Log.i(TAG, "Sleep timer scheduled for " + minutes + " minutes (target=" + targetSleepTimeMillis + ")");
        return true;
    }

    public static synchronized void cancelSleepTimer(Context context) {
        if (sleepRunnable != null) {
            timerHandler.removeCallbacks(sleepRunnable);
            sleepRunnable = null;
        }
        targetSleepTimeMillis = 0L;
        scheduledMinutes = 0;
        Log.i(TAG, "Sleep timer cancelled");
    }

    public static synchronized boolean isTimerActive() {
        return sleepRunnable != null && targetSleepTimeMillis > System.currentTimeMillis();
    }

    public static synchronized int getRemainingMinutes() {
        if (!isTimerActive()) return 0;
        long diff = targetSleepTimeMillis - System.currentTimeMillis();
        return Math.max(1, (int) Math.ceil(diff / 60000.0));
    }

    public static synchronized int getScheduledMinutes() {
        return scheduledMinutes;
    }

    private static void performSleep(Context context) {
        new Thread(() -> {
            boolean lockScreenSuccess = false;
            try {
                VoiceBridgeAccessibilityService accessibility = VoiceBridgeAccessibilityService.getInstance();
                if (accessibility != null) {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                        lockScreenSuccess = accessibility.performGlobalAction(
                                android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_LOCK_SCREEN
                        );
                    }
                }
            } catch (Exception e) {
                Log.e(TAG, "Error executing accessibility sleep command", e);
            }
            if (!lockScreenSuccess) {
                try {
                    com.atv.launcher.systembridge.accessmanager.adb.LocalAdbBridge.executeShell(context, "input keyevent 223");
                } catch (Exception e) {
                    Log.e(TAG, "Error executing ADB sleep command", e);
                }
            }
        }, "SleepTimerExecutor").start();
    }
}
