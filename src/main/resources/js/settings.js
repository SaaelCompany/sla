/* Project settings for the portal SLA block. Placement stays at the sidebar bottom. */
(function (window, document) {
    "use strict";

    if (!window.PortalSlaRender) {
        return;
    }

    var api = window.PortalSlaRender;
    var UI = {
        ru: {
            title: "SLA на портале",
            projects: "Настройки проекта",
            show: "Показывать клиентам",
            reset: "Сбросить",
            save: "Сохранить",
            saving: "Сохраняю…",
            saved: "Сохранено. Клиенты увидят это внизу боковой панели.",
            savedLocal: "Сохранено в этом браузере.",
            general: "Общие",
            place: "Место на странице заявки всегда одно: боковая панель снизу. Его нельзя перенести.",
            day: "Часов в рабочем дне",
            week: "Дней в неделе",
            dayHint: "0 — как в учёте времени Jira. Сейчас в Jira: ",
            block: "Блок",
            add: "Добавить блок",
            name: "Заголовок",
            variant: "Как показывать",
            collapsed: "Свёрнут по умолчанию",
            showName: "Имена метрик",
            pause: "Значок паузы",
            breach: "Дата срока",
            timeMode: "Какое время показывать",
            timeStyle: "Формат времени",
            textSource: "Откуда текст",
            metricMode: "Какие SLA",
            risk: "Порог «истекает», %",
            refresh: "Обновление, секунды",
            hideEmpty: "Скрывать, если SLA нет",
            metrics: "Метрики",
            up: "Выше",
            down: "Ниже",
            remove: "Удалить",
            tooMany: "Уже 16 блоков.",
            confirmReset: "Вернуть настройки по умолчанию? Несохранённые правки пропадут.",
            preview: "Так блок выглядит у клиента",
            issue: "Ключ заявки",
            applyIssue: "Показать",
            sample: "Пример",
            corrupt: "Сохранённые настройки повреждены. Показан вариант по умолчанию — сохраните его, чтобы заменить старый.",
            metricsUnavailable: "Список SLA проекта сейчас недоступен. Можно оставить «Только отмеченные на портале» или «Все SLA».",
            noSelection: "Для режима «Только выбранные» отметьте хотя бы одну метрику.",
            variants: {
                plain: "Одной фразой",
                portal: "Как в портале",
                when: "Дата срока",
                facts: "Осталось и срок",
                compact: "Компактный список",
                badges: "Плашки",
                progress: "Полоса",
                cards: "Подробно",
                timeline: "Хронология",
                "status-strip": "В одну строку",
                clock: "Часы",
                traffic: "Светофор"
            },
            modes: {remaining: "Осталось", elapsed: "Прошло", goal: "Цель"},
            styles: {spoken: "Словами (1 день 2 часа)", largest: "Крупная единица (1 д.)", precise: "Две единицы (1 д. 2 ч.)"},
            sources: {portal: "Стиль портала", jira: "Формат Jira"},
            metricModes: {
                "customer-visible": "Только отмеченные на портале",
                all: "Все SLA проекта",
                selected: "Только выбранные"
            },
            presets: {
                paused: "На паузе",
                running: "В срок",
                risk: "Истекает",
                breached: "Срок прошел",
                done: "Выполнено"
            },
            errors: {
                "invalid-json": "Не удалось прочитать настройки.",
                "invalid-layout": "Настройки не прошли проверку.",
                "too-many-blocks": "Слишком много блоков.",
                "bad-variant": "Неизвестный вариант.",
                "bad-metric-id": "Некорректный идентификатор SLA.",
                "hours-per-day": "Часов в дне должно быть от 1 до 24, либо 0.",
                "days-per-week": "Дней в неделе должно быть от 1 до 7, либо 0.",
                forbidden: "Недостаточно прав.",
                "not-found": "Заявка или проект не найдены.",
                auth: "Нужно войти в Jira."
            }
        },
        en: {
            title: "Niout Portal SLA for JSM",
            projects: "Project settings",
            show: "Show to customers",
            reset: "Reset",
            save: "Save",
            saving: "Saving…",
            saved: "Saved. Customers will see this at the bottom of the sidebar.",
            savedLocal: "Saved in this browser.",
            general: "General",
            place: "The request page has one fixed place: the bottom of the sidebar. It cannot be moved.",
            day: "Hours in a working day",
            week: "Days in a week",
            dayHint: "0 uses Jira time tracking. Jira is currently ",
            block: "Block",
            add: "Add block",
            name: "Title",
            variant: "Appearance",
            collapsed: "Collapsed by default",
            showName: "Metric names",
            pause: "Pause icon",
            breach: "Due date",
            timeMode: "Which time to show",
            timeStyle: "Time format",
            textSource: "Text source",
            metricMode: "Which SLAs",
            risk: "“Due soon” threshold, %",
            refresh: "Refresh, seconds",
            hideEmpty: "Hide when there is no SLA",
            metrics: "Metrics",
            up: "Up",
            down: "Down",
            remove: "Remove",
            tooMany: "There are already 16 blocks.",
            confirmReset: "Restore the default settings? Unsaved changes will be lost.",
            preview: "How the block looks to a customer",
            issue: "Request key",
            applyIssue: "Show",
            sample: "Sample",
            corrupt: "The saved settings are damaged. The default is shown — save it to replace the old one.",
            metricsUnavailable: "This project's SLA list is unavailable. “Show on portal” or “Every project SLA” still work.",
            noSelection: "Tick at least one metric for “Selected only”.",
            variants: {
                plain: "One sentence",
                portal: "Portal panel",
                when: "Due date",
                facts: "Left and due",
                compact: "Compact list",
                badges: "Badges",
                progress: "Bar",
                cards: "Details",
                timeline: "Chronology",
                "status-strip": "One line",
                clock: "Clock",
                traffic: "Traffic light"
            },
            modes: {remaining: "Remaining", elapsed: "Elapsed", goal: "Goal"},
            styles: {spoken: "Words (1 day 2 hours)", largest: "Largest unit (1d)", precise: "Two units (1d 2h)"},
            sources: {portal: "Portal style", jira: "Jira format"},
            metricModes: {
                "customer-visible": "Only “show on portal”",
                all: "Every project SLA",
                selected: "Selected only"
            },
            presets: {
                paused: "Paused",
                running: "On time",
                risk: "Expiring",
                breached: "Overdue",
                done: "Done"
            },
            errors: {
                "invalid-json": "The settings could not be read.",
                "invalid-layout": "The settings did not pass validation.",
                "too-many-blocks": "Too many blocks.",
                "bad-variant": "Unknown variant.",
                "bad-metric-id": "Invalid SLA id.",
                "hours-per-day": "Hours per day must be 0 or 1–24.",
                "days-per-week": "Days per week must be 0 or 1–7.",
                forbidden: "You do not have permission.",
                "not-found": "The request or project was not found.",
                auth: "Sign in to Jira first."
            }
        }
    };

    var VARIANT_ORDER = ["plain", "portal", "when", "facts", "clock", "traffic", "compact", "badges", "progress", "cards", "timeline", "status-strip"];
    var state = {
        layout: null,
        factory: null,
        catalog: [],
        preset: "paused",
        live: null,
        dirty: false,
        error: "",
        notice: "",
        warning: "",
        mock: false,
        locale: "ru",
        projectKey: "",
        projectName: "",
        rest: "",
        base: "",
        jiraHoursPerDay: 8,
        jiraDaysPerWeek: 5
    };

    function lang() {
        return (state.locale || "").toLowerCase().indexOf("ru") === 0 ? "ru" : "en";
    }

    function tr(key) {
        return UI[lang()][key];
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

    function copy(value) {
        return JSON.parse(JSON.stringify(value));
    }

    function explain(code) {
        var key = String(code || "").split(":")[0];
        return tr("errors")[key] || tr("errors")["invalid-layout"];
    }

    function effectiveHours() {
        var value = state.layout && state.layout.hoursPerDay;
        return value > 0 ? value : (state.jiraHoursPerDay || 8);
    }

    function effectiveDays() {
        var value = state.layout && state.layout.daysPerWeek;
        return value > 0 ? value : (state.jiraDaysPerWeek || 5);
    }

    function dayMs() {
        return effectiveHours() * 60 * 60 * 1000;
    }

    function sampleCatalog() {
        var ru = lang() === "ru";
        return [
            {id: 1, name: ru ? "Время до первого отклика" : "Time to first response", customerVisible: true},
            {id: 2, name: ru ? "Время до решения" : "Time to resolution", customerVisible: true}
        ];
    }

    function metric(id, name, options) {
        var goal = options.goal * dayMs();
        var remaining = options.remaining * dayMs();
        var elapsed = options.elapsed * dayMs();
        return {
            id: id,
            name: name,
            customerVisible: options.customerVisible !== false,
            ongoing: options.ongoing !== false,
            paused: !!options.paused,
            breached: !!options.breached,
            withinCalendarHours: options.within !== false,
            remainingMs: remaining,
            elapsedMs: elapsed,
            goalMs: goal,
            breachTimeMs: Date.now() + remaining,
            startTimeMs: Date.now() - Math.max(elapsed, 60 * 1000),
            stopTimeMs: options.ongoing === false ? Date.now() : null,
            cycles: [{
                ongoing: options.ongoing !== false,
                breached: !!options.breached,
                paused: !!options.paused,
                elapsedMs: elapsed,
                remainingMs: remaining,
                goalMs: goal,
                startTimeMs: Date.now() - Math.max(elapsed, 60 * 1000),
                stopTimeMs: options.ongoing === false ? Date.now() : null
            }]
        };
    }

    function named(index, fallback) {
        if (state.catalog && state.catalog[index]) {
            return state.catalog[index];
        }
        return {id: index + 1, name: fallback, customerVisible: true};
    }

    function presetMetrics(preset) {
        var first = named(0, lang() === "ru" ? "Время до первого отклика" : "Time to first response");
        var second = named(1, lang() === "ru" ? "Время до решения" : "Time to resolution");
        if (preset === "running") {
            return [
                metric(first.id, first.name, {goal: 1, remaining: 0.75, elapsed: 0.25, customerVisible: first.customerVisible}),
                metric(second.id, second.name, {goal: 5, remaining: 4, elapsed: 1, customerVisible: second.customerVisible})
            ];
        }
        if (preset === "risk") {
            return [
                metric(first.id, first.name, {goal: 1, remaining: 0.1, elapsed: 0.9, customerVisible: first.customerVisible}),
                metric(second.id, second.name, {goal: 1, remaining: 0.15, elapsed: 0.85, customerVisible: second.customerVisible})
            ];
        }
        if (preset === "breached") {
            return [
                metric(first.id, first.name, {goal: 1, remaining: -0.4, elapsed: 1.4, breached: true, ongoing: false, customerVisible: first.customerVisible}),
                metric(second.id, second.name, {goal: 2, remaining: -0.5, elapsed: 2.5, breached: true, ongoing: false, customerVisible: second.customerVisible})
            ];
        }
        if (preset === "done") {
            return [
                metric(first.id, first.name, {goal: 1, remaining: 0.3, elapsed: 0.7, ongoing: false, customerVisible: first.customerVisible}),
                metric(second.id, second.name, {goal: 5, remaining: 1, elapsed: 4, ongoing: false, customerVisible: second.customerVisible})
            ];
        }
        return [
            metric(first.id, first.name, {goal: 1, remaining: 1, elapsed: 0, paused: true, within: false, customerVisible: first.customerVisible}),
            metric(second.id, second.name, {goal: 5, remaining: 3, elapsed: 2, paused: true, within: false, customerVisible: second.customerVisible})
        ];
    }

    function previewModel() {
        var model = {
            locale: state.locale,
            hoursPerDay: effectiveHours(),
            daysPerWeek: effectiveDays(),
            metrics: presetMetrics(state.preset)
        };
        if (state.live && state.live.metrics) {
            model.metrics = state.live.metrics;
            model.locale = state.live.locale || model.locale;
        }
        return model;
    }

    function lockBlock(block) {
        block.zone = "sidebar-bottom";
        block.showStatus = false;
        block.customSelector = "";
        block.customPosition = "after";
    }

    function ensureSingleBlock() {
        if (!state.layout) {
            return;
        }
        if (!state.layout.blocks || !state.layout.blocks.length) {
            state.layout.blocks = [newBlock("portal")];
        }
        if (state.layout.blocks.length > 1) {
            state.layout.blocks = [state.layout.blocks[0]];
        }
        lockBlock(state.layout.blocks[0]);
    }

    function newBlock(variant) {
        var block = {
            id: "b" + Math.random().toString(36).substr(2, 8),
            variant: variant,
            zone: "sidebar-bottom",
            title: "SLA",
            collapsed: false,
            showName: variant !== "compact" && variant !== "status-strip",
            showStatus: false,
            showPauseIcon: true,
            showBreachTime: variant === "cards" || variant === "plain" || variant === "portal" || variant === "when" || variant === "facts" || variant === "clock" || variant === "traffic",
            timeMode: "remaining",
            timeStyle: variant === "plain" ? "spoken" : (variant === "cards" || variant === "timeline" || variant === "portal" || variant === "clock" || variant === "traffic" ? "precise" : "largest"),
            textSource: "portal",
            metricMode: "customer-visible",
            metricIds: [],
            riskPercent: 20,
            refreshSeconds: 60,
            hideWhenEmpty: true,
            customSelector: "",
            customPosition: "after"
        };
        return block;
    }

    function field(label, control) {
        var row = el("div", "psla-field");
        row.appendChild(el("label", null, label));
        row.appendChild(control);
        return row;
    }

    function selectBox(value, options, onChange) {
        var select = el("select");
        var keys = Object.keys(options);
        var i;
        for (i = 0; i < keys.length; i++) {
            var option = el("option", null, options[keys[i]]);
            option.value = keys[i];
            if (keys[i] === value) {
                option.selected = true;
            }
            select.appendChild(option);
        }
        select.addEventListener("change", function () {
            onChange(select.value);
        });
        return select;
    }

    function checkBox(checked, label, onChange) {
        var row = el("label", "psla-check");
        var input = document.createElement("input");
        input.type = "checkbox";
        input.checked = !!checked;
        input.addEventListener("change", function () {
            onChange(input.checked);
        });
        row.appendChild(input);
        row.appendChild(document.createTextNode(label));
        return row;
    }

    function numberBox(value, min, max, onChange) {
        var input = document.createElement("input");
        input.type = "number";
        input.min = String(min);
        input.max = String(max);
        input.value = value == null ? "" : String(value);
        input.addEventListener("input", function () {
            var parsed = parseInt(input.value, 10);
            onChange(isNaN(parsed) ? 0 : parsed);
        });
        return input;
    }

    function textBox(value, onChange) {
        var input = document.createElement("input");
        input.type = "text";
        input.value = value || "";
        input.addEventListener("input", function () {
            onChange(input.value);
        });
        return input;
    }

    function touch() {
        state.dirty = true;
        state.notice = "";
        renderPreview();
        paintBanner();
    }

    function variantOptions() {
        var options = {};
        var labels = tr("variants");
        var i;
        for (i = 0; i < VARIANT_ORDER.length; i++) {
            options[VARIANT_ORDER[i]] = labels[VARIANT_ORDER[i]];
        }
        return options;
    }

    function renderBlock(block) {
        var card = el("section", "psla-card");
        card.setAttribute("data-block-settings", block.id);
        var fields = el("div", "psla-fields");
        fields.appendChild(field(tr("variant"), selectBox(block.variant, variantOptions(), function (value) {
            block.variant = value;
            touch();
        })));
        fields.appendChild(field(tr("name"), textBox(block.title, function (value) {
            block.title = value;
            touch();
        })));
        var checks = el("div", "psla-checks");
        checks.appendChild(checkBox(block.collapsed, tr("collapsed"), function (value) {
            block.collapsed = value;
            touch();
        }));
        checks.appendChild(checkBox(block.showName, tr("showName"), function (value) {
            block.showName = value;
            touch();
        }));
        checks.appendChild(checkBox(block.showPauseIcon, tr("pause"), function (value) {
            block.showPauseIcon = value;
            touch();
        }));
        checks.appendChild(checkBox(block.showBreachTime, tr("breach"), function (value) {
            block.showBreachTime = value;
            touch();
        }));
        checks.appendChild(checkBox(block.hideWhenEmpty, tr("hideEmpty"), function (value) {
            block.hideWhenEmpty = value;
            touch();
        }));
        fields.appendChild(checks);
        fields.appendChild(field(tr("timeMode"), selectBox(block.timeMode, tr("modes"), function (value) {
            block.timeMode = value;
            touch();
        })));
        fields.appendChild(field(tr("timeStyle"), selectBox(block.timeStyle, tr("styles"), function (value) {
            block.timeStyle = value;
            touch();
        })));
        fields.appendChild(field(tr("textSource"), selectBox(block.textSource, tr("sources"), function (value) {
            block.textSource = value;
            touch();
        })));
        fields.appendChild(field(tr("metricMode"), selectBox(block.metricMode, tr("metricModes"), function (value) {
            block.metricMode = value;
            touch();
            renderBlocks();
        })));
        if (block.metricMode === "selected") {
            fields.appendChild(metricPicker(block));
        }
        fields.appendChild(field(tr("risk"), numberBox(block.riskPercent, 1, 90, function (value) {
            block.riskPercent = value;
            touch();
        })));
        fields.appendChild(field(tr("refresh"), numberBox(block.refreshSeconds, 15, 600, function (value) {
            block.refreshSeconds = value;
            touch();
        })));
        card.appendChild(fields);
        return card;
    }

    function metricPicker(block) {
        var box = el("div", "psla-field psla-span");
        box.appendChild(el("label", null, tr("metrics")));
        var catalog = state.catalog || [];
        if (!catalog.length) {
            box.appendChild(el("p", "psla-hint", tr("metricsUnavailable")));
            return box;
        }
        if (!block.metricIds) {
            block.metricIds = [];
        }
        var i;
        for (i = 0; i < catalog.length; i++) {
            (function (item) {
                var checked = block.metricIds.indexOf(item.id) >= 0;
                var label = item.name + (item.customerVisible ? "" : " ·");
                box.appendChild(checkBox(checked, label, function (value) {
                    var at = block.metricIds.indexOf(item.id);
                    if (value && at < 0) {
                        block.metricIds.push(item.id);
                    }
                    if (!value && at >= 0) {
                        block.metricIds.splice(at, 1);
                    }
                    touch();
                }));
            }(catalog[i]));
        }
        return box;
    }

    function renderBlocks() {
        var host = document.getElementById("psla-blocks");
        if (!host || !state.layout) {
            return;
        }
        while (host.firstChild) {
            host.removeChild(host.firstChild);
        }
        ensureSingleBlock();
        host.appendChild(renderBlock(state.layout.blocks[0]));
    }

    function renderPreview() {
        var host = document.getElementById("psla-preview-host");
        if (!host || !state.layout) {
            return;
        }
        while (host.firstChild) {
            host.removeChild(host.firstChild);
        }
        var model = previewModel();
        var blocks = state.layout.blocks || [];
        var i;
        for (i = 0; i < blocks.length; i++) {
            lockBlock(blocks[i]);
            var mount = el("div", "psla-host");
            if (api.render(mount, blocks[i], model, {editor: true})) {
                host.appendChild(mount);
            }
        }
        var buttons = document.querySelectorAll("[data-preset]");
        for (i = 0; i < buttons.length; i++) {
            buttons[i].className = buttons[i].getAttribute("data-preset") === state.preset && !state.live ? "is-on" : "";
        }
        var ribbon = document.getElementById("psla-hidden");
        if (ribbon) {
            ribbon.style.display = state.layout.enabled ? "none" : "block";
        }
    }

    function previewCard() {
        var card = el("div", "psla-preview-card");
        card.appendChild(el("h2", null, tr("preview")));
        var host = el("div");
        host.id = "psla-preview-host";
        card.appendChild(host);
        return card;
    }

    function paintBanner() {
        var banner = document.getElementById("psla-banner");
        if (!banner) {
            return;
        }
        var text = state.error || state.notice;
        if (!text && state.warning === "corrupt") {
            text = tr("corrupt");
        }
        if (!text && state.warning === "metrics-unavailable") {
            text = tr("metricsUnavailable");
        }
        banner.textContent = text || "";
        banner.className = "psla-banner" + (state.error ? "" : " is-info");
    }

    function shell() {
        ensureSingleBlock();
        var root = document.getElementById("psla-settings");
        while (root.firstChild) {
            root.removeChild(root.firstChild);
        }
        var page = el("main", "psla-page");
        var top = el("div", "psla-top");
        var titles = el("div");
        titles.appendChild(el("h1", null, tr("title")));
        titles.appendChild(el("div", "psla-project", state.projectName + " · " + state.projectKey));
        top.appendChild(titles);
        var actions = el("div", "psla-actions");
        var enabled = document.createElement("input");
        enabled.type = "checkbox";
        enabled.id = "psla-enabled";
        enabled.checked = !!(state.layout && state.layout.enabled);
        enabled.addEventListener("change", function () {
            state.layout.enabled = enabled.checked;
            touch();
        });
        var enabledLabel = el("label", "psla-check");
        enabledLabel.appendChild(enabled);
        enabledLabel.appendChild(document.createTextNode(tr("show")));
        var reset = el("button", "psla-btn", tr("reset"));
        reset.type = "button";
        reset.addEventListener("click", function () {
            if (!state.factory || !window.confirm(tr("confirmReset"))) {
                return;
            }
            state.layout = copy(state.factory);
            state.live = null;
            touch();
            shell();
        });
        var save = el("button", "psla-btn-primary", tr("save"));
        save.type = "button";
        save.id = "psla-save";
        save.addEventListener("click", saveLayout);
        actions.appendChild(enabledLabel);
        actions.appendChild(reset);
        actions.appendChild(save);
        top.appendChild(actions);
        page.appendChild(top);
        page.appendChild(el("div", "psla-banner", ""));
        page.lastChild.id = "psla-banner";

        var grid = el("div", "psla-workspace");
        var stage = el("section", "psla-stage");
        var stageBar = el("div", "psla-stage-bar");
        var presets = el("div", "psla-presets");
        var names = tr("presets");
        var keys = ["paused", "running", "risk", "breached", "done"];
        var i;
        for (i = 0; i < keys.length; i++) {
            (function (key) {
                var button = el("button", null, names[key]);
                button.type = "button";
                button.setAttribute("data-preset", key);
                button.addEventListener("click", function () {
                    state.preset = key;
                    state.live = null;
                    renderPreview();
                });
                presets.appendChild(button);
            }(keys[i]));
        }
        stageBar.appendChild(presets);
        if (!state.mock) {
            var issueRow = el("div", "psla-inline");
            var issue = document.createElement("input");
            issue.id = "psla-issue-key";
            issue.type = "text";
            issue.placeholder = tr("issue");
            var apply = el("button", "psla-btn", tr("applyIssue"));
            apply.type = "button";
            apply.addEventListener("click", loadIssue);
            var sample = el("button", "psla-btn", tr("sample"));
            sample.type = "button";
            sample.addEventListener("click", function () {
                state.live = null;
                issue.value = "";
                renderPreview();
            });
            issueRow.appendChild(issue);
            issueRow.appendChild(apply);
            issueRow.appendChild(sample);
            stageBar.appendChild(issueRow);
        }
        stage.appendChild(stageBar);
        var ribbon = el("div", "psla-hidden-ribbon", tr("hidden") || "");
        ribbon.id = "psla-hidden";
        ribbon.style.display = "none";
        if (!tr("hidden")) {
            ribbon.textContent = lang() === "ru"
                ? "Клиенты это пока не видят. Включите «Показывать клиентам» и сохраните."
                : "Customers cannot see this yet. Turn on “Show to customers” and save.";
        }
        stage.appendChild(ribbon);
        stage.appendChild(previewCard());
        grid.appendChild(stage);

        var form = el("aside", "psla-inspector");
        var general = el("section", "psla-card");
        general.appendChild(el("h2", null, tr("general")));
        general.appendChild(el("p", "psla-place", tr("place")));
        var split = el("div", "psla-split");
        split.appendChild(field(tr("day"), numberBox(state.layout.hoursPerDay || 0, 0, 24, function (value) {
            state.layout.hoursPerDay = value;
            touch();
        })));
        split.appendChild(field(tr("week"), numberBox(state.layout.daysPerWeek || 0, 0, 7, function (value) {
            state.layout.daysPerWeek = value;
            touch();
        })));
        general.appendChild(split);
        general.appendChild(el("p", "psla-hint", tr("dayHint") + state.jiraHoursPerDay + " / " + state.jiraDaysPerWeek));
        form.appendChild(general);
        var blocks = el("div");
        blocks.id = "psla-blocks";
        form.appendChild(blocks);
        grid.appendChild(form);
        page.appendChild(grid);
        root.appendChild(page);
        renderBlocks();
        renderPreview();
        paintBanner();
    }

    function prepareLayout() {
        ensureSingleBlock();
        state.layout.selectors = {};
        var blocks = state.layout.blocks || [];
        var i;
        for (i = 0; i < blocks.length; i++) {
            lockBlock(blocks[i]);
            if (blocks[i].metricMode === "selected" && (!blocks[i].metricIds || !blocks[i].metricIds.length)) {
                state.error = tr("noSelection");
                paintBanner();
                return false;
            }
        }
        return true;
    }

    function saveLayout() {
        if (!prepareLayout()) {
            return;
        }
        var button = document.getElementById("psla-save");
        button.disabled = true;
        button.textContent = tr("saving");
        var payload = JSON.stringify(state.layout);
        if (state.mock) {
            try {
                window.localStorage.setItem("psla-settings-layout", payload);
            } catch (ignore) {
                /* ignore */
            }
            state.dirty = false;
            state.error = "";
            state.notice = tr("savedLocal");
            button.disabled = false;
            button.textContent = tr("save");
            paintBanner();
            return;
        }
        window.fetch(state.rest + "/config/" + encodeURIComponent(state.projectKey), {
            method: "PUT",
            credentials: "same-origin",
            headers: {
                "Accept": "application/json",
                "Content-Type": "application/json",
                "X-Atlassian-Token": "no-check"
            },
            body: payload
        }).then(function (response) {
            return response.json().then(function (body) {
                return {ok: response.ok, body: body};
            });
        }).then(function (result) {
            button.disabled = false;
            button.textContent = tr("save");
            if (!result.ok) {
                var messages = result.body && result.body.messages ? result.body.messages : [];
                state.error = messages.length ? messages.map(explain).join(" ") : explain(result.body && result.body.error);
                paintBanner();
                return;
            }
            state.layout = result.body.layout;
            state.catalog = result.body.catalog || state.catalog;
            state.warning = result.body.warning || "";
            state.dirty = false;
            state.error = "";
            state.notice = tr("saved");
            shell();
        }).catch(function () {
            button.disabled = false;
            button.textContent = tr("save");
            state.error = tr("errors")["invalid-json"];
            paintBanner();
        });
    }

    function loadIssue() {
        var input = document.getElementById("psla-issue-key");
        var key = input && input.value ? input.value.replace(/\s+/g, "") : "";
        if (!key) {
            state.live = null;
            renderPreview();
            return;
        }
        window.fetch(state.rest + "/config/" + encodeURIComponent(state.projectKey) + "/preview/" + encodeURIComponent(key), {
            credentials: "same-origin",
            headers: {"Accept": "application/json"}
        }).then(function (response) {
            return response.json().then(function (body) {
                return {ok: response.ok, body: body};
            });
        }).then(function (result) {
            if (!result.ok) {
                state.error = explain(result.body && result.body.error);
                paintBanner();
                return;
            }
            state.live = result.body;
            state.error = "";
            renderPreview();
            paintBanner();
        }).catch(function () {
            state.error = tr("errors")["not-found"];
            paintBanner();
        });
    }

    function host() {
        return document.getElementById("psla-settings") || document.body;
    }

    function defaultsUrl() {
        var body = host();
        var explicit = body.getAttribute("data-layout-url");
        if (explicit) {
            return explicit;
        }
        return (state.base || "") + "/download/resources/com.portalsla.portal-sla:portal-sla-settings/default-layout.json";
    }

    function load() {
        var body = host();
        state.mock = body.getAttribute("data-mock") === "true";
        state.locale = body.getAttribute("data-locale") || (navigator.language || "ru");
        state.projectKey = body.getAttribute("data-project-key") || "SD";
        state.projectName = body.getAttribute("data-project-name") || "Service Desk";
        state.rest = body.getAttribute("data-rest") || "";
        state.base = body.getAttribute("data-base") || "";
        if (state.mock) {
            var saved = null;
            try {
                saved = window.localStorage.getItem("psla-settings-layout");
            } catch (ignore) {
                saved = null;
            }
            return window.fetch(defaultsUrl()).then(function (response) {
                return response.json();
            }).then(function (factory) {
                state.factory = factory;
                state.layout = saved ? JSON.parse(saved) : copy(factory);
                state.catalog = sampleCatalog();
                state.jiraHoursPerDay = 8;
                state.jiraDaysPerWeek = 5;
            });
        }
        return window.fetch(state.rest + "/config/" + encodeURIComponent(state.projectKey), {
            credentials: "same-origin",
            headers: {"Accept": "application/json"}
        }).then(function (response) {
            return response.json().then(function (payload) {
                return {ok: response.ok, body: payload};
            });
        }).then(function (result) {
            if (!result.ok) {
                throw new Error(result.body && result.body.error ? result.body.error : "config");
            }
            state.layout = result.body.layout;
            state.catalog = result.body.catalog || [];
            state.jiraHoursPerDay = result.body.jiraHoursPerDay || 8;
            state.jiraDaysPerWeek = result.body.jiraDaysPerWeek || 5;
            state.warning = result.body.warning || "";
            if (result.body.projectName) {
                state.projectName = result.body.projectName;
            }
            return window.fetch(defaultsUrl()).then(function (response) {
                return response.json();
            }).then(function (factory) {
                state.factory = factory;
            });
        });
    }

    function boot() {
        load().then(shell).catch(function () {
            var root = document.getElementById("psla-settings");
            if (root) {
                root.textContent = tr("errors").auth;
            }
        });
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", boot);
    } else {
        boot();
    }
})(window, document);
