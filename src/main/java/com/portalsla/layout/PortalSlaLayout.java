package com.portalsla.layout;

import java.util.List;
import java.util.Map;

/**
 * Saved per service project. Boxed fields stay null when the JSON omits them,
 * so the sanitizer can apply defaults instead of Gson zeros.
 */
public class PortalSlaLayout {

    public Integer version;
    public Boolean enabled;
    public Integer hoursPerDay;
    public Integer daysPerWeek;
    public List<Block> blocks;
    public Map<String, List<String>> selectors;

    public static class Block {
        public String id;
        public String variant;
        public String zone;
        public String title;
        public Boolean collapsed;
        public Boolean showName;
        public Boolean showStatus;
        public Boolean showPauseIcon;
        public Boolean showBreachTime;
        public String timeMode;
        public String timeStyle;
        public String textSource;
        public String metricMode;
        public List<Integer> metricIds;
        public Integer riskPercent;
        public Integer refreshSeconds;
        public Boolean hideWhenEmpty;
        public String customSelector;
        public String customPosition;
    }
}
