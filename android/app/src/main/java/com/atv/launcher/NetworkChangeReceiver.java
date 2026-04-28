package com.atv.launcher;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;

import java.util.LinkedHashMap;
import java.util.Map;

import io.flutter.plugin.common.EventChannel;

public class NetworkChangeReceiver extends BroadcastReceiver
{
    private final EventChannel.EventSink _eventSink;

    public NetworkChangeReceiver(EventChannel.EventSink eventSink)
    {
        _eventSink = eventSink;
    }

    @Override
    public void onReceive(Context context, Intent intent)
    {
        boolean noConnectivity = intent.getBooleanExtra(ConnectivityManager.EXTRA_NO_CONNECTIVITY, false);

        if (noConnectivity) {
            _eventSink.success(eventMap("NETWORK_UNAVAILABLE", null));
        }
        else {
            //noinspection deprecation
            NetworkInfo networkInfo = intent.getParcelableExtra(ConnectivityManager.EXTRA_NETWORK_INFO);
            _eventSink.success(eventMap("NETWORK_AVAILABLE", NetworkUtils.getNetworkInformation(context, networkInfo)));
        }
    }

    private Map<String, Object> eventMap(String name, Object arguments)
    {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("name", name);
        if (arguments != null) {
            map.put("arguments", arguments);
        }
        return map;
    }
}


