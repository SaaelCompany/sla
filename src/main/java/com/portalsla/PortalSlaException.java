package com.portalsla;

import java.util.Collections;
import java.util.List;

public final class PortalSlaException extends RuntimeException {

    private final int status;
    private final String code;
    private final List<String> messages;

    public PortalSlaException(int status, String code) {
        this(status, code, Collections.<String>emptyList());
    }

    public PortalSlaException(int status, String code, List<String> messages) {
        super(code);
        this.status = status;
        this.code = code;
        this.messages = messages == null ? Collections.<String>emptyList() : messages;
    }

    public int getStatus() {
        return status;
    }

    public String getCode() {
        return code;
    }

    public List<String> getMessages() {
        return messages;
    }
}
