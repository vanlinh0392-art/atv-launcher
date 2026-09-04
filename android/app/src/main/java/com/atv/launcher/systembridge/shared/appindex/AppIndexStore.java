package com.atv.launcher.systembridge.shared.appindex;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.text.TextUtils;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.text.Normalizer;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.regex.Pattern;

public final class AppIndexStore {
    private static final String TAG = "AppIndexStore";
    private static final String PREF_NAME = "flauncher_app_index_db";
    private static final String KEY_INDEXED_APPS = "indexed_apps_json";

    private static volatile AppIndexStore instance;

    private final Context appContext;
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Map<String, AppEntry> appCache = new ConcurrentHashMap<>();
    private volatile boolean isInitialized = false;

    public static class AppEntry {
        public final String packageName;
        public final String label;
        public final String normalizedLabel;
        public final Set<String> aliases;
        public final boolean isSystemApp;
        public final long lastUpdated;

        public AppEntry(String packageName, String label, String normalizedLabel, Set<String> aliases, boolean isSystemApp, long lastUpdated) {
            this.packageName = packageName;
            this.label = label;
            this.normalizedLabel = normalizedLabel;
            this.aliases = aliases != null ? Collections.unmodifiableSet(aliases) : Collections.emptySet();
            this.isSystemApp = isSystemApp;
            this.lastUpdated = lastUpdated;
        }

        public JSONObject toJson() {
            try {
                JSONObject obj = new JSONObject();
                obj.put("package", packageName);
                obj.put("label", label);
                obj.put("norm", normalizedLabel);
                obj.put("system", isSystemApp);
                obj.put("updated", lastUpdated);
                JSONArray aliasArr = new JSONArray();
                for (String alias : aliases) {
                    aliasArr.put(alias);
                }
                obj.put("aliases", aliasArr);
                return obj;
            } catch (Exception e) {
                return null;
            }
        }

        public static AppEntry fromJson(JSONObject obj) {
            if (obj == null) return null;
            try {
                String pkg = obj.optString("package", "");
                String lbl = obj.optString("label", "");
                String norm = obj.optString("norm", "");
                boolean sys = obj.optBoolean("system", false);
                long upd = obj.optLong("updated", 0);
                Set<String> aliasSet = new HashSet<>();
                JSONArray aliasArr = obj.optJSONArray("aliases");
                if (aliasArr != null) {
                    for (int i = 0; i < aliasArr.length(); i++) {
                        aliasSet.add(aliasArr.getString(i));
                    }
                }
                return new AppEntry(pkg, lbl, norm, aliasSet, sys, upd);
            } catch (Exception e) {
                return null;
            }
        }
    }

    public static class MatchResult {
        public final AppEntry app;
        public final float score;
        public final String matchType;

        public MatchResult(AppEntry app, float score, String matchType) {
            this.app = app;
            this.score = score;
            this.matchType = matchType;
        }
    }

    private AppIndexStore(Context context) {
        this.appContext = context.getApplicationContext();
        loadFromCache();
    }

    public static AppIndexStore getInstance(Context context) {
        if (instance == null) {
            synchronized (AppIndexStore.class) {
                if (instance == null) {
                    instance = new AppIndexStore(context);
                }
            }
        }
        return instance;
    }

    private void loadFromCache() {
        try {
            SharedPreferences sp = appContext.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
            String jsonStr = sp.getString(KEY_INDEXED_APPS, null);
            if (!TextUtils.isEmpty(jsonStr)) {
                JSONArray arr = new JSONArray(jsonStr);
                for (int i = 0; i < arr.length(); i++) {
                    AppEntry entry = AppEntry.fromJson(arr.getJSONObject(i));
                    if (entry != null && !TextUtils.isEmpty(entry.packageName)) {
                        appCache.put(entry.packageName, entry);
                    }
                }
                isInitialized = true;
                Log.i(TAG, "Loaded " + appCache.size() + " indexed apps from persistent cache");
            }
        } catch (Exception e) {
            Log.w(TAG, "Error loading cached app index: " + e.getMessage());
        }
    }

    public void syncAppsAsync() {
        executor.execute(this::syncApps);
    }

    public synchronized void syncApps() {
        Log.i(TAG, "Starting full app indexing from PackageManager...");
        long t0 = System.currentTimeMillis();
        PackageManager pm = appContext.getPackageManager();

        Map<String, AppEntry> newIndex = new HashMap<>();

        // 1. Quét Leanback TV Apps + Standard Launcher Apps
        Intent launcherIntent = new Intent(Intent.ACTION_MAIN, null);
        launcherIntent.addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> standardApps = pm.queryIntentActivities(launcherIntent, 0);

        Intent leanbackIntent = new Intent(Intent.ACTION_MAIN, null);
        leanbackIntent.addCategory(Intent.CATEGORY_LEANBACK_LAUNCHER);
        List<ResolveInfo> tvApps = pm.queryIntentActivities(leanbackIntent, 0);

        Set<ResolveInfo> allResolves = new HashSet<>();
        if (standardApps != null) allResolves.addAll(standardApps);
        if (tvApps != null) allResolves.addAll(tvApps);

        for (ResolveInfo ri : allResolves) {
            if (ri.activityInfo == null || TextUtils.isEmpty(ri.activityInfo.packageName)) continue;
            String pkg = ri.activityInfo.packageName;
            CharSequence labelSeq = ri.loadLabel(pm);
            String label = (labelSeq != null && !TextUtils.isEmpty(labelSeq.toString())) ? labelSeq.toString().trim() : pkg;
            String norm = stripAccents(label).toLowerCase(Locale.ROOT).trim();

            boolean isSystem = false;
            try {
                ApplicationInfo appInfo = pm.getApplicationInfo(pkg, 0);
                isSystem = (appInfo.flags & ApplicationInfo.FLAG_SYSTEM) != 0;
            } catch (Exception ignored) {}

            Set<String> aliases = generateAliases(pkg, label, norm);
            AppEntry entry = new AppEntry(pkg, label, norm, aliases, isSystem, System.currentTimeMillis());
            newIndex.put(pkg, entry);
        }

        // Bổ sung các ứng dụng hệ thống quan trọng nếu chưa có launcher icon
        addSpecialSystemTarget(newIndex, "com.android.tv.settings", "Cài đặt", new String[]{"cai dat", "settings", "thiet lap", "cài đặt tivi"});
        addSpecialSystemTarget(newIndex, "com.android.vending", "CH Play", new String[]{"ch play", "play store", "google play", "cửa hàng"});
        addSpecialSystemTarget(newIndex, "org.smarttube.stable", "SmartTube", new String[]{"youtube", "smarttube", "du tu be", "you tube", "dút túp", "smart tube", "xem youtube"});
        addSpecialSystemTarget(newIndex, "com.google.android.youtube.tv", "YouTube TV", new String[]{"youtube", "du tu be", "you tube", "xem youtube"});
        addSpecialSystemTarget(newIndex, "com.xemtv.app", "XemTV", new String[]{"xemtv", "xem tv", "truyền hình", "tivi", "xem tivi"});
        addSpecialSystemTarget(newIndex, "com.dinhlap.movielegend", "Movie Legend", new String[]{"kho phim", "movie legend", "phim đình lặp", "phim dinh lap", "xem phim"});
        addSpecialSystemTarget(newIndex, "com.dinhlap.dlstore", "DLStore", new String[]{"dlstore", "dl store", "chợ ứng dụng", "kho ứng dụng", "app store"});
        addSpecialSystemTarget(newIndex, "com.coccoc.trinhduyet_tv", "Cốc Cốc", new String[]{"cốc cốc", "coc coc", "trình duyệt", "trinh duyet", "web", "trình duyệt web"});
        addSpecialSystemTarget(newIndex, "com.stremio.one", "Stremio", new String[]{"stremio", "xem phim stremio"});
        addSpecialSystemTarget(newIndex, "com.lagradost.cloudstream3.prerelease", "Cloudstream", new String[]{"cloudstream", "cloud stream"});
        addSpecialSystemTarget(newIndex, "com.rs.explorer.filemanager", "Quản lý File", new String[]{"quan ly file", "file manager", "file", "tệp tin"});
        addSpecialSystemTarget(newIndex, "com.monster.tv", "Monster TV", new String[]{"monster tv", "monstertv"});
        addSpecialSystemTarget(newIndex, "vn.vtv.vtvgo", "VTV Go", new String[]{"vtv go", "vtvgo", "vê tê vê go"});
        addSpecialSystemTarget(newIndex, "com.viettel.tv360", "TV360", new String[]{"tv360", "tv 360", "viettel tv"});
        addSpecialSystemTarget(newIndex, "com.fptplay.activity", "FPT Play", new String[]{"fpt play", "fpt", "ép pê tê", "fptplay"});
        addSpecialSystemTarget(newIndex, "com.vnpt.mytv", "MyTV", new String[]{"mytv", "my tv", "vnpt tv"});
        addSpecialSystemTarget(newIndex, "org.xbmc.kodi", "Kodi", new String[]{"kodi", "cô đi", "co di"});
        addSpecialSystemTarget(newIndex, "ar.tvplayer.tv", "TiviMate", new String[]{"tivimate", "tivi mate"});

        appCache.putAll(newIndex);
        appCache.keySet().retainAll(newIndex.keySet());
        isInitialized = true;

        // Lưu vào SharedPreferences
        try {
            JSONArray arr = new JSONArray();
            for (AppEntry e : appCache.values()) {
                JSONObject o = e.toJson();
                if (o != null) arr.put(o);
            }
            SharedPreferences sp = appContext.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
            sp.edit().putString(KEY_INDEXED_APPS, arr.toString()).apply();
            Log.i(TAG, "Synced and persisted " + appCache.size() + " apps into AppIndexStore in " + (System.currentTimeMillis() - t0) + "ms");
        } catch (Exception e) {
            Log.w(TAG, "Error persisting app index: " + e.getMessage());
        }
    }

    private void addSpecialSystemTarget(Map<String, AppEntry> map, String pkg, String label, String[] customAliases) {
        AppEntry existing = map.get(pkg);
        Set<String> aliases = new HashSet<>();
        if (existing != null) {
            aliases.addAll(existing.aliases);
        }
        for (String a : customAliases) {
            aliases.add(a.toLowerCase(Locale.ROOT).trim());
            aliases.add(stripAccents(a).toLowerCase(Locale.ROOT).trim());
        }
        String norm = stripAccents(label).toLowerCase(Locale.ROOT).trim();
        map.put(pkg, new AppEntry(pkg, label, norm, aliases, false, System.currentTimeMillis()));
    }

    private Set<String> generateAliases(String pkg, String label, String norm) {
        Set<String> aliases = new HashSet<>();
        aliases.add(label.toLowerCase(Locale.ROOT).trim());
        aliases.add(norm);

        // Sinh từ viết tắt (Acronym: e.g. "FPT Play" -> "fpt", "VTV Go" -> "vtvgo")
        String[] parts = norm.split("\\s+");
        if (parts.length > 1) {
            StringBuilder acronym = new StringBuilder();
            for (String p : parts) {
                if (!p.isEmpty()) acronym.append(p.charAt(0));
            }
            aliases.add(acronym.toString());
            aliases.add(norm.replace(" ", ""));
        }

        // Tách đuôi package name (e.g. com.coccoc.trinhduyet_tv -> coccoc, trinhduyet)
        String[] pkgParts = pkg.split("\\.");
        if (pkgParts.length > 0) {
            String lastPart = pkgParts[pkgParts.length - 1].toLowerCase(Locale.ROOT).replace("_", " ");
            aliases.add(lastPart);
            aliases.add(stripAccents(lastPart));
        }

        return aliases;
    }

    public MatchResult findBestMatch(String query) {
        if (query == null || query.trim().isEmpty()) {
            return null;
        }

        String queryNorm = stripAccents(query).trim();

        // 1. Tầng 1: Khớp chính xác (Score = 1.0)
        for (AppEntry app : appCache.values()) {
            if (app.label.equalsIgnoreCase(query) || app.normalizedLabel.equalsIgnoreCase(queryNorm)) {
                return new MatchResult(app, 1.0f, "exact_label");
            }
            for (String alias : app.aliases) {
                if (alias.equalsIgnoreCase(query) || alias.equalsIgnoreCase(queryNorm)) {
                    return new MatchResult(app, 1.0f, "exact_alias");
                }
            }
        }

        // 2. Tầng 2: Khớp chứa cụm từ hoặc Token Overlap (Score = 0.85 - 0.95)
        AppEntry bestContainMatch = null;
        float bestContainScore = 0f;

        for (AppEntry app : appCache.values()) {
            String appNorm = app.normalizedLabel;
            if (appNorm.length() >= 2) {
                if (queryNorm.matches(".*\\b" + Pattern.quote(appNorm) + "\\b.*")) {
                    float score = 0.95f;
                    if (score > bestContainScore) {
                        bestContainScore = score;
                        bestContainMatch = app;
                    }
                } else if (queryNorm.contains(appNorm)) {
                    float score = Math.max(0.60f, (float) appNorm.length() / queryNorm.length() * 0.90f);
                    if (score > bestContainScore) {
                        bestContainScore = score;
                        bestContainMatch = app;
                    }
                }
            }
            for (String alias : app.aliases) {
                if (alias.length() >= 2) {
                    if (queryNorm.matches(".*\\b" + Pattern.quote(alias) + "\\b.*")) {
                        float score = 0.96f;
                        if (score > bestContainScore) {
                            bestContainScore = score;
                            bestContainMatch = app;
                        }
                    } else if (queryNorm.contains(alias)) {
                        float score = Math.max(0.60f, (float) alias.length() / queryNorm.length() * 0.92f);
                        if (score > bestContainScore) {
                            bestContainScore = score;
                            bestContainMatch = app;
                        }
                    }
                }
            }
        }

        if (bestContainMatch != null && bestContainScore >= 0.50f) {
            return new MatchResult(bestContainMatch, bestContainScore, "contain_match");
        }

        // 3. Tầng 3: Khớp mờ Levenshtein Distance (Score >= 0.70)
        AppEntry bestFuzzyMatch = null;
        float bestFuzzyScore = 0f;

        for (AppEntry app : appCache.values()) {
            float sim = similarity(queryNorm, app.normalizedLabel);
            if (sim > bestFuzzyScore) {
                bestFuzzyScore = sim;
                bestFuzzyMatch = app;
            }
            for (String alias : app.aliases) {
                float aSim = similarity(queryNorm, alias);
                if (aSim > bestFuzzyScore) {
                    bestFuzzyScore = aSim;
                    bestFuzzyMatch = app;
                }
            }
        }

        if (bestFuzzyMatch != null && bestFuzzyScore >= 0.70f) {
            return new MatchResult(bestFuzzyMatch, bestFuzzyScore, "fuzzy_levenshtein");
        }

        return null;
    }

    public String getInstalledAppNamesSummary() {
        List<String> names = new ArrayList<>();
        for (AppEntry e : appCache.values()) {
            if (!e.isSystemApp && !names.contains(e.label)) {
                names.add(e.label);
            }
        }
        if (names.size() > 15) {
            names = names.subList(0, 15);
        }
        return TextUtils.join(", ", names);
    }

    public static float similarity(String s1, String s2) {
        if (s1 == null || s2 == null) return 0f;
        if (s1.equals(s2)) return 1.0f;
        int maxLen = Math.max(s1.length(), s2.length());
        if (maxLen == 0) return 1.0f;
        int distance = computeLevenshteinDistance(s1, s2);
        return 1.0f - ((float) distance / maxLen);
    }

    private static int computeLevenshteinDistance(String lhs, String rhs) {
        int len0 = lhs.length() + 1;
        int len1 = rhs.length() + 1;
        int[] cost = new int[len0];
        int[] newcost = new int[len0];

        for (int i = 0; i < len0; i++) cost[i] = i;

        for (int j = 1; j < len1; j++) {
            newcost[0] = j;
            for (int i = 1; i < len0; i++) {
                int match = (lhs.charAt(i - 1) == rhs.charAt(j - 1)) ? 0 : 1;
                int cost_replace = cost[i - 1] + match;
                int cost_insert = cost[i] + 1;
                int cost_delete = newcost[i - 1] + 1;
                newcost[i] = Math.min(Math.min(cost_insert, cost_delete), cost_replace);
            }
            int[] swap = cost;
            cost = newcost;
            newcost = swap;
        }
        return cost[len0 - 1];
    }

    private static final Pattern DIACRITICAL_MARKS_PATTERN =
            Pattern.compile("\\p{InCombiningDiacriticalMarks}+");

    public static String stripAccents(String s) {
        if (s == null) return "";
        String normalized = Normalizer.normalize(s, Normalizer.Form.NFD);
        return DIACRITICAL_MARKS_PATTERN.matcher(normalized).replaceAll("")
                .replaceAll("đ", "d")
                .replaceAll("Đ", "D");
    }
}
