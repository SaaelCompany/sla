package com.portalsla.service;

import com.atlassian.jira.config.properties.APKeys;
import com.atlassian.jira.config.properties.ApplicationProperties;
import com.atlassian.jira.issue.Issue;
import com.atlassian.jira.issue.IssueManager;
import com.atlassian.jira.permission.GlobalPermissionKey;
import com.atlassian.jira.permission.ProjectPermissions;
import com.atlassian.jira.project.Project;
import com.atlassian.jira.project.ProjectManager;
import com.atlassian.jira.security.GlobalPermissionManager;
import com.atlassian.jira.security.JiraAuthenticationContext;
import com.atlassian.jira.security.PermissionManager;
import com.atlassian.jira.user.ApplicationUser;
import com.atlassian.plugin.spring.scanner.annotation.imports.ComponentImport;
import com.atlassian.servicedesk.api.ServiceDesk;
import com.atlassian.servicedesk.api.ServiceDeskService;
import com.atlassian.servicedesk.api.ServiceDeskServiceException;
import com.atlassian.servicedesk.api.request.CustomerRequest;
import com.atlassian.servicedesk.api.request.ServiceDeskCustomerRequestService;
import com.atlassian.servicedesk.api.sla.info.SlaInformation;
import com.atlassian.servicedesk.api.sla.info.SlaInformationCompletedCycle;
import com.atlassian.servicedesk.api.sla.info.SlaInformationOngoingCycle;
import com.atlassian.servicedesk.api.sla.info.SlaInformationQuery;
import com.atlassian.servicedesk.api.sla.info.SlaInformationService;
import com.atlassian.servicedesk.api.sla.metrics.TimeMetric;
import com.atlassian.servicedesk.api.sla.metrics.TimeMetricService;
import com.atlassian.servicedesk.api.util.paging.PagedResponse;
import com.atlassian.servicedesk.api.util.paging.SimplePagedRequest;
import com.portalsla.PortalSlaException;
import com.portalsla.dto.PortalDtos.BulkKeys;
import com.portalsla.dto.PortalDtos.BulkView;
import com.portalsla.dto.PortalDtos.CatalogMetric;
import com.portalsla.dto.PortalDtos.ConfigView;
import com.portalsla.dto.PortalDtos.CycleView;
import com.portalsla.dto.PortalDtos.JiraTexts;
import com.portalsla.dto.PortalDtos.MetricView;
import com.portalsla.dto.PortalDtos.PortalView;
import com.portalsla.dto.PortalDtos.ProjectItem;
import com.portalsla.dto.PortalDtos.StatusView;
import com.portalsla.layout.LayoutCodec;
import com.portalsla.layout.LayoutSanitizer;
import com.portalsla.layout.PortalSlaLayout;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Inject;
import javax.inject.Named;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.regex.Pattern;

@Named
public class PortalSlaService {

    private static final Logger log = LoggerFactory.getLogger(PortalSlaService.class);
    private static final Pattern PROJECT_KEY = Pattern.compile("^[A-Za-z][A-Za-z0-9]{1,31}$");
    private static final Pattern ISSUE_KEY = Pattern.compile("^[A-Z][A-Z0-9]+-\\d+$");

    private final LayoutStore layoutStore;
    private final JiraAuthenticationContext authenticationContext;
    private final ApplicationProperties applicationProperties;
    private final IssueManager issueManager;
    private final ProjectManager projectManager;
    private final PermissionManager permissionManager;
    private final GlobalPermissionManager globalPermissionManager;
    private final ServiceDeskService serviceDeskService;
    private final ServiceDeskCustomerRequestService customerRequestService;
    private final SlaInformationService slaInformationService;
    private final TimeMetricService timeMetricService;

    @Inject
    public PortalSlaService(LayoutStore layoutStore,
                            @ComponentImport JiraAuthenticationContext authenticationContext,
                            @ComponentImport ApplicationProperties applicationProperties,
                            @ComponentImport IssueManager issueManager,
                            @ComponentImport ProjectManager projectManager,
                            @ComponentImport PermissionManager permissionManager,
                            @ComponentImport GlobalPermissionManager globalPermissionManager,
                            @ComponentImport ServiceDeskService serviceDeskService,
                            @ComponentImport ServiceDeskCustomerRequestService customerRequestService,
                            @ComponentImport SlaInformationService slaInformationService,
                            @ComponentImport TimeMetricService timeMetricService) {
        this.layoutStore = layoutStore;
        this.authenticationContext = authenticationContext;
        this.applicationProperties = applicationProperties;
        this.issueManager = issueManager;
        this.projectManager = projectManager;
        this.permissionManager = permissionManager;
        this.globalPermissionManager = globalPermissionManager;
        this.serviceDeskService = serviceDeskService;
        this.customerRequestService = customerRequestService;
        this.slaInformationService = slaInformationService;
        this.timeMetricService = timeMetricService;
    }

    public String portalJson(ApplicationUser user, String issueKey) {
        Visible visible = requireVisible(user, issueKey);
        return LayoutCodec.write(buildView(user, visible.issue, visible.request, null));
    }

    public String bulkJson(ApplicationUser user, String json) {
        if (user == null) {
            throw new PortalSlaException(401, "auth");
        }
        BulkKeys body;
        try {
            body = LayoutCodec.parse(json, BulkKeys.class);
        } catch (RuntimeException ex) {
            throw new PortalSlaException(400, "invalid-json");
        }
        BulkView bulk = new BulkView();
        bulk.locale = localeTag();
        bulk.items = new ArrayList<PortalView>();
        if (body.keys == null) {
            return LayoutCodec.write(bulk);
        }
        Set<String> seen = new HashSet<String>();
        for (int i = 0; i < body.keys.size() && bulk.items.size() < 30; i++) {
            String raw = body.keys.get(i);
            if (raw == null) {
                continue;
            }
            String key = raw.trim().toUpperCase(Locale.US);
            if (!seen.add(key)) {
                continue;
            }
            try {
                Visible visible = requireVisible(user, key);
                bulk.items.add(buildView(user, visible.issue, visible.request, "my-requests"));
            } catch (PortalSlaException ex) {
                log.debug("Skipping request {} for the portal list", key);
            }
        }
        return LayoutCodec.write(bulk);
    }

    public String configJson(ApplicationUser user, String projectKey) {
        Project project = requireServiceProjectAdmin(user, projectKey);
        LayoutStore.Stored stored = layoutStore.load(project.getId().longValue());
        ConfigView view = new ConfigView();
        view.projectKey = project.getKey();
        view.projectName = project.getName();
        view.jiraHoursPerDay = trackingHours();
        view.jiraDaysPerWeek = trackingDays();
        if (stored.corrupt) {
            view.layout = layoutStore.defaults();
            view.warning = "corrupt";
        } else if (stored.layout == null) {
            view.layout = layoutStore.defaults();
        } else {
            view.layout = stored.layout;
        }
        List<CatalogMetric> catalog = catalog(user, project);
        if (catalog == null) {
            view.catalog = new ArrayList<CatalogMetric>();
            if (view.warning == null) {
                view.warning = "metrics-unavailable";
            }
        } else {
            view.catalog = catalog;
        }
        return LayoutCodec.write(view);
    }

    public void save(ApplicationUser user, String projectKey, String json) {
        Project project = requireServiceProjectAdmin(user, projectKey);
        PortalSlaLayout parsed;
        try {
            parsed = LayoutCodec.parse(json);
        } catch (RuntimeException ex) {
            throw new PortalSlaException(400, "invalid-json");
        }
        LayoutSanitizer.Result result = LayoutSanitizer.sanitize(parsed);
        if (!result.ok()) {
            throw new PortalSlaException(400, "invalid-layout", result.errors);
        }
        layoutStore.save(project.getId().longValue(), result.layout);
    }

    public String previewJson(ApplicationUser user, String projectKey, String issueKey) {
        Project project = requireServiceProjectAdmin(user, projectKey);
        Issue issue = requireIssueInProject(issueKey, project);
        return LayoutCodec.write(buildView(user, issue, null, null));
    }

    public List<ProjectItem> listProjects(ApplicationUser user) {
        List<ProjectItem> items = new ArrayList<ProjectItem>();
        if (user == null) {
            return items;
        }
        int start = 0;
        while (start < 500) {
            PagedResponse<ServiceDesk> page;
            try {
                page = serviceDeskService.getServiceDesks(user, false, SimplePagedRequest.paged(start, 50));
            } catch (RuntimeException ex) {
                log.warn("Cannot list service projects", ex);
                break;
            }
            if (page == null || page.getResults() == null || page.getResults().isEmpty()) {
                break;
            }
            for (int i = 0; i < page.getResults().size(); i++) {
                ServiceDesk desk = page.getResults().get(i);
                Project project = projectManager.getProjectObj(Long.valueOf(desk.getProjectId()));
                if (project == null || !isProjectAdmin(user, project)) {
                    continue;
                }
                ProjectItem item = new ProjectItem();
                item.key = project.getKey();
                item.name = project.getName();
                items.add(item);
            }
            if (!page.hasNextPage()) {
                break;
            }
            int size = page.getResults().size();
            if (size <= 0) {
                break;
            }
            start += size;
        }
        return items;
    }

    public Project requireEditorProject(ApplicationUser user, String projectKey) {
        return requireServiceProjectAdmin(user, projectKey);
    }

    private PortalView buildView(ApplicationUser user, Issue issue, CustomerRequest request, String onlyZone) {
        Project project = projectManager.getProjectObj(issue.getProjectId());
        LayoutStore.Stored stored = project == null
                ? LayoutStore.Stored.missing()
                : layoutStore.load(project.getId().longValue());
        PortalSlaLayout layout = stored.layout;
        PortalView view = new PortalView();
        view.issueKey = issue.getKey();
        view.locale = localeTag();
        view.hoursPerDay = resolvedHours(layout);
        view.daysPerWeek = resolvedDays(layout);
        view.refreshSeconds = 60;
        view.status = statusOf(user, issue, request);
        view.selectors = layout == null || layout.selectors == null
                ? new HashMap<String, List<String>>()
                : layout.selectors;
        view.metrics = new ArrayList<MetricView>();
        if (layout == null || !Boolean.TRUE.equals(layout.enabled) || layout.blocks == null || layout.blocks.isEmpty()) {
            view.enabled = false;
            view.blocks = new ArrayList<PortalSlaLayout.Block>();
            return view;
        }
        PortalSlaLayout effective = onlyZone == null ? layout : filterZone(layout, onlyZone);
        view.enabled = true;
        view.blocks = effective.blocks;
        view.refreshSeconds = minRefresh(effective.blocks);
        if (!effective.blocks.isEmpty() && project != null) {
            view.metrics = loadMetrics(user, project, issue, effective);
        }
        return view;
    }

    private PortalSlaLayout filterZone(PortalSlaLayout layout, String zone) {
        PortalSlaLayout copy = new PortalSlaLayout();
        copy.enabled = layout.enabled;
        copy.hoursPerDay = layout.hoursPerDay;
        copy.daysPerWeek = layout.daysPerWeek;
        copy.selectors = layout.selectors;
        copy.blocks = new ArrayList<PortalSlaLayout.Block>();
        for (int i = 0; i < layout.blocks.size(); i++) {
            PortalSlaLayout.Block block = layout.blocks.get(i);
            if (zone.equals(block.zone)) {
                copy.blocks.add(block);
            }
        }
        return copy;
    }

    private List<MetricView> loadMetrics(ApplicationUser user, Project project, Issue issue, PortalSlaLayout layout) {
        boolean wantsAll = false;
        boolean wantsVisible = false;
        Set<Integer> selected = new LinkedHashSet<Integer>();
        for (int i = 0; i < layout.blocks.size(); i++) {
            PortalSlaLayout.Block block = layout.blocks.get(i);
            if ("all".equals(block.metricMode)) {
                wantsAll = true;
            } else if ("selected".equals(block.metricMode)) {
                if (block.metricIds != null) {
                    selected.addAll(block.metricIds);
                }
            } else {
                wantsVisible = true;
            }
        }
        boolean privileged = wantsAll || !selected.isEmpty();
        List<SlaInformation> secure = querySla(user, issue.getId(), false);
        List<SlaInformation> source = privileged ? querySla(user, issue.getId(), true) : secure;
        if (source.isEmpty()) {
            source = secure;
        }
        Set<Integer> secureIds = new HashSet<Integer>();
        for (int i = 0; i < secure.size(); i++) {
            Integer id = secure.get(i).getId();
            if (id != null) {
                secureIds.add(id);
            }
        }
        Map<Integer, Boolean> visibility = visibilityMap(user, project);
        boolean visibilityKnown = visibility != null;
        if (!visibilityKnown) {
            visibility = Collections.emptyMap();
        }

        List<MetricView> metrics = new ArrayList<MetricView>();
        Set<Integer> emitted = new HashSet<Integer>();
        for (Integer id : selected) {
            SlaInformation info = find(source, id);
            if (info == null) {
                info = find(secure, id);
            }
            MetricView view = info == null ? null : toView(user, info, visibilityKnown, visibility, secureIds, true);
            if (view != null && emitted.add(Integer.valueOf(view.id))) {
                metrics.add(view);
            }
        }
        for (int i = 0; i < source.size(); i++) {
            SlaInformation info = source.get(i);
            if (info.getId() == null || !emitted.add(info.getId())) {
                continue;
            }
            if (!include(info.getId(), wantsAll, wantsVisible, selected, visibilityKnown, visibility, secureIds)) {
                continue;
            }
            boolean force = selected.contains(info.getId());
            MetricView view = toView(user, info, visibilityKnown, visibility, secureIds, force);
            if (view != null) {
                metrics.add(view);
            }
        }
        return metrics;
    }

    private boolean include(Integer id, boolean wantsAll, boolean wantsVisible, Set<Integer> selected,
                            boolean visibilityKnown, Map<Integer, Boolean> visibility, Set<Integer> secureIds) {
        if (wantsAll || selected.contains(id)) {
            return true;
        }
        if (!wantsVisible) {
            return false;
        }
        if (visibilityKnown) {
            return Boolean.TRUE.equals(visibility.get(id));
        }
        return secureIds.contains(id);
    }

    private MetricView toView(ApplicationUser user, SlaInformation info, boolean visibilityKnown,
                              Map<Integer, Boolean> visibility, Set<Integer> secureIds, boolean keepWithoutCycle) {
        SlaInformationOngoingCycle ongoing = null;
        Optional<SlaInformationOngoingCycle> ongoingOptional = info.getOngoingCycle();
        if (ongoingOptional != null && ongoingOptional.isPresent()) {
            ongoing = ongoingOptional.get();
        }
        List<SlaInformationCompletedCycle> completed = info.getCompletedCycles();
        if (completed == null) {
            completed = Collections.emptyList();
        }
        boolean hasCycle = ongoing != null || !completed.isEmpty();
        if (!hasCycle && !keepWithoutCycle) {
            return null;
        }

        SlaInformationCompletedCycle last = completed.isEmpty() ? null : completed.get(completed.size() - 1);
        MetricView view = new MetricView();
        view.id = info.getId() == null ? 0 : info.getId().intValue();
        view.name = info.getName() == null ? "SLA" : info.getName();
        if (visibilityKnown) {
            view.customerVisible = Boolean.TRUE.equals(visibility.get(info.getId()));
        } else {
            view.customerVisible = secureIds.contains(info.getId());
        }
        view.ongoing = ongoing != null;
        view.paused = ongoing != null && ongoing.getPaused();
        view.withinCalendarHours = ongoing == null || ongoing.getWithinCalendarHours();
        if (ongoing != null) {
            view.breached = ongoing.getBreached();
            view.remainingMs = nz(ongoing.getRemainingTime());
            view.elapsedMs = nz(ongoing.getElapsedTime());
            view.goalMs = nz(ongoing.getGoalDuration());
            view.startTimeMs = millis(ongoing.getStartTime());
            view.breachTimeMs = millis(optionalInstant(ongoing.getBreachTime()));
        } else if (last != null) {
            view.breached = last.getBreached();
            view.remainingMs = nz(last.getRemainingTime());
            view.elapsedMs = nz(last.getElapsedTime());
            view.goalMs = nz(last.getGoalDuration());
            view.startTimeMs = millis(last.getStartTime());
            view.stopTimeMs = millis(last.getStopTime());
        }
        view.jira = jiraTexts(user, view.remainingMs, view.elapsedMs, view.goalMs);
        view.cycles = cyclesOf(completed, ongoing);
        return view;
    }

    private List<CycleView> cyclesOf(List<SlaInformationCompletedCycle> completed, SlaInformationOngoingCycle ongoing) {
        int from = 0;
        if (completed.size() > 20) {
            from = completed.size() - 20;
        }
        List<CycleView> cycles = new ArrayList<CycleView>();
        for (int i = from; i < completed.size(); i++) {
            SlaInformationCompletedCycle cycle = completed.get(i);
            CycleView view = new CycleView();
            view.ongoing = false;
            view.breached = cycle.getBreached();
            view.paused = false;
            view.elapsedMs = nz(cycle.getElapsedTime());
            view.remainingMs = nz(cycle.getRemainingTime());
            view.goalMs = nz(cycle.getGoalDuration());
            view.startTimeMs = millis(cycle.getStartTime());
            view.stopTimeMs = millis(cycle.getStopTime());
            cycles.add(view);
        }
        if (ongoing != null) {
            CycleView view = new CycleView();
            view.ongoing = true;
            view.breached = ongoing.getBreached();
            view.paused = ongoing.getPaused();
            view.elapsedMs = nz(ongoing.getElapsedTime());
            view.remainingMs = nz(ongoing.getRemainingTime());
            view.goalMs = nz(ongoing.getGoalDuration());
            view.startTimeMs = millis(ongoing.getStartTime());
            view.breachTimeMs = millis(optionalInstant(ongoing.getBreachTime()));
            cycles.add(view);
        }
        return cycles;
    }

    private JiraTexts jiraTexts(ApplicationUser user, long remaining, long elapsed, long goal) {
        SlaInformationService.DurationFormatter formatter;
        try {
            formatter = slaInformationService.getDurationFormatter();
        } catch (RuntimeException ex) {
            formatter = null;
        }
        JiraTexts texts = new JiraTexts();
        texts.remainingShort = jira(formatter, user, remaining, true);
        texts.remainingLong = jira(formatter, user, remaining, false);
        texts.elapsedShort = jira(formatter, user, elapsed, true);
        texts.elapsedLong = jira(formatter, user, elapsed, false);
        texts.goalShort = jira(formatter, user, goal, true);
        texts.goalLong = jira(formatter, user, goal, false);
        return texts;
    }

    private String jira(SlaInformationService.DurationFormatter formatter, ApplicationUser user, long millis, boolean shortForm) {
        if (formatter == null) {
            return "";
        }
        try {
            long magnitude = millis < 0L ? -millis : millis;
            String text = shortForm ? formatter.formatShort(user, magnitude) : formatter.format(user, magnitude);
            if (text == null) {
                return "";
            }
            if (millis < 0L && text.length() > 0 && text.charAt(0) != '-' && text.charAt(0) != '\u2212') {
                return "-" + text;
            }
            return text;
        } catch (RuntimeException ex) {
            log.debug("Jira SLA duration could not be formatted", ex);
            return "";
        }
    }

    private List<SlaInformation> querySla(ApplicationUser user, Long issueId, boolean override) {
        List<SlaInformation> all = new ArrayList<SlaInformation>();
        int start = 0;
        try {
            while (start < 100) {
                SlaInformationQuery.Builder builder = slaInformationService.newInfoQueryBuilder()
                        .issue(issueId)
                        .pagedRequest(SimplePagedRequest.paged(start, 50));
                if (override) {
                    builder.overrideSecurity();
                }
                PagedResponse<SlaInformation> page = slaInformationService.getInfo(user, builder.build());
                if (page == null || page.getResults() == null || page.getResults().isEmpty()) {
                    break;
                }
                all.addAll(page.getResults());
                if (!page.hasNextPage()) {
                    break;
                }
                int size = page.getResults().size();
                if (size <= 0) {
                    break;
                }
                start += size;
            }
        } catch (RuntimeException ex) {
            log.debug("SLA information is not available", ex);
        }
        return all;
    }

    private Map<Integer, Boolean> visibilityMap(ApplicationUser user, Project project) {
        try {
            ServiceDesk desk = serviceDeskService.getServiceDeskForProject(user, project);
            Collection<TimeMetric> metrics = timeMetricService.getTimeMetrics(user, desk);
            Map<Integer, Boolean> map = new HashMap<Integer, Boolean>();
            if (metrics != null) {
                for (TimeMetric metric : metrics) {
                    if (metric != null && metric.getId() != null) {
                        map.put(metric.getId(), Boolean.valueOf(metric.isCustomerVisible()));
                    }
                }
            }
            return map;
        } catch (RuntimeException ex) {
            log.debug("SLA metric catalogue is not available to this user", ex);
            return null;
        }
    }

    private List<CatalogMetric> catalog(ApplicationUser user, Project project) {
        try {
            ServiceDesk desk = serviceDeskService.getServiceDeskForProject(user, project);
            Collection<TimeMetric> metrics = timeMetricService.getTimeMetrics(user, desk);
            List<CatalogMetric> catalog = new ArrayList<CatalogMetric>();
            if (metrics == null) {
                return catalog;
            }
            for (TimeMetric metric : metrics) {
                if (metric == null || metric.getId() == null) {
                    continue;
                }
                CatalogMetric item = new CatalogMetric();
                item.id = metric.getId().intValue();
                item.name = metric.getName() == null ? ("SLA #" + metric.getId()) : metric.getName();
                item.customerVisible = metric.isCustomerVisible();
                catalog.add(item);
            }
            return catalog;
        } catch (RuntimeException ex) {
            log.warn("Cannot read SLA metrics for project {}", project.getKey());
            log.debug("SLA metric catalogue failed", ex);
            return null;
        }
    }

    private StatusView statusOf(ApplicationUser user, Issue issue, CustomerRequest request) {
        StatusView status = new StatusView();
        status.name = "";
        status.category = "undefined";
        if (issue.getStatus() != null) {
            if (issue.getStatus().getName() != null) {
                status.name = issue.getStatus().getName();
            }
            if (issue.getStatus().getStatusCategory() != null && issue.getStatus().getStatusCategory().getKey() != null) {
                status.category = issue.getStatus().getStatusCategory().getKey();
            }
        }
        CustomerRequest resolved = request;
        if (resolved == null) {
            try {
                resolved = customerRequestService.getCustomerRequest(user,
                        customerRequestService.newIssueQueryBuilder().issue(issue.getId().longValue()).build());
            } catch (RuntimeException ex) {
                log.debug("Customer request status is hidden for {}", issue.getKey());
            }
        }
        if (resolved != null && resolved.currentStatus() != null && resolved.currentStatus().status() != null) {
            status.name = resolved.currentStatus().status();
        }
        return status;
    }

    private Visible requireVisible(ApplicationUser user, String issueKey) {
        if (user == null) {
            throw new PortalSlaException(401, "auth");
        }
        if (issueKey == null || !ISSUE_KEY.matcher(issueKey.toUpperCase(Locale.US)).matches()) {
            throw new PortalSlaException(404, "not-found");
        }
        Issue issue = issueManager.getIssueByCurrentKey(issueKey.toUpperCase(Locale.US));
        if (issue == null || issue.getId() == null) {
            throw new PortalSlaException(404, "not-found");
        }
        try {
            CustomerRequest request = customerRequestService.getCustomerRequest(user,
                    customerRequestService.newIssueQueryBuilder().issue(issue.getId().longValue()).build());
            if (request == null) {
                throw new PortalSlaException(404, "not-found");
            }
            return new Visible(issue, request);
        } catch (ServiceDeskServiceException ex) {
            throw new PortalSlaException(404, "not-found");
        }
    }

    private Issue requireIssueInProject(String issueKey, Project project) {
        if (issueKey == null || !ISSUE_KEY.matcher(issueKey.toUpperCase(Locale.US)).matches()) {
            throw new PortalSlaException(404, "not-found");
        }
        Issue issue = issueManager.getIssueByCurrentKey(issueKey.toUpperCase(Locale.US));
        if (issue == null || issue.getProjectId() == null
                || issue.getProjectId().longValue() != project.getId().longValue()) {
            throw new PortalSlaException(404, "not-found");
        }
        return issue;
    }

    private Project requireServiceProjectAdmin(ApplicationUser user, String projectKey) {
        if (user == null) {
            throw new PortalSlaException(401, "auth");
        }
        if (projectKey == null || !PROJECT_KEY.matcher(projectKey).matches()) {
            throw new PortalSlaException(404, "not-found");
        }
        Project project = projectManager.getProjectByCurrentKey(projectKey);
        if (project == null || project.getId() == null) {
            throw new PortalSlaException(404, "not-found");
        }
        if (!isProjectAdmin(user, project)) {
            throw new PortalSlaException(403, "forbidden");
        }
        try {
            serviceDeskService.getServiceDeskForProject(user, project);
        } catch (ServiceDeskServiceException ex) {
            throw new PortalSlaException(404, "not-service-desk");
        }
        return project;
    }

    private boolean isProjectAdmin(ApplicationUser user, Project project) {
        if (permissionManager.hasPermission(ProjectPermissions.ADMINISTER_PROJECTS, project, user)) {
            return true;
        }
        return globalPermissionManager.hasPermission(GlobalPermissionKey.ADMINISTER, user);
    }

    private int minRefresh(List<PortalSlaLayout.Block> blocks) {
        int refresh = 600;
        for (int i = 0; i < blocks.size(); i++) {
            Integer value = blocks.get(i).refreshSeconds;
            int seconds = value == null ? 60 : value.intValue();
            if (seconds < refresh) {
                refresh = seconds;
            }
        }
        if (refresh < 15) {
            return 15;
        }
        return refresh;
    }

    private int resolvedHours(PortalSlaLayout layout) {
        if (layout != null && layout.hoursPerDay != null && layout.hoursPerDay.intValue() > 0) {
            return layout.hoursPerDay.intValue();
        }
        return trackingHours();
    }

    private int resolvedDays(PortalSlaLayout layout) {
        if (layout != null && layout.daysPerWeek != null && layout.daysPerWeek.intValue() > 0) {
            return layout.daysPerWeek.intValue();
        }
        return trackingDays();
    }

    private int trackingHours() {
        return ranged(applicationProperties.getDefaultBackedString(APKeys.JIRA_TIMETRACKING_HOURS_PER_DAY), 8, 24);
    }

    private int trackingDays() {
        return ranged(applicationProperties.getDefaultBackedString(APKeys.JIRA_TIMETRACKING_DAYS_PER_WEEK), 5, 7);
    }

    private int ranged(String raw, int fallback, int max) {
        if (raw == null) {
            return fallback;
        }
        try {
            int value = Integer.parseInt(raw.trim());
            if (value < 1 || value > max) {
                return fallback;
            }
            return value;
        } catch (NumberFormatException ex) {
            return fallback;
        }
    }

    private String localeTag() {
        Locale locale = authenticationContext.getLocale();
        if (locale == null) {
            return "en";
        }
        return locale.toLanguageTag();
    }

    private static SlaInformation find(List<SlaInformation> infos, Integer id) {
        for (int i = 0; i < infos.size(); i++) {
            if (id.equals(infos.get(i).getId())) {
                return infos.get(i);
            }
        }
        return null;
    }

    private static long nz(Long value) {
        return value == null ? 0L : value.longValue();
    }

    private static Long millis(Instant instant) {
        if (instant == null) {
            return null;
        }
        return Long.valueOf(instant.toEpochMilli());
    }

    private static Instant optionalInstant(Optional<Instant> optional) {
        if (optional == null || !optional.isPresent()) {
            return null;
        }
        return optional.get();
    }

    private static final class Visible {
        final Issue issue;
        final CustomerRequest request;

        Visible(Issue issue, CustomerRequest request) {
            this.issue = issue;
            this.request = request;
        }
    }
}
