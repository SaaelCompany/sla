package com.portalsla.service;

import com.atlassian.plugin.spring.scanner.annotation.imports.ComponentImport;
import com.atlassian.sal.api.pluginsettings.PluginSettings;
import com.atlassian.sal.api.pluginsettings.PluginSettingsFactory;
import com.google.gson.JsonSyntaxException;
import com.portalsla.layout.LayoutCodec;
import com.portalsla.layout.LayoutSanitizer;
import com.portalsla.layout.PortalSlaLayout;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Inject;
import javax.inject.Named;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

@Named
public class LayoutStore {

    private static final Logger log = LoggerFactory.getLogger(LayoutStore.class);
    private static final String PREFIX = "com.portalsla.portal-sla.project.";
    private static final String ENTRY = "layout";

    private final PluginSettingsFactory settingsFactory;

    @Inject
    public LayoutStore(@ComponentImport PluginSettingsFactory settingsFactory) {
        this.settingsFactory = settingsFactory;
    }

    public Stored load(long projectId) {
        Object raw = settingsFactory.createSettingsForKey(PREFIX + projectId).get(ENTRY);
        if (!(raw instanceof String) || ((String) raw).trim().length() == 0) {
            return Stored.missing();
        }
        try {
            LayoutSanitizer.Result result = LayoutSanitizer.sanitize(LayoutCodec.parse((String) raw));
            if (!result.ok()) {
                log.warn("Stored portal SLA layout for project {} is invalid", Long.valueOf(projectId));
                return Stored.corrupt();
            }
            return Stored.ok(result.layout);
        } catch (JsonSyntaxException ex) {
            log.warn("Stored portal SLA layout for project {} is not valid JSON", Long.valueOf(projectId));
            return Stored.corrupt();
        }
    }

    public void save(long projectId, PortalSlaLayout layout) {
        PluginSettings settings = settingsFactory.createSettingsForKey(PREFIX + projectId);
        settings.put(ENTRY, LayoutCodec.write(layout));
    }

    public PortalSlaLayout defaults() {
        InputStream in = getClass().getResourceAsStream("/default-layout.json");
        if (in == null) {
            throw new IllegalStateException("default-layout.json is missing");
        }
        try {
            String json = read(in);
            return LayoutSanitizer.sanitize(LayoutCodec.parse(json)).layout;
        } catch (IOException ex) {
            throw new IllegalStateException("default-layout.json cannot be read", ex);
        } finally {
            try {
                in.close();
            } catch (IOException ignored) {
                // already returning or throwing
            }
        }
    }

    private static String read(InputStream in) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buffer = new byte[4096];
        int read;
        while ((read = in.read(buffer)) >= 0) {
            out.write(buffer, 0, read);
        }
        return new String(out.toByteArray(), "UTF-8");
    }

    public static final class Stored {
        public final PortalSlaLayout layout;
        public final boolean corrupt;

        private Stored(PortalSlaLayout layout, boolean corrupt) {
            this.layout = layout;
            this.corrupt = corrupt;
        }

        static Stored missing() {
            return new Stored(null, false);
        }

        static Stored corrupt() {
            return new Stored(null, true);
        }

        static Stored ok(PortalSlaLayout layout) {
            return new Stored(layout, false);
        }
    }
}
