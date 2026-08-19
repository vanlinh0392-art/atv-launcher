package com.atv.launcher.systembridge.shared.voice;

import android.accessibilityservice.AccessibilityService;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.media.AudioManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.text.TextUtils;
import android.util.Log;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.atv.launcher.systembridge.tts.VietnameseTtsEngine;

import java.util.ArrayList;
import java.util.Map;

public final class VoiceFloatingOverlayManager {
    private static final String TAG = "VoiceFloatingOverlay";

    private static volatile VoiceFloatingOverlayManager instance;
    private static volatile AccessibilityService accessibilityServiceInstance;

    public static void setAccessibilityService(AccessibilityService service) {
        accessibilityServiceInstance = service;
        Log.i(TAG, "setAccessibilityService: " + (service != null));
    }

    private final Context context;
    private final AudioManager audioManager;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private View overlayView;
    private TextView subtitleTextView;
    private AuroraWaveformView waveformView;

    private SpeechRecognizer speechRecognizer;
    private boolean isListening = false;
    private Runnable dismissRunnable;

    private final AudioManager.OnAudioFocusChangeListener audioFocusListener = focusChange -> {
        Log.i(TAG, "Audio focus changed: " + focusChange);
    };

    private VoiceFloatingOverlayManager(Context context) {
        this.context = context.getApplicationContext();
        this.audioManager = (AudioManager) this.context.getSystemService(Context.AUDIO_SERVICE);
    }

    public static boolean isOverlayShowing() {
        return instance != null && instance.overlayView != null;
    }

    public static VoiceFloatingOverlayManager getInstance(Context context) {
        if (instance == null) {
            synchronized (VoiceFloatingOverlayManager.class) {
                if (instance == null) {
                    instance = new VoiceFloatingOverlayManager(context);
                }
            }
        }
        return instance;
    }

    public void showAndListen() {
        mainHandler.post(() -> {
            try {
                // 1. Dừng TTS nếu đang phát
                VietnameseTtsEngine.getInstance(context).stop();

                // 2. Duck audio (hạ nhỏ âm lượng video/nhạc đang phát)
                abandonAudioDucking();
                requestAudioDucking();

                // 3. Tạo hoặc hiển thị Floating Overlay trong suốt
                createAndAttachOverlay();

                // 4. Cập nhật trạng thái 'Đang nghe...'
                updateSubtitle("Đang nghe...", 0xFF00E5FF);
                if (waveformView != null) {
                    waveformView.setTtsMode(false);
                    waveformView.startAnimation();
                }

                // 5. Bắt đầu thu âm in-process
                startInProcessSpeechRecognition();
            } catch (Exception e) {
                Log.e(TAG, "showAndListen error", e);
                abandonAudioDucking();
            }
        });
    }

    public void startTtsWaveform() {
        mainHandler.post(() -> {
            if (waveformView != null) {
                waveformView.setTtsMode(true);
            }
        });
    }

    public void stopTtsWaveform() {
        mainHandler.post(() -> {
            if (waveformView != null) {
                waveformView.setTtsMode(false);
                waveformView.stopAnimation();
            }
        });
    }

    private void requestAudioDucking() {
        if (audioManager != null) {
            try {
                audioManager.requestAudioFocus(
                        audioFocusListener,
                        AudioManager.STREAM_MUSIC,
                        AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
                );
                Log.i(TAG, "Audio ducking activated");
            } catch (Exception e) {
                Log.w(TAG, "Cannot duck audio", e);
            }
        }
    }

    private void abandonAudioDucking() {
        if (audioManager != null) {
            try {
                audioManager.abandonAudioFocus(audioFocusListener);
                Log.i(TAG, "Audio ducking abandoned, volume restored");
            } catch (Exception e) {
                Log.w(TAG, "Cannot abandon audio ducking", e);
            }
        }
    }

    private void createAndAttachOverlay() {
        if (overlayView != null) {
            cancelDismissTimer();
            overlayView.setVisibility(View.VISIBLE);
            return;
        }

        FrameLayout root = new FrameLayout(context);
        root.setBackgroundColor(Color.TRANSPARENT);

        // Khung viên thuốc kính mờ bo tròn (Frosted Glass Pill) sang trọng
        LinearLayout barLayout = new LinearLayout(context);
        barLayout.setOrientation(LinearLayout.HORIZONTAL);
        barLayout.setGravity(Gravity.CENTER_VERTICAL);

        android.graphics.drawable.GradientDrawable pill = new android.graphics.drawable.GradientDrawable();
        pill.setColor(0xEE141721); // Nền tối cao cấp 93% mờ
        pill.setCornerRadius(dpToPx(24));
        pill.setStroke(dpToPx(1), 0x33FFFFFF); // Viền kính mờ tinh tế
        barLayout.setBackground(pill);
        barLayout.setPadding(dpToPx(18), dpToPx(8), dpToPx(24), dpToPx(8));
        barLayout.setElevation(dpToPx(10));

        // Waveform Equalizer Aurora cố định bên trái
        waveformView = new AuroraWaveformView(context);
        LinearLayout.LayoutParams waveLp = new LinearLayout.LayoutParams(dpToPx(54), dpToPx(36));
        waveLp.gravity = Gravity.CENTER_VERTICAL;
        waveformView.setLayoutParams(waveLp);
        barLayout.addView(waveformView);

        // Subtitle Text trong suốt có cỡ chữ và màu sắc theo cài đặt người dùng
        int customSize = com.atv.launcher.systembridge.shared.state.BridgeStateStore.getVoiceSubtitleSize(context);
        int customColor = com.atv.launcher.systembridge.shared.state.BridgeStateStore.getVoiceSubtitleColor(context);

        subtitleTextView = new TextView(context);
        subtitleTextView.setText("Đang nghe...");
        subtitleTextView.setTextColor(customColor);
        subtitleTextView.setTextSize(TypedValue.COMPLEX_UNIT_SP, customSize > 0 ? customSize : 20);
        subtitleTextView.setTypeface(Typeface.DEFAULT_BOLD);
        subtitleTextView.setShadowLayer(8.0f, 0, 2, 0xFF000000);
        subtitleTextView.setMaxLines(4);
        subtitleTextView.setMaxWidth(dpToPx(760));
        subtitleTextView.setEllipsize(TextUtils.TruncateAt.END);

        LinearLayout.LayoutParams textLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        );
        textLp.gravity = Gravity.CENTER_VERTICAL;
        textLp.setMargins(dpToPx(14), 0, 0, 0);
        subtitleTextView.setLayoutParams(textLp);
        barLayout.addView(subtitleTextView);

        FrameLayout.LayoutParams rootLp = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        );
        rootLp.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
        rootLp.topMargin = dpToPx(52); // Vị trí trên cùng màn hình TV
        root.addView(barLayout, rootLp);

        overlayView = root;

        WindowManager wm = null;
        WindowManager.LayoutParams wmParams = new WindowManager.LayoutParams();
        if (accessibilityServiceInstance != null && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP_MR1) {
            wm = (WindowManager) accessibilityServiceInstance.getSystemService(Context.WINDOW_SERVICE);
            wmParams.type = WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY;
        } else {
            wm = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                wmParams.type = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY;
            } else {
                wmParams.type = WindowManager.LayoutParams.TYPE_SYSTEM_ALERT;
            }
        }

        wmParams.format = PixelFormat.TRANSLUCENT;
        wmParams.flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS;
        wmParams.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
        wmParams.width = WindowManager.LayoutParams.MATCH_PARENT;
        wmParams.height = WindowManager.LayoutParams.WRAP_CONTENT;

        try {
            if (wm != null) {
                wm.addView(overlayView, wmParams);
                Log.i(TAG, "Floating transparent overlay attached to WindowManager without activity transition (0% flicker)");
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to add overlayView to WindowManager", e);
        }
    }

    private boolean hasRetriedRecognition = false;

    private void startInProcessSpeechRecognition() {
        hasRetriedRecognition = false;
        startSpeechRecognitionInternal(false);
    }

    private void startSpeechRecognitionInternal(boolean isFallback) {
        stopSpeechRecognition();

        try {
            if (isFallback) {
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context);
            } else {
                android.content.ComponentName serviceComponent = new android.content.ComponentName(
                        "com.google.android.katniss",
                        "com.google.android.katniss.search.serviceapi.KatnissRecognitionService"
                );
                try {
                    speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context, serviceComponent);
                } catch (Exception e) {
                    speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context);
                }
            }
        } catch (Exception ex) {
            try {
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context);
            } catch (Exception e) {
                Log.e(TAG, "Cannot create SpeechRecognizer", e);
            }
        }

        if (speechRecognizer == null) {
            updateSubtitle("Không tìm thấy trợ lý giọng nói", 0xFFFF5252);
            scheduleDismiss(2500);
            return;
        }

        speechRecognizer.setRecognitionListener(new RecognitionListener() {
            @Override
            public void onReadyForSpeech(Bundle params) {
                Log.i(TAG, "SpeechRecognizer: onReadyForSpeech");
                updateSubtitle("Đang nghe...", 0xFF00E5FF);
                isListening = true;
                if (waveformView != null) {
                    waveformView.setTtsMode(false);
                    waveformView.startAnimation();
                }
            }

            @Override
            public void onBeginningOfSpeech() {
                Log.i(TAG, "SpeechRecognizer: onBeginningOfSpeech");
            }

            @Override
            public void onRmsChanged(float rmsdB) {
                if (waveformView != null) {
                    waveformView.setRms(rmsdB);
                }
            }

            @Override
            public void onBufferReceived(byte[] buffer) {
            }

            @Override
            public void onEndOfSpeech() {
                Log.i(TAG, "SpeechRecognizer: onEndOfSpeech");
                if (waveformView != null) {
                    waveformView.stopAnimation();
                }
                updateSubtitle("Đang xử lý...", 0xFFFFAB00);
            }

            @Override
            public void onError(int error) {
                Log.w(TAG, "SpeechRecognizer onError code=" + error + ", isFallback=" + isFallback + ", hasRetried=" + hasRetriedRecognition);
                isListening = false;

                if (!hasRetriedRecognition && (error == SpeechRecognizer.ERROR_NETWORK ||
                        error == SpeechRecognizer.ERROR_NETWORK_TIMEOUT ||
                        error == SpeechRecognizer.ERROR_SERVER ||
                        error == SpeechRecognizer.ERROR_CLIENT ||
                        error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY)) {
                    hasRetriedRecognition = true;
                    Log.i(TAG, "SpeechRecognizer network/server glitch, auto-retrying with system speech engine...");
                    mainHandler.postDelayed(() -> {
                        if (isOverlayShowing()) {
                            updateSubtitle("Đang kết nối lại...", 0xFF00E5FF);
                            startSpeechRecognitionInternal(true);
                        }
                    }, 250);
                    return;
                }

                if (waveformView != null) {
                    waveformView.stopAnimation();
                }
                if (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
                    updateSubtitle("Không nghe rõ câu lệnh", 0xFFFF5252);
                } else if (error == SpeechRecognizer.ERROR_AUDIO) {
                    updateSubtitle("Lỗi ghi âm Micro", 0xFFFF5252);
                } else if (error == SpeechRecognizer.ERROR_NETWORK || error == SpeechRecognizer.ERROR_NETWORK_TIMEOUT) {
                    updateSubtitle("Lỗi kết nối mạng", 0xFFFF5252);
                } else {
                    updateSubtitle("Lỗi nhận diện (" + error + ")", 0xFFFF5252);
                }
                scheduleDismiss(2000);
            }

            @Override
            public void onResults(Bundle results) {
                isListening = false;
                if (waveformView != null) {
                    waveformView.stopAnimation();
                }
                ArrayList<String> matches = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                String recognizedText = (matches != null && !matches.isEmpty()) ? matches.get(0).trim() : "";
                Log.i(TAG, "Speech recognized: '" + recognizedText + "'");

                if (!TextUtils.isEmpty(recognizedText)) {
                    updateSubtitle(recognizedText, 0xFFFFFFFF);
                    handleVoiceText(recognizedText);
                } else {
                    updateSubtitle("Không có giọng nói", 0xFFFF5252);
                    scheduleDismiss(2000);
                }
            }

            @Override
            public void onPartialResults(Bundle partialResults) {
                ArrayList<String> matches = partialResults.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                if (matches != null && !matches.isEmpty()) {
                    updateSubtitle(matches.get(0), 0xFFE0E0E0);
                }
            }

            @Override
            public void onEvent(int eventType, Bundle params) {
            }
        });

        Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "vi-VN");
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "vi-VN");
        intent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.getPackageName());
        intent.putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true);
        intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
        intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3);
        intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 3500L);
        intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2200L);
        intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1800L);

        try {
            speechRecognizer.startListening(intent);
        } catch (Exception e) {
            Log.e(TAG, "startListening error", e);
            if (!hasRetriedRecognition) {
                hasRetriedRecognition = true;
                mainHandler.postDelayed(() -> startSpeechRecognitionInternal(true), 250);
            } else {
                updateSubtitle("Lỗi khởi động thu âm", 0xFFFF5252);
                scheduleDismiss(2000);
            }
        }
    }

    private void handleVoiceText(String query) {
        Map<String, Object> result = SmartVoiceDispatcher.dispatch(context, query);
        String type = (String) result.get("type");
        String message = (String) result.get("message");

        if ("ai_qa".equals(type)) {
            updateSubtitle("Đang hỏi Trợ lý AI...", 0xFF7C4DFF);
            scheduleDismiss(15000L);
        } else {
            if (!TextUtils.isEmpty(message)) {
                updateSubtitle(message, 0xFF00E676);
            }
            scheduleDismiss(2800L);
        }
    }

    public void updateSubtitle(String text, int color) {
        mainHandler.post(() -> {
            if (subtitleTextView != null) {
                subtitleTextView.setText(text);
                int userColor = com.atv.launcher.systembridge.shared.state.BridgeStateStore.getVoiceSubtitleColor(context);
                int userSize = com.atv.launcher.systembridge.shared.state.BridgeStateStore.getVoiceSubtitleSize(context);
                subtitleTextView.setTextSize(TypedValue.COMPLEX_UNIT_SP, userSize > 0 ? userSize : 20);
                if (color == Color.WHITE || color == 0xFFFFFFFF) {
                    subtitleTextView.setTextColor(userColor);
                } else {
                    subtitleTextView.setTextColor(color);
                }
            }
        });
    }

    private void stopSpeechRecognition() {
        if (speechRecognizer != null) {
            try {
                speechRecognizer.stopListening();
                speechRecognizer.cancel();
                speechRecognizer.destroy();
            } catch (Exception ignored) {
            }
            speechRecognizer = null;
        }
        isListening = false;
        if (waveformView != null) {
            waveformView.stopAnimation();
        }
    }

    public void scheduleDismiss(long delayMs) {
        cancelDismissTimer();
        dismissRunnable = this::dismiss;
        mainHandler.postDelayed(dismissRunnable, delayMs);
    }

    public void cancelDismissTimer() {
        if (dismissRunnable != null) {
            mainHandler.removeCallbacks(dismissRunnable);
            dismissRunnable = null;
        }
    }

    public void dismiss() {
        mainHandler.post(() -> {
            try {
                VietnameseTtsEngine.getInstance(context).stop();
            } catch (Exception ignored) {}
            stopSpeechRecognition();
            cancelDismissTimer();
            if (overlayView != null) {
                try {
                    WindowManager wm = accessibilityServiceInstance != null
                            ? (WindowManager) accessibilityServiceInstance.getSystemService(Context.WINDOW_SERVICE)
                            : (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
                    if (wm != null) {
                        wm.removeView(overlayView);
                    }
                } catch (Exception ignored) {
                }
                overlayView = null;
                subtitleTextView = null;
                waveformView = null;
            }
            abandonAudioDucking();
            Log.i(TAG, "Floating overlay dismissed");
        });
    }

    private int dpToPx(int dp) {
        return (int) TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                dp,
                context.getResources().getDisplayMetrics()
        );
    }
}
