package com.atv.launcher;

import android.os.Build;
import android.telephony.TelephonyCallback;

import androidx.annotation.RequiresApi;

import java.util.LinkedHashMap;
import java.util.Map;

import io.flutter.plugin.common.EventChannel;

@RequiresApi(api = Build.VERSION_CODES.S)
public class TelephonyCallbackImpl extends TelephonyCallback
        implements TelephonyCallback.DataConnectionStateListener
{
    private final EventChannel.EventSink _eventSink;

    public TelephonyCallbackImpl(EventChannel.EventSink eventSink)
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


