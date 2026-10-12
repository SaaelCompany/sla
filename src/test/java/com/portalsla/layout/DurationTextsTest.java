package com.portalsla.layout;

import org.junit.Test;

import java.util.Locale;

import static org.junit.Assert.assertEquals;

public class DurationTextsTest {

    private static final Locale RU = new Locale("ru");
    private static final long HOUR = 60L * 60L * 1000L;

    @Test
    public void screenshotUsesWorkingDays() {
        assertEquals("1 \u0434.", DurationTexts.format(8 * HOUR, "largest", 8, 5, RU));
        assertEquals("2 \u0434.", DurationTexts.format(16 * HOUR, "largest", 8, 5, RU));
    }

    @Test
    public void preciseKeepsTwoUnits() {
        assertEquals("1 \u0447. 30 \u043c\u0438\u043d.", DurationTexts.format(90L * 60L * 1000L, "precise", 8, 5, RU));
        assertEquals("1h 30m", DurationTexts.format(90L * 60L * 1000L, "precise", 8, 5, Locale.ENGLISH));
    }

    @Test
    public void largestStopsAtTheBiggestUnit() {
        assertEquals("1 \u0447.", DurationTexts.format(90L * 60L * 1000L, "largest", 8, 5, RU));
        assertEquals("45 \u043c\u0438\u043d.", DurationTexts.format(45L * 60L * 1000L, "largest", 8, 5, RU));
        assertEquals("1 \u043d.", DurationTexts.format(5 * 8 * HOUR, "largest", 8, 5, RU));
        assertEquals("1d", DurationTexts.format(24 * HOUR, "largest", 24, 7, Locale.ENGLISH));
    }

    @Test
    public void spokenUsesFullWords() {
        assertEquals("1 \u0434\u0435\u043d\u044c", DurationTexts.format(8 * HOUR, "spoken", 8, 5, RU));
        assertEquals("2 \u0434\u043d\u044f", DurationTexts.format(16 * HOUR, "spoken", 8, 5, RU));
        assertEquals("4 \u0434\u043d\u044f", DurationTexts.format(4 * 8 * HOUR, "spoken", 8, 5, RU));
        assertEquals("1 \u043d\u0435\u0434\u0435\u043b\u044f", DurationTexts.format(5 * 8 * HOUR, "spoken", 8, 5, RU));
        assertEquals("5 \u0434\u043d\u0435\u0439", DurationTexts.format(5 * 8 * HOUR, "spoken", 8, 7, RU));
        assertEquals("11 \u043c\u0438\u043d\u0443\u0442", DurationTexts.format(11L * 60L * 1000L, "spoken", 8, 5, RU));
        assertEquals("21 \u043c\u0438\u043d\u0443\u0442\u0430", DurationTexts.format(21L * 60L * 1000L, "spoken", 8, 5, RU));
        assertEquals("22 \u043c\u0438\u043d\u0443\u0442\u044b", DurationTexts.format(22L * 60L * 1000L, "spoken", 8, 5, RU));
        assertEquals("1 \u0447\u0430\u0441 30 \u043c\u0438\u043d\u0443\u0442", DurationTexts.format(90L * 60L * 1000L, "spoken", 8, 5, RU));
        assertEquals("1 hour", DurationTexts.format(HOUR, "spoken", 8, 5, Locale.ENGLISH));
        assertEquals("2 hours", DurationTexts.format(2 * HOUR, "spoken", 8, 5, Locale.ENGLISH));
        assertEquals("\u22121 \u0434\u0435\u043d\u044c", DurationTexts.format(-8 * HOUR, "spoken", 8, 5, RU));
        assertEquals("0 \u043c\u0438\u043d\u0443\u0442", DurationTexts.format(0L, "spoken", 8, 5, RU));
    }

    @Test
    public void negativeAndZero() {
        assertEquals("\u22121 \u0434.", DurationTexts.format(-8 * HOUR, "largest", 8, 5, RU));
        assertEquals("0 \u043c\u0438\u043d.", DurationTexts.format(0L, "largest", 8, 5, RU));
        assertEquals("-1d", DurationTexts.format(-8 * HOUR, "largest", 8, 5, Locale.ENGLISH));
    }
}
