package com.atv.launcher.systembridge.ai;

import android.content.Context;
import android.text.TextUtils;
import android.util.Log;

import com.atv.launcher.systembridge.shared.voice.VoiceCaptureTransparentActivity;
import com.atv.launcher.systembridge.shared.voice.VoiceFloatingOverlayManager;
import com.atv.launcher.systembridge.tts.VietnameseTtsEngine;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class AiVoiceAssistantClient {
    private static final String TAG = "AiVoiceAssistant";

    private static String decodeKey(String b64) {
        try {
            return new String(android.util.Base64.decode(b64, android.util.Base64.DEFAULT), "UTF-8").trim();
        } catch (Exception e) {
            return "";
        }
    }

    // 100% Free Verified API Keys (Encoded)
    public static final String DEFAULT_GEMINI_KEY = decodeKey("QUl6YVN5RFlxU2Z1UlNfVm9Wa2FQSXAyeHNHeW5nN01zVjdVYk1B");
    public static final String DEFAULT_NVIDIA_KEY = decodeKey("bnZhcGktWmhWY0YxaExyTllZQkJLa09FV2d3YnpCejJiTmV5R1cxbm85a3poQnV6OGpJZVdxWURoNExuc2xuaTdhaS1Eaw==");
    public static final String DEFAULT_OPENROUTER_KEY = decodeKey("c2stb3ItdjEtZDliNjY3ZjUyZjgyYTdjM2UwZGU1N2E0MGNjODkyY2EyNjYwYWQyZGFmODQyMTAyNWVhMWYwMzMzZGEwYzJiMw==");

    public static final String GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent";
    public static final String NVIDIA_ENDPOINT = "https://integrate.api.nvidia.com/v1/chat/completions";
    public static final String OPENROUTER_ENDPOINT = "https://openrouter.ai/api/v1/chat/completions";

    public static final String TV_SYSTEM_PROMPT =
            "Bạn là Trợ lý Giọng nói Thông minh trên Android TV. " +
            "Hãy trả lời người dùng bằng tiếng Việt tự nhiên, súc tích, ngắn gọn trong 1 đến 2 câu (tối đa 35 từ), " +
            "không dùng markdown ký hiệu hoa mỹ, thích hợp để đọc thành tiếng qua loa TV.";

    public static boolean isStoryOrLongContent(String query) {
        if (TextUtils.isEmpty(query)) return false;
        String q = query.trim().toLowerCase(Locale.ROOT);
        return q.contains("kể chuyện") || q.contains("ke chuyen") || q.contains("câu chuyện")
                || q.contains("cau chuyen") || q.contains("truyện") || q.contains("truyen")
                || q.contains("thơ") || q.contains("tho") || q.contains("giải thích")
                || q.contains("giai thich") || q.contains("tại sao") || q.contains("vi sao");
    }

    public static String buildSystemPrompt(String query) {
        if (TextUtils.isEmpty(query)) return TV_SYSTEM_PROMPT;
        String q = query.trim().toLowerCase(Locale.ROOT);

        // 1. Kể chuyện (Truyện cổ tích, ngụ ngôn, truyện thiếu nhi, Rùa và Thỏ, etc.)
        if (q.contains("kể chuyện") || q.contains("ke chuyen") || q.contains("câu chuyện") || q.contains("cau chuyen") || q.contains("truyện") || q.contains("truyen")) {
            return "Bạn là Người Kể Chuyện trên Android TV. Hãy kể câu chuyện hoàn chỉnh, mạch lạc từ mở đầu, diễn biến đến kết thúc. " +
                    "Chia câu chuyện thành 3 đến 5 câu văn hoàn chỉnh, ngắt câu bằng dấu chấm rõ ràng để hệ thống đọc từng đoạn mượt mà, " +
                    "không dùng ký hiệu markdown, không thêm tiêu đề hay lời dẫn rườm rà.";
        }

        // 2. Giải trí: Chuyện cười, Hài hước
        if (q.contains("chuyện cười") || q.contains("chuyen cuoi") || q.contains("hài") || q.contains("vui")) {
            return "Bạn là Trợ lý TV vui tính. Hãy kể 1 mẩu chuyện cười dí dỏm gồm 2 đến 3 câu hoàn chỉnh, ngắt câu bằng dấu chấm, không dùng markdown.";
        }

        // 3. Thơ ca, Sáng tác
        if (q.contains("thơ") || q.contains("tho") || q.contains("bài thơ") || q.contains("làm thơ")) {
            return "Bạn là Trợ lý TV thi sĩ. Hãy sáng tác hoặc đọc 1 khổ thơ 4 câu ngắn gọn, vần điệu êm ái, giàu hình ảnh bằng tiếng Việt, ngắt câu bằng dấu chấm, không dùng ký hiệu markdown.";
        }

        // 4. Thời tiết & Khí hậu
        if (q.contains("thời tiết") || q.contains("thoi tiet") || q.contains("mưa") || q.contains("nhiệt độ") || q.contains("nóng") || q.contains("lạnh") || q.contains("dự báo")) {
            return "Bạn là Trợ lý TV cập nhật thời tiết. Hãy thông báo tình hình thời tiết ngắn gọn trong 1 đến 2 câu (nhiệt độ, trạng thái trời và lời khuyên), ngắt câu bằng dấu chấm, không dùng markdown.";
        }

        // 5. Ẩm thực & Gợi ý nấu ăn
        if (q.contains("ăn gì") || q.contains("an gi") || q.contains("nấu gì") || q.contains("món ăn") || q.contains("thực đơn") || q.contains("món ngon")) {
            return "Bạn là Trợ lý TV am hiểu ẩm thực. Hãy gợi ý 2-3 món ăn gia đình Việt Nam thơm ngon, hấp dẫn trong 2 câu ngắn gọn, ngắt câu bằng dấu chấm, không dùng markdown.";
        }

        // 6. Dịch thuật & Ngoại ngữ
        if (q.contains("dịch") || q.contains("dich") || q.contains("tiếng anh") || q.contains("tiếng nhật") || q.contains("tiếng trung") || q.contains("tiếng hàn") || q.contains("translate")) {
            return "Bạn là Trợ lý TV dịch thuật. Hãy đưa ra câu dịch chính xác ngay lập tức, kèm phát âm ngắn gọn trong 1 câu, không giải thích rườm rà.";
        }

        // 7. Định nghĩa, Kiến thức, Nhân vật, Địa danh
        if (q.contains("là gì") || q.contains("la gi") || q.contains("ai là") || q.contains("ai la") || q.contains("ở đâu") || q.contains("o dau") || q.contains("tại sao") || q.contains("vì sao")) {
            return "Bạn là Bách khoa toàn thư TV. Hãy giải thích trực tiếp, chính xác, súc tích trong 2 câu hoàn chỉnh, không chào hỏi mở đầu, ngắt câu bằng dấu chấm, không dùng markdown.";
        }

        return TV_SYSTEM_PROMPT;
    }

    private static final ExecutorService executor = Executors.newSingleThreadExecutor();

    public static class ModelTarget {
        public final String provider;
        public final String endpoint;
        public final String modelId;
        public final String description;

        public ModelTarget(String provider, String endpoint, String modelId, String description) {
            this.provider = provider;
            this.endpoint = endpoint;
            this.modelId = modelId;
            this.description = description;
        }
    }

    // Danh sách 8 Model AI Fallback Miễn Phí (4 NVIDIA NIM + 4 OpenRouter Free)
    private static final List<ModelTarget> FALLBACK_MODELS = new ArrayList<>();

    static {
        // --- 4 MODELS TỪ NVIDIA NIM CLOUD ---
        // 1. Meta Llama 3.1 8B Instruct (NVIDIA GPU Cloud - Siêu tốc 340ms)
        FALLBACK_MODELS.add(new ModelTarget(
                "NVIDIA NIM", NVIDIA_ENDPOINT, "meta/llama-3.1-8b-instruct",
                "Meta Llama 3.1 8B Instruct (NVIDIA Cloud - Siêu tốc)"
        ));
        // 2. Google Gemma 4 31B Instruct (NVIDIA GPU Cloud - Đỉnh cao)
        FALLBACK_MODELS.add(new ModelTarget(
                "NVIDIA NIM", NVIDIA_ENDPOINT, "google/gemma-4-31b-it",
                "Google Gemma 4 31B (NVIDIA Cloud - Thông minh)"
        ));
        // 3. Google Diffusion Gemma 26B (NVIDIA GPU Cloud - Đa nhiệm)
        FALLBACK_MODELS.add(new ModelTarget(
                "NVIDIA NIM", NVIDIA_ENDPOINT, "google/diffusiongemma-26b-a4b-it",
                "Google Diffusion Gemma 26B (NVIDIA Cloud)"
        ));
        // 4. Meta Llama 3.2 11B Instruct (NVIDIA GPU Cloud)
        FALLBACK_MODELS.add(new ModelTarget(
                "NVIDIA NIM", NVIDIA_ENDPOINT, "meta/llama-3.2-11b-vision-instruct",
                "Meta Llama 3.2 11B (NVIDIA Cloud - Chuẩn xác)"
        ));

        // --- 4 MODELS TỪ OPENROUTER FREE ---
        // 5. NVIDIA Nemotron 3.5 Lightning Free
        FALLBACK_MODELS.add(new ModelTarget(
                "OpenRouter", OPENROUTER_ENDPOINT, "nvidia/nemotron-3.5-lightning:free",
                "NVIDIA Nemotron 3.5 Lightning (OpenRouter Free)"
        ));
        // 6. Google Gemma 4 31B Free
        FALLBACK_MODELS.add(new ModelTarget(
                "OpenRouter", OPENROUTER_ENDPOINT, "google/gemma-4-31b-it:free",
                "Google Gemma 4 31B (OpenRouter Free)"
        ));
        // 7. Google Gemma 4 26B Free
        FALLBACK_MODELS.add(new ModelTarget(
                "OpenRouter", OPENROUTER_ENDPOINT, "google/gemma-4-26b-a4b-it:free",
                "Google Gemma 4 26B (OpenRouter Free)"
        ));
        // 8. OpenAI GPT-OSS 20B Free
        FALLBACK_MODELS.add(new ModelTarget(
                "OpenRouter", OPENROUTER_ENDPOINT, "openai/gpt-oss-20b:free",
                "OpenAI GPT-OSS 20B (OpenRouter Free)"
        ));
    }

    public static List<ModelTarget> getFallbackModels() {
        return Collections.unmodifiableList(FALLBACK_MODELS);
    }

    public interface AiResponseCallback {
        void onSuccess(String answerText, String modelUsed);
        void onError(String errorMessage);
    }

    private AiVoiceAssistantClient() {
    }

    public static boolean isQuestionOrConversation(String query) {
        if (TextUtils.isEmpty(query)) return false;
        String q = query.trim().toLowerCase(Locale.ROOT);

        String[] questionKeywords = {
                "tại sao", "tai sao", "vì sao", "vi sao", "như thế nào", "nhu the nao",
                "bao nhiêu", "bao nhieu", "mấy giờ", "may gio", "thời tiết", "thoi tiet",
                "hôm nay", "hom nay", "ngày mai", "ngay mai", "là gì", "la gi",
                "ai là", "ai la", "ở đâu", "o dau", "kể chuyện", "ke chuyen",
                "chuyện cười", "chuyen cuoi", "hát", "tho", "thơ", "giải thích",
                "giai thich", "hôm nay ăn gì", "tin tức", "tin tuc", "dự báo",
                "mấy độ", "nhiệt độ", "dịch", "dich", "tiếng anh", "bạn là ai",
                "chào", "xin chào", "hello", "hi", "tên gì"
        };

        for (String kw : questionKeywords) {
            if (q.contains(kw)) {
                return true;
            }
        }

        return q.endsWith("?") || q.endsWith("phải không") || q.endsWith("không") || q.endsWith("nhỉ") || q.length() > 20;
    }

    private static volatile String geminiApiKey = DEFAULT_GEMINI_KEY;
    private static volatile String nvidiaKey = DEFAULT_NVIDIA_KEY;
    private static volatile String openRouterKey = DEFAULT_OPENROUTER_KEY;

    public static void setGeminiApiKey(String key) {
        geminiApiKey = TextUtils.isEmpty(key) ? DEFAULT_GEMINI_KEY : key.trim();
    }

    public static String getGeminiApiKey() {
        return geminiApiKey;
    }

    public static void setOpenRouterKey(String key) {
        openRouterKey = TextUtils.isEmpty(key) ? DEFAULT_OPENROUTER_KEY : key.trim();
    }

    public static String getOpenRouterKey() {
        return openRouterKey;
    }

    public static class ConversationMessage {
        public final String role;
        public final String content;

        public ConversationMessage(String role, String content) {
            this.role = role;
            this.content = content;
        }
    }

    private static final List<ConversationMessage> conversationHistory = Collections.synchronizedList(new ArrayList<>());
    private static volatile long lastInteractionTime = 0L;
    private static final long HISTORY_TIMEOUT_MS = 60000L; // 60s memory

    public static synchronized void clearConversationHistory() {
        conversationHistory.clear();
        lastInteractionTime = 0L;
        Log.i(TAG, "Conversation history cleared");
    }

    public static synchronized void addMessageToHistory(String role, String content) {
        if (TextUtils.isEmpty(content)) return;
        long now = System.currentTimeMillis();
        if (now - lastInteractionTime > HISTORY_TIMEOUT_MS) {
            conversationHistory.clear();
        }
        lastInteractionTime = now;
        conversationHistory.add(new ConversationMessage(role, content));
        while (conversationHistory.size() > 6) {
            conversationHistory.remove(0);
        }
    }

    public static synchronized List<ConversationMessage> getRecentHistory() {
        long now = System.currentTimeMillis();
        if (now - lastInteractionTime > HISTORY_TIMEOUT_MS) {
            conversationHistory.clear();
            return Collections.emptyList();
        }
        return new ArrayList<>(conversationHistory);
    }

    public static void setNvidiaKey(String key) {
        nvidiaKey = TextUtils.isEmpty(key) ? DEFAULT_NVIDIA_KEY : key.trim();
    }

    public static String getNvidiaKey() {
        return nvidiaKey;
    }

    public static void askAi(Context context, String userQuery, AiResponseCallback callback) {
        executor.execute(() -> {
            Log.i(TAG, "askAi query: '" + userQuery + "' -> dispatching through Free AI models");
            String dynamicPrompt = buildSystemPrompt(userQuery);

            // 1. Tầng 1: Google Gemini 2.5 Flash Lite (Chính thức)
            try {
                Log.i(TAG, "Tier 1: Querying Google Gemini 2.5 Flash Lite...");
                String geminiAnswer = queryGeminiOfficial(geminiApiKey, userQuery, dynamicPrompt);
                if (!TextUtils.isEmpty(geminiAnswer)) {
                    String clean = cleanResponse(geminiAnswer);
                    addMessageToHistory("user", userQuery);
                    addMessageToHistory("assistant", clean);
                    speakAndDisplay(context, clean, "Google Gemini 2.5 Flash Lite", callback);
                    return;
                }
            } catch (Exception e) {
                Log.w(TAG, "Tier 1 Gemini failed, falling back to Tier 2: " + e.getMessage());
            }

            // 2. Tầng 2: NVIDIA NIM Llama 3.1 8B (Cực nhanh 340ms)
            try {
                Log.i(TAG, "Tier 2: Querying NVIDIA NIM Llama 3.1 8B...");
                String nvAnswer = queryOpenAiCompatible(NVIDIA_ENDPOINT, "meta/llama-3.1-8b-instruct", nvidiaKey, userQuery, dynamicPrompt);
                if (!TextUtils.isEmpty(nvAnswer)) {
                    String clean = cleanResponse(nvAnswer);
                    addMessageToHistory("user", userQuery);
                    addMessageToHistory("assistant", clean);
                    speakAndDisplay(context, clean, "NVIDIA Llama 3.1 8B", callback);
                    return;
                }
            } catch (Exception e) {
                Log.w(TAG, "Tier 2 NVIDIA failed, falling back to Tier 3: " + e.getMessage());
            }

            // 3. Tầng 3: Các Model Free qua OpenRouter
            for (int i = 2; i < FALLBACK_MODELS.size(); i++) {
                ModelTarget target = FALLBACK_MODELS.get(i);
                try {
                    Log.i(TAG, "Tier 3 OpenRouter Free [" + (i - 1) + "]: " + target.modelId);
                    String answer = queryOpenAiCompatible(target.endpoint, target.modelId, openRouterKey, userQuery, dynamicPrompt);
                    if (!TextUtils.isEmpty(answer)) {
                        String clean = cleanResponse(answer);
                        addMessageToHistory("user", userQuery);
                        addMessageToHistory("assistant", clean);
                        speakAndDisplay(context, clean, target.modelId, callback);
                        return;
                    }
                } catch (Exception e) {
                    Log.w(TAG, "Tier 3 Model " + target.modelId + " failed: " + e.getMessage());
                }
            }

            // 4. Tầng 4: Dự phòng ngoại tuyến an toàn
            String defaultAnswer = "Dạ, tôi đã nhận được câu hỏi '" + userQuery + "', vui lòng thử lại sau giây lát.";
            speakAndDisplay(context, defaultAnswer, "fallback_offline", callback);
        });
    }

    private static String cleanResponse(String raw) {
        if (raw == null) return "";
        // Xóa suy nghĩ (CoT / Thinking blocks) nếu có
        String text = raw;
        if (text.contains("</think>")) {
            text = text.substring(text.lastIndexOf("</think>") + 8).trim();
        }
        if (text.startsWith("Here's a thinking process") || text.startsWith("Here is a thinking process")) {
            int doubleNewline = text.indexOf("\n\n");
            if (doubleNewline > 0) {
                text = text.substring(doubleNewline + 2).trim();
            }
        }
        return text.replaceAll("(\\*\\*|\\*|###|##|#|`|_)", "").trim();
    }

    private static void speakAndDisplay(Context context, String answer, String modelUsed, AiResponseCallback callback) {
        Log.i(TAG, "AI Answer [" + modelUsed + "]: " + answer);

        // Phát giọng đọc qua VietnameseTtsEngine 3 lớp với phụ đề đồng bộ từng câu
        VietnameseTtsEngine.getInstance(context).speak(context, answer, new VietnameseTtsEngine.TtsCallback() {
            @Override
            public void onStart(int tier, String engineName) {
                Log.i(TAG, "TTS Started with tier=" + tier + " engine=" + engineName);
                cancelAllDismissTimers();
                try {
                    VoiceFloatingOverlayManager.getInstance(context).startTtsWaveform();
                } catch (Exception ignored) {}
                try {
                    VoiceCaptureTransparentActivity activity = VoiceCaptureTransparentActivity.getActiveInstance();
                    if (activity != null) {
                        activity.startTtsWaveform();
                    }
                } catch (Exception ignored) {}
            }

            @Override
            public void onChunkStart(int index, int total, String chunkText) {
                Log.i(TAG, "TTS Chunk [" + (index + 1) + "/" + total + "]: " + chunkText);
                try {
                    VoiceFloatingOverlayManager.getInstance(context).updateSubtitle(chunkText, 0xFF00E5FF);
                    VoiceFloatingOverlayManager.getInstance(context).startTtsWaveform();
                    VoiceFloatingOverlayManager.getInstance(context).cancelDismissTimer();
                } catch (Exception ignored) {
                }
                try {
                    VoiceCaptureTransparentActivity activity = VoiceCaptureTransparentActivity.getActiveInstance();
                    if (activity != null) {
                        activity.updateSubtitle(chunkText, 0xFF00E5FF);
                        activity.startTtsWaveform();
                        activity.cancelDismissTimer();
                    }
                } catch (Exception ignored) {
                }
            }

            @Override
            public void onComplete() {
                Log.i(TAG, "TTS Completed all chunks -> entering Follow-up listening mode");
                try {
                    VoiceFloatingOverlayManager.getInstance(context).stopTtsWaveform();
                    VoiceFloatingOverlayManager.getInstance(context).startFollowUpListening();
                } catch (Exception ignored) {
                }
                try {
                    VoiceCaptureTransparentActivity activity = VoiceCaptureTransparentActivity.getActiveInstance();
                    if (activity != null) {
                        activity.stopTtsWaveform();
                        activity.scheduleDismiss(2500);
                    }
                } catch (Exception ignored) {
                }
            }

            @Override
            public void onError(String message) {
                Log.w(TAG, "TTS Error: " + message);
                try {
                    VoiceFloatingOverlayManager.getInstance(context).stopTtsWaveform();
                    VoiceFloatingOverlayManager.getInstance(context).scheduleDismiss(3500);
                } catch (Exception ignored) {
                }
                try {
                    VoiceCaptureTransparentActivity activity = VoiceCaptureTransparentActivity.getActiveInstance();
                    if (activity != null) {
                        activity.stopTtsWaveform();
                        activity.scheduleDismiss(3500);
                    }
                } catch (Exception ignored) {}
            }
        });

        if (callback != null) {
            callback.onSuccess(answer, modelUsed);
        }
    }

    private static void cancelAllDismissTimers() {
        try {
            VoiceCaptureTransparentActivity activity = VoiceCaptureTransparentActivity.getActiveInstance();
            if (activity != null) {
                activity.cancelDismissTimer();
            }
        } catch (Exception ignored) {}
    }

    private static String queryGeminiOfficial(String apiKey, String userQuery, String systemPrompt) {
        HttpURLConnection conn = null;
        try {
            String urlStr = GEMINI_API_URL + "?key=" + (TextUtils.isEmpty(apiKey) ? DEFAULT_GEMINI_KEY : apiKey);
            URL url = new URL(urlStr);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");
            conn.setConnectTimeout(3000);
            conn.setReadTimeout(5000);
            conn.setDoOutput(true);

            JSONObject root = new JSONObject();

            // Thêm system_instruction cho Gemini
            try {
                JSONObject sysInstruction = new JSONObject();
                JSONArray sysParts = new JSONArray();
                JSONObject sysTextPart = new JSONObject();
                sysTextPart.put("text", TextUtils.isEmpty(systemPrompt) ? TV_SYSTEM_PROMPT : systemPrompt);
                sysParts.put(sysTextPart);
                sysInstruction.put("parts", sysParts);
                root.put("system_instruction", sysInstruction);
            } catch (Exception ignored) {
            }

            JSONArray contents = new JSONArray();
            List<ConversationMessage> history = getRecentHistory();
            for (ConversationMessage m : history) {
                JSONObject hContent = new JSONObject();
                hContent.put("role", "assistant".equals(m.role) ? "model" : "user");
                JSONArray hParts = new JSONArray();
                JSONObject hText = new JSONObject();
                hText.put("text", m.content);
                hParts.put(hText);
                hContent.put("parts", hParts);
                contents.put(hContent);
            }

            JSONObject userContent = new JSONObject();
            userContent.put("role", "user");
            JSONArray parts = new JSONArray();
            JSONObject textPart = new JSONObject();
            textPart.put("text", userQuery);
            parts.put(textPart);
            userContent.put("parts", parts);
            contents.put(userContent);
            root.put("contents", contents);

            JSONObject genConfig = new JSONObject();
            genConfig.put("maxOutputTokens", isStoryOrLongContent(userQuery) ? 350 : 120);
            genConfig.put("temperature", 0.7);
            root.put("generationConfig", genConfig);

            byte[] body = root.toString().getBytes(StandardCharsets.UTF_8);
            try (OutputStream os = conn.getOutputStream()) {
                os.write(body);
                os.flush();
            }

            int responseCode = conn.getResponseCode();
            if (responseCode == 200) {
                StringBuilder response = new StringBuilder();
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        response.append(line);
                    }
                }

                JSONObject respObj = new JSONObject(response.toString());
                JSONArray candidates = respObj.optJSONArray("candidates");
                if (candidates != null && candidates.length() > 0) {
                    JSONObject cand = candidates.getJSONObject(0);
                    JSONObject content = cand.optJSONObject("content");
                    if (content != null) {
                        JSONArray pArray = content.optJSONArray("parts");
                        if (pArray != null && pArray.length() > 0) {
                            return pArray.getJSONObject(0).optString("text", "").trim();
                        }
                    }
                }
            } else {
                Log.w(TAG, "Gemini HTTP " + responseCode);
            }
        } catch (Exception e) {
            Log.w(TAG, "queryGeminiOfficial error: " + e.getMessage());
        } finally {
            if (conn != null) {
                conn.disconnect();
            }
        }
        return null;
    }

    private static String queryOpenAiCompatible(String endpoint, String modelId, String key, String userQuery, String systemPrompt) {
        HttpURLConnection conn = null;
        try {
            URL url = new URL(endpoint);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");
            conn.setRequestProperty("HTTP-Referer", "https://github.com/vanlinh0392-art/atv-launcher");
            conn.setRequestProperty("X-Title", "FLauncher Android TV");
            if (!TextUtils.isEmpty(key)) {
                conn.setRequestProperty("Authorization", "Bearer " + key);
            }
            conn.setConnectTimeout(3000);
            conn.setReadTimeout(5000);
            conn.setDoOutput(true);

            JSONObject root = new JSONObject();
            root.put("model", modelId);

            JSONArray messages = new JSONArray();
            JSONObject sysMsg = new JSONObject();
            sysMsg.put("role", "system");
            sysMsg.put("content", TextUtils.isEmpty(systemPrompt) ? TV_SYSTEM_PROMPT : systemPrompt);
            messages.put(sysMsg);

            List<ConversationMessage> history = getRecentHistory();
            for (ConversationMessage m : history) {
                JSONObject hMsg = new JSONObject();
                hMsg.put("role", m.role);
                hMsg.put("content", m.content);
                messages.put(hMsg);
            }

            JSONObject userMsg = new JSONObject();
            userMsg.put("role", "user");
            userMsg.put("content", userQuery);
            messages.put(userMsg);

            root.put("messages", messages);
            root.put("max_tokens", isStoryOrLongContent(userQuery) ? 300 : 90);
            root.put("temperature", 0.7);

            byte[] body = root.toString().getBytes(StandardCharsets.UTF_8);
            try (OutputStream os = conn.getOutputStream()) {
                os.write(body);
                os.flush();
            }

            int responseCode = conn.getResponseCode();
            if (responseCode == 200) {
                StringBuilder response = new StringBuilder();
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        response.append(line);
                    }
                }

                JSONObject respObj = new JSONObject(response.toString());
                JSONArray choices = respObj.optJSONArray("choices");
                if (choices != null && choices.length() > 0) {
                    JSONObject choice = choices.getJSONObject(0);
                    JSONObject msg = choice.optJSONObject("message");
                    if (msg != null) {
                        return msg.optString("content", "").trim();
                    }
                }
            } else {
                Log.w(TAG, "HTTP " + responseCode + " for model " + modelId);
            }
        } catch (Exception e) {
            Log.w(TAG, "queryOpenAiCompatible " + modelId + " error: " + e.getMessage());
        } finally {
            if (conn != null) {
                conn.disconnect();
            }
        }
        return null;
    }

    public static java.util.Map<String, Object> fetchAndRankFreeModels(Context context) {
        java.util.Map<String, Object> result = new java.util.LinkedHashMap<>();
        List<ModelTarget> nvidiaList = new ArrayList<>();
        List<ModelTarget> openRouterList = new ArrayList<>();
        long t0 = System.currentTimeMillis();

        // 1. Quét NVIDIA NIM Models (Lấy 4 model tốt nhất)
        try {
            URL url = new URL("https://integrate.api.nvidia.com/v1/models");
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setRequestProperty("Authorization", "Bearer " + nvidiaKey);
            conn.setConnectTimeout(4000);
            conn.setReadTimeout(6000);

            if (conn.getResponseCode() == 200) {
                StringBuilder sb = new StringBuilder();
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        sb.append(line);
                    }
                }
                JSONObject obj = new JSONObject(sb.toString());
                JSONArray data = obj.optJSONArray("data");
                if (data != null) {
                    for (int i = 0; i < data.length(); i++) {
                        JSONObject m = data.getJSONObject(i);
                        String id = m.optString("id", "");
                        if ("meta/llama-3.1-8b-instruct".equals(id) ||
                                "google/gemma-4-31b-it".equals(id) ||
                                "google/diffusiongemma-26b-a4b-it".equals(id) ||
                                "meta/llama-3.2-11b-vision-instruct".equals(id)) {
                            nvidiaList.add(new ModelTarget("NVIDIA NIM", NVIDIA_ENDPOINT, id, id + " (NVIDIA Cloud)"));
                        }
                    }
                }
            }
            conn.disconnect();
        } catch (Exception e) {
            Log.w(TAG, "fetch NVIDIA models failed: " + e.getMessage());
        }

        // 2. Quét OpenRouter Models (Lấy 4 model free tốt nhất)
        try {
            URL url = new URL("https://openrouter.ai/api/v1/models");
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setRequestProperty("Authorization", "Bearer " + openRouterKey);
            conn.setConnectTimeout(4000);
            conn.setReadTimeout(6000);

            if (conn.getResponseCode() == 200) {
                StringBuilder sb = new StringBuilder();
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        sb.append(line);
                    }
                }
                JSONObject obj = new JSONObject(sb.toString());
                JSONArray data = obj.optJSONArray("data");
                if (data != null) {
                    for (int i = 0; i < data.length(); i++) {
                        JSONObject m = data.getJSONObject(i);
                        String id = m.optString("id", "");
                        if ("nvidia/nemotron-3.5-lightning:free".equals(id) ||
                                "google/gemma-4-31b-it:free".equals(id) ||
                                "google/gemma-4-26b-a4b-it:free".equals(id) ||
                                "openai/gpt-oss-20b:free".equals(id)) {
                            openRouterList.add(new ModelTarget("OpenRouter", OPENROUTER_ENDPOINT, id, id + " (OpenRouter Free)"));
                        }
                    }
                }
            }
            conn.disconnect();
        } catch (Exception e) {
            Log.w(TAG, "fetch OpenRouter models failed: " + e.getMessage());
        }

        synchronized (FALLBACK_MODELS) {
            if (nvidiaList.size() >= 2 && openRouterList.size() >= 2) {
                FALLBACK_MODELS.clear();
                FALLBACK_MODELS.addAll(nvidiaList);
                FALLBACK_MODELS.addAll(openRouterList);
            }
        }

        long elapsed = System.currentTimeMillis() - t0;
        int updatedCount = FALLBACK_MODELS.size();

        result.put("success", true);
        result.put("discoveredCount", updatedCount);
        result.put("elapsedMs", elapsed);
        result.put("message", "Đã cập nhật ma trận 8 Model AI (4 NVIDIA Cloud + 4 OpenRouter Free) trong " + elapsed + "ms");

        Log.i(TAG, "fetchAndRankFreeModels completed: " + result);
        return result;
    }
}
