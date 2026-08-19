package com.atv.launcher.systembridge.shared.voice;

import android.app.SearchManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.media.AudioManager;
import android.net.Uri;
import android.os.SystemClock;
import android.text.TextUtils;
import android.util.Log;
import android.view.KeyEvent;

import java.text.Normalizer;
import java.util.Calendar;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import com.atv.launcher.systembridge.shared.appindex.AppIndexStore;

public final class SmartVoiceDispatcher {
    private static final String TAG = "SmartVoiceDispatcher";

    public static final String XEMTV_PACKAGE = "com.xemtv.app";
    public static final String SMARTTUBE_PACKAGE = "org.smarttube.stable";
    public static final String YOUTUBE_TV_PACKAGE = "com.google.android.youtube.tv";

    public static final String TYPE_TV_CHANNEL = "tv_channel";
    public static final String TYPE_OPEN_APP = "open_app";
    public static final String TYPE_MEDIA_SEARCH = "media_search";
    public static final String TYPE_SYSTEM_ACTION = "system_action";
    public static final String TYPE_ASSISTANT_FALLBACK = "assistant_fallback";

    private static final Pattern CHANNEL_PATTERN = Pattern.compile(
            "^(?:mở|bật|xem|chuyển\\s*(?:sang)?|kênh)?\\s*(?:kênh|kenh)?\\s*(vtv\\s*\\d+|vtv\\s*cần\\s*thơ|vtv\\s*can\\s*tho|thvl\\s*\\d+|htv\\s*\\d+|vtc\\s*\\d+|sctv\\s*\\d+|antv|qpvn|bóng\\s*đá|thể\\s*thao|k\\+\\s*\\w+)",
            Pattern.CASE_INSENSITIVE
    );

    public static final Map<String, String> COMMON_APP_ALIASES = new HashMap<>();
    static {
        COMMON_APP_ALIASES.put("youtube", SMARTTUBE_PACKAGE);
        COMMON_APP_ALIASES.put("you tube", SMARTTUBE_PACKAGE);
        COMMON_APP_ALIASES.put("du tu be", SMARTTUBE_PACKAGE);
        COMMON_APP_ALIASES.put("smarttube", SMARTTUBE_PACKAGE);
        COMMON_APP_ALIASES.put("smart tube", SMARTTUBE_PACKAGE);
        COMMON_APP_ALIASES.put("xemtv", XEMTV_PACKAGE);
        COMMON_APP_ALIASES.put("xem tv", XEMTV_PACKAGE);
        COMMON_APP_ALIASES.put("truyền hình", XEMTV_PACKAGE);
        COMMON_APP_ALIASES.put("truyen hinh", XEMTV_PACKAGE);
        COMMON_APP_ALIASES.put("tivi", XEMTV_PACKAGE);
        COMMON_APP_ALIASES.put("cốc cốc", "com.coccoc.trinhduyet_tv");
        COMMON_APP_ALIASES.put("coc coc", "com.coccoc.trinhduyet_tv");
        COMMON_APP_ALIASES.put("trình duyệt", "com.coccoc.trinhduyet_tv");
        COMMON_APP_ALIASES.put("trinh duyet", "com.coccoc.trinhduyet_tv");
        COMMON_APP_ALIASES.put("kho phim", "com.dinhlap.movielegend");
        COMMON_APP_ALIASES.put("movie legend", "com.dinhlap.movielegend");
        COMMON_APP_ALIASES.put("dlstore", "com.dinhlap.dlstore");
        COMMON_APP_ALIASES.put("dl store", "com.dinhlap.dlstore");
        COMMON_APP_ALIASES.put("chợ ứng dụng", "com.dinhlap.dlstore");
        COMMON_APP_ALIASES.put("stremio", "com.stremio.one");
        COMMON_APP_ALIASES.put("cloudstream", "com.lagradost.cloudstream3.prerelease");
        COMMON_APP_ALIASES.put("telegram", "org.telegram.messenger.web");
        COMMON_APP_ALIASES.put("quản lý file", "com.rs.explorer.filemanager");
        COMMON_APP_ALIASES.put("file manager", "com.rs.explorer.filemanager");
        COMMON_APP_ALIASES.put("monster tv", "com.monster.tv");
        COMMON_APP_ALIASES.put("monstertv", "com.monster.tv");
        COMMON_APP_ALIASES.put("vtv go", "vn.vtv.vtvgo");
        COMMON_APP_ALIASES.put("vtvgo", "vn.vtv.vtvgo");
        COMMON_APP_ALIASES.put("tv360", "com.viettel.tv360");
        COMMON_APP_ALIASES.put("tv 360", "com.viettel.tv360");
        COMMON_APP_ALIASES.put("fpt play", "com.fptplay.activity");
        COMMON_APP_ALIASES.put("fptplay", "com.fptplay.activity");
        COMMON_APP_ALIASES.put("mytv", "com.vnpt.mytv");
        COMMON_APP_ALIASES.put("my tv", "com.vnpt.mytv");
        COMMON_APP_ALIASES.put("kodi", "org.xbmc.kodi");
        COMMON_APP_ALIASES.put("tivimate", "ar.tvplayer.tv");
        COMMON_APP_ALIASES.put("ch play", "com.android.vending");
        COMMON_APP_ALIASES.put("play store", "com.android.vending");
        COMMON_APP_ALIASES.put("cài đặt", "com.android.tv.settings");
        COMMON_APP_ALIASES.put("cai dat", "com.android.tv.settings");
        COMMON_APP_ALIASES.put("settings", "com.android.tv.settings");
    }

    private SmartVoiceDispatcher() {
    }

    public static Map<String, Object> dispatch(Context context, String rawQuery) {
        Map<String, Object> result = new LinkedHashMap<>();
        if (context == null || TextUtils.isEmpty(rawQuery)) {
            result.put("success", false);
            result.put("type", "none");
            result.put("message", "Query is empty");
            return result;
        }

        String query = rawQuery.trim();
        String normalized = stripAccents(query).toLowerCase(Locale.ROOT).replaceAll("\\s+", " ").trim();
        String lowerQuery = query.toLowerCase(Locale.ROOT).replaceAll("\\s+", " ").trim();

        Log.i(TAG, "dispatch voice query: '" + query + "' (normalized: '" + normalized + "')");

        // 0. Kiểm tra lệnh phần cứng TV và hỏi đáp cục bộ 0ms (Âm lượng, Hẹn giờ ngủ, Media, Đồng hồ, Lời chào)
        Map<String, Object> localAction = handleHardwareAndFastLocalCommands(context, query, lowerQuery, normalized);
        if (localAction != null) {
            return localAction;
        }

        // 1. Kiểm tra lệnh kênh TV (VTV, HTV, THVL, VTC, SCTV...)
        String channelName = extractTvChannel(query, lowerQuery, normalized);
        if (channelName != null) {
            boolean launched = launchXemTvChannel(context, channelName);
            result.put("success", launched);
            result.put("type", TYPE_TV_CHANNEL);
            result.put("target", channelName);
            result.put("package", XEMTV_PACKAGE);
            String msg = launched
                    ? "Đang mở kênh " + channelName + " trên XemTV"
                    : "Không thể khởi chạy kênh " + channelName;
            result.put("message", msg);
            if (launched) {
                com.atv.launcher.systembridge.tts.VietnameseTtsEngine.getInstance(context).speak(context, msg, null);
            }
            return result;
        }

        // 2. Nhận diện các lệnh liên quan Bài Hát, Ca Khúc, Nhạc, YouTube, Karaoke, Video
        if (isMediaOrSongOrYoutubeQuery(lowerQuery, normalized)) {
            String cleanSearchQuery = extractCleanMediaSearchQuery(query);
            boolean searchLaunched = launchMediaSearch(context, cleanSearchQuery);
            result.put("success", searchLaunched);
            result.put("type", TYPE_MEDIA_SEARCH);
            result.put("query", cleanSearchQuery);
            String msg = searchLaunched
                    ? "Đang tìm kiếm " + cleanSearchQuery + " trên YouTube"
                    : "Không thể mở tìm kiếm cho: " + cleanSearchQuery;
            result.put("message", msg);
            if (searchLaunched) {
                com.atv.launcher.systembridge.tts.VietnameseTtsEngine.getInstance(context).speak(context, msg, null);
            }
            return result;
        }

        // 3. Kiểm tra lệnh mở ứng dụng (Mở Cốc Cốc, Mở Cài đặt, Mở XemTV...)
        String appQuery = extractAppQuery(lowerQuery, normalized);
        if (appQuery != null) {
            Map<String, Object> appLaunchResult = tryLaunchApp(context, appQuery);
            if (Boolean.TRUE.equals(appLaunchResult.get("success"))) {
                result.putAll(appLaunchResult);
                result.put("type", TYPE_OPEN_APP);
                return result;
            }
        }

        // 4. Kiểm tra câu hỏi / đàm thoại AI (Thời tiết, kiến thức, kể chuyện, hỏi đáp...)
        if (com.atv.launcher.systembridge.ai.AiVoiceAssistantClient.isQuestionOrConversation(query)) {
            com.atv.launcher.systembridge.ai.AiVoiceAssistantClient.askAi(context, query, null);
            result.put("success", true);
            result.put("type", "ai_qa");
            result.put("query", query);
            result.put("message", "Đang hỏi Trợ lý AI: " + query);
            return result;
        }

        // 5. Kiểm tra lệnh tìm kiếm chung (Tìm kiếm..., Tìm...)
        String searchQuery = extractMediaSearchQuery(lowerQuery, normalized);
        if (searchQuery != null) {
            boolean searchLaunched = launchMediaSearch(context, searchQuery);
            result.put("success", searchLaunched);
            result.put("type", TYPE_MEDIA_SEARCH);
            result.put("query", searchQuery);
            result.put("message", searchLaunched
                    ? "Đang tìm kiếm: " + searchQuery
                    : "Không thể mở tìm kiếm cho: " + searchQuery);
            return result;
        }

        // 6. Thử mở app trực tiếp nếu query trùng tên app
        Map<String, Object> directAppMatch = tryLaunchApp(context, lowerQuery);
        if (Boolean.TRUE.equals(directAppMatch.get("success"))) {
            result.putAll(directAppMatch);
            result.put("type", TYPE_OPEN_APP);
            return result;
        }

        // 7. Fallback cuối cùng: Tìm kiếm media trên YouTube/Katniss
        boolean fallbackLaunched = launchMediaSearch(context, query);
        result.put("success", fallbackLaunched);
        result.put("type", TYPE_MEDIA_SEARCH);
        result.put("query", query);
        result.put("message", "Đang tìm kiếm: " + query);
        return result;
    }

    public static boolean isMediaOrSongOrYoutubeQuery(String lowerQuery, String normalized) {
        if (TextUtils.isEmpty(lowerQuery)) return false;

        String[] mediaKeywords = {
                "bài hát", "bai hat", "ca khúc", "ca khuc",
                "mở bài hát", "mo bai hat", "nghe bài hát", "nghe bai hat", "bật bài hát", "bat bai hat",
                "nghe bài", "nghe bai", "mở bài", "mo bai", "bật bài", "bat bai",
                "nghe nhạc", "nghe nhac", "mở nhạc", "mo nhac", "bật nhạc", "bat nhac",
                "nhạc trẻ", "nhac tre", "nhạc trữ tình", "nhac tru tinh", "nhạc vàng", "nhac vang",
                "nhạc sống", "nhac song", "nhạc remix", "nhac remix", "nhạc đỏ", "nhac do",
                "nhạc không lời", "nhac khong loi", "nhạc tết", "nhac tet", "nhạc thiền", "nhac thien",
                "nhạc bolero", "nhac bolero", "nhạc edm", "nhac edm", "nhạc rap", "nhac rap",
                "nhạc", "nhac",
                "hát karaoke", "hat karaoke", "mở karaoke", "mo karaoke", "bật karaoke", "bat karaoke",
                "karaoke",
                "hát bài", "hat bai", "hát", "hat",
                "mở youtube", "mo youtube", "bật youtube", "bat youtube", "xem youtube", "xem du tu be",
                "du tu be", "you tube", "youtube", "smarttube", "smart tube",
                "xem video", "xem clip", "mở video", "mo video", "video", "clip",
                "xem phim", "mở phim", "mo phim", "phim",
                "tìm bài hát", "tim bai hat", "tìm nhạc", "tim nhac", "tìm video", "tim video",
                "tìm kiếm", "tim kiem"
        };

        for (String kw : mediaKeywords) {
            if (lowerQuery.startsWith(kw + " ") || lowerQuery.equals(kw)
                    || normalized.startsWith(kw + " ") || normalized.equals(kw)) {
                return true;
            }
        }

        return lowerQuery.contains("trên youtube") || lowerQuery.contains("tren youtube")
                || lowerQuery.contains("trên smarttube") || lowerQuery.contains("tren smarttube")
                || lowerQuery.contains("trên du tu be") || lowerQuery.contains("tren du tu be");
    }

    public static String extractCleanMediaSearchQuery(String rawQuery) {
        if (TextUtils.isEmpty(rawQuery)) return "";
        String clean = rawQuery.trim();

        // 1. Loại bỏ các đuôi 'trên youtube', 'trên smarttube'
        clean = clean.replaceAll("(?i)\\s*(trên|tren|ở|o)\\s*(youtube|smarttube|you tube|du tu be)\\s*$", "").trim();

        // 2. Xử lý chuyên sâu chế độ Hát Karaoke 1 chạm
        String lower = clean.toLowerCase(Locale.ROOT);
        if (lower.startsWith("hát bài ") || lower.startsWith("hat bai ") ||
                lower.startsWith("hát karaoke ") || lower.startsWith("hat karaoke ") ||
                lower.startsWith("karaoke bài ") || lower.startsWith("karaoke ")) {
            String sub = clean.replaceAll("(?i)^(?:hát\\s*karaoke|hat\\s*karaoke|hát\\s*bài|hat\\s*bai|karaoke\\s*bài|karaoke\\s*bai|karaoke|hát|hat)\\s*", "").trim();
            return "karaoke " + sub;
        }

        String[] leadingVerbs = {
                "mở bài hát ", "mo bai hat ", "nghe bài hát ", "nghe bai hat ", "bật bài hát ", "bat bai hat ",
                "nghe bài ", "nghe bai ", "mở bài ", "mo bai ", "bật bài ", "bat bai ",
                "nghe nhạc ", "nghe nhac ", "mở nhạc ", "mo nhac ", "bật nhạc ", "bat nhac ",
                "hát karaoke ", "hat karaoke ", "mở karaoke ", "mo karaoke ", "bật karaoke ", "bat karaoke ",
                "hát bài ", "hat bai ",
                "mở youtube tìm kiếm ", "mở youtube tìm ", "mở youtube ", "mo youtube ",
                "bật youtube tìm ", "bật youtube ", "bat youtube ",
                "xem youtube ", "xem du tu be ", "youtube ", "du tu be ", "smarttube ",
                "xem video ", "xem clip ", "mở video ", "mo video ",
                "xem phim ", "mở phim ", "mo phim ",
                "tìm bài hát ", "tim bai hat ", "tìm nhạc ", "tim nhac ", "tìm video ", "tim video ",
                "tìm kiếm ", "tim kiem ", "tìm ", "tim "
        };

        for (String verb : leadingVerbs) {
            if (lower.startsWith(verb)) {
                String sub = clean.substring(verb.length()).trim();
                if (!TextUtils.isEmpty(sub)) {
                    if (verb.contains("karaoke") && !sub.toLowerCase(Locale.ROOT).startsWith("karaoke")) {
                        return "karaoke " + sub;
                    }
                    if (verb.contains("nhạc") && !sub.toLowerCase(Locale.ROOT).startsWith("nhạc") && !sub.toLowerCase(Locale.ROOT).startsWith("bài")) {
                        return "nhạc " + sub;
                    }
                    return sub;
                }
            }
        }
        return clean;
    }

    public static String extractTvChannel(String query, String lowerQuery, String normalized) {
        Matcher matcher = CHANNEL_PATTERN.matcher(query);
        if (matcher.find()) {
            return normalizeChannelName(matcher.group(1));
        }

        String[] prefixes = {"mở kênh ", "mo kenh ", "bật kênh ", "bat kenh ", "xem kênh ", "xem kenh ", "chuyển kênh ", "chuyen kenh ", "kênh ", "kenh "};
        for (String prefix : prefixes) {
            if (lowerQuery.startsWith(prefix)) {
                String candidate = lowerQuery.substring(prefix.length()).trim();
                if (isKnownChannel(candidate)) {
                    return normalizeChannelName(candidate);
                }
            }
            if (normalized.startsWith(prefix)) {
                String candidate = normalized.substring(prefix.length()).trim();
                if (isKnownChannel(candidate)) {
                    return normalizeChannelName(candidate);
                }
            }
        }

        if (isKnownChannel(lowerQuery) || isKnownChannel(normalized)) {
            return normalizeChannelName(query);
        }

        return null;
    }

    private static boolean isKnownChannel(String s) {
        String clean = s.replaceAll("\\s+", "").toLowerCase(Locale.ROOT);
        return clean.matches("^(vtv|htv|thvl|vtc|sctv)\\d+$")
                || clean.equals("vtvcantho") || clean.equals("vtvcan tho")
                || clean.equals("antv") || clean.equals("qpvn")
                || clean.equals("bongda") || clean.equals("thethao")
                || clean.startsWith("k+");
    }

    private static String normalizeChannelName(String raw) {
        String clean = raw.replaceAll("\\s+", "").toUpperCase(Locale.ROOT);
        if (clean.startsWith("VTV") && clean.length() > 3) {
            String suffix = clean.substring(3);
            if (suffix.matches("\\d+")) {
                return "VTV" + suffix;
            }
        }
        if (clean.startsWith("HTV") && clean.length() > 3) {
            String suffix = clean.substring(3);
            if (suffix.matches("\\d+")) {
                return "HTV" + suffix;
            }
        }
        if (clean.startsWith("THVL") && clean.length() > 4) {
            String suffix = clean.substring(4);
            if (suffix.matches("\\d+")) {
                return "THVL" + suffix;
            }
        }
        if (clean.startsWith("VTC") && clean.length() > 3) {
            String suffix = clean.substring(3);
            if (suffix.matches("\\d+")) {
                return "VTC" + suffix;
            }
        }
        if (clean.startsWith("SCTV") && clean.length() > 4) {
            String suffix = clean.substring(4);
            if (suffix.matches("\\d+")) {
                return "SCTV" + suffix;
            }
        }
        return raw.trim().toUpperCase(Locale.ROOT);
    }

    public static boolean launchXemTvChannel(Context context, String channelName) {
        Context appContext = context.getApplicationContext();
        PackageManager pm = appContext.getPackageManager();

        // 1. Thử Intent ACTION_VIEW_CHANNEL tới com.xemtv.app
        try {
            Intent intent = new Intent("com.xemtv.app.ACTION_VIEW_CHANNEL")
                    .setPackage(XEMTV_PACKAGE)
                    .putExtra("query", channelName)
                    .putExtra(SearchManager.QUERY, channelName)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            appContext.startActivity(intent);
            Log.i(TAG, "Launched XemTV channel via ACTION_VIEW_CHANNEL: " + channelName);
            return true;
        } catch (Exception e1) {
            Log.w(TAG, "Failed ACTION_VIEW_CHANNEL, trying SearchableActivity", e1);
        }

        // 2. Thử SearchableActivity của com.xemtv.app
        try {
            Intent searchIntent = new Intent(Intent.ACTION_SEARCH)
                    .setClassName(XEMTV_PACKAGE, "com.xemtv.app.ui.search.SearchableActivity")
                    .putExtra(SearchManager.QUERY, channelName)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            appContext.startActivity(searchIntent);
            Log.i(TAG, "Launched XemTV channel via SearchableActivity: " + channelName);
            return true;
        } catch (Exception e2) {
            Log.w(TAG, "Failed SearchableActivity, trying Main Launch Intent", e2);
        }

        // 3. Thử Launch Intent với query extra
        try {
            Intent launchIntent = pm.getLaunchIntentForPackage(XEMTV_PACKAGE);
            if (launchIntent != null) {
                launchIntent.putExtra("query", channelName);
                launchIntent.putExtra(SearchManager.QUERY, channelName);
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                appContext.startActivity(launchIntent);
                Log.i(TAG, "Launched XemTV package with extra query: " + channelName);
                return true;
            }
        } catch (Exception e3) {
            Log.e(TAG, "Failed to launch XemTV", e3);
        }

        // 4. Nếu chưa cài XemTV, tìm kiếm video kênh trên SmartTube/YouTube
        Log.w(TAG, "XemTV not available, falling back to media search for channel: " + channelName);
        return launchMediaSearch(context, "Kênh " + channelName);
    }

    public static String extractAppQuery(String lowerQuery, String normalized) {
        String[] prefixes = {"mở ứng dụng ", "mo ung dung ", "mở app ", "mo app ", "mở ", "mo ", "bật ", "bat ", "chạy ", "chay ", "vào ", "vao ", "open ", "launch "};
        for (String prefix : prefixes) {
            if (lowerQuery.startsWith(prefix)) {
                return lowerQuery.substring(prefix.length()).trim();
            }
            if (normalized.startsWith(prefix)) {
                return normalized.substring(prefix.length()).trim();
            }
        }
        return null;
    }

    public static Map<String, Object> tryLaunchApp(Context context, String appNameQuery) {
        Map<String, Object> result = new LinkedHashMap<>();
        if (TextUtils.isEmpty(appNameQuery)) {
            result.put("success", false);
            return result;
        }

        Context appContext = context.getApplicationContext();
        PackageManager pm = appContext.getPackageManager();

        // 1. Tra cứu qua AppIndexStore (Hỗ trợ Khớp Mờ 4 Tầng & Alias Phiên Âm)
        AppIndexStore.MatchResult match = AppIndexStore.getInstance(context).findBestMatch(appNameQuery);
        if (match != null && match.app != null) {
            String pkg = match.app.packageName;
            Intent launchIntent = pm.getLaunchIntentForPackage(pkg);
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                appContext.startActivity(launchIntent);
                result.put("success", true);
                result.put("package", pkg);
                result.put("target", match.app.label);
                String msg = "Đang mở " + match.app.label;
                result.put("message", msg);
                com.atv.launcher.systembridge.tts.VietnameseTtsEngine.getInstance(context).speak(context, msg, null);
                Log.i(TAG, "Launched app via AppIndexStore [" + match.matchType + " score=" + match.score + "]: " + pkg + " (" + match.app.label + ")");
                return result;
            }
        }

        // 2. Kiểm tra bảng bí danh tĩnh dự phòng (Common Aliases)
        String target = appNameQuery.trim().toLowerCase(Locale.ROOT);
        String targetNorm = stripAccents(target);

        String aliasPackage = COMMON_APP_ALIASES.get(target);
        if (aliasPackage == null) {
            aliasPackage = COMMON_APP_ALIASES.get(targetNorm);
        }
        if (aliasPackage != null) {
            Intent launchIntent = pm.getLaunchIntentForPackage(aliasPackage);
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                appContext.startActivity(launchIntent);
                result.put("success", true);
                result.put("package", aliasPackage);
                result.put("target", appNameQuery);
                String msg = "Đang mở " + appNameQuery;
                result.put("message", msg);
                com.atv.launcher.systembridge.tts.VietnameseTtsEngine.getInstance(context).speak(context, msg, null);
                Log.i(TAG, "Launched app via alias: " + aliasPackage + " for query: " + appNameQuery);
                return result;
            }
        }

        // 3. Tra cứu danh sách ứng dụng đã cài đặt trên thiết bị
        Intent launcherIntent = new Intent(Intent.ACTION_MAIN, null);
        launcherIntent.addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> availableActivities = pm.queryIntentActivities(launcherIntent, 0);

        ResolveInfo bestMatch = null;
        for (ResolveInfo ri : availableActivities) {
            CharSequence label = ri.loadLabel(pm);
            if (label == null) continue;
            String labelStr = label.toString().toLowerCase(Locale.ROOT).trim();
            String labelNorm = stripAccents(labelStr);

            if (labelStr.equals(target) || labelNorm.equals(targetNorm)) {
                bestMatch = ri;
                break;
            }
            if (labelStr.contains(target) || labelNorm.contains(targetNorm)
                    || target.contains(labelStr) || targetNorm.contains(labelNorm)) {
                if (bestMatch == null) {
                    bestMatch = ri;
                }
            }
        }

        if (bestMatch != null && bestMatch.activityInfo != null) {
            String pkg = bestMatch.activityInfo.packageName;
            Intent launchIntent = pm.getLaunchIntentForPackage(pkg);
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                appContext.startActivity(launchIntent);
                result.put("success", true);
                result.put("package", pkg);
                result.put("target", bestMatch.loadLabel(pm).toString());
                String msg = "Đang mở " + bestMatch.loadLabel(pm);
                result.put("message", msg);
                com.atv.launcher.systembridge.tts.VietnameseTtsEngine.getInstance(context).speak(context, msg, null);
                Log.i(TAG, "Launched app by matched label: " + pkg + " (" + bestMatch.loadLabel(pm) + ")");
                return result;
            }
        }

        result.put("success", false);
        return result;
    }

    public static String extractMediaSearchQuery(String lowerQuery, String normalized) {
        if (lowerQuery.startsWith("karaoke ") || lowerQuery.startsWith("hát karaoke ")) {
            return lowerQuery.trim();
        }
        if (lowerQuery.startsWith("nghe nhạc ") || lowerQuery.startsWith("bài hát ") || lowerQuery.startsWith("ca khúc ")) {
            return lowerQuery.trim();
        }
        if (lowerQuery.startsWith("xem phim ") || lowerQuery.startsWith("phim ")) {
            return lowerQuery.trim();
        }
        return null;
    }

    public static boolean launchMediaSearch(Context context, String query) {
        Context appContext = context.getApplicationContext();
        PackageManager pm = appContext.getPackageManager();

        Log.i(TAG, "launchMediaSearch query: '" + query + "'");

        // 1. Thử SmartTube nếu đã cài
        Intent smartTubeIntent = pm.getLaunchIntentForPackage(SMARTTUBE_PACKAGE);
        if (smartTubeIntent != null) {
            try {
                Intent searchIntent = new Intent(Intent.ACTION_SEARCH)
                        .setPackage(SMARTTUBE_PACKAGE)
                        .putExtra(SearchManager.QUERY, query)
                        .putExtra("query", query)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                appContext.startActivity(searchIntent);
                Log.i(TAG, "Launched SmartTube search for: " + query);
                return true;
            } catch (Exception e1) {
                Log.w(TAG, "Failed SmartTube ACTION_SEARCH, trying URI intent: " + e1.getMessage());
                try {
                    Intent uriIntent = new Intent(Intent.ACTION_VIEW,
                            Uri.parse("https://www.youtube.com/results?search_query=" + Uri.encode(query)))
                            .setPackage(SMARTTUBE_PACKAGE)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                    appContext.startActivity(uriIntent);
                    return true;
                } catch (Exception e2) {
                    smartTubeIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    appContext.startActivity(smartTubeIntent);
                    return true;
                }
            }
        }

        // 2. Thử YouTube Android TV Chính thức (com.google.android.youtube.tv)
        Intent youtubeIntent = pm.getLaunchIntentForPackage(YOUTUBE_TV_PACKAGE);
        if (youtubeIntent != null) {
            try {
                Intent searchIntent = new Intent(Intent.ACTION_SEARCH)
                        .setPackage(YOUTUBE_TV_PACKAGE)
                        .putExtra(SearchManager.QUERY, query)
                        .putExtra("query", query)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                appContext.startActivity(searchIntent);
                Log.i(TAG, "Launched YouTube TV search for: " + query);
                return true;
            } catch (Exception e) {
                Log.w(TAG, "Failed YouTube TV search, trying URI", e);
                try {
                    Intent uriIntent = new Intent(Intent.ACTION_VIEW,
                            Uri.parse("https://www.youtube.com/results?search_query=" + Uri.encode(query)))
                            .setPackage(YOUTUBE_TV_PACKAGE)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                    appContext.startActivity(uriIntent);
                    return true;
                } catch (Exception ex) {
                    youtubeIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    appContext.startActivity(youtubeIntent);
                    return true;
                }
            }
        }

        // 3. Thử Google Katniss / Android TV Global Search
        try {
            Intent katnissSearch = new Intent("android.search.action.GLOBAL_SEARCH")
                    .putExtra(SearchManager.QUERY, query)
                    .putExtra("query", query)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            if (katnissSearch.resolveActivity(pm) != null) {
                appContext.startActivity(katnissSearch);
                Log.i(TAG, "Launched Katniss GLOBAL_SEARCH for: " + query);
                return true;
            }
        } catch (Exception e) {
            Log.w(TAG, "Katniss GLOBAL_SEARCH failed: " + e.getMessage());
        }

        // 4. Fallback: Mở trình duyệt Web tìm kiếm YouTube
        try {
            Intent webIntent = new Intent(Intent.ACTION_VIEW,
                    Uri.parse("https://www.youtube.com/results?search_query=" + Uri.encode(query)))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            appContext.startActivity(webIntent);
            Log.i(TAG, "Launched browser web fallback for: " + query);
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Failed web search fallback", e);
        }

        return false;
    }

    public static String stripAccents(String s) {
        if (s == null) return "";
        String normalized = Normalizer.normalize(s, Normalizer.Form.NFD);
        Pattern pattern = Pattern.compile("\\p{InCombiningDiacriticalMarks}+");
        return pattern.matcher(normalized).replaceAll("")
                .replaceAll("đ", "d")
                .replaceAll("Đ", "D");
    }

    private static Map<String, Object> handleHardwareAndFastLocalCommands(Context context, String query, String lowerQuery, String normalized) {
        Context appContext = context.getApplicationContext();
        AudioManager audioManager = (AudioManager) appContext.getSystemService(Context.AUDIO_SERVICE);

        // --- 1. ĐIỀU KHIỂN ÂM LƯỢNG (VOLUME) ---
        if (matchesAny(normalized, "tang am luong", "tang volume", "cho to len", "to len", "tang tieng", "cho lon len", "lon len")) {
            if (audioManager != null) {
                audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, AudioManager.FLAG_SHOW_UI);
            }
            return createSystemActionResult(context, "Đã tăng âm lượng TV");
        }
        if (matchesAny(normalized, "giam am luong", "giam volume", "cho nho lai", "nho lai", "giam tieng", "cho be lai", "be lai")) {
            if (audioManager != null) {
                audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, AudioManager.FLAG_SHOW_UI);
            }
            return createSystemActionResult(context, "Đã giảm âm lượng TV");
        }
        if (matchesAny(normalized, "tat tieng", "tat am thanh", "tat volume", "im lang", "mute")) {
            if (audioManager != null) {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                    audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_MUTE, AudioManager.FLAG_SHOW_UI);
                } else {
                    audioManager.setStreamMute(AudioManager.STREAM_MUSIC, true);
                }
            }
            return createSystemActionResult(context, "Đã tắt tiếng TV");
        }
        if (matchesAny(normalized, "bat tieng", "bat lai tieng", "mo tieng", "unmute", "mo am thanh")) {
            if (audioManager != null) {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                    audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_UNMUTE, AudioManager.FLAG_SHOW_UI);
                } else {
                    audioManager.setStreamMute(AudioManager.STREAM_MUSIC, false);
                }
            }
            return createSystemActionResult(context, "Đã bật lại tiếng TV");
        }
        Matcher volMatcher = Pattern.compile("(?:dat|chinh|cho|de)?\\s*am luong\\s*(\\d+)\\s*%?").matcher(normalized);
        if (volMatcher.find()) {
            try {
                int percent = Integer.parseInt(volMatcher.group(1));
                percent = Math.max(0, Math.min(100, percent));
                if (audioManager != null) {
                    int maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
                    int targetVol = Math.round((percent / 100.0f) * maxVol);
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVol, AudioManager.FLAG_SHOW_UI);
                }
                return createSystemActionResult(context, "Đã đặt âm lượng TV mức " + percent + "%");
            } catch (Exception ignored) {}
        }

        // --- 2. ĐIỀU KHIỂN PHÁT MEDIA TOÀN HỆ THỐNG ---
        if (matchesExactOrPrefix(normalized, "tam dung", "dung phat", "dung lai", "pause")) {
            dispatchMediaKey(appContext, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE);
            return createSystemActionResult(context, "Đã tạm dừng phát");
        }
        if (matchesExactOrPrefix(normalized, "tiep tuc", "phat tiep", "phat lai", "play")) {
            dispatchMediaKey(appContext, KeyEvent.KEYCODE_MEDIA_PLAY);
            return createSystemActionResult(context, "Đang tiếp tục phát");
        }
        if (matchesExactOrPrefix(normalized, "chuyen bai", "bai tiep theo", "bai ke tiep", "next")) {
            dispatchMediaKey(appContext, KeyEvent.KEYCODE_MEDIA_NEXT);
            return createSystemActionResult(context, "Đã chuyển bài tiếp theo");
        }
        if (matchesExactOrPrefix(normalized, "bai truoc", "quay lai bai truoc", "previous")) {
            dispatchMediaKey(appContext, KeyEvent.KEYCODE_MEDIA_PREVIOUS);
            return createSystemActionResult(context, "Đã quay lại bài trước");
        }

        // --- 3. HẸN GIỜ TẮT TV (SLEEP TIMER) ---
        if (normalized.contains("huy hen gio") || normalized.contains("huy tat tv") || normalized.contains("tat hen gio")) {
            SleepTimerManager.cancelSleepTimer(appContext);
            return createSystemActionResult(context, "Đã hủy hẹn giờ tắt TV");
        }
        Matcher sleepMatcher = Pattern.compile("hen\\s*(?:gio)?\\s*(\\d+)\\s*(phut|p|tieng|gio|h)").matcher(normalized);
        if (sleepMatcher.find()) {
            try {
                int val = Integer.parseInt(sleepMatcher.group(1));
                String unit = sleepMatcher.group(2);
                int minutes = ("tieng".equals(unit) || "gio".equals(unit) || "h".equals(unit)) ? val * 60 : val;
                SleepTimerManager.setSleepTimer(appContext, minutes);
                String msg = "Đã hẹn giờ " + val + " " + (minutes >= 60 && minutes % 60 == 0 ? "tiếng" : "phút") + " nữa tắt TV";
                return createSystemActionResult(context, msg);
            } catch (Exception ignored) {}
        }
        if (normalized.contains("hen gio con bao lau") || normalized.contains("con bao nhieu phut tat tv")) {
            if (SleepTimerManager.isTimerActive()) {
                int remaining = SleepTimerManager.getRemainingMinutes();
                return createSystemActionResult(context, "Hẹn giờ tắt TV còn lại khoảng " + remaining + " phút.");
            } else {
                return createSystemActionResult(context, "Hiện tại không có hẹn giờ tắt TV nào đang chạy.");
            }
        }

        // --- 4. CHUYỂN CỔNG ĐẦU VÀO HDMI ---
        Matcher hdmiMatcher = Pattern.compile("(?:chuyen\\s*(?:sang)?|mo|bat|cong)\\s*hdmi\\s*(\\d+)").matcher(normalized);
        if (hdmiMatcher.find()) {
            String port = hdmiMatcher.group(1);
            launchHdmiPort(appContext, port);
            return createSystemActionResult(context, "Đang chuyển sang cổng HDMI " + port);
        }

        // --- 5. HỎI ĐÁP CỤC BỘ 0MS (GIỜ GIẤC, NGÀY THÁNG, LỊCH) ---
        if (matchesAny(normalized, "may gio", "xem gio", "gio roi", "bay gio la may gio", "gio bay gio")) {
            Calendar cal = Calendar.getInstance();
            int hour = cal.get(Calendar.HOUR_OF_DAY);
            int min = cal.get(Calendar.MINUTE);
            String ans = "Bây giờ là " + hour + " giờ " + (min < 10 ? "0" + min : min) + " phút.";
            return createSystemActionResult(context, ans);
        }
        if (matchesAny(normalized, "ngay may", "ngay bao nhieu", "hom nay ngay may", "hom nay ngay bao nhieu")) {
            Calendar cal = Calendar.getInstance();
            int day = cal.get(Calendar.DAY_OF_MONTH);
            int month = cal.get(Calendar.MONTH) + 1;
            int year = cal.get(Calendar.YEAR);
            String dayName = getDayOfWeekVietnamese(cal.get(Calendar.DAY_OF_WEEK));
            String ans = "Hôm nay là " + dayName + ", ngày " + day + " tháng " + month + " năm " + year + ".";
            return createSystemActionResult(context, ans);
        }
        if (matchesAny(normalized, "thu may", "hom nay thu may", "thu may roi")) {
            Calendar cal = Calendar.getInstance();
            String dayName = getDayOfWeekVietnamese(cal.get(Calendar.DAY_OF_WEEK));
            String ans = "Hôm nay là " + dayName + ".";
            return createSystemActionResult(context, ans);
        }

        // --- 6. LỜI CHÀO & PERSONA CỤC BỘ ---
        if (matchesAny(normalized, "chao buoi sang", "good morning")) {
            return createSystemActionResult(context, "Chào buổi sáng! Chúc bạn một ngày mới an lành, tràn đầy niềm vui và may mắn.");
        }
        if (matchesAny(normalized, "chao buoi toi", "good evening")) {
            return createSystemActionResult(context, "Chào buổi tối! Chúc bạn có những phút giây xem TV thư giãn tuyệt vời.");
        }
        if (matchesAny(normalized, "ban la ai", "ban ten gi", "tro ly ten gi")) {
            return createSystemActionResult(context, "Tôi là Trợ lý Giọng nói Thông minh trên Android TV của bạn. Tôi có thể giúp bạn mở kênh, tìm video YouTube, điều khiển TV và trò chuyện.");
        }

        return null;
    }

    private static boolean matchesAny(String text, String... keywords) {
        if (TextUtils.isEmpty(text)) return false;
        for (String kw : keywords) {
            if (text.contains(kw)) return true;
        }
        return false;
    }

    private static boolean matchesExactOrPrefix(String text, String... keywords) {
        if (TextUtils.isEmpty(text)) return false;
        for (String kw : keywords) {
            if (text.equals(kw) || text.startsWith(kw + " ") || text.endsWith(" " + kw)) return true;
        }
        return false;
    }

    private static Map<String, Object> createSystemActionResult(Context context, String message) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("success", true);
        result.put("type", TYPE_SYSTEM_ACTION);
        result.put("message", message);
        com.atv.launcher.systembridge.tts.VietnameseTtsEngine.getInstance(context).speak(context, message, null);
        return result;
    }

    private static void dispatchMediaKey(Context context, int keyCode) {
        try {
            AudioManager audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
            long eventTime = SystemClock.uptimeMillis();
            if (audio != null) {
                audio.dispatchMediaKeyEvent(new KeyEvent(eventTime, eventTime, KeyEvent.ACTION_DOWN, keyCode, 0));
                audio.dispatchMediaKeyEvent(new KeyEvent(eventTime, eventTime, KeyEvent.ACTION_UP, keyCode, 0));
            }
        } catch (Exception e) {
            Log.w(TAG, "dispatchMediaKey error", e);
        }
    }

    private static void launchHdmiPort(Context context, String portNumber) {
        try {
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setData(Uri.parse("passthrough://com.android.tv.passthrough/HDMI" + portNumber));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        } catch (Exception e) {
            try {
                Intent tvInputIntent = new Intent("android.intent.action.TV_INPUT_BUTTON");
                tvInputIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(tvInputIntent);
            } catch (Exception ex) {
                Log.w(TAG, "Cannot launch HDMI input", ex);
            }
        }
    }

    private static String getDayOfWeekVietnamese(int dayOfWeek) {
        switch (dayOfWeek) {
            case Calendar.SUNDAY: return "Chủ Nhật";
            case Calendar.MONDAY: return "Thứ Hai";
            case Calendar.TUESDAY: return "Thứ Ba";
            case Calendar.WEDNESDAY: return "Thứ Tư";
            case Calendar.THURSDAY: return "Thứ Năm";
            case Calendar.FRIDAY: return "Thứ Sáu";
            case Calendar.SATURDAY: return "Thứ Bảy";
            default: return "";
        }
    }
}
