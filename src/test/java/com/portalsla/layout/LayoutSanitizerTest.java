package com.portalsla.layout;

import org.junit.Test;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class LayoutSanitizerTest {

    @Test
    public void defaultLayoutMatchesTheCompactPortalBlock() throws Exception {
        InputStream in = getClass().getResourceAsStream("/default-layout.json");
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buffer = new byte[1024];
        int read;
        while ((read = in.read(buffer)) >= 0) {
            out.write(buffer, 0, read);
        }
        in.close();
        PortalSlaLayout layout = LayoutCodec.parse(new String(out.toByteArray(), "UTF-8"));
        LayoutSanitizer.Result result = LayoutSanitizer.sanitize(layout);

        assertTrue(result.ok());
        assertTrue(result.layout.enabled.booleanValue());
        assertEquals(1, result.layout.blocks.size());
        PortalSlaLayout.Block block = result.layout.blocks.get(0);
        assertEquals("plain", block.variant);
        assertEquals("sidebar-top", block.zone);
        assertEquals("SLA", block.title);
        assertTrue(block.showName.booleanValue());
        assertFalse(block.showStatus.booleanValue());
        assertTrue(block.showPauseIcon.booleanValue());
        assertTrue(block.showBreachTime.booleanValue());
        assertEquals("remaining", block.timeMode);
        assertEquals("spoken", block.timeStyle);
        assertEquals("customer-visible", block.metricMode);
    }

    @Test
    public void rejectsUnknownVariantAndUnsafeSelector() {
        PortalSlaLayout layout = new PortalSlaLayout();
        layout.enabled = Boolean.TRUE;
        PortalSlaLayout.Block block = new PortalSlaLayout.Block();
        block.variant = "marquee";
        block.zone = "custom";
        block.title = "<script>alert(1)</script>SLA";
        block.customSelector = "div <script>";
        block.metricIds = Arrays.asList(Integer.valueOf(3), Integer.valueOf(-1), Integer.valueOf(3));
        layout.blocks = Collections.singletonList(block);

        LayoutSanitizer.Result result = LayoutSanitizer.sanitize(layout);

        assertFalse(result.ok());
        assertTrue(result.errors.contains("bad-variant:0"));
        assertTrue(result.errors.contains("custom-selector:0"));
        assertTrue(result.errors.contains("bad-metric-id:0"));
        assertEquals("scriptalert(1)/scriptSLA", result.layout.blocks.get(0).title);
        assertEquals(Collections.singletonList(Integer.valueOf(3)), result.layout.blocks.get(0).metricIds);
    }

    @Test
    public void clampsRiskAndDropsBadZoneSelectors() {
        PortalSlaLayout layout = new PortalSlaLayout();
        PortalSlaLayout.Block block = new PortalSlaLayout.Block();
        block.variant = "badges";
        block.zone = "under-title";
        block.riskPercent = Integer.valueOf(500);
        block.refreshSeconds = Integer.valueOf(1);
        layout.blocks = Collections.singletonList(block);
        layout.selectors = Collections.singletonMap("under-title", Arrays.asList(".cv-request-header", "<style>", ""));

        LayoutSanitizer.Result result = LayoutSanitizer.sanitize(layout);

        assertEquals(Integer.valueOf(90), result.layout.blocks.get(0).riskPercent);
        assertEquals(Integer.valueOf(15), result.layout.blocks.get(0).refreshSeconds);
        assertTrue(result.errors.contains("bad-selector:under-title"));
        assertEquals(Collections.singletonList(".cv-request-header"), result.layout.selectors.get("under-title"));
    }

    @Test
    public void acceptsCustomerVariantsAndDropsRequestStatus() {
        PortalSlaLayout layout = new PortalSlaLayout();
        layout.enabled = Boolean.TRUE;
        String[] variants = new String[] {"plain", "portal", "when", "facts"};
        layout.blocks = new ArrayList<PortalSlaLayout.Block>();
        for (int i = 0; i < variants.length; i++) {
            PortalSlaLayout.Block block = new PortalSlaLayout.Block();
            block.variant = variants[i];
            block.zone = "sidebar-top";
            block.timeStyle = "spoken";
            block.showStatus = Boolean.TRUE;
            layout.blocks.add(block);
        }

        LayoutSanitizer.Result result = LayoutSanitizer.sanitize(layout);

        assertTrue(result.ok());
        assertEquals(4, result.layout.blocks.size());
        assertEquals("plain", result.layout.blocks.get(0).variant);
        assertEquals("portal", result.layout.blocks.get(1).variant);
        assertEquals("when", result.layout.blocks.get(2).variant);
        assertEquals("facts", result.layout.blocks.get(3).variant);
        assertEquals("spoken", result.layout.blocks.get(0).timeStyle);
        assertFalse(result.layout.blocks.get(0).showStatus.booleanValue());
        assertFalse(result.layout.blocks.get(1).showStatus.booleanValue());
    }
}
