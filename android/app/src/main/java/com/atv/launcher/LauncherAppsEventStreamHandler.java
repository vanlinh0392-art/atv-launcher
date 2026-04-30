package com.atv.launcher;

import android.content.Context;
import android.content.pm.LauncherApps;
import android.os.UserHandle;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.EventChannel;

public class LauncherAppsEventStreamHandler implements EventChannel.StreamHandler
{
    private final LauncherApps _launcherApps;
    private final Context _context;

    private LauncherApps.Callback _launcherAppsCallback;

    public LauncherAppsEventStreamHandler(Context context)
    {
        _context = context.getApplicationContext();
        _launcherApps = (LauncherApps) _context.getSystemService(Context.LAUNCHER_APPS_SERVICE);
    }

    @Override
    public void onCancel(Object arguments)
    {
        _launcherApps.unregisterCallback(_launcherAppsCallback);
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events)
    {
        _launcherAppsCallback = new LauncherAppsCallback(events);
        _launcherApps.registerCallback(_launcherAppsCallback);
    }


    private class LauncherAppsCallback extends LauncherApps.Callback
    {
        private final EventChannel.EventSink _eventSink;

        public LauncherAppsCallback(EventChannel.EventSink eventSink)
        {
            _eventSink = eventSink;
        }

        @Override
        public void onPackageRemoved(String packageName, UserHandle user) {
            MainActivity.clearAppImageCacheForPackage(packageName);
            _eventSink.success(eventMap("PACKAGE_REMOVED", packageName, null, null));
        }

        @Override
        public void onPackageAdded(String packageName, UserHandle user) {
            MainActivity.clearAppImageCacheForPackage(packageName);
            Map<String, Serializable> application =
                    MainActivity.getApplicationForPackage(_context, packageName);

            if (!application.isEmpty()) {
                _eventSink.success(eventMap("PACKAGE_ADDED", null, application, null));
            }
        }

        @Override
        public void onPackageChanged(String packageName, UserHandle user) {
            MainActivity.clearAppImageCacheForPackage(packageName);
            Map<String, Serializable> application =
                    MainActivity.getApplicationForPackage(_context, packageName);

            if (!application.isEmpty()) {
                _eventSink.success(eventMap("PACKAGE_CHANGED", null, application, null));
            }
        }

        @Override
        public void onPackagesAvailable(String[] packageNames, UserHandle user, boolean replacing) {
            List<Map<String, Serializable>> applications = new ArrayList<>(packageNames.length);

            for (String name : packageNames) {
                MainActivity.clearAppImageCacheForPackage(name);
                Map<String, Serializable> application =
                        MainActivity.getApplicationForPackage(_context, name);

                if (!application.isEmpty()) {
                    applications.add(application);
                }
            }

            if (!applications.isEmpty()) {
                _eventSink.success(eventMap("PACKAGES_AVAILABLE", null, null, applications));
            }
        }

        @Override
        public void onPackagesUnavailable(String[] packageNames, UserHandle user, boolean replacing) {
        }

        private Map<String, Object> eventMap(
                String action,
                String packageName,
                Map<String, Serializable> activityInfo,
                List<Map<String, Serializable>> activitiesInfo
        ) {
            Map<String, Object> map = new LinkedHashMap<>();
            map.put("action", action);
            if (packageName != null) {
                map.put("packageName", packageName);
            }
            if (activityInfo != null) {
                map.put("activityInfo", activityInfo);
            }
            if (activitiesInfo != null) {
                map.put("activitiesInfo", activitiesInfo);
            }
            return map;
        }
    }
}


