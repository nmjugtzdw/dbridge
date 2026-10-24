package examples;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * cron 表达式的人类可读解析示例。
 *
 * <p>把「0 30 9 * * ?」这样的六段式 Quartz cron 翻译成人话，
 * 例如「每天 09:30」。仅演示通用的字符串解析思路，不涉及任何业务。
 */
public final class CronTextExample {

    private CronTextExample() {
    }

    private static final String[] CN_NUM = {
            "零", "一", "二", "三", "四", "五", "六", "七", "八", "九"
    };

    /**
     * 六段式 cron：秒 分 时 日 月 周。
     * 只覆盖最常见的几种写法，复杂表达式返回 null 表示无法翻译。
     */
    public static String toHuman(String cron) {
        if (cron == null) {
            return null;
        }
        String[] p = cron.trim().split("\\s+");
        if (p.length != 6 && p.length != 7) {
            return null;
        }
        String sec = p[0];
        String min = p[1];
        String hour = p[2];
        String day = p[3];
        String month = p[4];
        String week = p[5];

        // 每天固定时间：秒=0，分和时是具体数字，日/月/周是 *
        if ("0".equals(sec) && isNum(min) && isNum(hour)
                && "*".equals(day) && ("*".equals(month) || "?".equals(month)) && "*".equals(week)) {
            return "每天 " + hhmm(hour, min);
        }

        // 每隔 N 分钟
        if ("0".equals(sec) && min.startsWith("*/")) {
            String n = min.substring(2);
            if (isNum(n)) {
                return "每隔 " + n + " 分钟";
            }
        }

        // 每周某天固定时间
        if ("0".equals(sec) && isNum(min) && isNum(hour) && "?".equals(day) && "*".equals(month) && !"*".equals(week)) {
            String w = weekName(week);
            if (w != null) {
                return "每周" + w + " " + hhmm(hour, min);
            }
        }

        return null;
    }

    private static String hhmm(String hour, String min) {
        return pad(hour) + ":" + pad(min);
    }

    private static String pad(String s) {
        int v = Integer.parseInt(s);
        return (v < 10 ? "0" : "") + v;
    }

    private static boolean isNum(String s) {
        return s != null && s.matches("\\d{1,2}");
    }

    private static String weekName(String week) {
        Map<String, String> map = new LinkedHashMap<>();
        map.put("1", "日");
        map.put("2", "一");
        map.put("3", "二");
        map.put("4", "三");
        map.put("5", "四");
        map.put("6", "五");
        map.put("7", "六");
        return map.get(week);
    }
}
