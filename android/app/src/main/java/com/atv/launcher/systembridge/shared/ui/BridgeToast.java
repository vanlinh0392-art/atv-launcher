package com.atv.launcher.systembridge.shared.ui;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.TextView;
import android.widget.Toast;

import com.atv.launcher.R;
import com.atv.launcher.systembridge.shared.state.BridgeStateStore;

public final class BridgeToast {
    private static final long COOLDOWN_MS = 8000L;

    private BridgeToast() {
    }

    public static void showState(Context context, String message) {
        if (TextUtils.isEmpty(message)) {
            return;
        }

        Context appContext = context.getApplicationContext();
        long now = System.currentTimeMillis();
        long lastAt = BridgeStateStore.getToastTimestamp(appContext, message);
        if (now - lastAt < COOLDOWN_MS) {
            return;
        }
        BridgeStateStore.setToastTimestamp(appContext, message, now);

        Handler handler = new Handler(Looper.getMainLooper());
        handler.post(() -> {
            LayoutInflater inflater = LayoutInflater.from(appContext);
            View view = inflater.inflate(R.layout.toast_state, null, false);
            TextView textView = view.findViewById(R.id.toast_text);
            textView.setText(message);

            Toast toast = new Toast(appContext);
            toast.setView(view);
            toast.setDuration(Toast.LENGTH_SHORT);
            toast.setGravity(Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL, 0, dp(appContext, 28));
            toast.show();
        });
    }

    private static int dp(Context context, int value) {
        float density = context.getResources().getDisplayMetrics().density;
        return Math.round(value * density);
    }
}



