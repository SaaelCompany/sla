package com.portalsla.layout;

import java.util.Locale;

/**
 * Short SLA durations in the customer-portal style.
 * A day is the Jira working day ({@code hoursPerDay}, 8 by default), same as time tracking,
 * so an 8-hour goal is shown as {@code 1 д.} The screenshot layout uses {@code largest}.
 */
public final class DurationTexts {

    private DurationTexts() {
    }

    public static String format(long millis, String style, int hoursPerDay, int daysPerWeek, Locale locale) {
        int dayHours = hoursPerDay < 1 || hoursPerDay > 24 ? 8 : hoursPerDay;
        int weekDays = daysPerWeek < 1 || daysPerWeek > 7 ? 5 : daysPerWeek;
        boolean russian = locale != null && "ru".equalsIgnoreCase(locale.getLanguage());
        boolean spoken = "spoken".equals(style);
        boolean precise = "precise".equals(style);

        long abs = millis < 0 ? -millis : millis;
        long minute = 60L * 1000L;
        if (abs > 0L && abs < minute) {
            abs = minute;
        }
        long hour = 60L * minute;
        long day = dayHours * hour;
        long week = weekDays * day;

        long weeks = abs / week;
        long days = (abs % week) / day;
        long hours = (abs % day) / hour;
        long minutes = (abs % hour) / minute;

        String text = spoken
                ? spoken(weeks, days, hours, minutes, russian)
                : precise
                    ? precise(weeks, days, hours, minutes, russian)
                    : largest(weeks, days, hours, minutes, russian);
        if (millis < 0L && !"0".equals(text) && text.length() > 0) {
            return (russian ? "\u2212" : "-") + text;
        }
        return text;
    }

    private static String largest(long weeks, long days, long hours, long minutes, boolean russian) {
        if (weeks > 0L) {
            return unit(weeks, russian ? "\u043d." : "w", russian);
        }
        if (days > 0L) {
            return unit(days, russian ? "\u0434." : "d", russian);
        }
        if (hours > 0L) {
            return unit(hours, russian ? "\u0447." : "h", russian);
        }
        if (minutes > 0L) {
            return unit(minutes, russian ? "\u043c\u0438\u043d." : "m", russian);
        }
        return russian ? "0 \u043c\u0438\u043d." : "0m";
    }

    private static String precise(long weeks, long days, long hours, long minutes, boolean russian) {
        long[] values = new long[] {weeks, days, hours, minutes};
        String[] labels = russian
                ? new String[] {"\u043d.", "\u0434.", "\u0447.", "\u043c\u0438\u043d."}
                : new String[] {"w", "d", "h", "m"};
        StringBuilder out = new StringBuilder();
        int shown = 0;
        for (int i = 0; i < values.length; i++) {
            if (values[i] <= 0L) {
                continue;
            }
            if (shown == 2) {
                break;
            }
            if (shown > 0) {
                out.append(' ');
            }
            out.append(unit(values[i], labels[i], russian));
            shown++;
        }
        if (shown == 0) {
            return russian ? "0 \u043c\u0438\u043d." : "0m";
        }
        return out.toString();
    }

    private static String spoken(long weeks, long days, long hours, long minutes, boolean russian) {
        long[] values = new long[] {weeks, days, hours, minutes};
        String[][] ru = new String[][] {
                {"\u043d\u0435\u0434\u0435\u043b\u044f", "\u043d\u0435\u0434\u0435\u043b\u0438", "\u043d\u0435\u0434\u0435\u043b\u044c"},
                {"\u0434\u0435\u043d\u044c", "\u0434\u043d\u044f", "\u0434\u043d\u0435\u0439"},
                {"\u0447\u0430\u0441", "\u0447\u0430\u0441\u0430", "\u0447\u0430\u0441\u043e\u0432"},
                {"\u043c\u0438\u043d\u0443\u0442\u0430", "\u043c\u0438\u043d\u0443\u0442\u044b", "\u043c\u0438\u043d\u0443\u0442"}
        };
        String[][] en = new String[][] {
                {"week", "weeks"},
                {"day", "days"},
                {"hour", "hours"},
                {"minute", "minutes"}
        };
        StringBuilder out = new StringBuilder();
        int shown = 0;
        for (int i = 0; i < values.length; i++) {
            if (values[i] <= 0L) {
                continue;
            }
            if (shown == 2) {
                break;
            }
            if (shown > 0) {
                out.append(' ');
            }
            if (russian) {
                out.append(values[i]).append(' ').append(ruPlural(values[i], ru[i][0], ru[i][1], ru[i][2]));
            } else {
                out.append(values[i]).append(' ').append(values[i] == 1L ? en[i][0] : en[i][1]);
            }
            shown++;
        }
        if (shown == 0) {
            return russian ? "0 \u043c\u0438\u043d\u0443\u0442" : "0 minutes";
        }
        return out.toString();
    }

    private static String ruPlural(long value, String one, String few, String many) {
        long n10 = value % 10L;
        long n100 = value % 100L;
        if (n10 == 1L && n100 != 11L) {
            return one;
        }
        if (n10 >= 2L && n10 <= 4L && (n100 < 12L || n100 > 14L)) {
            return few;
        }
        return many;
    }

    private static String unit(long value, String label, boolean russian) {
        if (russian) {
            return value + " " + label;
        }
        return value + label;
    }
}
