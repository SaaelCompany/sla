package com.portalsla.layout;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonSyntaxException;

public final class LayoutCodec {

    private static final Gson GSON = new GsonBuilder()
            .disableHtmlEscaping()
            .setPrettyPrinting()
            .create();

    private LayoutCodec() {
    }

    public static PortalSlaLayout parse(String json) {
        if (json == null || json.trim().length() == 0) {
            throw new JsonSyntaxException("empty");
        }
        PortalSlaLayout layout = GSON.fromJson(json, PortalSlaLayout.class);
        if (layout == null) {
            throw new JsonSyntaxException("null");
        }
        return layout;
    }

    public static String write(PortalSlaLayout layout) {
        return GSON.toJson(layout);
    }

    public static String write(Object value) {
        return GSON.toJson(value);
    }

    public static <T> T parse(String json, Class<T> type) {
        if (json == null || json.trim().length() == 0) {
            throw new JsonSyntaxException("empty");
        }
        T value = GSON.fromJson(json, type);
        if (value == null) {
            throw new JsonSyntaxException("null");
        }
        return value;
    }
}
