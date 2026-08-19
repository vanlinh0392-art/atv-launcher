package com.atv.launcher.systembridge.tts;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.os.Handler;
import android.os.Looper;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.text.TextUtils;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Queue;
import java.util.UUID;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class VietnameseTtsEngine {
    private static final String TAG = "VietnameseTtsEngine";

    public static final String VOICE_HOAI_MY = "vi-VN-HoaiMyNeural";
    public static final String VOICE_NAM_MINH = "vi-VN-NamMinhNeural";
    public static final long TIER1_TIMEOUT_MS = 5000L;

    private static volatile VietnameseTtsEngine instance;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService executor = Executors.newCachedThreadPool();

    private TextToSpeech nativeTts;
    private boolean nativeTtsInitialized;
    private MediaPlayer mediaPlayer;
    private String preferredEngine = "auto";

    public static class PlaybackItem {
        public final File file;
        public final String text;
        public final int index;
        public final int total;

        public PlaybackItem(File file, String text, int index, int total) {
            this.file = file;
            this.text = text;
            this.index = index;
            this.total = total;
        }
    }

    private final Queue<PlaybackItem> playbackQueue = new ConcurrentLinkedQueue<>();
    private final List<File> tempFilesToClean = new CopyOnWriteArrayList<>();
    private volatile boolean isPlayingQueue = false;
    private volatile boolean isDownloadingFinished = false;
    private volatile boolean isWaitingForNextChunk = false;
    private volatile boolean isStopped = false;
    private TtsCallback activeCallback;

    public boolean isSpeaking() {
        try {
            if (isPlayingQueue || !playbackQueue.isEmpty()) return true;
            if (mediaPlayer != null && mediaPlayer.isPlaying()) return true;
            if (nativeTts != null && nativeTts.isSpeaking()) return true;
        } catch (Exception ignored) {}
        return false;
    }

    public static boolean isSpeakingAny() {
        return instance != null && instance.isSpeaking();
    }

    public void setPreferredEngine(Context context, String engine) {
        if (!TextUtils.isEmpty(engine)) {
            this.preferredEngine = engine;
            com.atv.launcher.systembridge.shared.state.BridgeStateStore.setTtsEngine(context, engine);
            Log.i(TAG, "Preferred TTS engine set to: " + engine);
        }
    }

    public void setPreferredEngine(String engine) {
        if (!TextUtils.isEmpty(engine)) {
            this.preferredEngine = engine;
            Log.i(TAG, "Preferred TTS engine set to: " + engine);
        }
    }

    public String getPreferredEngine() {
        return preferredEngine;
    }

    public interface TtsCallback {
        void onStart(int tier, String engineName);
        void onChunkStart(int index, int total, String chunkText);
        void onComplete();
        void onError(String message);
    }

    private VietnameseTtsEngine(Context context) {
        Context appContext = context.getApplicationContext();
        this.preferredEngine = com.atv.launcher.systembridge.shared.state.BridgeStateStore.getTtsEngine(appContext);
        initNativeTts(appContext);
    }

    public static VietnameseTtsEngine getInstance(Context context) {
        if (instance == null) {
            synchronized (VietnameseTtsEngine.class) {
                if (instance == null) {
                    instance = new VietnameseTtsEngine(context);
                }
            }
        }
        return instance;
    }

    private void initNativeTts(Context context) {
        try {
            nativeTts = new TextToSpeech(context, status -> {
                if (status == TextToSpeech.SUCCESS) {
                    int result = nativeTts.setLanguage(new Locale("vi", "VN"));
                    if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                        nativeTts.setLanguage(Locale.getDefault());
                    }
                    nativeTts.setSpeechRate(1.0f);
                    nativeTts.setPitch(1.0f);
                    nativeTtsInitialized = true;
                    Log.i(TAG, "Native Android TextToSpeech initialized successfully");
                } else {
                    Log.w(TAG, "Native TextToSpeech initialization failed status=" + status);
                    nativeTtsInitialized = false;
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "Error creating TextToSpeech", e);
            nativeTtsInitialized = false;
        }
    }

    public void speak(Context context, String rawText, TtsCallback callback) {
        final String textToSpeak = VietnameseTextPreprocessor.preprocessForSpeech(rawText);
        if (TextUtils.isEmpty(textToSpeak)) {
            notifyComplete(callback);
            return;
        }

        stop();
        isStopped = false;
        activeCallback = callback;
        playbackQueue.clear();
        tempFilesToClean.clear();
        isPlayingQueue = false;
        isDownloadingFinished = false;
        isWaitingForNextChunk = false;

        final List<String> sentences = VietnameseTextPreprocessor.splitIntoSentences(textToSpeak);
        if (sentences.isEmpty()) {
            notifyComplete(callback);
            return;
        }

        final Context appContext = context.getApplicationContext();
        final int totalSentences = sentences.size();

        executor.execute(() -> {
            // Tải câu đầu tiên
            File firstChunk = fetchOnlineTtsAudio(appContext, sentences.get(0));
            if (firstChunk != null && firstChunk.exists() && firstChunk.length() > 0 && !isStopped) {
                playbackQueue.add(new PlaybackItem(firstChunk, sentences.get(0), 0, totalSentences));
                tempFilesToClean.add(firstChunk);

                notifyStart(callback, 1, "Online Neural TTS");
                mainHandler.post(() -> playNextChunkInQueue(appContext));

                // Tải ngầm các câu tiếp theo (nếu có)
                for (int i = 1; i < totalSentences; i++) {
                    if (isStopped) break;
                    File nextChunk = fetchOnlineTtsAudio(appContext, sentences.get(i));
                    if (nextChunk != null && nextChunk.exists() && nextChunk.length() > 0) {
                        playbackQueue.add(new PlaybackItem(nextChunk, sentences.get(i), i, totalSentences));
                        tempFilesToClean.add(nextChunk);

                        synchronized (VietnameseTtsEngine.this) {
                            if (isWaitingForNextChunk && !isPlayingQueue) {
                                isWaitingForNextChunk = false;
                                mainHandler.post(() -> playNextChunkInQueue(appContext));
                            }
                        }
                    }
                }

                isDownloadingFinished = true;

                synchronized (VietnameseTtsEngine.this) {
                    if (isWaitingForNextChunk && !isPlayingQueue) {
                        isWaitingForNextChunk = false;
                        if (!playbackQueue.isEmpty()) {
                            mainHandler.post(() -> playNextChunkInQueue(appContext));
                        } else {
                            notifyComplete(activeCallback);
                            cleanupTempFiles();
                        }
                    }
                }
            } else if (!isStopped) {
                // Fallback Native TTS nếu Online thất bại
                mainHandler.post(() -> {
                    boolean nativeSuccess = tryNativeTts(textToSpeak, callback);
                    if (!nativeSuccess) {
                        Log.i(TAG, "TTS Fallback Visual Subtitle");
                        notifyStart(callback, 3, "Visual Subtitle");
                        notifyChunkStart(callback, 0, 1, textToSpeak);
                        notifyComplete(callback);
                    }
                });
            }
        });
    }

    private synchronized void playNextChunkInQueue(Context context) {
        if (isStopped) return;

        PlaybackItem nextItem = playbackQueue.poll();
        if (nextItem != null && nextItem.file != null && nextItem.file.exists()) {
            isPlayingQueue = true;
            isWaitingForNextChunk = false;
            try {
                stopMediaPlayer();
                mediaPlayer = new MediaPlayer();
                mediaPlayer.setAudioAttributes(new AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setLegacyStreamType(AudioManager.STREAM_MUSIC)
                        .build());
                mediaPlayer.setDataSource(nextItem.file.getAbsolutePath());
                mediaPlayer.setVolume(1.0f, 1.0f);

                // Báo hiển thị câu đang phát ra màn hình
                notifyChunkStart(activeCallback, nextItem.index, nextItem.total, nextItem.text);

                mediaPlayer.setOnCompletionListener(mp -> {
                    stopMediaPlayer();
                    synchronized (VietnameseTtsEngine.this) {
                        if (!playbackQueue.isEmpty()) {
                            playNextChunkInQueue(context);
                        } else if (isDownloadingFinished) {
                            isPlayingQueue = false;
                            isWaitingForNextChunk = false;
                            cleanupTempFiles();
                            notifyComplete(activeCallback);
                        } else {
                            // Đang đợi chunk tiếp theo tải về
                            isPlayingQueue = false;
                            isWaitingForNextChunk = true;
                        }
                    }
                });

                mediaPlayer.setOnErrorListener((mp, what, extra) -> {
                    Log.e(TAG, "MediaPlayer error: what=" + what + " extra=" + extra);
                    stopMediaPlayer();
                    synchronized (VietnameseTtsEngine.this) {
                        if (!playbackQueue.isEmpty()) {
                            playNextChunkInQueue(context);
                        } else if (isDownloadingFinished) {
                            isPlayingQueue = false;
                            isWaitingForNextChunk = false;
                            cleanupTempFiles();
                            notifyComplete(activeCallback);
                        } else {
                            isPlayingQueue = false;
                            isWaitingForNextChunk = true;
                        }
                    }
                    return true;
                });

                mediaPlayer.prepare();
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                    try {
                        String eng = getPreferredEngine();
                        android.media.PlaybackParams params = mediaPlayer.getPlaybackParams();
                        if ("edge_namminh".equals(eng) || "namminh".equals(eng)) {
                            params.setPitch(0.78f);
                            params.setSpeed(0.96f);
                        } else if ("edge_hoaimy".equals(eng) || "hoaimy".equals(eng)) {
                            params.setPitch(1.22f);
                            params.setSpeed(1.02f);
                        } else {
                            params.setPitch(1.0f);
                            params.setSpeed(1.0f);
                        }
                        mediaPlayer.setPlaybackParams(params);
                    } catch (Exception ignored) {}
                }
                mediaPlayer.start();
                Log.i(TAG, "MediaPlayer playing chunk [" + (nextItem.index + 1) + "/" + nextItem.total + "]: " + nextItem.file.getName());
            } catch (Exception e) {
                Log.e(TAG, "playNextChunkInQueue error", e);
                isPlayingQueue = false;
                if (isDownloadingFinished && playbackQueue.isEmpty()) {
                    notifyComplete(activeCallback);
                    cleanupTempFiles();
                }
            }
        } else {
            isPlayingQueue = false;
            if (isDownloadingFinished) {
                isWaitingForNextChunk = false;
                cleanupTempFiles();
                notifyComplete(activeCallback);
            } else {
                isWaitingForNextChunk = true;
            }
        }
    }

    private void notifyStart(TtsCallback callback, int tier, String name) {
        mainHandler.post(() -> {
            if (callback != null) {
                try {
                    callback.onStart(tier, name);
                } catch (Exception ignored) {}
            }
        });
    }

    private void notifyChunkStart(TtsCallback callback, int index, int total, String chunkText) {
        mainHandler.post(() -> {
            if (callback != null) {
                try {
                    callback.onChunkStart(index, total, chunkText);
                } catch (Exception ignored) {}
            }
        });
    }

    private void notifyComplete(TtsCallback callback) {
        mainHandler.post(() -> {
            if (callback != null) {
                try {
                    callback.onComplete();
                } catch (Exception ignored) {}
            }
        });
    }

    private boolean tryEdgeTts(Context context, String text, String voice, TtsCallback callback) {
        File audioFile = fetchOnlineTtsAudio(context, text);
        if (audioFile != null && audioFile.exists() && audioFile.length() > 0) {
            mainHandler.post(() -> {
                notifyStart(callback, 1, "Online Neural TTS");
                playbackQueue.add(new PlaybackItem(audioFile, text, 0, 1));
                tempFilesToClean.add(audioFile);
                playNextChunkInQueue(context);
            });
            return true;
        }
        return false;
    }

    private File fetchOnlineTtsAudio(Context context, String text) {
        for (int attempt = 0; attempt < 2; attempt++) {
            if (isStopped) return null;
            HttpURLConnection conn = null;
            try {
                String encodedText = URLEncoder.encode(text, "UTF-8");
                String urlStr = "https://translate.google.com/translate_tts?ie=UTF-8&q=" + encodedText + "&tl=vi&client=tw-ob";
                URL url = new URL(urlStr);

                conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("GET");
                conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
                conn.setConnectTimeout(4500);
                conn.setReadTimeout(5500);

                int code = conn.getResponseCode();
                if (code == 200) {
                    File cacheDir = context.getCacheDir();
                    File tempFile = new File(cacheDir, "tts_" + System.currentTimeMillis() + "_" + UUID.randomUUID().toString().substring(0, 5) + ".mp3");
                    try (InputStream is = conn.getInputStream();
                         OutputStream os = new FileOutputStream(tempFile)) {
                        byte[] buffer = new byte[4096];
                        int len;
                        while ((len = is.read(buffer)) != -1) {
                            os.write(buffer, 0, len);
                        }
                        os.flush();
                    }
                    Log.i(TAG, "Online TTS downloaded chunk (" + text.length() + " chars): " + tempFile.length() + " bytes");
                    return tempFile;
                } else {
                    try (InputStream es = conn.getErrorStream()) {
                        if (es != null) {
                            byte[] buf = new byte[512];
                            while (es.read(buf) > 0) {}
                        }
                    } catch (Exception ignored) {}
                    Log.w(TAG, "Online TTS HTTP " + code + " (attempt " + (attempt + 1) + ")");
                }
            } catch (Exception e) {
                Log.w(TAG, "fetchOnlineTtsAudio error (attempt " + (attempt + 1) + "): " + e.getMessage());
            } finally {
                if (conn != null) {
                    conn.disconnect();
                }
            }
            if (attempt == 0 && !isStopped) {
                try {
                    Thread.sleep(180);
                } catch (InterruptedException ignored) {}
            }
        }
        return null;
    }

    private boolean tryNativeTts(String text, TtsCallback callback) {
        Log.i(TAG, "Attempting TTS Tier 2: Native Android TextToSpeech");
        if (nativeTts == null || !nativeTtsInitialized) {
            Log.w(TAG, "Native TTS not ready");
            return false;
        }

        try {
            String utteranceId = UUID.randomUUID().toString();
            nativeTts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                @Override
                public void onStart(String utteranceId) {
                    notifyStart(callback, 2, "Native Google TTS");
                    notifyChunkStart(callback, 0, 1, text);
                }

                @Override
                public void onDone(String utteranceId) {
                    notifyComplete(callback);
                }

                @Override
                public void onError(String utteranceId) {
                    notifyComplete(callback);
                }
            });

            String eng = getPreferredEngine();
            if ("edge_namminh".equals(eng) || "namminh".equals(eng)) {
                nativeTts.setPitch(0.78f);
                nativeTts.setSpeechRate(0.96f);
            } else if ("edge_hoaimy".equals(eng) || "hoaimy".equals(eng)) {
                nativeTts.setPitch(1.22f);
                nativeTts.setSpeechRate(1.02f);
            } else {
                nativeTts.setPitch(1.0f);
                nativeTts.setSpeechRate(1.0f);
            }

            int result = nativeTts.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId);
            return result == TextToSpeech.SUCCESS;
        } catch (Exception e) {
            Log.e(TAG, "Native TTS speak failed", e);
            return false;
        }
    }

    public synchronized void stop() {
        isStopped = true;
        isPlayingQueue = false;
        isWaitingForNextChunk = false;
        isDownloadingFinished = true;
        playbackQueue.clear();
        stopMediaPlayer();
        cleanupTempFiles();
        if (nativeTts != null && nativeTtsInitialized) {
            try {
                nativeTts.stop();
            } catch (Exception ignored) {
            }
        }
    }

    private void cleanupTempFiles() {
        for (File f : tempFilesToClean) {
            try {
                if (f != null && f.exists()) {
                    f.delete();
                }
            } catch (Exception ignored) {
            }
        }
        tempFilesToClean.clear();
    }

    private void stopMediaPlayer() {
        if (mediaPlayer != null) {
            try {
                if (mediaPlayer.isPlaying()) {
                    mediaPlayer.stop();
                }
                mediaPlayer.reset();
                mediaPlayer.release();
            } catch (Exception ignored) {
            }
            mediaPlayer = null;
        }
    }

    public void shutdown() {
        stop();
        if (nativeTts != null) {
            try {
                nativeTts.shutdown();
            } catch (Exception ignored) {
            }
            nativeTts = null;
        }
        executor.shutdown();
    }
}
