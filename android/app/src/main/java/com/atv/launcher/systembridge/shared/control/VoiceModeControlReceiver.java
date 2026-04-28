package com.atv.launcher.systembridge.shared.control;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.text.TextUtils;

import com.atv.launcher.systembridge.shared.service.SystemBridgeCoordinator;
import com.atv.launcher.systembridge.shared.state.BridgeStateStore;

public class VoiceModeControlReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent != null ? intent.getAction() : null;
        if (TextUtils.equals(action, VoiceModeControlContract.ACTION_GET_MODE)) {
            respondWithConfig(context, Activity.RESULT_OK, VoiceModeControlContract.STATUS_OK);
            return;
        }
        if (TextUtils.equals(action, VoiceModeControlContract.ACTION_SET_MODE)) {
            int mode = intent.getIntExtra(VoiceModeControlContract.EXTRA_MODE, Integer.MIN_VALUE);
            if (!isSupportedMode(mode)) {
                respondWithConfig(context, Activity.RESULT_CANCELED, VoiceModeControlContract.STATUS_INVALID_MODE);
                return;
            }
            int keyCode = intent.getIntExtra(
                    VoiceModeControlContract.EXTRA_KEY_CODE,
                    BridgeStateStore.getKeyCode(context)
            );
            if (keyCode < 0) {
                respondWithConfig(context, Activity.RESULT_CANCELED, VoiceModeControlContract.STATUS_INVALID_KEY);
                return;
            }
            BridgeStateStore.setMode(context, mode);
            BridgeStateStore.setKeyCode(context, keyCode);
            BridgeStateStore.setLearningMode(context, false);
            SystemBridgeCoordinator.startCore(context, "external_config_update");
            respondWithConfig(context, Activity.RESULT_OK, VoiceModeControlContract.STATUS_OK);
        }
    }

    private void respondWithConfig(Context context, int resultCode, String status) {
        Bundle result = getResultExtras(true);
        int mode = BridgeStateStore.getMode(context);
        int keyCode = BridgeStateStore.getKeyCode(context);
        result.putInt(VoiceModeControlContract.EXTRA_MODE, mode);
        result.putInt(VoiceModeControlContract.EXTRA_KEY_CODE, keyCode);
        result.putString(VoiceModeControlContract.EXTRA_STATUS, status);
        setResultData("status=" + status + " mode=" + mode + " key=" + keyCode);
        setResult(resultCode, null, result);
    }

    private boolean isSupportedMode(int mode) {
        return mode == BridgeStateStore.MODE_DOUBLE
                || mode == BridgeStateStore.MODE_SINGLE
                || mode == BridgeStateStore.MODE_LONG
                || mode == BridgeStateStore.MODE_DOUBLE_HOLD;
    }
}


