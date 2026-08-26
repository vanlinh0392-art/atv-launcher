package com.atv.launcher.systembridge.ai;

import android.text.TextUtils;
import android.util.Log;
import android.util.Xml;

import org.xmlpull.v1.XmlPullParser;

import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;

public final class VietnamNewsProvider {
    private static final String TAG = "VietnamNewsProvider";

    public static class NewsItem {
        public final String title;
        public final String summary;
        public final String source;
        public final String pubDate;
        public final String link;

        public NewsItem(String title, String summary, String source, String pubDate, String link) {
            this.title = title != null ? title.trim() : "";
            this.summary = summary != null ? summary.trim() : "";
            this.source = source != null ? source.trim() : "";
            this.pubDate = pubDate != null ? pubDate.trim() : "";
            this.link = link != null ? link.trim() : "";
        }
    }

    private static class CachedNews {
        final List<NewsItem> items;
        final long timestamp;

        CachedNews(List<NewsItem> items) {
            this.items = items;
            this.timestamp = System.currentTimeMillis();
        }

        boolean isValid() {
            return (System.currentTimeMillis() - timestamp) < 600000L; // Cache 10 phút
        }
    }

    private static volatile CachedNews cache = null;

    private static final String[][] RSS_FEEDS = new String[][]{
            {"VnExpress", "https://vnexpress.net/rss/tin-moi-nhat.rss"},
            {"Tuổi Trẻ", "https://tuoitre.vn/rss/tin-moi-nhat.rss"},
            {"Dân Trí", "https://dantri.com.vn/rss/tin-moi-nhat.rss"},
            {"Thanh Niên", "https://thanhnien.vn/rss/home.rss"}
    };

    private static final Pattern HTML_TAG_PATTERN = Pattern.compile("<.*?>", Pattern.DOTALL);

    private VietnamNewsProvider() {
    }

    public static synchronized List<NewsItem> getLatestTop3News() {
        if (cache != null && cache.isValid() && cache.items != null && !cache.items.isEmpty()) {
            Log.i(TAG, "Serving latest news from 10-minute cache (" + cache.items.size() + " items)");
            return cache.items;
        }

        List<NewsItem> collected = new ArrayList<>();

        for (String[] feed : RSS_FEEDS) {
            String sourceName = feed[0];
            String feedUrl = feed[1];
            try {
                List<NewsItem> items = fetchRssFeed(sourceName, feedUrl);
                if (items != null && !items.isEmpty()) {
                    for (NewsItem it : items) {
                        if (!isDuplicate(collected, it)) {
                            collected.add(it);
                        }
                        if (collected.size() >= 3) {
                            break;
                        }
                    }
                }
            } catch (Exception e) {
                Log.w(TAG, "Failed fetching feed from " + sourceName + ": " + e.getMessage());
            }

            if (collected.size() >= 3) {
                break;
            }
        }

        if (!collected.isEmpty()) {
            cache = new CachedNews(Collections.unmodifiableList(collected));
            return cache.items;
        }

        return Collections.emptyList();
    }

    private static boolean isDuplicate(List<NewsItem> existing, NewsItem newItem) {
        if (TextUtils.isEmpty(newItem.title)) return true;
        String newTitle = newItem.title.toLowerCase(Locale.ROOT);
        for (NewsItem it : existing) {
            String existingTitle = it.title.toLowerCase(Locale.ROOT);
            if (existingTitle.equals(newTitle) || existingTitle.contains(newTitle) || newTitle.contains(existingTitle)) {
                return true;
            }
        }
        return false;
    }

    private static List<NewsItem> fetchRssFeed(String sourceName, String feedUrl) {
        List<NewsItem> results = new ArrayList<>();
        HttpURLConnection conn = null;
        InputStream in = null;
        try {
            URL url = new URL(feedUrl);
            conn = (HttpURLConnection) url.openConnection();
            conn.setConnectTimeout(4000);
            conn.setReadTimeout(4000);
            conn.setRequestMethod("GET");
            conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ATVLauncherNews/1.0");
            conn.setRequestProperty("Accept", "application/rss+xml, application/xml, text/xml; q=0.9, */*; q=0.8");
            conn.connect();

            if (conn.getResponseCode() != 200) {
                return results;
            }

            in = conn.getInputStream();
            XmlPullParser parser = Xml.newPullParser();
            parser.setInput(in, "UTF-8");

            int eventType = parser.getEventType();
            boolean insideItem = false;
            String currentTitle = "";
            String currentDesc = "";
            String currentPubDate = "";
            String currentLink = "";

            while (eventType != XmlPullParser.END_DOCUMENT) {
                String tagName = parser.getName();
                if (eventType == XmlPullParser.START_TAG) {
                    if ("item".equalsIgnoreCase(tagName)) {
                        insideItem = true;
                        currentTitle = "";
                        currentDesc = "";
                        currentPubDate = "";
                        currentLink = "";
                    } else if (insideItem) {
                        if ("title".equalsIgnoreCase(tagName)) {
                            currentTitle = parser.nextText();
                        } else if ("description".equalsIgnoreCase(tagName)) {
                            currentDesc = parser.nextText();
                        } else if ("pubDate".equalsIgnoreCase(tagName)) {
                            currentPubDate = parser.nextText();
                        } else if ("link".equalsIgnoreCase(tagName)) {
                            currentLink = parser.nextText();
                        }
                    }
                } else if (eventType == XmlPullParser.END_TAG) {
                    if ("item".equalsIgnoreCase(tagName)) {
                        insideItem = false;
                        String cleanTitle = cleanHtml(currentTitle);
                        String cleanDesc = cleanHtml(currentDesc);
                        if (!TextUtils.isEmpty(cleanTitle)) {
                            results.add(new NewsItem(cleanTitle, cleanDesc, sourceName, currentPubDate, currentLink));
                            if (results.size() >= 5) {
                                break;
                            }
                        }
                    }
                }
                eventType = parser.next();
            }
        } catch (Exception e) {
            Log.w(TAG, "Error parsing RSS " + feedUrl + ": " + e.getMessage());
        } finally {
            if (in != null) {
                try {
                    in.close();
                } catch (Exception ignored) {}
            }
            if (conn != null) {
                try {
                    conn.disconnect();
                } catch (Exception ignored) {}
            }
        }
        return results;
    }

    private static String cleanHtml(String raw) {
        if (raw == null) return "";
        String text = HTML_TAG_PATTERN.matcher(raw).replaceAll(" ");
        text = text.replace("&nbsp;", " ")
                .replace("&amp;", "&")
                .replace("&quot;", "\"")
                .replace("&apos;", "'")
                .replace("&lt;", "<")
                .replace("&gt;", ">")
                .replaceAll("&#\\d+;", "")
                .replaceAll("\\s+", " ")
                .trim();
        return text;
    }

    public static String buildNewsContextForAi(List<NewsItem> items) {
        if (items == null || items.isEmpty()) {
            return "Không có dữ liệu tin tức.";
        }
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < items.size() && i < 3; i++) {
            NewsItem item = items.get(i);
            sb.append("Tin ").append(i + 1).append(" (Nguồn ").append(item.source).append("):\n");
            sb.append("- Tiêu đề: ").append(item.title).append("\n");
            if (!TextUtils.isEmpty(item.summary)) {
                sb.append("- Tóm tắt: ").append(item.summary).append("\n");
            }
            sb.append("\n");
        }
        return sb.toString().trim();
    }

    public static String buildDirectBroadcastScript(List<NewsItem> items) {
        SimpleDateFormat sdf = new SimpleDateFormat("dd 'tháng' MM", new Locale("vi", "VN"));
        String todayStr = sdf.format(new Date());

        if (items == null || items.isEmpty()) {
            return "Chào bạn, hiện tại hệ thống chưa thể cập nhật tin tức trực tuyến ngày " + todayStr + ". Vui lòng kiểm tra lại kết nối mạng sau giây lát.";
        }

        StringBuilder sb = new StringBuilder();
        sb.append("Sau đây là bản tin tổng hợp 3 tin tức mới nhất của Việt Nam ngày ").append(todayStr).append(". ");

        for (int i = 0; i < items.size() && i < 3; i++) {
            NewsItem item = items.get(i);
            String numberPrefix = (i == 0) ? "Tin thứ nhất: " : (i == 1) ? "Tin thứ hai: " : "Tin thứ ba: ";
            sb.append(numberPrefix);
            sb.append(item.title).append(". ");
            if (!TextUtils.isEmpty(item.summary)) {
                sb.append(item.summary).append(". ");
            }
        }

        sb.append("Đó là 3 tin tức nổi bật nhất ngày hôm nay.");
        return sb.toString().replaceAll("\\s+", " ").trim();
    }
}
