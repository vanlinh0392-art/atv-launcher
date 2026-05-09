package com.atv.launcher;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.net.ConnectivityManager;

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
            ConnectivityManager connectivityManager =
                    (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
            Map<String, Object> networkInformation = NetworkUtils.getNetworkInformation(
                    context,
                    connectivityManager == null ? null : connectivityManager.getActiveNetwork()
            );
            boolean networkAvailable = Boolean.TRUE.equals(
                    networkInformation.get(NetworkUtils.KEY_NETWORK_ACCESS)
            );
            _eventSink.success(eventMap(
                    networkAvailable ? "NETWORK_AVAILABLE" : "NETWORK_UNAVAILABLE",
                    networkAvailable ? networkInformation : null
            ));
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


