package com.atv.launcher.systembridge.density;

import android.content.Context;

import java.util.LinkedHashMap;
import java.util.Map;

public final class DensityBridge {
    private DensityBridge() {
    }

    public static Map<String, Object> getStatus(Context context) {
        DensityController.Snapshot snapshot = DensityController.loadSnapshot(context);
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("currentDensity", snapshot.currentDensity);
        map.put("factoryDensity", snapshot.factoryDensity);
        map.put("overrideDensity", snapshot.overrideDensity);
        map.put("hasWriteSecureSettings", snapshot.hasWriteSecureSettings);
        map.put("rootAvailable", snapshot.rootAvailable);
        map.put("executionPath", snapshot.executionSummary);
        return map;
    }

    public static Map<String, Object> applyDensity(Context context, int density) {
        return actionResultToMap(DensityController.applyDensity(context, density));
    }

    public static Map<String, Object> resetDensity(Context context) {
        return actionResultToMap(DensityController.resetDensity(context));
    }

    private static Map<String, Object> actionResultToMap(DensityController.ActionResult actionResult) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("success", actionResult.success);
        map.put("message", actionResult.message);
        if (actionResult.snapshot != null) {
            map.putAll(getStatusFromSnapshot(actionResult.snapshot));
        }
        return map;
    }

    private static Map<String, Object> getStatusFromSnapshot(DensityController.Snapshot snapshot) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("currentDensity", snapshot.currentDensity);
        map.put("factoryDensity", snapshot.factoryDensity);
        map.put("overrideDensity", snapshot.overrideDensity);
        map.put("hasWriteSecureSettings", snapshot.hasWriteSecureSettings);
        map.put("rootAvailable", snapshot.rootAvailable);
        map.put("executionPath", snapshot.executionSummary);
        return map;
    }
}
