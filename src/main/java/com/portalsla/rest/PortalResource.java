package com.portalsla.rest;

import com.atlassian.jira.security.JiraAuthenticationContext;
import com.atlassian.plugin.spring.scanner.annotation.imports.ComponentImport;
import com.atlassian.plugins.rest.common.security.AnonymousAllowed;
import com.portalsla.PortalSlaException;
import com.portalsla.service.PortalSlaService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Inject;
import javax.inject.Named;
import javax.ws.rs.Consumes;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

/**
 * Customer-portal read API. Anonymous callers are allowed because a service
 * desk can open the portal without a login; visibility is still decided by
 * {@code ServiceDeskCustomerRequestService}.
 */
@Named
@AnonymousAllowed
@Path("/portal")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class PortalResource {

    private static final Logger log = LoggerFactory.getLogger(PortalResource.class);

    private final PortalSlaService service;
    private final JiraAuthenticationContext authenticationContext;

    @Inject
    public PortalResource(PortalSlaService service,
                          @ComponentImport JiraAuthenticationContext authenticationContext) {
        this.service = service;
        this.authenticationContext = authenticationContext;
    }

    @GET
    @Path("/request/{issueKey}")
    public Response request(@PathParam("issueKey") String issueKey) {
        try {
            return RestResponses.json(service.portalJson(authenticationContext.getLoggedInUser(), issueKey));
        } catch (PortalSlaException ex) {
            return RestResponses.error(ex);
        } catch (RuntimeException ex) {
            return RestResponses.failure(log, ex);
        }
    }

    @POST
    @Path("/requests")
    public Response requests(String body) {
        try {
            return RestResponses.json(service.bulkJson(authenticationContext.getLoggedInUser(), body));
        } catch (PortalSlaException ex) {
            return RestResponses.error(ex);
        } catch (RuntimeException ex) {
            return RestResponses.failure(log, ex);
        }
    }
}
