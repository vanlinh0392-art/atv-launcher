package com.atv.launcher.systembridge.tts;

import android.text.TextUtils;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class VietnameseTextPreprocessor {

    private static final Pattern MARKDOWN_PATTERN = Pattern.compile(
            "(\\*\\*|\\*|__|_|###|##|#|```[a-zA-Z]*|```|`|>|- \\[ \\]|- \\[x\\]|\\n\\s*[-*+]|https?://\\S+)"
    );

    private static final Pattern TIME_PATTERN_1 = Pattern.compile("\\b(\\d{1,2}):(\\d{2})\\b");
    private static final Pattern TIME_PATTERN_2 = Pattern.compile("\\b(\\d{1,2})h(\\d{2})?\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern TEMP_PATTERN = Pattern.compile("(-?\\d+(?:\\.\\d+)?)\\s*°C", Pattern.CASE_INSENSITIVE);
    private static final Pattern SPEED_PATTERN = Pattern.compile("(\\d+(?:\\.\\d+)?)\\s*km/h", Pattern.CASE_INSENSITIVE);
    private static final Pattern PERCENT_PATTERN = Pattern.compile("(\\d+(?:\\.\\d+)?)\\s*%");

    private VietnameseTextPreprocessor() {
    }

    public static String preprocessForSpeech(String rawText) {
        if (TextUtils.isEmpty(rawText)) {
            return "";
        }

        String text = rawText.trim();

        // 1. Loại bỏ các ký tự Markdown và link URL
        text = MARKDOWN_PATTERN.matcher(text).replaceAll(" ");

        // 2. Chuẩn hóa thời gian (19:30 -> 19 giờ 30 phút)
        Matcher timeMatcher1 = TIME_PATTERN_1.matcher(text);
        StringBuffer sbTime = new StringBuffer();
        while (timeMatcher1.find()) {
            String hour = timeMatcher1.group(1);
            String minute = timeMatcher1.group(2);
            if ("00".equals(minute)) {
                timeMatcher1.appendReplacement(sbTime, hour + " giờ");
            } else {
                timeMatcher1.appendReplacement(sbTime, hour + " giờ " + minute + " phút");
            }
        }
        timeMatcher1.appendTail(sbTime);
        text = sbTime.toString();

        // 3. Chuẩn hóa nhiệt độ, tốc độ, phần trăm
        text = TEMP_PATTERN.matcher(text).replaceAll("$1 độ C");
        text = SPEED_PATTERN.matcher(text).replaceAll("$1 kilômét một giờ");
        text = PERCENT_PATTERN.matcher(text).replaceAll("$1 phần trăm");

        // 4. Chuẩn hóa tên kênh truyền hình Việt Nam để giọng đọc tự nhiên nhất
        text = replaceChannelNames(text);

        // 5. Chuẩn hóa các từ viết tắt công nghệ phổ biến
        text = replaceAbbreviations(text);

        // 6. Dọn dẹp khoảng trắng thừa và dấu câu lặp
        text = text.replaceAll("\\s+", " ")
                .replaceAll("\\s+([.,!?;:])", "$1")
                .trim();

        return text;
    }

    private static String replaceChannelNames(String input) {
        String text = input;

        // VTV
        text = text.replaceAll("(?i)\\bVTV\\s*1\\b", "Vê Tê Vê một");
        text = text.replaceAll("(?i)\\bVTV\\s*2\\b", "Vê Tê Vê hai");
        text = text.replaceAll("(?i)\\bVTV\\s*3\\b", "Vê Tê Vê ba");
        text = text.replaceAll("(?i)\\bVTV\\s*4\\b", "Vê Tê Vê bốn");
        text = text.replaceAll("(?i)\\bVTV\\s*5\\b", "Vê Tê Vê năm");
        text = text.replaceAll("(?i)\\bVTV\\s*6\\b", "Vê Tê Vê sáu");
        text = text.replaceAll("(?i)\\bVTV\\s*7\\b", "Vê Tê Vê bảy");
        text = text.replaceAll("(?i)\\bVTV\\s*8\\b", "Vê Tê Vê tám");
        text = text.replaceAll("(?i)\\bVTV\\s*9\\b", "Vê Tê Vê chín");
        text = text.replaceAll("(?i)\\bVTV\\s*Cần\\s*Thơ\\b", "Vê Tê Vê Cần Thơ");

        // HTV
        text = text.replaceAll("(?i)\\bHTV\\s*7\\b", "Hát Tê Vê bảy");
        text = text.replaceAll("(?i)\\bHTV\\s*9\\b", "Hát Tê Vê chín");
        text = text.replaceAll("(?i)\\bHTV\\s*2\\b", "Hát Tê Vê hai");
        text = text.replaceAll("(?i)\\bHTV\\s*3\\b", "Hát Tê Vê ba");

        // THVL
        text = text.replaceAll("(?i)\\bTHVL\\s*1\\b", "Truyền hình Vĩnh Long một");
        text = text.replaceAll("(?i)\\bTHVL\\s*2\\b", "Truyền hình Vĩnh Long hai");
        text = text.replaceAll("(?i)\\bTHVL\\s*3\\b", "Truyền hình Vĩnh Long ba");
        text = text.replaceAll("(?i)\\bTHVL\\s*4\\b", "Truyền hình Vĩnh Long bốn");

        // VTC
        text = text.replaceAll("(?i)\\bVTC\\s*1\\b", "Vê Tê Xê một");
        text = text.replaceAll("(?i)\\bVTC\\s*3\\b", "Vê Tê Xê ba");
        text = text.replaceAll("(?i)\\bVTC\\s*14\\b", "Vê Tê Xê mười bốn");

        // ANTV / QPVN
        text = text.replaceAll("(?i)\\bANTV\\b", "An Ninh Ti Vi");
        text = text.replaceAll("(?i)\\bQPVN\\b", "Quốc Phòng Việt Nam");

        // Chất lượng
        text = text.replaceAll("(?i)\\bHD\\b", "Hát Đê");
        text = text.replaceAll("(?i)\\bFull\\s*HD\\b", "Full Hát Đê");
        text = text.replaceAll("(?i)\\b4K\\b", "Bốn Ka");

        return text;
    }

    private static String replaceAbbreviations(String input) {
        String text = input;
        text = text.replaceAll("(?i)\\bAI\\b", "Trí tuệ nhân tạo");
        text = text.replaceAll("(?i)\\bTV\\b", "ti vi");
        text = text.replaceAll("(?i)\\bApp\\b", "ứng dụng");
        text = text.replaceAll("(?i)\\bApps\\b", "ứng dụng");
        text = text.replaceAll("(?i)\\bkm\\b", "kilômét");
        text = text.replaceAll("(?i)\\bkg\\b", "kilôgam");
        text = text.replaceAll("&", " và ");
        return text;
    }

    public static List<String> splitIntoSentences(String text) {
        if (TextUtils.isEmpty(text)) {
            return Collections.emptyList();
        }

        String[] rawSentences = text.split("(?<=[.!?;\n])\\s+");
        List<String> list = new ArrayList<>();
        for (String s : rawSentences) {
            String trimmed = s.trim();
            if (trimmed.isEmpty()) continue;

            if (trimmed.length() <= 150) {
                list.add(trimmed);
            } else {
                // Tách tiếp theo dấu phẩy hoặc khoảng trắng nếu câu quá dài (> 150 ký tự)
                String[] subParts = trimmed.split("(?<=,)\\s+");
                StringBuilder current = new StringBuilder();
                for (String part : subParts) {
                    if (current.length() + part.length() + 1 <= 150) {
                        if (current.length() > 0) current.append(" ");
                        current.append(part);
                    } else {
                        if (current.length() > 0) {
                            list.add(current.toString().trim());
                            current = new StringBuilder();
                        }
                        if (part.length() <= 150) {
                            current.append(part);
                        } else {
                            // Cắt theo từ nếu 1 cụm từ quá dài
                            String[] words = part.split("\\s+");
                            for (String w : words) {
                                if (current.length() + w.length() + 1 <= 150) {
                                    if (current.length() > 0) current.append(" ");
                                    current.append(w);
                                } else {
                                    if (current.length() > 0) list.add(current.toString().trim());
                                    current = new StringBuilder(w);
                                }
                            }
                        }
                    }
                }
                if (current.length() > 0) {
                    list.add(current.toString().trim());
                }
            }
        }
        return list;
    }
}
