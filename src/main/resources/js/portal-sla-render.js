/* Shared SLA renderer. The portal and the layout editor both call PortalSlaRender. */
(function (window) {
    "use strict";

    var COPY = {
        ru: {
            paused: "На паузе",
            running: "В срок",
            at_risk: "Срок близко",
            breached: "Срок прошёл",
            met: "Успели",
            missed: "Не успели",
            inactive: "Нет данных",
            empty: "Нет данных по сроку",
            remaining: "Осталось",
            elapsed: "Прошло",
            goal: "Цель",
            breach: "Срок",
            overdueLabel: "Опоздание",
            outside: "Вне графика",
            cycle: "Шаг",
            leftHead: "Осталось ",
            leftTail: "",
            riskHead: "Осталось мало: ",
            pauseHead: "На паузе. Осталось ",
            pauseMid: ", время не идёт",
            overHead: "Срок уже прошёл ",
            overTail: " назад.",
            dueJoin: ". Срок — ",
            endMark: ".",
            sentenceMet: "Успели вовремя.",
            sentenceMissed: "Не уложились в срок.",
            sentenceNone: "Пока нет данных по этому сроку.",
            subLeft: "осталось ",
            subPause: "на паузе · осталось ",
            subOver: "опоздание ",
            subWas: " · было ",
            subJoin: " · "
        },
        en: {
            paused: "Paused",
            running: "On time",
            at_risk: "Due soon",
            breached: "Overdue",
            met: "Finished",
            missed: "Missed",
            inactive: "No data",
            empty: "No SLA data",
            remaining: "Remaining",
            elapsed: "Elapsed",
            goal: "Goal",
            breach: "Due",
            overdueLabel: "Overdue",
            outside: "Outside hours",
            cycle: "Step",
            leftHead: "",
            leftTail: " left",
            riskHead: "Only ",
            pauseHead: "Paused. ",
            pauseMid: " left, the clock is stopped",
            overHead: "Overdue by ",
            overTail: ".",
            dueJoin: ". Due ",
            endMark: ".",
            sentenceMet: "Finished on time.",
            sentenceMissed: "Missed the due time.",
            sentenceNone: "There is no due time yet.",
            subLeft: "",
            subPause: "paused · ",
            subOver: "overdue ",
            subWas: " · was ",
            subJoin: " · "
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
        var lang = isRussian(locale) ? "ru" : "en";
        var table = COPY[lang];
        if (Object.prototype.hasOwnProperty.call(table, key)) {
            return table[key];
        }
        if (Object.prototype.hasOwnProperty.call(COPY.en, key)) {
            return COPY.en[key];
        }
        return key;
    }

    function isRussian(locale) {
        return locale && String(locale).toLowerCase().indexOf("ru") === 0;
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

    function appendBits(node, bits) {
        var i;
        for (i = 0; i < bits.length; i++) {
            if (bits[i] == null || bits[i] === "") {
                continue;
            }
            if (typeof bits[i] === "string") {
                node.appendChild(document.createTextNode(bits[i]));
            } else {
                node.appendChild(bits[i]);
            }
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

    function dot(state) {
        var node = el("span", "psla-dot psla-state-" + state);
        node.setAttribute("aria-hidden", "true");
        return node;
    }

    function pluralRu(value, one, few, many) {
        var n10 = value % 10;
        var n100 = value % 100;
        if (n10 === 1 && n100 !== 11) {
            return one;
        }
        if (n10 >= 2 && n10 <= 4 && (n100 < 12 || n100 > 14)) {
            return few;
        }
        return many;
    }

    function pluralEn(value, one, many) {
        return value === 1 ? one : many;
    }

    function formatDuration(millis, style, hoursPerDay, daysPerWeek, locale) {
        var dayHours = hoursPerDay < 1 || hoursPerDay > 24 ? 8 : hoursPerDay;
        var weekDays = daysPerWeek < 1 || daysPerWeek > 7 ? 5 : daysPerWeek;
        var russian = isRussian(locale);
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
        var text = style === "spoken"
            ? spoken(weeks, days, hours, minutes, russian)
            : style === "precise"
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

    function spoken(weeks, days, hours, minutes, russian) {
        var values = [weeks, days, hours, minutes];
        var ru = [
            ["неделя", "недели", "недель"],
            ["день", "дня", "дней"],
            ["час", "часа", "часов"],
            ["минута", "минуты", "минут"]
        ];
        var en = [
            ["week", "weeks"],
            ["day", "days"],
            ["hour", "hours"],
            ["minute", "minutes"]
        ];
        var parts = [];
        var i;
        for (i = 0; i < values.length; i++) {
            if (values[i] > 0) {
                parts.push(russian
                    ? values[i] + " " + pluralRu(values[i], ru[i][0], ru[i][1], ru[i][2])
                    : values[i] + " " + pluralEn(values[i], en[i][0], en[i][1]));
            }
            if (parts.length === 2) {
                break;
            }
        }
        if (!parts.length) {
            return russian ? "0 минут" : "0 minutes";
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
        var wordy = block.timeStyle === "precise" || block.timeStyle === "spoken";
        if (block.textSource === "jira" && metric.jira) {
            var bag = metric.jira;
            var value = mode === "elapsed"
                ? (wordy ? bag.elapsedLong : bag.elapsedShort)
                : mode === "goal"
                    ? (wordy ? bag.goalLong : bag.goalShort)
                    : (wordy ? bag.remainingLong : bag.remainingShort);
            if (value) {
                return value;
            }
        }
        return formatDuration(primaryMs(metric, mode), block.timeStyle, model.hoursPerDay, model.daysPerWeek, model.locale);
    }

    function clock(date) {
        var hours = date.getHours();
        var minutes = date.getMinutes();
        return (hours < 10 ? "0" : "") + hours + ":" + (minutes < 10 ? "0" : "") + minutes;
    }

    function friendlyWhen(ms, locale) {
        if (!ms) {
            return "";
        }
        var date = new Date(ms);
        if (isNaN(date.getTime())) {
            return "";
        }
        var time = clock(date);
        var sameYear = date.getFullYear() === new Date().getFullYear();
        if (isRussian(locale)) {
            var months = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"];
            var day = date.getDate() + " " + months[date.getMonth()];
            if (!sameYear) {
                day += " " + date.getFullYear();
            }
            return day + ", " + time;
        }
        var enMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        var text = enMonths[date.getMonth()] + " " + date.getDate();
        if (!sameYear) {
            text += ", " + date.getFullYear();
        }
        return text + ", " + time;
    }

    function when(ms, locale) {
        if (!ms) {
            return "";
        }
        var friendly = friendlyWhen(ms, locale);
        if (friendly) {
            return friendly;
        }
        try {
            return new Date(ms).toLocaleString(locale || undefined);
        } catch (ignore) {
            return "";
        }
    }

    function dueText(block, metric, model) {
        if (!block.showBreachTime || !metric.breachTimeMs) {
            return "";
        }
        return friendlyWhen(metric.breachTimeMs, model.locale);
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

    function absTimeNode(metric, block, model, described) {
        var node = timeNode(metric, block, model, described);
        var text = node.textContent || "";
        if (text.charAt(0) === "\u2212" || text.charAt(0) === "-") {
            node.textContent = text.substring(1);
        }
        node.setAttribute("data-psla-abs", "1");
        return node;
    }

    function finished(state) {
        return state === "met" || state === "missed" || state === "inactive";
    }

    function asRemaining(block) {
        if (!block || !block.timeMode || block.timeMode === "remaining") {
            return block;
        }
        return {
            timeMode: "remaining",
            timeStyle: block.timeStyle,
            textSource: block.textSource,
            showBreachTime: block.showBreachTime,
            showPauseIcon: block.showPauseIcon,
            showName: block.showName
        };
    }

    function withDue(locale, due) {
        if (!due) {
            return t(locale, "endMark");
        }
        return t(locale, "dueJoin") + due + t(locale, "endMark");
    }

    function sentenceBits(metric, block, model, described) {
        var locale = model.locale;
        var due = dueText(block, metric, model);
        var state = described.state;
        if (state === "met") {
            return [t(locale, "sentenceMet")];
        }
        if (state === "missed") {
            return [t(locale, "sentenceMissed")];
        }
        if (state === "inactive") {
            return [t(locale, "sentenceNone")];
        }
        if (state === "breached") {
            return [t(locale, "overHead"), absTimeNode(metric, block, model, described), t(locale, "overTail")];
        }
        if (state === "paused") {
            return [t(locale, "pauseHead"), timeNode(metric, block, model, described), t(locale, "pauseMid"), withDue(locale, due)];
        }
        if (state === "at_risk") {
            return [t(locale, "riskHead"), timeNode(metric, block, model, described), t(locale, "leftTail"), withDue(locale, due)];
        }
        return [t(locale, "leftHead"), timeNode(metric, block, model, described), t(locale, "leftTail"), withDue(locale, due)];
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
            if (block.showBreachTime && metric.breachTimeMs && !finished(described.state)) {
                box.appendChild(el("p", "psla-sub", t(model.locale, "breach") + ": " + when(metric.breachTimeMs, model.locale)));
            }
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
            var card = el("article", "psla-card psla-state-" + described.state);
            card.appendChild(el("h3", null, metric.name));
            card.appendChild(el("p", "psla-card-state", t(model.locale, described.state)));
            var list = el("dl");
            if (!finished(described.state)) {
                var remainingText = formatDuration(metric.remainingMs || 0, block.timeStyle === "spoken" ? "spoken" : "precise", model.hoursPerDay, model.daysPerWeek, model.locale);
                addPair(list, t(model.locale, described.state === "breached" ? "overdueLabel" : "remaining"), described.state === "breached" ? unsigned(remainingText) : remainingText);
            }
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

    function unsigned(text) {
        if (text && (text.charAt(0) === "\u2212" || text.charAt(0) === "-")) {
            return text.substring(1);
        }
        return text;
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
                    var state = cycle.ongoing ? describe(metric, block.riskPercent).state : (cycle.breached ? "missed" : "met");
                    var li = el("li", "is-" + (cycle.breached ? "breached" : "met"));
                    var title = t(model.locale, state);
                    if (!cycle.ongoing && items.length > 1) {
                        title = (c + 1) + ". " + title;
                    }
                    li.appendChild(el("strong", null, title));
                    var detail = formatDuration(cycle.elapsedMs || 0, block.timeStyle === "spoken" ? "spoken" : "precise", model.hoursPerDay, model.daysPerWeek, model.locale);
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
        if (block.title && block.title !== "SLA") {
            row.appendChild(el("strong", null, block.title));
        }
        var i;
        for (i = 0; i < metrics.length; i++) {
            var described = describe(metrics[i], block.riskPercent);
            var bit = el("span", "psla-row-main psla-state-" + described.state);
            if (block.showName) {
                bit.appendChild(el("span", "psla-name", metrics[i].name));
            }
            bit.appendChild(timeNode(metrics[i], block, model, described));
            bit.appendChild(el("span", "psla-soft", t(model.locale, described.state)));
            var mark = marker(block, described);
            if (mark) {
                bit.appendChild(mark);
            }
            row.appendChild(bit);
        }
        body.appendChild(row);
    }

    function renderPlain(body, block, model, metrics) {
        var i;
        for (i = 0; i < metrics.length; i++) {
            var described = describe(metrics[i], block.riskPercent);
            var box = el("div", "psla-plain psla-state-" + described.state);
            if (block.showName) {
                box.appendChild(el("div", "psla-name", metrics[i].name));
            }
            box.appendChild(appendBits(el("p", "psla-sentence"), sentenceBits(metrics[i], asRemaining(block), model, described)));
            body.appendChild(box);
        }
    }

    function renderPortal(body, block, model, metrics) {
        var i;
        for (i = 0; i < metrics.length; i++) {
            var metric = metrics[i];
            var described = describe(metric, block.riskPercent);
            var item = el("div", "psla-portal-item psla-state-" + described.state);
            if (block.showName) {
                item.appendChild(el("div", "psla-portal-name", metric.name));
            }
            var line = el("div", "psla-portal-line");
            var mark = marker(block, described);
            if (mark) {
                line.appendChild(mark);
            } else {
                line.appendChild(dot(described.state));
            }
            line.appendChild(el("span", "psla-portal-state", t(model.locale, described.state)));
            item.appendChild(line);
            var meta = portalMeta(metric, asRemaining(block), model, described);
            if (meta) {
                item.appendChild(meta);
            }
            body.appendChild(item);
        }
    }

    function portalMeta(metric, block, model, described) {
        if (described.state === "met" || described.state === "inactive") {
            return null;
        }
        var meta = el("div", "psla-portal-meta");
        var due = dueText(block, metric, model);
        if ((described.state === "breached" || described.state === "missed") && metric.remainingMs < 0) {
            appendBits(meta, [t(model.locale, "subOver"), absTimeNode(metric, block, model, described)]);
            if (due && described.state === "breached") {
                meta.appendChild(document.createTextNode(t(model.locale, "subWas") + due));
            }
            return meta;
        }
        if (described.state === "missed") {
            return null;
        }
        meta.appendChild(timeNode(metric, block, model, described));
        if (due) {
            meta.appendChild(document.createTextNode(" \u2014 " + due));
        }
        return meta;
    }

    function renderWhen(body, block, model, metrics) {
        var i;
        for (i = 0; i < metrics.length; i++) {
            var metric = metrics[i];
            var described = describe(metric, block.riskPercent);
            var box = el("div", "psla-when psla-state-" + described.state);
            if (block.showName) {
                box.appendChild(el("div", "psla-name", metric.name));
            }
            var clockBlock = asRemaining(block);
            var due = dueText(block, metric, model);
            var hero = el("div", "psla-when-date");
            if (described.state === "met") {
                hero.textContent = t(model.locale, "sentenceMet");
            } else if (described.state === "missed") {
                hero.textContent = t(model.locale, "sentenceMissed");
            } else if (described.state === "inactive") {
                hero.textContent = t(model.locale, "sentenceNone");
            } else if (due) {
                hero.textContent = due;
            } else if (described.state === "breached") {
                hero.appendChild(absTimeNode(metric, clockBlock, model, described));
            } else {
                hero.appendChild(timeNode(metric, clockBlock, model, described));
            }
            box.appendChild(hero);
            var sub = whenSub(metric, clockBlock, model, described, due);
            if (sub) {
                box.appendChild(sub);
            }
            body.appendChild(box);
        }
    }

    function whenSub(metric, block, model, described, due) {
        if (finished(described.state)) {
            return null;
        }
        var sub = el("p", "psla-sub");
        var locale = model.locale;
        if (described.state === "breached") {
            if (!due) {
                return null;
            }
            appendBits(sub, [t(locale, "subOver"), absTimeNode(metric, block, model, described)]);
            return sub;
        }
        if (!due) {
            sub.textContent = t(locale, described.state);
            return sub;
        }
        if (described.state === "paused") {
            appendBits(sub, [t(locale, "subPause"), timeNode(metric, block, model, described), t(locale, "leftTail")]);
            return sub;
        }
        appendBits(sub, [
            t(locale, "subLeft"),
            timeNode(metric, block, model, described),
            t(locale, "leftTail"),
            t(locale, "subJoin"),
            t(locale, described.state).toLowerCase()
        ]);
        return sub;
    }

    function renderFacts(body, block, model, metrics) {
        var i;
        for (i = 0; i < metrics.length; i++) {
            var metric = metrics[i];
            var described = describe(metric, block.riskPercent);
            var box = el("div", "psla-facts psla-state-" + described.state);
            if (block.showName) {
                box.appendChild(el("div", "psla-name", metric.name));
            }
            box.appendChild(el("div", "psla-facts-state", t(model.locale, described.state)));
            if (!finished(described.state)) {
                var clockBlock = asRemaining(block);
                var row = el("div", "psla-fact");
                row.appendChild(el("span", "psla-fact-label", t(model.locale, described.state === "breached" ? "overdueLabel" : "remaining")));
                row.appendChild(described.state === "breached"
                    ? absTimeNode(metric, clockBlock, model, described)
                    : timeNode(metric, clockBlock, model, described));
                box.appendChild(row);
                var due = dueText(block, metric, model);
                if (due) {
                    var dueRow = el("div", "psla-fact");
                    dueRow.appendChild(el("span", "psla-fact-label", t(model.locale, "breach")));
                    dueRow.appendChild(el("span", null, due));
                    box.appendChild(dueRow);
                }
            }
            body.appendChild(box);
        }
    }

    var RENDERERS = {
        compact: renderCompact,
        badges: renderBadges,
        progress: renderProgress,
        countdown: renderCountdown,
        cards: renderCards,
        timeline: renderTimeline,
        "status-strip": renderStrip,
        plain: renderPlain,
        portal: renderPortal,
        when: renderWhen,
        facts: renderFacts
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
