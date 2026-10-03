package com.portalsla.dto;

import com.portalsla.layout.PortalSlaLayout;

import java.util.List;
import java.util.Map;

public final class PortalDtos {

    private PortalDtos() {
    }

    public static class PortalView {
        public boolean enabled;
        public String issueKey;
        public String locale;
        public int hoursPerDay;
        public int daysPerWeek;
        public int refreshSeconds;
        public List<PortalSlaLayout.Block> blocks;
        public Map<String, List<String>> selectors;
        public StatusView status;
        public List<MetricView> metrics;
    }

    public static class StatusView {
        public String name;
        public String category;
    }

    public static class MetricView {
        public int id;
        public String name;
        public boolean customerVisible;
        public boolean ongoing;
        public boolean paused;
        public boolean breached;
        public boolean withinCalendarHours;
        public long remainingMs;
        public long elapsedMs;
        public long goalMs;
        public Long breachTimeMs;
        public Long startTimeMs;
        public Long stopTimeMs;
        public JiraTexts jira;
        public List<CycleView> cycles;
    }

    public static class CycleView {
        public boolean ongoing;
        public boolean breached;
        public boolean paused;
        public long elapsedMs;
        public long remainingMs;
        public long goalMs;
        public Long startTimeMs;
        public Long stopTimeMs;
        public Long breachTimeMs;
    }

    public static class JiraTexts {
        public String remainingShort;
        public String remainingLong;
        public String elapsedShort;
        public String elapsedLong;
        public String goalShort;
        public String goalLong;
    }

    public static class ConfigView {
        public String projectKey;
        public String projectName;
        public PortalSlaLayout layout;
        public List<CatalogMetric> catalog;
        public int jiraHoursPerDay;
        public int jiraDaysPerWeek;
        public String warning;
    }

    public static class CatalogMetric {
        public int id;
        public String name;
        public boolean customerVisible;
    }

    public static class BulkView {
        public String locale;
        public List<PortalView> items;
    }

    public static class BulkKeys {
        public List<String> keys;
    }

    public static class ErrorView {
        public String error;
        public List<String> messages;
    }

    public static class ProjectItem {
        public String key;
        public String name;
    }
}
