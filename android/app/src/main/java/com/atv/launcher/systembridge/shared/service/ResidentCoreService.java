package com.atv.launcher.systembridge.shared.service;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;

import com.atv.launcher.R;

public class ResidentCoreService extends Service {
    private static final String TAG = "SystemBridgeCore";
    private static final int NOTIFICATION_ID = 0x181;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private static final java.util.concurrent.ExecutorService BACKGROUND_EXECUTOR =
            java.util.concurrent.Executors.newSingleThreadExecutor();
    private BroadcastReceiver wakeReceiver;

    @Override
    public void onCreate() {
        super.onCreate();
        startForeground(NOTIFICATION_ID, buildNotification());
        registerWakeReceiver();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String reason = intent != null ? intent.getStringExtra(SystemBridgeCoordinator.EXTRA_REASON) : null;
        String resolvedReason = reason == null ? "service_start" : reason;
        boolean allowToast = reason == null || !reason.startsWith("silent_launcher_tap");
        Log.i(TAG, "ResidentCoreService onStartCommand: " + resolvedReason);
        BACKGROUND_EXECUTOR.execute(() -> SystemBridgeCoordinator.ensureSystemState(getApplicationContext(), resolvedReason, allowToast));
        return START_STICKY;
    }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        SystemBridgeCoordinator.scheduleExactHeal(this, 2000L, "task_removed");
        super.onTaskRemoved(rootIntent);
    }

    @Override
    public void onDestroy() {
        if (wakeReceiver != null) {
            try {
                unregisterReceiver(wakeReceiver);
            } catch (Exception ignored) {
            }
        }
        SystemBridgeCoordinator.scheduleExactHeal(this, 2000L, "service_destroyed");
        super.onDestroy();
    }

    @Override
    public void onTrimMemory(int level) {
        super.onTrimMemory(level);
        if (level >= TRIM_MEMORY_RUNNING_CRITICAL || level >= TRIM_MEMORY_COMPLETE) {
            System.gc();
        }
    }

    @Override
    public void onLowMemory() {
        super.onLowMemory();
        System.gc();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
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
                if (isSleepAction(resolvedAction)) {
                    SystemBridgeCoordinator.handleSleepTransition(context, resolvedAction);
                    return;
                }
                if (!SystemBridgeCoordinator.shouldHandleRuntimeTrigger(context, resolvedAction)) {
                    return;
                }
                Log.i(TAG, "Wake trigger accepted: " + resolvedAction);
                SystemBridgeCoordinator.kickAccessManager(context, resolvedAction);
                SystemBridgeCoordinator.startCore(context, resolvedAction);
                SystemBridgeCoordinator.scheduleWakeBackstop(context, resolvedAction);
            }
        };

        IntentFilter filter = new IntentFilter();
        filter.addAction(Intent.ACTION_SCREEN_ON);
        filter.addAction(Intent.ACTION_SCREEN_OFF);
        filter.addAction(Intent.ACTION_USER_PRESENT);
        filter.addAction(Intent.ACTION_USER_UNLOCKED);
        filter.addAction(Intent.ACTION_DREAMING_STARTED);
        filter.addAction(Intent.ACTION_DREAMING_STOPPED);
        filter.addAction("android.intent.action.SCREEN_ON");
        filter.addAction("android.intent.action.SCREEN_OFF");
        filter.addAction("com.xiaomi.mitv.ACTION_SCREEN_ON");
        filter.addAction("com.xiaomi.mitv.ACTION_SCREEN_OFF");
        filter.addAction("com.xiaomi.tv.ACTION_OPEN_CLOSE_SCREEN_SAVER");
        filter.addAction("mitv.action.STR_BOOT_COMPLETED");
        filter.addAction("com.tcl.tv.action.SCREEN_ON");
        filter.addAction("com.tcl.tv.action.SCREEN_OFF");
        filter.addAction("com.sony.dtv.intent.action.PANEL_ON");
        filter.addAction("com.sony.dtv.intent.action.PANEL_OFF");
        filter.addAction("com.hisense.tv.action.PANEL_ON");
        filter.addAction("com.hisense.tv.action.PANEL_OFF");
        filter.setPriority(999999);

        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(wakeReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            registerReceiver(wakeReceiver, filter);
        }
    }

    private static boolean isSleepAction(String action) {
        return Intent.ACTION_SCREEN_OFF.equals(action)
                || Intent.ACTION_DREAMING_STARTED.equals(action)
                || "android.intent.action.SCREEN_OFF".equals(action)
                || "com.sony.dtv.intent.action.PANEL_OFF".equals(action)
                || "com.tcl.tv.action.SCREEN_OFF".equals(action)
                || "com.hisense.tv.action.PANEL_OFF".equals(action)
                || "com.xiaomi.mitv.ACTION_SCREEN_OFF".equals(action);
    }

    private Notification buildNotification() {
        NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        String channelId = getPackageName() + ".channel";
        if (manager != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    channelId,
                    getString(R.string.notification_channel_name),
                    NotificationManager.IMPORTANCE_MIN
            );
            channel.setDescription(getString(R.string.notification_channel_description));
            channel.setShowBadge(false);
            manager.createNotificationChannel(channel);
        }

        Notification.Builder builder = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? new Notification.Builder(this, channelId)
                : new Notification.Builder(this);

        return builder
                .setContentTitle(getString(R.string.app_name))
                .setContentText(getString(R.string.notification_text))
                .setSmallIcon(R.drawable.ic_stat_bridge)
                .setOngoing(true)
                .build();
    }
}


