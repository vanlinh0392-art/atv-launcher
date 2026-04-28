package com.atv.launcher.systembridge.shared.admin;

import android.app.admin.DeviceAdminReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;

import com.atv.launcher.systembridge.shared.service.SystemBridgeCoordinator;

public class MapVoiceAdminReceiver extends DeviceAdminReceiver {
    public static ComponentName component(Context context) {
        return new ComponentName(context, MapVoiceAdminReceiver.class);
    }

    @Override
    public void onEnabled(Context context, Intent intent) {
        SystemBridgeCoordinator.startCore(context, "admin_enabled");
    }

    @Override
    public void onProfileProvisioningComplete(Context context, Intent intent) {
        SystemBridgeCoordinator.startCore(context, "provisioning_complete");
    }
}



