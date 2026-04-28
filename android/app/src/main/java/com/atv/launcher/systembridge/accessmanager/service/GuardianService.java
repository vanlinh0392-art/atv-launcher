package com.atv.launcher.systembridge.accessmanager.service;

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

public class GuardianService extends Service {
    private static final String TAG = "AccessManagerBoot";
    private static final int NOTIFICATION_ID = 0x291;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private BroadcastReceiver wakeReceiver;

    @Override
    public void onCreate() {
        super.onCreate();
        startForeground(NOTIFICATION_ID, buildNotification());
        registerWakeReceiver();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String reason = intent != null ? intent.getStringExtra(AccessibilityGrantCoordinator.EXTRA_REASON) : null;
        String resolvedReason = reason == null ? "service_start" : reason;
        Log.i(TAG, "GuardianService onStartCommand: " + resolvedReason);
        mainHandler.post(() -> AccessibilityGrantCoordinator.ensureManagedAccessibility(getApplicationContext(), resolvedReason));
        return START_STICKY;
    }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        AccessibilityGrantCoordinator.scheduleExactHeal(this, 2000L, "task_removed");
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
        AccessibilityGrantCoordinator.scheduleExactHeal(this, 2000L, "service_destroyed");
        super.onDestroy();
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
                String reason = action == null ? "wake" : "guardian_" + action;
                if (!AccessibilityGrantCoordinator.shouldHandleStartupTrigger(getApplicationContext(), reason)) {
                    return;
                }
                Log.i(TAG, "Wake trigger accepted: " + reason);
                AccessibilityGrantCoordinator.startGuardian(getApplicationContext(), reason);
                AccessibilityGrantCoordinator.scheduleWakeBackstop(getApplicationContext(), reason);
            }
        };

        IntentFilter filter = new IntentFilter();
        filter.addAction(Intent.ACTION_SCREEN_ON);
        filter.addAction(Intent.ACTION_USER_PRESENT);
        filter.addAction(Intent.ACTION_USER_UNLOCKED);
        filter.addAction(Intent.ACTION_DREAMING_STOPPED);
        filter.addAction("com.xiaomi.mitv.ACTION_SCREEN_ON");
        filter.addAction("com.xiaomi.tv.ACTION_OPEN_CLOSE_SCREEN_SAVER");
        filter.setPriority(999999);

        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(wakeReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            registerReceiver(wakeReceiver, filter);
        }
    }

    private Notification buildNotification() {
        NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        String channelId = getPackageName() + ".guardian";
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
                .setSmallIcon(R.drawable.ic_stat_access_manager)
                .setOngoing(true)
                .build();
    }
}


