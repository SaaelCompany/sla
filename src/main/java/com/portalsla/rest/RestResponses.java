package com.portalsla.rest;

import com.portalsla.PortalSlaException;
import com.portalsla.dto.PortalDtos.ErrorView;
import com.portalsla.layout.LayoutCodec;
import org.slf4j.Logger;

import javax.ws.rs.core.Response;

final class RestResponses {

    private RestResponses() {
    }

    static Response json(String body) {
        return Response.ok(body, "application/json;charset=UTF-8")
                .header("Cache-Control", "no-store")
                .build();
    }

    static Response error(PortalSlaException exception) {
        ErrorView body = new ErrorView();
        body.error = exception.getCode();
        body.messages = exception.getMessages();
        return Response.status(exception.getStatus())
                .entity(LayoutCodec.write(body))
                .type("application/json;charset=UTF-8")
                .build();
    }

    static Response failure(Logger log, RuntimeException exception) {
        log.error("Portal SLA request failed", exception);
        ErrorView body = new ErrorView();
        body.error = "error";
        return Response.status(500)
                .entity(LayoutCodec.write(body))
                .type("application/json;charset=UTF-8")
                .build();
    }
}
