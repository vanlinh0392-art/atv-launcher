package com.atv.launcher.systembridge.shared.voice;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
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
import android.view.KeyEvent;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.atv.launcher.systembridge.shared.state.BridgeStateStore;
import com.atv.launcher.systembridge.tts.VietnameseTtsEngine;

import java.util.ArrayList;
import java.util.Map;

public class VoiceCaptureTransparentActivity extends Activity {
    private static final String TAG = "VoiceCaptureActivity";
    private static volatile VoiceCaptureTransparentActivity activeInstance;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private AuroraWaveformView waveformView;
    private TextView subtitleTextView;
    private SpeechRecognizer speechRecognizer;
    private AudioManager audioManager;
    private VoiceKeyHandler voiceKeyHandler;
    private boolean isListening = false;
    private Runnable dismissRunnable;

    public static VoiceCaptureTransparentActivity getActiveInstance() {
        return activeInstance;
    }

    private final AudioManager.OnAudioFocusChangeListener audioFocusListener = focusChange -> {
        Log.i(TAG, "Audio focus changed: " + focusChange);
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        activeInstance = this;
        voiceKeyHandler = new VoiceKeyHandler(TAG, "transparent_activity");

        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setBackgroundDrawableResource(android.R.color.transparent);
        getWindow().setWindowAnimations(0);
        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);
        getWindow().setFlags(
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL |
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN |
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL |
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN |
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        );
        overridePendingTransition(0, 0);

        audioManager = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        requestAudioDucking();

        initLayout();
        startSpeechRecognition();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        Log.i(TAG, "onNewIntent received -> restarting voice listening while open");
        restartVoiceListening();
    }

    public void restartVoiceListening() {
        mainHandler.post(() -> {
            cancelDismissTimer();
            if (waveformView != null) {
                waveformView.setTtsMode(false);
            }
            VietnameseTtsEngine.getInstance(this).stop();
            abandonAudioDucking();
            requestAudioDucking();
            updateSubtitle("Đang nghe...", 0xFF00E5FF);
            startSpeechRecognition();
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

    private void initLayout() {
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.TRANSPARENT);

        LinearLayout barLayout = new LinearLayout(this);
        barLayout.setOrientation(LinearLayout.HORIZONTAL);
        barLayout.setGravity(Gravity.CENTER_VERTICAL);
        
        android.graphics.drawable.GradientDrawable pill = new android.graphics.drawable.GradientDrawable();
        pill.setColor(0xEE141721); // Nền tối cao cấp 93% mờ
        pill.setCornerRadius(dpToPx(24));
        pill.setStroke(dpToPx(1), 0x33FFFFFF); // Viền kính mờ tinh tế
        barLayout.setBackground(pill);
        barLayout.setPadding(dpToPx(18), dpToPx(8), dpToPx(24), dpToPx(8));
        barLayout.setElevation(dpToPx(10));

        // Waveform Equalizer 60fps
        waveformView = new AuroraWaveformView(this);
        LinearLayout.LayoutParams waveLp = new LinearLayout.LayoutParams(dpToPx(54), dpToPx(36));
        waveLp.gravity = Gravity.CENTER_VERTICAL;
        waveformView.setLayoutParams(waveLp);
        barLayout.addView(waveformView);

        int customSize = BridgeStateStore.getVoiceSubtitleSize(this);
        int customColor = BridgeStateStore.getVoiceSubtitleColor(this);

        subtitleTextView = new TextView(this);
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
        rootLp.topMargin = dpToPx(56);
        root.addView(barLayout, rootLp);

        setContentView(root);
    }

    private boolean hasRetriedRecognition = false;

    private void startSpeechRecognition() {
        hasRetriedRecognition = false;
        startSpeechRecognitionInternal(false);
    }

    private void startSpeechRecognitionInternal(boolean isFallback) {
        stopSpeechRecognition();

        try {
            if (isFallback) {
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this);
            } else {
                android.content.ComponentName serviceComponent = new android.content.ComponentName(
                        "com.google.android.katniss",
                        "com.google.android.katniss.search.serviceapi.KatnissRecognitionService"
                );
                try {
                    speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this, serviceComponent);
                } catch (Exception e) {
                    speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this);
                }
            }
        } catch (Exception ex) {
            try {
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this);
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
                    Log.i(TAG, "SpeechRecognizer network glitch, retrying with fallback...");
                    new Handler(Looper.getMainLooper()).postDelayed(() -> {
                        if (!isFinishing()) {
                            updateSubtitle("Đang kết nối lại...", 0xFF00E5FF);
                            startSpeechRecognitionInternal(true);
                        }
                    }, 250);
                    return;
                }

                if (waveformView != null) {
                    waveformView.stopAnimation();
                }
                String msg;
                switch (error) {
                    case SpeechRecognizer.ERROR_NO_MATCH:
                        msg = "Không nghe rõ câu lệnh, vui lòng thử lại";
                        break;
                    case SpeechRecognizer.ERROR_SPEECH_TIMEOUT:
                        msg = "Chưa nhận được giọng nói";
                        break;
                    case SpeechRecognizer.ERROR_NETWORK:
                    case SpeechRecognizer.ERROR_NETWORK_TIMEOUT:
                        msg = "Lỗi kết nối mạng";
                        break;
                    case SpeechRecognizer.ERROR_AUDIO:
                        msg = "Lỗi thu âm micro";
                        break;
                    case SpeechRecognizer.ERROR_RECOGNIZER_BUSY:
                        msg = "Trợ lý giọng nói đang bận";
                        break;
                    case SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS:
                        msg = "Chưa cấp quyền Micro";
                        break;
                    default:
                        msg = "Lỗi nhận diện (" + error + ")";
                        break;
                }
                updateSubtitle(msg, 0xFFFF5252);
                scheduleDismiss(2200);
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
        intent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, getPackageName());
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
                new Handler(Looper.getMainLooper()).postDelayed(() -> startSpeechRecognitionInternal(true), 250);
            } else {
                updateSubtitle("Lỗi khởi động thu âm", 0xFFFF5252);
                scheduleDismiss(2000);
            }
        }
    }

    private void handleVoiceText(String query) {
        Map<String, Object> result = SmartVoiceDispatcher.dispatch(this, query);
        String type = (String) result.get("type");
        String message = (String) result.get("message");

        if ("ai_qa".equals(type)) {
            updateSubtitle("Đang hỏi Trợ lý AI...", 0xFF7C4DFF);
            // Hẹn giờ đóng dự phòng sau 15s nếu TTS gặp sự cố mạng
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
                int userColor = BridgeStateStore.getVoiceSubtitleColor(this);
                int userSize = BridgeStateStore.getVoiceSubtitleSize(this);
                subtitleTextView.setTextSize(TypedValue.COMPLEX_UNIT_SP, userSize > 0 ? userSize : 20);
                if (color == Color.WHITE || color == 0xFFFFFFFF) {
                    subtitleTextView.setTextColor(userColor);
                } else {
                    subtitleTextView.setTextColor(color);
                }
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
            } catch (Exception ignored) {}
        }
    }

    private void abandonAudioDucking() {
        if (audioManager != null) {
            try {
                audioManager.abandonAudioFocus(audioFocusListener);
            } catch (Exception ignored) {}
        }
    }

    private void stopSpeechRecognition() {
        if (speechRecognizer != null) {
            try {
                speechRecognizer.stopListening();
                speechRecognizer.cancel();
                speechRecognizer.destroy();
            } catch (Exception ignored) {}
            speechRecognizer = null;
        }
        isListening = false;
        if (waveformView != null) {
            waveformView.stopAnimation();
        }
    }

    public void scheduleDismiss(long delayMs) {
        cancelDismissTimer();
        dismissRunnable = this::finishWithCleanup;
        mainHandler.postDelayed(dismissRunnable, delayMs);
    }

    public void cancelDismissTimer() {
        if (dismissRunnable != null) {
            mainHandler.removeCallbacks(dismissRunnable);
            dismissRunnable = null;
        }
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        if (voiceKeyHandler != null && voiceKeyHandler.handle(this, event)) {
            return true;
        }
        return super.dispatchKeyEvent(event);
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_BACK || keyCode == KeyEvent.KEYCODE_HOME) {
            finishWithCleanup();
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    private void finishWithCleanup() {
        stopSpeechRecognition();
        cancelDismissTimer();
        abandonAudioDucking();
        VietnameseTtsEngine.getInstance(this).stop();
        finish();
        overridePendingTransition(0, 0);
    }

    @Override
    protected void onDestroy() {
        if (activeInstance == this) {
            activeInstance = null;
        }
        if (voiceKeyHandler != null) {
            voiceKeyHandler.clearPendingActions();
        }
        stopSpeechRecognition();
        cancelDismissTimer();
        abandonAudioDucking();
        super.onDestroy();
    }

    private int dpToPx(int dp) {
        return (int) TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                dp,
                getResources().getDisplayMetrics()
        );
    }
}
