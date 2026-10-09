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
    public void negativeAndZero() {
        assertEquals("\u22121 \u0434.", DurationTexts.format(-8 * HOUR, "largest", 8, 5, RU));
        assertEquals("0 \u043c\u0438\u043d.", DurationTexts.format(0L, "largest", 8, 5, RU));
        assertEquals("-1d", DurationTexts.format(-8 * HOUR, "largest", 8, 5, Locale.ENGLISH));
    }
}
