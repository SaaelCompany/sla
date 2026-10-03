/* Injects the configured SLA blocks into the JSM 4.21 customer portal. */
(function (window, document) {
    "use strict";

    if (!window.fetch || !window.PortalSlaRender) {
        return;
    }

    var api = window.PortalSlaRender;
    var currentKey = null;
    var lastModel = null;
    var pollTimer = null;
    var tickTimer = null;
    var listSignature = "";

    function contextPath() {
        var meta = document.querySelector('meta[name="ajs-context-path"]');
        if (meta) {
            return meta.getAttribute("content") || "";
        }
        if (window.AJS && typeof window.AJS.contextPath === "function") {
            return window.AJS.contextPath() || "";
        }
        return "";
    }

    function rest(path) {
        return contextPath() + "/rest/portal-sla/1.0" + path;
    }

    function issueKeyFromLocation() {
        var path = window.location.pathname || "";
        var match = path.match(/\/servicedesk\/customer\/portal\/\d+\/([A-Za-z][A-Za-z0-9]+-\d+)\/?$/);
        if (!match) {
            return null;
        }
        return match[1].toUpperCase();
    }

    function onMyRequests() {
        return /\/user\/requests(?:\/|$)/.test(window.location.pathname || "");
    }

    function clearHosts() {
        var hosts = document.querySelectorAll(".psla-host");
        var i;
        for (i = 0; i < hosts.length; i++) {
            if (hosts[i].parentNode) {
                hosts[i].parentNode.removeChild(hosts[i]);
            }
        }
    }

    function blockPresent(id) {
        return !!document.querySelector('.psla-block[data-block-id="' + id + '"]');
    }

    function stillPlaced(model) {
        if (!model || !model.enabled || !model.blocks) {
            return !document.querySelector(".psla-host");
        }
        var i;
        var needed = 0;
        for (i = 0; i < model.blocks.length; i++) {
            if (model.blocks[i].zone === "my-requests") {
                continue;
            }
            needed++;
            if (!blockPresent(model.blocks[i].id)) {
                return false;
            }
        }
        return needed > 0 || !document.querySelector(".psla-host");
    }

    function selectorsFor(block, model) {
        if (model.selectors && model.selectors[block.zone] && model.selectors[block.zone].length) {
            return model.selectors[block.zone];
        }
        var known = api.zone(block.zone);
        return known ? known.selectors : [];
    }

    function safeQuery(selector) {
        try {
            return document.querySelector(selector);
        } catch (ignore) {
            return null;
        }
    }

    function acceptable(node) {
        if (!node) {
            return false;
        }
        if (node.closest && (node.closest(".psla-block") || node.closest(".psla-editor-body") || node.closest(".psla-host"))) {
            return false;
        }
        return true;
    }

    function targetFor(block, model) {
        var zone = api.zone(block.zone) || {position: "append", fallback: "panel"};
        if (block.zone === "custom" && block.customSelector) {
            var custom = safeQuery(block.customSelector);
            if (acceptable(custom)) {
                return {node: custom, position: block.customPosition || "after"};
            }
        }
        var selectors = selectorsFor(block, model);
        var i;
        for (i = 0; i < selectors.length; i++) {
            var found = safeQuery(selectors[i]);
            if (acceptable(found)) {
                return {node: found, position: zone.position || "append"};
            }
        }
        var mountName = zone.fallback || "panel";
        var mount = document.querySelector('[data-psla-mount="' + mountName + '"]');
        if (mount) {
            return {node: mount, position: "append"};
        }
        var panel = document.querySelector('[data-psla-mount="panel"]');
        if (panel) {
            return {node: panel, position: "append"};
        }
        return null;
    }

    function insert(target, node) {
        var parent = target.node;
        var position = target.position;
        if (!parent || !parent.parentNode && position !== "append" && position !== "prepend") {
            return;
        }
        if (position === "prepend") {
            parent.insertBefore(node, parent.firstChild);
        } else if (position === "before") {
            parent.parentNode.insertBefore(node, parent);
        } else if (position === "after") {
            parent.parentNode.insertBefore(node, parent.nextSibling);
        } else {
            parent.appendChild(node);
        }
    }

    function place(model) {
        clearHosts();
        if (!model || !model.enabled || !model.blocks) {
            return;
        }
        var i;
        for (i = 0; i < model.blocks.length; i++) {
            var block = model.blocks[i];
            if (block.zone === "my-requests") {
                continue;
            }
            var target = targetFor(block, model);
            if (!target) {
                continue;
            }
            var host = document.createElement("div");
            host.className = "psla-host";
            host.setAttribute("data-psla-host", block.id);
            if (api.render(host, block, model, {editor: false})) {
                insert(target, host);
            }
        }
    }

    function findMetric(id) {
        var metrics = lastModel && lastModel.metrics ? lastModel.metrics : [];
        var i;
        for (i = 0; i < metrics.length; i++) {
            if (String(metrics[i].id) === String(id)) {
                return metrics[i];
            }
        }
        return null;
    }

    function findBlock(node) {
        var root = node.closest ? node.closest("[data-block-id]") : null;
        if (!root || !lastModel || !lastModel.blocks) {
            return null;
        }
        var id = root.getAttribute("data-block-id");
        var i;
        for (i = 0; i < lastModel.blocks.length; i++) {
            if (lastModel.blocks[i].id === id) {
                return lastModel.blocks[i];
            }
        }
        return null;
    }

    function tick() {
        if (!lastModel || !lastModel.metrics) {
            return;
        }
        var running = false;
        var i;
        for (i = 0; i < lastModel.metrics.length; i++) {
            var metric = lastModel.metrics[i];
            if (metric.ongoing && !metric.paused && metric.withinCalendarHours !== false) {
                metric.remainingMs -= 1000;
                metric.elapsedMs += 1000;
                running = true;
            }
        }
        if (!running) {
            return;
        }
        var times = document.querySelectorAll(".psla-time[data-psla-tick]");
        for (i = 0; i < times.length; i++) {
            if (times[i].getAttribute("data-psla-source") === "jira") {
                continue;
            }
            var metric = findMetric(times[i].getAttribute("data-psla-tick"));
            var block = findBlock(times[i]);
            if (!metric || !block) {
                continue;
            }
            var mode = times[i].getAttribute("data-psla-mode") || "remaining";
            var ms = mode === "elapsed" ? metric.elapsedMs : mode === "goal" ? metric.goalMs : metric.remainingMs;
            times[i].textContent = api.formatDuration(ms, block.timeStyle, lastModel.hoursPerDay, lastModel.daysPerWeek, lastModel.locale);
        }
        var bars = document.querySelectorAll(".psla-fill[data-psla-bar]");
        for (i = 0; i < bars.length; i++) {
            var barMetric = findMetric(bars[i].getAttribute("data-psla-bar"));
            if (!barMetric || !barMetric.goalMs) {
                continue;
            }
            var ratio = barMetric.elapsedMs / barMetric.goalMs;
            if (ratio < 0) {
                ratio = 0;
            }
            if (ratio > 1) {
                ratio = 1;
            }
            bars[i].style.width = Math.round(ratio * 100) + "%";
        }
    }

    function arm(model, key) {
        window.clearInterval(pollTimer);
        window.clearInterval(tickTimer);
        var seconds = model && model.refreshSeconds ? model.refreshSeconds : 60;
        if (seconds < 15) {
            seconds = 15;
        }
        pollTimer = window.setInterval(function () {
            load(key, true);
        }, seconds * 1000);
        tickTimer = window.setInterval(tick, 1000);
    }

    function load(key, force) {
        window.fetch(rest("/portal/request/" + encodeURIComponent(key)), {
            credentials: "same-origin",
            headers: {"Accept": "application/json"}
        }).then(function (response) {
            if (!response.ok) {
                throw new Error("status");
            }
            return response.json();
        }).then(function (model) {
            currentKey = key;
            lastModel = model;
            if (force || !stillPlaced(model)) {
                place(model);
            }
            arm(model, key);
        }).catch(function () {
            /* The customer stays on the request page either way. */
        });
    }

    function requestLinks() {
        var anchors = document.querySelectorAll('a[href*="/servicedesk/customer/portal/"]');
        var grouped = {};
        var keys = [];
        var i;
        for (i = 0; i < anchors.length; i++) {
            var href = anchors[i].getAttribute("href") || "";
            var match = href.match(/\/portal\/\d+\/([A-Za-z][A-Za-z0-9]+-\d+)(?:$|[?#])/);
            if (!match) {
                continue;
            }
            var key = match[1].toUpperCase();
            if (!grouped[key]) {
                grouped[key] = [];
                keys.push(key);
            }
            grouped[key].push(anchors[i]);
        }
        return {keys: keys.slice(0, 30), grouped: grouped};
    }

    function renderMyRequests() {
        var found = requestLinks();
        var signature = window.location.pathname + "|" + found.keys.join(",");
        if (!found.keys.length) {
            return;
        }
        if (signature === listSignature && document.querySelector(".psla-host-inline")) {
            return;
        }
        window.fetch(rest("/portal/requests"), {
            method: "POST",
            credentials: "same-origin",
            headers: {
                "Accept": "application/json",
                "Content-Type": "application/json",
                "X-Atlassian-Token": "no-check"
            },
            body: JSON.stringify({keys: found.keys})
        }).then(function (response) {
            if (!response.ok) {
                throw new Error("status");
            }
            return response.json();
        }).then(function (body) {
            listSignature = signature;
            var items = body.items || [];
            var i;
            var n;
            for (i = 0; i < items.length; i++) {
                var item = items[i];
                if (!item.enabled || !item.blocks || !item.blocks.length) {
                    continue;
                }
                var links = found.grouped[item.issueKey] || [];
                for (n = 0; n < links.length; n++) {
                    var parent = links[n].parentNode;
                    if (!parent || parent.querySelector('.psla-host[data-issue-key="' + item.issueKey + '"]')) {
                        continue;
                    }
                    var host = document.createElement("div");
                    host.className = "psla-host psla-host-inline";
                    host.setAttribute("data-issue-key", item.issueKey);
                    var b;
                    for (b = 0; b < item.blocks.length; b++) {
                        var mount = document.createElement("div");
                        api.render(mount, item.blocks[b], item, {editor: false, dense: true});
                        while (mount.firstChild) {
                            host.appendChild(mount.firstChild);
                        }
                    }
                    if (host.firstChild) {
                        parent.appendChild(host);
                    }
                }
            }
        }).catch(function () {
            /* List badges are optional. */
        });
    }

    function sync() {
        if (onMyRequests()) {
            currentKey = null;
            window.clearInterval(pollTimer);
            window.clearInterval(tickTimer);
            renderMyRequests();
            return;
        }
        var key = issueKeyFromLocation();
        if (!key) {
            currentKey = null;
            lastModel = null;
            window.clearInterval(pollTimer);
            window.clearInterval(tickTimer);
            clearHosts();
            return;
        }
        if (key !== currentKey || !lastModel) {
            load(key, true);
            return;
        }
        if (!stillPlaced(lastModel)) {
            place(lastModel);
        }
    }

    var queued = 0;

    function schedule() {
        window.clearTimeout(queued);
        queued = window.setTimeout(sync, 150);
    }

    function start() {
        sync();
        if (window.MutationObserver && document.body) {
            var observer = new MutationObserver(function () {
                schedule();
            });
            observer.observe(document.body, {childList: true, subtree: true});
        }
        var href = window.location.href;
        window.setInterval(function () {
            if (window.location.href !== href) {
                href = window.location.href;
                listSignature = "";
                schedule();
            }
        }, 400);
    }

    window.PortalSla = {
        refresh: function () {
            currentKey = null;
            listSignature = "";
            sync();
        }
    };

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", start);
    } else {
        start();
    }
})(window, document);
