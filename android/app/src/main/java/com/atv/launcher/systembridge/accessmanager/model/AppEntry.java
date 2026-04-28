package com.atv.launcher.systembridge.accessmanager.model;

import android.graphics.drawable.Drawable;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public final class AppEntry {
    public final String packageName;
    public final String label;
    public final boolean systemApp;
    public final boolean launchable;
    public final boolean hasAccessibilityService;
    public final boolean accessibilityEnabled;
    public final boolean managed;
    public final List<String> serviceIds;
    public final Drawable icon;

    public AppEntry(
            String packageName,
            String label,
            boolean systemApp,
            boolean launchable,
            boolean hasAccessibilityService,
            boolean accessibilityEnabled,
            boolean managed,
            List<String> serviceIds,
            Drawable icon
    ) {
        this.packageName = packageName;
        this.label = label;
        this.systemApp = systemApp;
        this.launchable = launchable;
        this.hasAccessibilityService = hasAccessibilityService;
        this.accessibilityEnabled = accessibilityEnabled;
        this.managed = managed;
        this.serviceIds = Collections.unmodifiableList(new ArrayList<>(serviceIds));
        this.icon = icon;
    }
}


