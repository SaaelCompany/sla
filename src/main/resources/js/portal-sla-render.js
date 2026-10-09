/* Shared SLA renderer. The portal and the layout editor both call PortalSlaRender. */
(function (window) {
    "use strict";

    var COPY = {
        ru: {
            paused: "Пауза",
            running: "В срок",
            at_risk: "Скоро нарушит",
            breached: "Нарушено",
            met: "Выполнено",
            missed: "Нарушено",
            inactive: "Нет данных",
            empty: "Нет данных по SLA",
            remaining: "Осталось",
            elapsed: "Прошло",
            goal: "Цель",
            breach: "Срок",
            outside: "Вне графика",
            ongoing: "Сейчас",
            cycle: "Цикл"
        },
        en: {
            paused: "Paused",
            running: "On track",
            at_risk: "At risk",
            breached: "Breached",
            met: "Met",
            missed: "Breached",
            inactive: "No data",
            empty: "No SLA data",
            remaining: "Remaining",
            elapsed: "Elapsed",
            goal: "Goal",
            breach: "Due",
            outside: "Outside hours",
            ongoing: "Ongoing",
            cycle: "Cycle"
        }
    };

    var ZONES = [
        {
            id: "header",
            position: "append",
            fallback: "header",
            selectors: []
        },
        {
            id: "under-title",
            position: "after",
            fallback: "subheader",
            selectors: [
                ".cv-request-header",
                ".cv-request-summary",
                "[data-test-id='request-details.summary']",
                "[data-test-id='request-details.header']",
                ".jsd-request-header",
                ".vp-request-header"
            ]
        },
        {
            id: "beside-status",
            position: "after",
            fallback: "subheader",
            selectors: [
                ".cv-request-status",
                "[data-test-id='request-details.status']",
                ".jsd-request-status",
                ".cv-status-lozenge"
            ]
        },
        {
            id: "above-description",
            position: "before",
            fallback: "panel",
            selectors: [
                ".cv-request-description",
                "[data-test-id='request-details.description']",
                ".jsd-request-description"
            ]
        },
        {
            id: "above-activity",
            position: "before",
            fallback: "panel",
            selectors: [
                ".cv-activity-section",
                ".cv-request-activity",
                "#activity-panel",
                "[data-test-id='request-details.activity']",
                ".jsd-activity"
            ]
        },
        {
            id: "sidebar-top",
            position: "prepend",
            fallback: "panel",
            selectors: [
                ".cv-request-sidebar",
                ".cv-sidebar",
                "[data-test-id='request-details.sidebar']",
                ".jsd-request-sidebar"
            ]
        },
        {
            id: "sidebar-bottom",
            position: "append",
            fallback: "panel",
            selectors: [
                ".cv-request-sidebar",
                ".cv-sidebar",
                "[data-test-id='request-details.sidebar']",
                ".jsd-request-sidebar"
            ]
        },
        {
            id: "portal-panel",
            position: "append",
            fallback: "panel",
            selectors: ["[data-psla-mount='panel']"]
        },
        {
            id: "request-footer",
            position: "append",
            fallback: "footer",
            selectors: []
        },
        {
            id: "my-requests",
            position: "append",
            fallback: null,
            selectors: []
        },
        {
            id: "custom",
            position: "after",
            fallback: "panel",
            selectors: []
        }
    ];

    function t(locale, key) {
        var lang = locale && String(locale).toLowerCase().indexOf("ru") === 0 ? "ru" : "en";
        var table = COPY[lang];
        return table[key] || COPY.en[key] || key;
    }

    function el(tag, className, text) {
        var node = document.createElement(tag);
        if (className) {
            node.className = className;
        }
        if (text != null) {
            node.textContent = text;
        }
        return node;
    }

    function icon(name) {
        var span = el("span", "psla-icon psla-icon-" + name);
        span.setAttribute("aria-hidden", "true");
        if (name === "pause") {
            span.innerHTML = '<svg viewBox="0 0 16 16"><rect x="3" y="2" width="3.2" height="12" rx="0.6"></rect><rect x="9.8" y="2" width="3.2" height="12" rx="0.6"></rect></svg>';
        } else if (name === "chevron") {
            span.innerHTML = '<svg viewBox="0 0 16 16"><path d="M4 6l4 4 4-4" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"></path></svg>';
        } else if (name === "check") {
            span.innerHTML = '<svg viewBox="0 0 16 16"><path d="M3.5 8.5l3 3 6-6.5" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"></path></svg>';
        } else {
            span.innerHTML = '<svg viewBox="0 0 16 16"><path d="M8 2.2l6.2 11.2H1.8L8 2.2z" fill="none" stroke="currentColor" stroke-width="1.4"></path><path d="M8 6.5v3.2" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"></path></svg>';
        }
        return span;
    }

    function formatDuration(millis, style, hoursPerDay, daysPerWeek, locale) {
        var dayHours = hoursPerDay < 1 || hoursPerDay > 24 ? 8 : hoursPerDay;
        var weekDays = daysPerWeek < 1 || daysPerWeek > 7 ? 5 : daysPerWeek;
        var russian = locale && String(locale).toLowerCase().indexOf("ru") === 0;
        var negative = millis < 0;
        var abs = negative ? -millis : millis;
        var minute = 60 * 1000;
        if (abs > 0 && abs < minute) {
            abs = minute;
        }
        var hour = 60 * minute;
        var day = dayHours * hour;
        var week = weekDays * day;
        var weeks = Math.floor(abs / week);
        var days = Math.floor((abs % week) / day);
        var hours = Math.floor((abs % day) / hour);
        var minutes = Math.floor((abs % hour) / minute);
        var text = style === "precise"
            ? precise(weeks, days, hours, minutes, russian)
            : largest(weeks, days, hours, minutes, russian);
        if (negative && text.charAt(0) !== "0") {
            return (russian ? "\u2212" : "-") + text;
        }
        return text;
    }

    function unit(value, label, russian) {
        return russian ? value + " " + label : String(value) + label;
    }

    function largest(weeks, days, hours, minutes, russian) {
        if (weeks > 0) {
            return unit(weeks, russian ? "н." : "w", russian);
        }
        if (days > 0) {
            return unit(days, russian ? "д." : "d", russian);
        }
        if (hours > 0) {
            return unit(hours, russian ? "ч." : "h", russian);
        }
        if (minutes > 0) {
            return unit(minutes, russian ? "мин." : "m", russian);
        }
        return russian ? "0 мин." : "0m";
    }

    function precise(weeks, days, hours, minutes, russian) {
        var values = [weeks, days, hours, minutes];
        var labels = russian ? ["н.", "д.", "ч.", "мин."] : ["w", "d", "h", "m"];
        var parts = [];
        var i;
        for (i = 0; i < values.length; i++) {
            if (values[i] > 0) {
                parts.push(unit(values[i], labels[i], russian));
            }
            if (parts.length === 2) {
                break;
            }
        }
        if (!parts.length) {
            return russian ? "0 мин." : "0m";
        }
        return parts.join(" ");
    }

    function describe(metric, riskPercent) {
        var risk = riskPercent == null ? 20 : riskPercent;
        var hasCycles = metric.cycles && metric.cycles.length;
        if (!metric.ongoing && !hasCycles) {
            return {state: "inactive", pause: false};
        }
        if (metric.ongoing) {
            var stopped = !!metric.paused || metric.withinCalendarHours === false;
            var breached = !!metric.breached || metric.remainingMs < 0;
            if (breached) {
                return {state: "breached", pause: stopped};
            }
            if (stopped) {
                return {state: "paused", pause: true};
            }
            if (metric.goalMs > 0 && metric.remainingMs >= 0 && (metric.remainingMs / metric.goalMs) * 100 <= risk) {
                return {state: "at_risk", pause: false};
            }
            return {state: "running", pause: false};
        }
        return {state: metric.breached ? "missed" : "met", pause: false};
    }

    function metricsFor(block, metrics) {
        var source = metrics || [];
        var chosen = [];
        var i;
        var j;
        if (block.metricMode === "selected") {
            var ids = block.metricIds || [];
            for (i = 0; i < ids.length; i++) {
                for (j = 0; j < source.length; j++) {
                    if (source[j].id === ids[i]) {
                        chosen.push(source[j]);
                    }
                }
            }
            return chosen;
        }
        for (i = 0; i < source.length; i++) {
            if (block.metricMode === "all" || source[i].customerVisible) {
                chosen.push(source[i]);
            }
        }
        return chosen;
    }

    function primaryMs(metric, mode) {
        if (mode === "elapsed") {
            return metric.elapsedMs || 0;
        }
        if (mode === "goal") {
            return metric.goalMs || 0;
        }
        return metric.remainingMs || 0;
    }

    function displayText(metric, block, model) {
        var mode = block.timeMode || "remaining";
        var preciseStyle = block.timeStyle === "precise";
        if (block.textSource === "jira" && metric.jira) {
            var bag = metric.jira;
            var value = mode === "elapsed"
                ? (preciseStyle ? bag.elapsedLong : bag.elapsedShort)
                : mode === "goal"
                    ? (preciseStyle ? bag.goalLong : bag.goalShort)
                    : (preciseStyle ? bag.remainingLong : bag.remainingShort);
            if (value) {
                return value;
            }
        }
        return formatDuration(primaryMs(metric, mode), block.timeStyle, model.hoursPerDay, model.daysPerWeek, model.locale);
    }

    function when(ms, locale) {
        if (!ms) {
            return "";
        }
        try {
            return new Date(ms).toLocaleString(locale || undefined);
        } catch (ignore) {
            return "";
        }
    }

    function timeNode(metric, block, model, described) {
        var node = el("span", "psla-time psla-state-" + described.state, displayText(metric, block, model));
        node.setAttribute("data-psla-tick", String(metric.id));
        node.setAttribute("data-psla-mode", block.timeMode || "remaining");
        if (block.textSource === "jira") {
            node.setAttribute("data-psla-source", "jira");
        }
        return node;
    }

    function marker(block, described) {
        if (block.showPauseIcon && described.pause) {
            return icon("pause");
        }
        if (described.state === "breached" || described.state === "missed") {
            return icon("alert");
        }
        if (described.state === "met") {
            return icon("check");
        }
        return null;
    }

    function statusLozenge(model) {
        if (!model.status || !model.status.name) {
            return null;
        }
        var category = model.status.category || "undefined";
        return el("span", "psla-lozenge psla-cat-" + category, model.status.name);
    }

    function header(block, open) {
        var button = el("button", "psla-head");
        button.type = "button";
        button.appendChild(el("span", null, block.title || "SLA"));
        button.appendChild(icon("chevron"));
        button.setAttribute("aria-expanded", open ? "true" : "false");
        return button;
    }

    function rememberOpen(block, open) {
        try {
            window.sessionStorage.setItem("psla-open-" + block.id, open ? "1" : "0");
        } catch (ignore) {
            /* private mode */
        }
    }

    function initiallyOpen(block) {
        try {
            var stored = window.sessionStorage.getItem("psla-open-" + block.id);
            if (stored === "0") {
                return false;
            }
            if (stored === "1") {
                return true;
            }
        } catch (ignore) {
            /* ignore */
        }
        return !block.collapsed;
    }

    function wireCollapse(root, button, block) {
        button.addEventListener("click", function (event) {
            event.stopPropagation();
            var open = root.className.indexOf("is-collapsed") >= 0;
            if (open) {
                root.className = root.className.replace(" is-collapsed", "");
            } else {
                root.className += " is-collapsed";
            }
            button.setAttribute("aria-expanded", open ? "true" : "false");
            rememberOpen(block, open);
        });
    }

    function renderCompact(body, block, model, metrics) {
        var i;
        for (i = 0; i < metrics.length; i++) {
            var described = describe(metrics[i], block.riskPercent);
            var row = el("div", "psla-row psla-state-" + described.state);
            var main = el("div", "psla-row-main");
            if (block.showName) {
                main.appendChild(el("span", "psla-name", metrics[i].name));
            }
            main.appendChild(timeNode(metrics[i], block, model, described));
            row.appendChild(main);
            var mark = marker(block, described);
            if (mark) {
                row.appendChild(mark);
            }
            row.title = metrics[i].name;
            body.appendChild(row);
            appendBreach(body, block, model, metrics[i]);
        }
    }

    function appendBreach(parent, block, model, metric) {
        if (!block.showBreachTime || !metric.breachTimeMs) {
            return;
        }
        parent.appendChild(el("p", "psla-sub", t(model.locale, "breach") + ": " + when(metric.breachTimeMs, model.locale)));
    }

    function renderBadges(body, block, model, metrics) {
        var wrap = el("div", "psla-badges");
        if (block.showStatus) {
            var status = statusLozenge(model);
            if (status) {
                wrap.appendChild(status);
            }
        }
        var i;
        for (i = 0; i < metrics.length; i++) {
            var described = describe(metrics[i], block.riskPercent);
            var badge = el("span", "psla-badge psla-state-" + described.state);
            if (block.showName) {
                badge.appendChild(el("span", null, metrics[i].name));
            }
            badge.appendChild(timeNode(metrics[i], block, model, described));
            var mark = marker(block, described);
            if (mark) {
                badge.appendChild(mark);
            }
            badge.title = t(model.locale, described.state);
            wrap.appendChild(badge);
        }
        body.appendChild(wrap);
    }

    function renderProgress(body, block, model, metrics) {
        var i;
        for (i = 0; i < metrics.length; i++) {
            var metric = metrics[i];
            var described = describe(metric, block.riskPercent);
            var box = el("div", "psla-progress");
            var top = el("div", "psla-progress-top");
            top.appendChild(el("span", "psla-name", block.showName ? metric.name : t(model.locale, described.state)));
            top.appendChild(timeNode(metric, block, model, described));
            box.appendChild(top);
            var ratio = 0;
            if (metric.goalMs > 0) {
                ratio = metric.elapsedMs / metric.goalMs;
            } else if (described.state === "breached" || described.state === "missed") {
                ratio = 1;
            }
            if (ratio < 0) {
                ratio = 0;
            }
            if (ratio > 1) {
                ratio = 1;
            }
            var track = el("div", "psla-track");
            var fill = el("div", "psla-fill psla-state-" + described.state);
            fill.style.width = Math.round(ratio * 100) + "%";
            fill.setAttribute("data-psla-bar", String(metric.id));
            track.appendChild(fill);
            box.appendChild(track);
            body.appendChild(box);
        }
    }

    function renderCountdown(body, block, model, metrics) {
        var i;
        for (i = 0; i < metrics.length; i++) {
            var described = describe(metrics[i], block.riskPercent);
            var box = el("div", "psla-countdown");
            if (block.showName) {
                box.appendChild(el("div", "psla-name", metrics[i].name));
            }
            var value = timeNode(metrics[i], block, model, described);
            value.className += " psla-countdown-value";
            box.appendChild(value);
            box.appendChild(el("p", "psla-sub", t(model.locale, described.state)));
            appendBreach(box, block, model, metrics[i]);
            body.appendChild(box);
        }
    }

    function renderCards(body, block, model, metrics) {
        var grid = el("div", "psla-cards");
        var i;
        for (i = 0; i < metrics.length; i++) {
            var metric = metrics[i];
            var described = describe(metric, block.riskPercent);
            var card = el("article", "psla-card");
            card.appendChild(el("h3", null, metric.name));
            var list = el("dl");
            addPair(list, t(model.locale, "status"), t(model.locale, described.state));
            addPair(list, t(model.locale, "remaining"), formatDuration(metric.remainingMs || 0, "precise", model.hoursPerDay, model.daysPerWeek, model.locale));
            addPair(list, t(model.locale, "elapsed"), formatDuration(metric.elapsedMs || 0, "precise", model.hoursPerDay, model.daysPerWeek, model.locale));
            addPair(list, t(model.locale, "goal"), formatDuration(metric.goalMs || 0, "precise", model.hoursPerDay, model.daysPerWeek, model.locale));
            if (block.showBreachTime && metric.breachTimeMs) {
                addPair(list, t(model.locale, "breach"), when(metric.breachTimeMs, model.locale));
            }
            card.appendChild(list);
            grid.appendChild(card);
        }
        body.appendChild(grid);
    }

    function addPair(list, label, value) {
        var row = el("div");
        row.appendChild(el("dt", null, label));
        row.appendChild(el("dd", null, value));
        list.appendChild(row);
    }

    function renderTimeline(body, block, model, metrics) {
        var i;
        var c;
        for (i = 0; i < metrics.length; i++) {
            var metric = metrics[i];
            var box = el("section", "psla-timeline");
            box.appendChild(el("h3", null, metric.name));
            var items = metric.cycles || [];
            if (!items.length) {
                box.appendChild(el("p", "psla-empty", t(model.locale, "empty")));
            } else {
                var list = el("ol");
                for (c = 0; c < items.length; c++) {
                    var cycle = items[c];
                    var state = cycle.ongoing ? (cycle.breached ? "breached" : "running") : (cycle.breached ? "missed" : "met");
                    var li = el("li", "is-" + (cycle.breached ? "breached" : "met"));
                    var title = cycle.ongoing ? t(model.locale, "ongoing") : t(model.locale, "cycle") + " " + (c + 1);
                    li.appendChild(el("strong", null, title + " · " + t(model.locale, state)));
                    var detail = formatDuration(cycle.elapsedMs || 0, "precise", model.hoursPerDay, model.daysPerWeek, model.locale);
                    var range = when(cycle.startTimeMs, model.locale);
                    if (cycle.stopTimeMs) {
                        range += " — " + when(cycle.stopTimeMs, model.locale);
                    }
                    li.appendChild(el("p", "psla-sub", detail + (range ? " · " + range : "")));
                    list.appendChild(li);
                }
                box.appendChild(list);
            }
            body.appendChild(box);
        }
    }

    function renderStrip(body, block, model, metrics) {
        var row = el("div", "psla-status-row");
        if (block.showStatus) {
            var status = statusLozenge(model);
            if (status) {
                row.appendChild(status);
            }
        }
        if (block.title && block.title !== "SLA") {
            row.appendChild(el("strong", null, block.title));
        }
        var i;
        for (i = 0; i < metrics.length; i++) {
            var described = describe(metrics[i], block.riskPercent);
            var bit = el("span", "psla-row-main");
            if (block.showName) {
                bit.appendChild(el("span", "psla-name", metrics[i].name));
            }
            bit.appendChild(timeNode(metrics[i], block, model, described));
            var mark = marker(block, described);
            if (mark) {
                bit.appendChild(mark);
            }
            row.appendChild(bit);
        }
        body.appendChild(row);
    }

    var RENDERERS = {
        compact: renderCompact,
        badges: renderBadges,
        progress: renderProgress,
        countdown: renderCountdown,
        cards: renderCards,
        timeline: renderTimeline,
        "status-strip": renderStrip
    };

    function render(container, block, model, options) {
        var opts = options || {};
        while (container.firstChild) {
            container.removeChild(container.firstChild);
        }
        var safeModel = model || {};
        var metrics = metricsFor(block, safeModel.metrics || []);
        if (!metrics.length && block.hideWhenEmpty && !opts.editor) {
            return false;
        }
        var root = el("section", "psla-block psla-variant-" + (block.variant || "compact") + " psla-zone-" + (block.zone || "sidebar-top"));
        root.setAttribute("data-block-id", block.id || "");
        if (opts.dense) {
            root.className += " psla-dense";
        }
        var open = initiallyOpen(block);
        if (!open) {
            root.className += " is-collapsed";
        }
        if (block.variant !== "status-strip") {
            var head = header(block, open);
            root.appendChild(head);
            wireCollapse(root, head, block);
        }
        if (block.showStatus && block.variant !== "badges" && block.variant !== "status-strip") {
            var status = statusLozenge(safeModel);
            if (status) {
                root.appendChild(status);
            }
        }
        var body = el("div", "psla-body");
        if (!metrics.length) {
            body.appendChild(el("p", "psla-empty", t(safeModel.locale, "empty")));
        } else {
            var painter = RENDERERS[block.variant] || renderCompact;
            painter(body, block, safeModel, metrics);
        }
        root.appendChild(body);
        container.appendChild(root);
        return true;
    }

    function zone(id) {
        var i;
        for (i = 0; i < ZONES.length; i++) {
            if (ZONES[i].id === id) {
                return ZONES[i];
            }
        }
        return null;
    }

    window.PortalSlaRender = {
        formatDuration: formatDuration,
        render: render,
        describe: describe,
        zones: ZONES,
        zone: zone,
        metricsFor: metricsFor
    };
})(window);
