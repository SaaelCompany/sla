package com.portalsla.servlet;

import com.atlassian.jira.config.properties.APKeys;
import com.atlassian.jira.config.properties.ApplicationProperties;
import com.atlassian.jira.project.Project;
import com.atlassian.jira.security.JiraAuthenticationContext;
import com.atlassian.jira.user.ApplicationUser;
import com.atlassian.plugin.spring.scanner.annotation.imports.ComponentImport;
import com.portalsla.PortalSlaException;
import com.portalsla.dto.PortalDtos.ProjectItem;
import com.portalsla.service.PortalSlaService;

import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URLEncoder;
import java.util.List;

@Named
public class EditorServlet extends HttpServlet {

    private final JiraAuthenticationContext authenticationContext;
    private final ApplicationProperties applicationProperties;
    private final PortalSlaService service;

    @Inject
    public EditorServlet(@ComponentImport JiraAuthenticationContext authenticationContext,
                         @ComponentImport ApplicationProperties applicationProperties,
                         PortalSlaService service) {
        this.authenticationContext = authenticationContext;
        this.applicationProperties = applicationProperties;
        this.service = service;
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        ApplicationUser user = authenticationContext.getLoggedInUser();
        String base = baseUrl();
        if (user == null) {
            String path = request.getRequestURI();
            String context = request.getContextPath() == null ? "" : request.getContextPath();
            if (path.startsWith(context)) {
                path = path.substring(context.length());
            }
            if (request.getQueryString() != null) {
                path = path + "?" + request.getQueryString();
            }
            response.sendRedirect(base + "/login.jsp?os_destination=" + URLEncoder.encode(path, "UTF-8"));
            return;
        }

        response.setCharacterEncoding("UTF-8");
        response.setContentType("text/html;charset=UTF-8");
        String projectKey = projectKey(request);
        if (projectKey == null) {
            writePicker(response, base, service.listProjects(user));
            return;
        }
        if (!inProjectConfig(request)) {
            response.sendRedirect(base + "/plugins/servlet/project-config/" + url(projectKey) + "/portal-sla");
            return;
        }

        Project project;
        try {
            project = service.requireEditorProject(user, projectKey.trim());
        } catch (PortalSlaException ex) {
            response.setStatus(ex.getStatus());
            String message = ex.getStatus() == 403
                    ? "Нужны права администратора этого сервисного проекта."
                    : "Сервисный проект не найден.";
            response.getWriter().write(messagePage(base, message));
            return;
        }

        String locale = authenticationContext.getLocale() == null
                ? "en"
                : authenticationContext.getLocale().toLanguageTag();
        String html = read("/templates/settings-shell.html")
                .replace("@@BASE@@", esc(base))
                .replace("@@PROJECT_KEY@@", esc(project.getKey()))
                .replace("@@PROJECT_NAME@@", esc(project.getName()))
                .replace("@@LOCALE@@", esc(locale))
                .replace("@@REST@@", esc(base + "/rest/portal-sla/1.0"))
                .replace("@@MOCK@@", "false");
        response.getWriter().write(html);
    }

    private void writePicker(HttpServletResponse response, String base, List<ProjectItem> projects) throws IOException {
        StringBuilder list = new StringBuilder();
        if (projects.isEmpty()) {
            list.append("<p class=\"psla-muted\">Нет сервисных проектов, где вы администратор.</p>");
        } else {
            list.append("<ul class=\"psla-picker-list\">");
            for (int i = 0; i < projects.size(); i++) {
                ProjectItem project = projects.get(i);
                String href = base + "/plugins/servlet/project-config/" + url(project.key) + "/portal-sla";
                list.append("<li><a href=\"").append(esc(href)).append("\"><strong>")
                        .append(esc(project.name)).append("</strong><span>")
                        .append(esc(project.key)).append("</span></a></li>");
            }
            list.append("</ul>");
        }
        String html = read("/templates/picker.html")
                .replace("@@BASE@@", esc(base))
                .replace("@@LIST@@", list.toString());
        response.getWriter().write(html);
    }

    private String messagePage(String base, String message) throws IOException {
        return read("/templates/picker.html")
                .replace("@@BASE@@", esc(base))
                .replace("@@LIST@@", "<p class=\"psla-muted\">" + esc(message) + "</p>");
    }

    private String projectKey(HttpServletRequest request) {
        String fromPath = projectKeyFromPath(request.getRequestURI());
        if (fromPath != null) {
            return fromPath;
        }
        String query = request.getParameter("projectKey");
        if (query == null || query.trim().length() == 0) {
            return null;
        }
        return query.trim();
    }

    private boolean inProjectConfig(HttpServletRequest request) {
        return projectKeyFromPath(request.getRequestURI()) != null;
    }

    private String projectKeyFromPath(String uri) {
        if (uri == null) {
            return null;
        }
        String marker = "/project-config/";
        int at = uri.indexOf(marker);
        if (at < 0) {
            return null;
        }
        String rest = uri.substring(at + marker.length());
        int slash = rest.indexOf('/');
        if (slash <= 0) {
            return null;
        }
        String tail = rest.substring(slash);
        if (!tail.equals("/portal-sla") && !tail.startsWith("/portal-sla/")) {
            return null;
        }
        return rest.substring(0, slash);
    }

    private String baseUrl() {
        String base = applicationProperties.getString(APKeys.JIRA_BASEURL);
        if (base == null) {
            return "";
        }
        if (base.endsWith("/")) {
            return base.substring(0, base.length() - 1);
        }
        return base;
    }

    private String read(String path) throws IOException {
        InputStream in = getClass().getResourceAsStream(path);
        if (in == null) {
            throw new IOException("Missing " + path);
        }
        try {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buffer = new byte[4096];
            int read;
            while ((read = in.read(buffer)) >= 0) {
                out.write(buffer, 0, read);
            }
            return new String(out.toByteArray(), "UTF-8");
        } finally {
            in.close();
        }
    }

    private static String esc(String value) {
        if (value == null) {
            return "";
        }
        return value.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;");
    }

    private static String url(String value) throws IOException {
        return URLEncoder.encode(value == null ? "" : value, "UTF-8");
    }
}
