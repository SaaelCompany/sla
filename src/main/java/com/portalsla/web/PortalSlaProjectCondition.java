package com.portalsla.web;

import com.atlassian.jira.component.ComponentAccessor;
import com.atlassian.jira.permission.GlobalPermissionKey;
import com.atlassian.jira.permission.ProjectPermissions;
import com.atlassian.jira.plugin.webfragment.conditions.AbstractWebCondition;
import com.atlassian.jira.plugin.webfragment.model.JiraHelper;
import com.atlassian.jira.project.Project;
import com.atlassian.jira.security.GlobalPermissionManager;
import com.atlassian.jira.security.PermissionManager;
import com.atlassian.jira.user.ApplicationUser;
import com.atlassian.servicedesk.api.ServiceDeskService;

/**
 * Project settings link: service projects only, and only for a project admin.
 */
public class PortalSlaProjectCondition extends AbstractWebCondition {

    @Override
    public boolean shouldDisplay(ApplicationUser user, JiraHelper jiraHelper) {
        if (user == null || jiraHelper == null || jiraHelper.getProject() == null) {
            return false;
        }
        Project project = jiraHelper.getProject();
        PermissionManager permissionManager = ComponentAccessor.getComponent(PermissionManager.class);
        GlobalPermissionManager globalPermissionManager = ComponentAccessor.getComponent(GlobalPermissionManager.class);
        if (permissionManager == null) {
            return false;
        }
        boolean admin = permissionManager.hasPermission(ProjectPermissions.ADMINISTER_PROJECTS, project, user);
        if (!admin && globalPermissionManager != null) {
            admin = globalPermissionManager.hasPermission(GlobalPermissionKey.ADMINISTER, user);
        }
        if (!admin) {
            return false;
        }
        ServiceDeskService serviceDeskService = ComponentAccessor.getOSGiComponentInstanceOfType(ServiceDeskService.class);
        if (serviceDeskService == null) {
            return false;
        }
        try {
            serviceDeskService.getServiceDeskForProject(user, project);
            return true;
        } catch (RuntimeException ex) {
            return false;
        }
    }
}
