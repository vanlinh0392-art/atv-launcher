package com.atv.launcher.systembridge.shared.voice;

import android.app.SearchManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.text.TextUtils;
import android.util.Log;

import java.text.Normalizer;
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

        // 2. Xử lý các tiền tố mở / nghe / tìm kiếm
        String lower = clean.toLowerCase(Locale.ROOT);
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
}
