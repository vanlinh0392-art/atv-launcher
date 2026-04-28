package com.atv.launcher;

import android.telephony.PhoneStateListener;

import java.util.LinkedHashMap;
import java.util.Map;

import io.flutter.plugin.common.EventChannel;

public class PhoneStateListenerImpl extends PhoneStateListener
{
    private final EventChannel.EventSink _eventSink;

    public  PhoneStateListenerImpl(EventChannel.EventSink eventSink)
    {
        _eventSink = eventSink;
    }

    @Override
    public void onDataConnectionStateChanged(int state, int networkType)
    {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("name", "CELLULAR_STATE_CHANGED");
        map.put("arguments", networkType);
        _eventSink.success(map);
    }
}


