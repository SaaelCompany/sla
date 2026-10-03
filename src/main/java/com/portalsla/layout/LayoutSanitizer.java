package com.portalsla.layout;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

public final class LayoutSanitizer {

    public static final List<String> VARIANTS = Collections.unmodifiableList(Arrays.asList(
            "compact", "badges", "progress", "countdown", "cards", "timeline", "status-strip"));

    public static final List<String> ZONES = Collections.unmodifiableList(Arrays.asList(
            "header", "under-title", "beside-status", "above-description", "above-activity",
            "sidebar-top", "sidebar-bottom", "portal-panel", "request-footer", "my-requests", "custom"));

    private static final List<String> TIME_MODES = Arrays.asList("remaining", "elapsed", "goal");
    private static final List<String> TIME_STYLES = Arrays.asList("largest", "precise");
    private static final List<String> TEXT_SOURCES = Arrays.asList("portal", "jira");
    private static final List<String> METRIC_MODES = Arrays.asList("customer-visible", "all", "selected");
    private static final List<String> POSITIONS = Arrays.asList("before", "after", "prepend", "append");

    private static final Pattern ID = Pattern.compile("^[A-Za-z0-9_-]{1,40}$");
    private static final Pattern SELECTOR = Pattern.compile("^[\\w\\s\\[\\]\\.#>:\"'=+~*^$()|,\\-]{1,180}$");
    private static final int MAX_BLOCKS = 16;

    private LayoutSanitizer() {
    }

    public static final class Result {
        public final PortalSlaLayout layout;
        public final List<String> errors;

        Result(PortalSlaLayout layout, List<String> errors) {
            this.layout = layout;
            this.errors = errors;
        }

        public boolean ok() {
            return errors.isEmpty();
        }
    }

    public static Result sanitize(PortalSlaLayout input) {
        List<String> errors = new ArrayList<String>();
        PortalSlaLayout layout = new PortalSlaLayout();
        if (input == null) {
            errors.add("empty");
            layout.version = Integer.valueOf(1);
            layout.enabled = Boolean.FALSE;
            layout.hoursPerDay = Integer.valueOf(0);
            layout.daysPerWeek = Integer.valueOf(0);
            layout.blocks = new ArrayList<PortalSlaLayout.Block>();
            layout.selectors = new LinkedHashMap<String, List<String>>();
            return new Result(layout, errors);
        }

        layout.version = Integer.valueOf(1);
        layout.enabled = Boolean.valueOf(Boolean.TRUE.equals(input.enabled));
        layout.hoursPerDay = Integer.valueOf(clampOptional(input.hoursPerDay, 0, 24, "hours-per-day", errors));
        layout.daysPerWeek = Integer.valueOf(clampOptional(input.daysPerWeek, 0, 7, "days-per-week", errors));
        layout.blocks = new ArrayList<PortalSlaLayout.Block>();
        layout.selectors = sanitizeSelectors(input.selectors, errors);

        List<PortalSlaLayout.Block> source = input.blocks == null
                ? Collections.<PortalSlaLayout.Block>emptyList()
                : input.blocks;
        if (source.size() > MAX_BLOCKS) {
            errors.add("too-many-blocks");
        }
        Set<String> usedIds = new HashSet<String>();
        int limit = Math.min(source.size(), MAX_BLOCKS);
        for (int i = 0; i < limit; i++) {
            PortalSlaLayout.Block raw = source.get(i);
            if (raw == null) {
                errors.add("block-empty:" + i);
                continue;
            }
            layout.blocks.add(sanitizeBlock(raw, i, usedIds, errors));
        }
        return new Result(layout, errors);
    }

    private static int clampOptional(Integer value, int min, int max, String code, List<String> errors) {
        if (value == null || value.intValue() == 0) {
            return 0;
        }
        if (value.intValue() < min || value.intValue() > max) {
            errors.add(code);
            return 0;
        }
        return value.intValue();
    }

    private static PortalSlaLayout.Block sanitizeBlock(PortalSlaLayout.Block raw, int index, Set<String> usedIds,
                                                       List<String> errors) {
        PortalSlaLayout.Block block = new PortalSlaLayout.Block();
        block.id = cleanId(raw.id, usedIds);
        block.variant = enumValue(raw.variant, VARIANTS, "compact", "bad-variant:" + index, errors);
        block.zone = enumValue(raw.zone, ZONES, "sidebar-top", "bad-zone:" + index, errors);
        block.title = cleanTitle(raw.title);
        block.collapsed = Boolean.valueOf(Boolean.TRUE.equals(raw.collapsed));
        block.showName = Boolean.valueOf(raw.showName == null ? !"compact".equals(block.variant) : raw.showName.booleanValue());
        block.showStatus = Boolean.valueOf(raw.showStatus == null ? "status-strip".equals(block.variant) : raw.showStatus.booleanValue());
        block.showPauseIcon = Boolean.valueOf(raw.showPauseIcon == null || raw.showPauseIcon.booleanValue());
        block.showBreachTime = Boolean.valueOf(Boolean.TRUE.equals(raw.showBreachTime));
        block.timeMode = enumValue(raw.timeMode, TIME_MODES, "remaining", "bad-time-mode:" + index, errors);
        block.timeStyle = enumValue(raw.timeStyle, TIME_STYLES, "largest", "bad-time-style:" + index, errors);
        block.textSource = enumValue(raw.textSource, TEXT_SOURCES, "portal", "bad-text-source:" + index, errors);
        block.metricMode = enumValue(raw.metricMode, METRIC_MODES, "customer-visible", "bad-metric-mode:" + index, errors);
        block.metricIds = cleanMetricIds(raw.metricIds, index, errors);
        block.riskPercent = Integer.valueOf(clampInt(raw.riskPercent, 20, 1, 90));
        block.refreshSeconds = Integer.valueOf(clampInt(raw.refreshSeconds, 60, 15, 600));
        block.hideWhenEmpty = Boolean.valueOf(raw.hideWhenEmpty == null || raw.hideWhenEmpty.booleanValue());
        block.customPosition = enumValue(raw.customPosition, POSITIONS, "after", "bad-position:" + index, errors);
        block.customSelector = cleanSelector(raw.customSelector, false);
        if ("custom".equals(block.zone)) {
            if (block.customSelector.length() == 0 || !SELECTOR.matcher(block.customSelector).matches()) {
                errors.add("custom-selector:" + index);
                block.customSelector = "";
            }
        } else if (block.customSelector.length() > 0 && !SELECTOR.matcher(block.customSelector).matches()) {
            errors.add("bad-selector:" + index);
            block.customSelector = "";
        }
        return block;
    }

    private static String enumValue(String value, List<String> allowed, String fallback, String code, List<String> errors) {
        if (value == null || value.trim().length() == 0) {
            return fallback;
        }
        String normalized = value.trim().toLowerCase(Locale.US);
        if (!allowed.contains(normalized)) {
            errors.add(code);
            return fallback;
        }
        return normalized;
    }

    private static String cleanId(String id, Set<String> usedIds) {
        String candidate = id == null ? "" : id.trim();
        if (!ID.matcher(candidate).matches() || usedIds.contains(candidate)) {
            candidate = freshId(usedIds);
        }
        usedIds.add(candidate);
        return candidate;
    }

    private static String freshId(Set<String> usedIds) {
        String id;
        do {
            id = "b" + UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        } while (usedIds.contains(id));
        return id;
    }

    private static String cleanTitle(String title) {
        if (title == null) {
            return "SLA";
        }
        String cleaned = title.replace("<", "").replace(">", "").replace("\r", " ").replace("\n", " ").trim();
        if (cleaned.length() == 0) {
            return "SLA";
        }
        if (cleaned.length() > 80) {
            return cleaned.substring(0, 80);
        }
        return cleaned;
    }

    private static List<Integer> cleanMetricIds(List<Integer> ids, int index, List<String> errors) {
        List<Integer> clean = new ArrayList<Integer>();
        if (ids == null) {
            return clean;
        }
        Set<Integer> seen = new HashSet<Integer>();
        for (int i = 0; i < ids.size() && clean.size() < 20; i++) {
            Integer id = ids.get(i);
            if (id == null || id.intValue() <= 0) {
                errors.add("bad-metric-id:" + index);
                continue;
            }
            if (seen.add(id)) {
                clean.add(id);
            }
        }
        return clean;
    }

    private static int clampInt(Integer value, int fallback, int min, int max) {
        if (value == null) {
            return fallback;
        }
        int raw = value.intValue();
        if (raw < min) {
            return min;
        }
        if (raw > max) {
            return max;
        }
        return raw;
    }

    private static String cleanSelector(String selector, boolean required) {
        if (selector == null) {
            return "";
        }
        String trimmed = selector.trim();
        if (!required && trimmed.length() == 0) {
            return "";
        }
        return trimmed;
    }

    private static Map<String, List<String>> sanitizeSelectors(Map<String, List<String>> input, List<String> errors) {
        Map<String, List<String>> clean = new LinkedHashMap<String, List<String>>();
        if (input == null) {
            return clean;
        }
        for (Map.Entry<String, List<String>> entry : input.entrySet()) {
            if (entry.getKey() == null || !ZONES.contains(entry.getKey()) || "custom".equals(entry.getKey())) {
                continue;
            }
            List<String> selectors = new ArrayList<String>();
            List<String> raw = entry.getValue() == null ? Collections.<String>emptyList() : entry.getValue();
            for (int i = 0; i < raw.size() && selectors.size() < 8; i++) {
                String selector = raw.get(i) == null ? "" : raw.get(i).trim();
                if (selector.length() == 0) {
                    continue;
                }
                if (!SELECTOR.matcher(selector).matches()) {
                    errors.add("bad-selector:" + entry.getKey());
                    continue;
                }
                selectors.add(selector);
            }
            if (!selectors.isEmpty()) {
                clean.put(entry.getKey(), selectors);
            }
        }
        return clean;
    }
}
