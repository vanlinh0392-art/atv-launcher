package com.atv.launcher.systembridge.shared.control;

public final class VoiceModeControlContract {
    public static final String CORE_PACKAGE = "com.atv.launcher";
    public static final String RECEIVER_CLASS =
            "com.atv.launcher.systembridge.shared.control.VoiceModeControlReceiver";
    public static final String ACTION_GET_MODE = "com.atv.launcher.control.GET_MODE";
    public static final String ACTION_SET_MODE = "com.atv.launcher.control.SET_MODE";
    public static final String EXTRA_MODE = "mode";
    public static final String EXTRA_KEY_CODE = "key_code";
    public static final String EXTRA_STATUS = "status";
    public static final String STATUS_OK = "ok";
    public static final String STATUS_INVALID_MODE = "invalid_mode";
    public static final String STATUS_INVALID_KEY = "invalid_key";

    private VoiceModeControlContract() {
    }
}


