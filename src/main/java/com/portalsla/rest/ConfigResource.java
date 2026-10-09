package com.portalsla.rest;

import com.atlassian.jira.security.JiraAuthenticationContext;
import com.atlassian.plugin.spring.scanner.annotation.imports.ComponentImport;
import com.portalsla.PortalSlaException;
import com.portalsla.service.PortalSlaService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Inject;
import javax.inject.Named;
import javax.ws.rs.Consumes;
import javax.ws.rs.GET;
import javax.ws.rs.PUT;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

@Named
@Path("/config")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ConfigResource {

    private static final Logger log = LoggerFactory.getLogger(ConfigResource.class);

    private final PortalSlaService service;
    private final JiraAuthenticationContext authenticationContext;

    @Inject
    public ConfigResource(PortalSlaService service,
                          @ComponentImport JiraAuthenticationContext authenticationContext) {
        this.service = service;
        this.authenticationContext = authenticationContext;
    }

    @GET
    @Path("/{projectKey}")
    public Response get(@PathParam("projectKey") String projectKey) {
        try {
            return RestResponses.json(service.configJson(authenticationContext.getLoggedInUser(), projectKey));
        } catch (PortalSlaException ex) {
            return RestResponses.error(ex);
        } catch (RuntimeException ex) {
            return RestResponses.failure(log, ex);
        }
    }

    @PUT
    @Path("/{projectKey}")
    public Response put(@PathParam("projectKey") String projectKey, String body) {
        try {
            service.save(authenticationContext.getLoggedInUser(), projectKey, body);
            return RestResponses.json(service.configJson(authenticationContext.getLoggedInUser(), projectKey));
        } catch (PortalSlaException ex) {
            return RestResponses.error(ex);
        } catch (RuntimeException ex) {
            return RestResponses.failure(log, ex);
        }
    }

    @GET
    @Path("/{projectKey}/preview/{issueKey}")
    public Response preview(@PathParam("projectKey") String projectKey, @PathParam("issueKey") String issueKey) {
        try {
            return RestResponses.json(service.previewJson(authenticationContext.getLoggedInUser(), projectKey, issueKey));
        } catch (PortalSlaException ex) {
            return RestResponses.error(ex);
        } catch (RuntimeException ex) {
            return RestResponses.failure(log, ex);
        }
    }
}
