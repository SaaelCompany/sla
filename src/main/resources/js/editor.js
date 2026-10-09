/* Visual layout editor. The canvas uses the same renderer as the customer portal. */
(function (window, document) {
    "use strict";

    if (!window.PortalSlaRender) {
        return;
    }

    var api = window.PortalSlaRender;
    var UI = {
        ru: {
            title: "SLA на портале",
            projects: "Все проекты",
            show: "Показывать клиентам",
            reset: "Сбросить",
            save: "Сохранить",
            saving: "Сохраняю…",
            saved: "Сохранено. Клиенты увидят это на портале.",
            savedLocal: "Сохранено в этом браузере. Это локальный просмотр, не Jira.",
            mockIssue: "Пример остаётся на месте: живые данные заявки читаются только из Jira.",
            variantsTitle: "Варианты",
            canvas: "Страница заявки",
            inspector: "Блок",
            emptyInspector: "Выберите блок на странице или перетащите вариант в нужное место.",
            hidden: "Клиенты это пока не видят. Включите «Показывать клиентам» и сохраните.",
            preview: "Так блок выглядит у клиента.",
            issue: "Ключ заявки",
            applyIssue: "Подставить",
            clearIssue: "Пример",
            advanced: "День, неделя и свои селекторы",
            day: "Часов в рабочем дне (0 — как в Jira)",
            week: "Дней в неделе (0 — как в Jira)",
            dayHint: "1 день на портале равен этому числу часов. Для календаря 24/7 поставьте 24. Сейчас в Jira: ",
            selectors: "Если портал размечен иначе, впишите CSS-селектор — по одному в строке. Пустое поле оставляет стандартные.",
            defaults: "Сейчас ищем: ",
            none: "Пока ничего не выбрано",
            name: "Заголовок",
            zone: "Место",
            collapsed: "Свёрнут по умолчанию",
            showName: "Имена метрик",
            showStatus: "Статус заявки",
            pause: "Значок паузы",
            breach: "Дата нарушения",
            timeMode: "Какое время показывать",
            timeStyle: "Формат",
            textSource: "Откуда текст",
            metricMode: "Какие SLA",
            risk: "Порог «скоро нарушит», %",
            refresh: "Обновление, секунды",
            hideEmpty: "Скрывать, если SLA нет",
            selector: "CSS-селектор",
            position: "Как вставить",
            metrics: "Метрики",
            up: "Выше",
            down: "Ниже",
            remove: "Удалить блок",
            tooMany: "На странице уже 16 блоков.",
            confirmReset: "Вернуть предложенную раскладку? Несохранённые правки пропадут.",
            corrupt: "Сохранённая схема повреждена. Показан вариант по умолчанию — сохраните его, чтобы заменить старый.",
            metricsUnavailable: "Список SLA проекта недоступен. Можно выбрать «Все SLA» или указать их позже.",
            noSelection: "Для режима «Выбранные» отметьте хотя бы одну метрику.",
            zones: {
                header: "Шапка страницы",
                "under-title": "Под заголовком",
                "beside-status": "Рядом со статусом",
                "above-description": "Над описанием",
                "above-activity": "Над перепиской",
                "sidebar-top": "Боковая панель сверху",
                "sidebar-bottom": "Боковая панель снизу",
                "portal-panel": "Панель портала",
                "request-footer": "Подвал страницы",
                "my-requests": "Список «Мои заявки»",
                custom: "Свой селектор"
            },
            variants: {
                compact: ["Компактный список", "Как на портале: «1 д.» и значок паузы"],
                badges: ["Плашки", "Цветные статусы SLA"],
                progress: ["Прогресс", "Полоса прошедшего времени"],
                countdown: ["Обратный отсчёт", "Крупный остаток"],
                cards: ["Карточки", "Цель, прошло, осталось, срок"],
                timeline: ["Хронология", "Текущий и закрытые циклы"],
                "status-strip": ["Строка статуса", "Статус заявки и SLA в одну линию"]
            },
            modes: {remaining: "Осталось", elapsed: "Прошло", goal: "Цель"},
            styles: {largest: "Крупная единица (1 д.)", precise: "Две единицы (1 д. 2 ч.)"},
            sources: {portal: "Стиль портала", jira: "Формат Jira"},
            metricModes: {
                "customer-visible": "Только отмеченные «на портале»",
                all: "Все SLA проекта",
                selected: "Только выбранные"
            },
            positions: {before: "Перед элементом", after: "После элемента", prepend: "В начало", append: "В конец"},
            presets: {
                paused: "На паузе",
                running: "В срок",
                risk: "Скоро нарушит",
                breached: "Нарушено",
                done: "Завершено"
            },
            sampleTitle: "Не работает принтер на 3 этаже",
            sampleStatus: "В ожидании поддержки",
            navHelp: "Порталы",
            navRequests: "Заявки",
            description: "Описание заявки",
            activity: "Переписка",
            people: "Участники",
            fields: "Поля заявки",
            errors: {
                "invalid-json": "Не удалось прочитать схему.",
                "invalid-layout": "Схема не прошла проверку.",
                "too-many-blocks": "Слишком много блоков.",
                "bad-variant": "Неизвестный вариант.",
                "bad-zone": "Неизвестное место.",
                "bad-selector": "Селектор содержит недопустимые символы.",
                "custom-selector": "Для своего места нужен CSS-селектор.",
                "bad-metric-id": "Некорректный идентификатор SLA.",
                "hours-per-day": "Часов в дне должно быть от 1 до 24, либо 0.",
                "days-per-week": "Дней в неделе должно быть от 1 до 7, либо 0.",
                forbidden: "Недостаточно прав.",
                "not-found": "Заявка или проект не найдены.",
                auth: "Нужно войти в Jira."
            }
        },
        en: {
            title: "Portal SLA",
            projects: "All projects",
            show: "Show to customers",
            reset: "Reset",
            save: "Save",
            saving: "Saving…",
            saved: "Saved. Customers will see this on the portal.",
            savedLocal: "Saved in this browser. This is a local preview, not Jira.",
            mockIssue: "The sample stays in place: a real request is read only from Jira.",
            variantsTitle: "Variants",
            canvas: "Request page",
            inspector: "Block",
            emptyInspector: "Select a block on the page, or drag a variant where it should appear.",
            hidden: "Customers cannot see this yet. Turn on “Show to customers” and save.",
            preview: "This is what the customer sees.",
            issue: "Request key",
            applyIssue: "Use request",
            clearIssue: "Sample",
            advanced: "Day length and custom selectors",
            day: "Hours in a working day (0 = Jira setting)",
            week: "Days in a week (0 = Jira setting)",
            dayHint: "One displayed day equals this many hours. Use 24 for a 24/7 calendar. Jira currently uses ",
            selectors: "If the portal markup differs, add one CSS selector per line. Leave blank to keep the defaults.",
            defaults: "Currently matching: ",
            none: "Nothing selected yet",
            name: "Title",
            zone: "Placement",
            collapsed: "Collapsed by default",
            showName: "Metric names",
            showStatus: "Request status",
            pause: "Pause icon",
            breach: "Breach date",
            timeMode: "Which time to show",
            timeStyle: "Format",
            textSource: "Text source",
            metricMode: "Which SLAs",
            risk: "“At risk” threshold, %",
            refresh: "Refresh, seconds",
            hideEmpty: "Hide when there is no SLA",
            selector: "CSS selector",
            position: "Insert",
            metrics: "Metrics",
            up: "Up",
            down: "Down",
            remove: "Remove block",
            tooMany: "The page already has 16 blocks.",
            confirmReset: "Restore the suggested layout? Unsaved changes will be lost.",
            corrupt: "The saved layout is damaged. The default is shown — save it to replace the old one.",
            metricsUnavailable: "This project's SLA list is unavailable. You can still choose “All SLAs”.",
            noSelection: "Tick at least one metric for “Selected only”.",
            zones: {
                header: "Page header",
                "under-title": "Under the title",
                "beside-status": "Next to status",
                "above-description": "Above the description",
                "above-activity": "Above the conversation",
                "sidebar-top": "Sidebar, top",
                "sidebar-bottom": "Sidebar, bottom",
                "portal-panel": "Portal panel",
                "request-footer": "Request footer",
                "my-requests": "My requests list",
                custom: "Custom selector"
            },
            variants: {
                compact: ["Compact list", "Portal style: “1d” and a pause icon"],
                badges: ["Badges", "Coloured SLA statuses"],
                progress: ["Progress", "Elapsed-time bar"],
                countdown: ["Countdown", "Large remaining time"],
                cards: ["Cards", "Goal, elapsed, remaining, due"],
                timeline: ["Timeline", "Current and completed cycles"],
                "status-strip": ["Status strip", "Request status and SLA on one line"]
            },
            modes: {remaining: "Remaining", elapsed: "Elapsed", goal: "Goal"},
            styles: {largest: "Largest unit (1d)", precise: "Two units (1d 2h)"},
            sources: {portal: "Portal style", jira: "Jira format"},
            metricModes: {
                "customer-visible": "Only “show on portal”",
                all: "Every project SLA",
                selected: "Selected only"
            },
            positions: {before: "Before the element", after: "After the element", prepend: "At the start", append: "At the end"},
            presets: {
                paused: "Paused",
                running: "On track",
                risk: "At risk",
                breached: "Breached",
                done: "Completed"
            },
            sampleTitle: "Printer on floor 3 is down",
            sampleStatus: "Waiting for support",
            navHelp: "Portals",
            navRequests: "Requests",
            description: "Request description",
            activity: "Conversation",
            people: "Participants",
            fields: "Request fields",
            errors: {
                "invalid-json": "The layout could not be read.",
                "invalid-layout": "The layout did not pass validation.",
                "too-many-blocks": "Too many blocks.",
                "bad-variant": "Unknown variant.",
                "bad-zone": "Unknown placement.",
                "bad-selector": "The selector contains unsupported characters.",
                "custom-selector": "A custom placement needs a CSS selector.",
                "bad-metric-id": "Invalid SLA id.",
                "hours-per-day": "Hours per day must be 0 or 1–24.",
                "days-per-week": "Days per week must be 0 or 1–7.",
                forbidden: "You do not have permission.",
                "not-found": "The request or project was not found.",
                auth: "Sign in to Jira first."
            }
        }
    };

    var VARIANT_ORDER = ["compact", "badges", "progress", "countdown", "cards", "timeline", "status-strip"];
    var ZONE_ORDER = ["header", "under-title", "beside-status", "above-description", "above-activity", "sidebar-top", "sidebar-bottom", "portal-panel", "request-footer", "my-requests", "custom"];

    var state = {
        layout: null,
        factory: null,
        catalog: [],
        jiraHoursPerDay: 8,
        jiraDaysPerWeek: 5,
        locale: "ru",
        projectKey: "",
        projectName: "",
        rest: "",
        mock: false,
        selectedId: "sla-main",
        preset: "paused",
        live: null,
        armed: null,
        dirty: false,
        warning: "",
        error: ""
    };

    function lang() {
        return state.locale && String(state.locale).toLowerCase().indexOf("ru") === 0 ? "ru" : "en";
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

    function effectiveHours() {
        var value = state.layout && state.layout.hoursPerDay;
        return value > 0 ? value : state.jiraHoursPerDay || 8;
    }

    function effectiveDays() {
        var value = state.layout && state.layout.daysPerWeek;
        return value > 0 ? value : state.jiraDaysPerWeek || 5;
    }

    function dayMs() {
        return effectiveHours() * 60 * 60 * 1000;
    }

    function selectedBlock() {
        var blocks = state.layout && state.layout.blocks ? state.layout.blocks : [];
        var i;
        for (i = 0; i < blocks.length; i++) {
            if (blocks[i].id === state.selectedId) {
                return blocks[i];
            }
        }
        return null;
    }

    function markDirty() {
        state.dirty = true;
        state.error = "";
    }

    function sampleCatalog() {
        var ru = lang() === "ru";
        return [
            {id: 1, name: ru ? "Время до первого ответа" : "Time to first response", customerVisible: true},
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
            jira: null,
            cycles: options.cycles || [{
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
            return {id: state.catalog[index].id, name: state.catalog[index].name, customerVisible: state.catalog[index].customerVisible !== false};
        }
        return {id: index + 1, name: fallback, customerVisible: true};
    }

    function presetMetrics(preset) {
        var first = named(0, lang() === "ru" ? "Время до первого ответа" : "Time to first response");
        var second = named(1, lang() === "ru" ? "Время до решения" : "Time to resolution");
        if (preset === "running") {
            return [
                metric(first.id, first.name, {goal: 1, remaining: 0.75, elapsed: 0.25, within: true, customerVisible: first.customerVisible}),
                metric(second.id, second.name, {goal: 5, remaining: 4, elapsed: 1, within: true, customerVisible: second.customerVisible})
            ];
        }
        if (preset === "risk") {
            return [
                metric(first.id, first.name, {goal: 1, remaining: 0.1, elapsed: 0.9, within: true, customerVisible: first.customerVisible}),
                metric(second.id, second.name, {goal: 1, remaining: 0.15, elapsed: 0.85, within: true, customerVisible: second.customerVisible})
            ];
        }
        if (preset === "breached") {
            return [
                metric(first.id, first.name, {goal: 1, remaining: -0.4, elapsed: 1.4, breached: true, within: true, customerVisible: first.customerVisible}),
                metric(second.id, second.name, {goal: 2, remaining: 1, elapsed: 1, within: true, customerVisible: second.customerVisible})
            ];
        }
        if (preset === "done") {
            return [
                metric(first.id, first.name, {goal: 1, remaining: 0.3, elapsed: 0.7, ongoing: false, customerVisible: first.customerVisible}),
                metric(second.id, second.name, {goal: 1, remaining: -0.5, elapsed: 1.5, breached: true, ongoing: false, customerVisible: second.customerVisible})
            ];
        }
        return [
            metric(first.id, first.name, {goal: 1, remaining: 1, elapsed: 0, paused: true, within: false, customerVisible: first.customerVisible}),
            metric(second.id, second.name, {goal: 2, remaining: 2, elapsed: 0, paused: true, within: false, customerVisible: second.customerVisible})
        ];
    }

    function currentModel() {
        if (state.live) {
            state.live.hoursPerDay = effectiveHours();
            state.live.daysPerWeek = effectiveDays();
            state.live.locale = state.locale;
            return state.live;
        }
        return {
            locale: state.locale,
            hoursPerDay: effectiveHours(),
            daysPerWeek: effectiveDays(),
            status: {name: tr("sampleStatus"), category: "indeterminate"},
            metrics: presetMetrics(state.preset)
        };
    }

    function newBlock(variant, zone) {
        return {
            id: "b" + Math.random().toString(36).substr(2, 8),
            variant: variant,
            zone: zone,
            title: "SLA",
            collapsed: false,
            showName: variant !== "compact" && variant !== "status-strip",
            showStatus: variant === "status-strip",
            showPauseIcon: true,
            showBreachTime: variant === "cards" || variant === "countdown",
            timeMode: "remaining",
            timeStyle: variant === "cards" || variant === "countdown" || variant === "timeline" ? "precise" : "largest",
            textSource: "portal",
            metricMode: "customer-visible",
            metricIds: [],
            riskPercent: 20,
            refreshSeconds: 60,
            hideWhenEmpty: true,
            customSelector: "",
            customPosition: "after"
        };
    }

    function addBlock(variant, zone) {
        if (state.layout.blocks.length >= 16) {
            state.error = tr("tooMany");
            renderBanner();
            return;
        }
        var block = newBlock(variant, zone);
        state.layout.blocks.push(block);
        state.selectedId = block.id;
        state.armed = null;
        markDirty();
        renderPalette();
        renderCanvas();
        renderInspector();
    }

    function moveBlock(id, zone) {
        var blocks = state.layout.blocks;
        var block = null;
        var index = -1;
        var i;
        for (i = 0; i < blocks.length; i++) {
            if (blocks[i].id === id) {
                block = blocks[i];
                index = i;
            }
        }
        if (!block) {
            return;
        }
        blocks.splice(index, 1);
        block.zone = zone;
        var insertAt = blocks.length;
        for (i = blocks.length - 1; i >= 0; i--) {
            if (blocks[i].zone === zone) {
                insertAt = i + 1;
                break;
            }
        }
        blocks.splice(insertAt, 0, block);
        state.selectedId = id;
        markDirty();
        renderCanvas();
        renderInspector();
    }

    function shift(block, direction) {
        var blocks = state.layout.blocks;
        var same = [];
        var i;
        for (i = 0; i < blocks.length; i++) {
            if (blocks[i].zone === block.zone) {
                same.push(blocks[i]);
            }
        }
        var pos = same.indexOf(block);
        var other = same[pos + direction];
        if (!other) {
            return;
        }
        var a = blocks.indexOf(block);
        var b = blocks.indexOf(other);
        blocks[a] = other;
        blocks[b] = block;
        markDirty();
        renderCanvas();
    }

    function removeBlock(block) {
        var blocks = state.layout.blocks;
        var i;
        for (i = 0; i < blocks.length; i++) {
            if (blocks[i] === block) {
                blocks.splice(i, 1);
                break;
            }
        }
        state.selectedId = blocks.length ? blocks[0].id : null;
        markDirty();
        renderCanvas();
        renderInspector();
    }

    function explain(code) {
        var base = String(code || "").split(":")[0];
        var table = UI[lang()].errors;
        return table[base] || code;
    }

    function renderBanner() {
        var banner = document.getElementById("psla-banner");
        banner.className = "psla-banner";
        banner.textContent = "";
        if (state.error) {
            banner.className += " is-error";
            banner.textContent = state.error;
            banner.hidden = false;
            return;
        }
        if (state.warning === "corrupt") {
            banner.className += " is-warn";
            banner.textContent = tr("corrupt");
            banner.hidden = false;
            return;
        }
        if (state.warning === "metrics-unavailable") {
            banner.className += " is-warn";
            banner.textContent = tr("metricsUnavailable");
            banner.hidden = false;
            return;
        }
        banner.hidden = true;
    }

    function toast(message) {
        var node = document.getElementById("psla-toast");
        node.hidden = false;
        node.textContent = message;
        window.clearTimeout(toast._t);
        toast._t = window.setTimeout(function () {
            node.hidden = true;
        }, 3200);
    }

    function renderPalette() {
        var root = document.getElementById("psla-palette");
        root.innerHTML = "";
        root.appendChild(el("h2", null, tr("variantsTitle")));
        var i;
        for (i = 0; i < VARIANT_ORDER.length; i++) {
            (function (variant) {
                var meta = UI[lang()].variants[variant];
                var button = el("button", "psla-variant" + (state.armed === variant ? " is-armed" : ""));
                button.type = "button";
                button.draggable = true;
                button.appendChild(el("strong", null, meta[0]));
                button.appendChild(el("span", null, meta[1]));
                button.addEventListener("dragstart", function (event) {
                    event.dataTransfer.setData("text/plain", "variant:" + variant);
                    event.dataTransfer.effectAllowed = "copy";
                });
                button.addEventListener("click", function () {
                    state.armed = state.armed === variant ? null : variant;
                    renderPalette();
                    renderCanvas();
                });
                root.appendChild(button);
            })(VARIANT_ORDER[i]);
        }
        root.appendChild(el("p", "psla-hint", tr("preview")));
    }

    function zoneBox(id) {
        var zone = el("div", "psla-zone" + (state.armed ? " is-target" : ""));
        zone.setAttribute("data-zone", id);
        zone.appendChild(el("div", "psla-zone-label", tr("zones")[id]));
        var body = el("div", "psla-zone-body");
        var blocks = state.layout.blocks || [];
        var i;
        for (i = 0; i < blocks.length; i++) {
            if (blocks[i].zone !== id) {
                continue;
            }
            body.appendChild(placed(blocks[i]));
        }
        zone.appendChild(body);
        zone.addEventListener("dragover", function (event) {
            event.preventDefault();
            zone.className += zone.className.indexOf("is-over") >= 0 ? "" : " is-over";
        });
        zone.addEventListener("dragleave", function () {
            zone.className = zone.className.replace(" is-over", "");
        });
        zone.addEventListener("drop", function (event) {
            event.preventDefault();
            zone.className = zone.className.replace(" is-over", "");
            var data = event.dataTransfer.getData("text/plain") || "";
            if (data.indexOf("variant:") === 0) {
                addBlock(data.substring(8), id);
            } else if (data.indexOf("block:") === 0) {
                moveBlock(data.substring(6), id);
            }
        });
        zone.addEventListener("click", function () {
            if (state.armed) {
                addBlock(state.armed, id);
            }
        });
        return zone;
    }

    function placed(block) {
        var wrap = el("div", "psla-placed" + (block.id === state.selectedId ? " is-selected" : ""));
        wrap.draggable = true;
        wrap.appendChild(el("div", "psla-handle", "⋮⋮"));
        var mount = el("div");
        api.render(mount, block, currentModel(), {editor: true, dense: block.zone === "my-requests"});
        wrap.appendChild(mount);
        wrap.addEventListener("click", function (event) {
            event.stopPropagation();
            state.selectedId = block.id;
            renderCanvas();
            renderInspector();
        });
        wrap.addEventListener("dragstart", function (event) {
            if (event.target && event.target.closest && event.target.closest("button")) {
                event.preventDefault();
                return;
            }
            event.dataTransfer.setData("text/plain", "block:" + block.id);
            event.dataTransfer.effectAllowed = "move";
            event.stopPropagation();
        });
        return wrap;
    }

    function renderCanvas() {
        var canvas = document.getElementById("psla-canvas");
        canvas.innerHTML = "";
        if (!state.layout.enabled) {
            canvas.appendChild(el("div", "psla-hidden-ribbon", tr("hidden")));
        }
        var frame = el("div", "psla-portal-frame");
        var browser = el("div", "psla-browser-top");
        browser.appendChild(el("i"));
        browser.appendChild(el("i"));
        browser.appendChild(el("i"));
        browser.appendChild(el("div", "psla-url", "/servicedesk/customer/portal/1/SD-42"));
        frame.appendChild(browser);
        var nav = el("div", "psla-portal-nav");
        nav.appendChild(el("strong", null, state.projectName || "Service Desk"));
        var links = el("span");
        links.textContent = tr("navHelp") + "  ·  " + tr("navRequests");
        nav.appendChild(links);
        frame.appendChild(nav);
        frame.appendChild(zoneBox("header"));

        var request = el("article", "psla-request");
        request.appendChild(zoneBox("under-title"));
        request.appendChild(el("div", "psla-req-key", "SD-42"));
        request.appendChild(el("h2", null, tr("sampleTitle")));
        var statusLine = el("div", "psla-status-line");
        statusLine.appendChild(el("span", "psla-lozenge psla-cat-indeterminate", tr("sampleStatus")));
        statusLine.appendChild(zoneBox("beside-status"));
        request.appendChild(statusLine);

        var grid = el("div", "psla-request-grid");
        var main = el("div");
        main.appendChild(zoneBox("above-description"));
        main.appendChild(el("div", "psla-fake-text", tr("description")));
        main.appendChild(zoneBox("above-activity"));
        main.appendChild(el("div", "psla-fake-text", tr("activity")));
        var side = el("aside");
        side.appendChild(zoneBox("sidebar-top"));
        side.appendChild(el("div", "psla-fake-side", tr("people")));
        side.appendChild(el("div", "psla-fake-side", tr("fields")));
        side.appendChild(zoneBox("sidebar-bottom"));
        side.appendChild(zoneBox("portal-panel"));
        grid.appendChild(main);
        grid.appendChild(side);
        request.appendChild(grid);
        frame.appendChild(request);
        frame.appendChild(zoneBox("request-footer"));
        canvas.appendChild(frame);

        var extra = el("div", "psla-extra");
        extra.appendChild(zoneBox("my-requests"));
        extra.appendChild(zoneBox("custom"));
        canvas.appendChild(extra);
    }

    function fieldLabel(text) {
        return el("label", null, text);
    }

    function textInput(block, field) {
        var input = el("input");
        input.type = "text";
        input.value = block[field] || "";
        input.addEventListener("input", function () {
            block[field] = input.value;
            markDirty();
            renderCanvas();
        });
        return input;
    }

    function numberInput(block, field, min, max) {
        var input = el("input");
        input.type = "number";
        input.min = String(min);
        input.max = String(max);
        input.value = block[field];
        input.addEventListener("input", function () {
            var value = parseInt(input.value, 10);
            if (!isNaN(value)) {
                block[field] = value;
                markDirty();
                renderCanvas();
            }
        });
        return input;
    }

    function selectInput(block, field, options) {
        var select = el("select");
        var keys = Object.keys(options);
        var i;
        for (i = 0; i < keys.length; i++) {
            var option = el("option", null, options[keys[i]]);
            option.value = keys[i];
            if (block[field] === keys[i]) {
                option.selected = true;
            }
            select.appendChild(option);
        }
        select.addEventListener("change", function () {
            block[field] = select.value;
            markDirty();
            renderCanvas();
            if (field === "metricMode" || field === "zone") {
                renderInspector();
            }
        });
        return select;
    }

    function checkInput(block, field, label) {
        var wrap = el("label", "psla-check");
        var input = el("input");
        input.type = "checkbox";
        input.checked = !!block[field];
        input.addEventListener("change", function () {
            block[field] = input.checked;
            markDirty();
            renderCanvas();
        });
        wrap.appendChild(input);
        wrap.appendChild(document.createTextNode(label));
        return wrap;
    }

    function renderInspector() {
        var root = document.getElementById("psla-inspector");
        root.innerHTML = "";
        root.appendChild(el("h2", null, tr("inspector")));
        var block = selectedBlock();
        if (!block) {
            root.appendChild(el("p", "psla-hint", tr("emptyInspector")));
            return;
        }
        root.appendChild(fieldLabel(tr("name")));
        root.appendChild(textInput(block, "title"));
        root.appendChild(fieldLabel(tr("zone")));
        root.appendChild(selectInput(block, "zone", tr("zones")));
        root.appendChild(checkInput(block, "collapsed", tr("collapsed")));
        root.appendChild(checkInput(block, "showName", tr("showName")));
        root.appendChild(checkInput(block, "showStatus", tr("showStatus")));
        root.appendChild(checkInput(block, "showPauseIcon", tr("pause")));
        root.appendChild(checkInput(block, "showBreachTime", tr("breach")));
        root.appendChild(checkInput(block, "hideWhenEmpty", tr("hideEmpty")));
        root.appendChild(fieldLabel(tr("timeMode")));
        root.appendChild(selectInput(block, "timeMode", tr("modes")));
        root.appendChild(fieldLabel(tr("timeStyle")));
        root.appendChild(selectInput(block, "timeStyle", tr("styles")));
        root.appendChild(fieldLabel(tr("textSource")));
        root.appendChild(selectInput(block, "textSource", tr("sources")));
        root.appendChild(fieldLabel(tr("metricMode")));
        root.appendChild(selectInput(block, "metricMode", tr("metricModes")));
        if (block.metricMode === "selected") {
            root.appendChild(fieldLabel(tr("metrics")));
            root.appendChild(metricPicker(block));
            if (!block.metricIds || !block.metricIds.length) {
                root.appendChild(el("p", "psla-hint", tr("noSelection")));
            }
        }
        root.appendChild(fieldLabel(tr("risk")));
        root.appendChild(numberInput(block, "riskPercent", 1, 90));
        root.appendChild(fieldLabel(tr("refresh")));
        root.appendChild(numberInput(block, "refreshSeconds", 15, 600));
        if (block.zone === "custom") {
            root.appendChild(fieldLabel(tr("selector")));
            root.appendChild(textInput(block, "customSelector"));
            root.appendChild(fieldLabel(tr("position")));
            root.appendChild(selectInput(block, "customPosition", tr("positions")));
        }
        var row = el("div", "psla-row-buttons");
        var up = el("button", null, tr("up"));
        up.type = "button";
        up.addEventListener("click", function () {
            shift(block, -1);
        });
        var down = el("button", null, tr("down"));
        down.type = "button";
        down.addEventListener("click", function () {
            shift(block, 1);
        });
        var remove = el("button", "psla-danger", tr("remove"));
        remove.type = "button";
        remove.addEventListener("click", function () {
            removeBlock(block);
        });
        row.appendChild(up);
        row.appendChild(down);
        row.appendChild(remove);
        root.appendChild(row);
    }

    function metricPicker(block) {
        var box = el("div", "psla-metrics");
        var catalog = state.catalog || [];
        if (!catalog.length) {
            box.appendChild(el("p", "psla-hint", tr("none")));
            return box;
        }
        var i;
        for (i = 0; i < catalog.length; i++) {
            (function (item) {
                var wrap = el("label", "psla-check");
                var input = el("input");
                input.type = "checkbox";
                input.checked = (block.metricIds || []).indexOf(item.id) >= 0;
                input.addEventListener("change", function () {
                    var ids = block.metricIds || [];
                    var next = [];
                    var n;
                    for (n = 0; n < ids.length; n++) {
                        if (ids[n] !== item.id) {
                            next.push(ids[n]);
                        }
                    }
                    if (input.checked) {
                        next.push(item.id);
                    }
                    block.metricIds = next;
                    markDirty();
                    renderCanvas();
                });
                wrap.appendChild(input);
                wrap.appendChild(document.createTextNode(item.name + (item.customerVisible ? "" : " ·")));
                box.appendChild(wrap);
            })(catalog[i]);
        }
        return box;
    }

    function renderAdvanced() {
        var root = document.getElementById("psla-advanced");
        root.innerHTML = "";
        var summary = el("summary", null, tr("advanced"));
        root.appendChild(summary);
        root.appendChild(fieldLabel(tr("day")));
        var hours = el("input");
        hours.type = "number";
        hours.min = "0";
        hours.max = "24";
        hours.value = state.layout.hoursPerDay || 0;
        hours.addEventListener("input", function () {
            var value = parseInt(hours.value, 10);
            state.layout.hoursPerDay = isNaN(value) ? 0 : value;
            markDirty();
            renderCanvas();
        });
        root.appendChild(hours);
        root.appendChild(el("p", "psla-hint", tr("dayHint") + state.jiraHoursPerDay));
        root.appendChild(fieldLabel(tr("week")));
        var days = el("input");
        days.type = "number";
        days.min = "0";
        days.max = "7";
        days.value = state.layout.daysPerWeek || 0;
        days.addEventListener("input", function () {
            var value = parseInt(days.value, 10);
            state.layout.daysPerWeek = isNaN(value) ? 0 : value;
            markDirty();
            renderCanvas();
        });
        root.appendChild(days);
        root.appendChild(el("p", "psla-hint", tr("selectors")));
        var i;
        for (i = 0; i < ZONE_ORDER.length; i++) {
            if (ZONE_ORDER[i] === "custom" || ZONE_ORDER[i] === "my-requests" || ZONE_ORDER[i] === "header" || ZONE_ORDER[i] === "request-footer" || ZONE_ORDER[i] === "portal-panel") {
                continue;
            }
            selectorEditor(root, ZONE_ORDER[i]);
        }
    }

    function selectorEditor(root, zoneId) {
        root.appendChild(fieldLabel(tr("zones")[zoneId]));
        var area = el("textarea");
        area.rows = 3;
        var current = state.layout.selectors && state.layout.selectors[zoneId] ? state.layout.selectors[zoneId] : [];
        area.value = current.join("\n");
        area.addEventListener("input", function () {
            if (!state.layout.selectors) {
                state.layout.selectors = {};
            }
            var lines = area.value.split("\n");
            var clean = [];
            var n;
            for (n = 0; n < lines.length; n++) {
                if (lines[n].trim()) {
                    clean.push(lines[n].trim());
                }
            }
            if (clean.length) {
                state.layout.selectors[zoneId] = clean;
            } else {
                delete state.layout.selectors[zoneId];
            }
            markDirty();
        });
        root.appendChild(area);
        var known = api.zone(zoneId);
        var defaults = known && known.selectors ? known.selectors.join(", ") : tr("none");
        root.appendChild(el("p", "psla-hint", tr("defaults") + defaults));
    }

    function renderPresets() {
        var bar = document.getElementById("psla-presets");
        bar.innerHTML = "";
        var names = ["paused", "running", "risk", "breached", "done"];
        var i;
        for (i = 0; i < names.length; i++) {
            (function (name) {
                var button = el("button", state.preset === name && !state.live ? "is-on" : "", tr("presets")[name]);
                button.type = "button";
                button.addEventListener("click", function () {
                    state.preset = name;
                    state.live = null;
                    renderPresets();
                    renderCanvas();
                });
                bar.appendChild(button);
            })(names[i]);
        }
    }

    function shell() {
        var root = document.getElementById("psla-editor");
        root.innerHTML = "";
        var app = el("div", "psla-app");
        var top = el("header", "psla-top");
        var brand = el("div", "psla-brand");
        var back = el("a", "psla-back", tr("projects"));
        back.href = (document.body.getAttribute("data-base") || "") + "/plugins/servlet/portal-sla/editor";
        if (state.mock) {
            back.hidden = true;
        }
        brand.appendChild(back);
        brand.appendChild(el("strong", null, tr("title")));
        brand.appendChild(el("span", "psla-kicker", state.projectName + " · " + state.projectKey));
        top.appendChild(brand);

        var toggle = el("label", "psla-switch");
        var enabled = el("input");
        enabled.type = "checkbox";
        enabled.checked = !!state.layout.enabled;
        enabled.addEventListener("change", function () {
            state.layout.enabled = enabled.checked;
            markDirty();
            renderCanvas();
        });
        toggle.appendChild(enabled);
        toggle.appendChild(document.createTextNode(tr("show")));
        top.appendChild(toggle);

        var actions = el("div", "psla-top-actions");
        var reset = el("button", null, tr("reset"));
        reset.type = "button";
        reset.addEventListener("click", function () {
            if (!window.confirm(tr("confirmReset"))) {
                return;
            }
            state.layout = copy(state.factory);
            state.selectedId = state.layout.blocks.length ? state.layout.blocks[0].id : null;
            state.live = null;
            state.warning = "";
            markDirty();
            shell();
        });
        var save = el("button", "psla-primary", tr("save"));
        save.type = "button";
        save.id = "psla-save";
        save.addEventListener("click", saveLayout);
        actions.appendChild(reset);
        actions.appendChild(save);
        top.appendChild(actions);
        app.appendChild(top);
        var banner = el("div", "psla-banner");
        banner.id = "psla-banner";
        app.appendChild(banner);
        var toastNode = el("div", "psla-toast");
        toastNode.id = "psla-toast";
        toastNode.hidden = true;
        app.appendChild(toastNode);

        var workspace = el("div", "psla-workspace");
        var palette = el("aside", "psla-palette");
        palette.id = "psla-palette";
        workspace.appendChild(palette);
        var stage = el("div");
        var bar = el("div", "psla-stage-bar");
        bar.appendChild(el("h2", null, tr("canvas")));
        var presets = el("div", "psla-presets");
        presets.id = "psla-presets";
        bar.appendChild(presets);
        var issue = el("input");
        issue.type = "text";
        issue.placeholder = tr("issue");
        issue.id = "psla-issue-key";
        var apply = el("button", null, tr("applyIssue"));
        apply.type = "button";
        apply.addEventListener("click", loadIssue);
        var issueRow = el("div", "psla-issue-row");
        issueRow.appendChild(issue);
        issueRow.appendChild(apply);
        bar.appendChild(issueRow);
        stage.appendChild(bar);
        var canvas = el("div");
        canvas.id = "psla-canvas";
        stage.appendChild(canvas);
        var advanced = el("details", "psla-advanced");
        advanced.id = "psla-advanced";
        stage.appendChild(advanced);
        workspace.appendChild(stage);
        var inspector = el("aside", "psla-inspector");
        inspector.id = "psla-inspector";
        workspace.appendChild(inspector);
        app.appendChild(workspace);
        root.appendChild(app);

        renderBanner();
        renderPalette();
        renderPresets();
        renderCanvas();
        renderInspector();
        renderAdvanced();
    }

    function saveLayout() {
        var button = document.getElementById("psla-save");
        button.disabled = true;
        button.textContent = tr("saving");
        var payload = JSON.stringify(state.layout);
        if (state.mock) {
            try {
                window.localStorage.setItem("psla-preview-layout", payload);
            } catch (ignore) {
                /* ignore */
            }
            state.dirty = false;
            button.disabled = false;
            button.textContent = tr("save");
            toast(tr("savedLocal"));
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
                var text = result.body && result.body.error ? explain(result.body.error) : tr("errors")["invalid-layout"];
                if (messages.length) {
                    text = messages.map(explain).join(" ");
                }
                state.error = text;
                renderBanner();
                return;
            }
            state.layout = result.body.layout;
            state.catalog = result.body.catalog || state.catalog;
            state.warning = result.body.warning || "";
            state.dirty = false;
            state.error = "";
            renderBanner();
            renderCanvas();
            renderInspector();
            toast(tr("saved"));
        }).catch(function () {
            button.disabled = false;
            button.textContent = tr("save");
            state.error = tr("errors")["invalid-json"];
            renderBanner();
        });
    }

    function loadIssue() {
        var input = document.getElementById("psla-issue-key");
        var key = input.value.replace(/\s+/g, "");
        if (!key || state.mock) {
            state.live = null;
            renderPresets();
            renderCanvas();
            if (state.mock && key) {
                toast(tr("mockIssue"));
            }
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
                renderBanner();
                return;
            }
            state.live = result.body;
            state.error = "";
            renderBanner();
            renderPresets();
            renderCanvas();
        }).catch(function () {
            state.error = tr("errors")["not-found"];
            renderBanner();
        });
    }

    function load() {
        var body = document.body;
        state.mock = body.getAttribute("data-mock") === "true";
        state.locale = body.getAttribute("data-locale") || (navigator.language || "ru");
        state.projectKey = body.getAttribute("data-project-key") || "SD";
        state.projectName = body.getAttribute("data-project-name") || "Service Desk";
        state.rest = body.getAttribute("data-rest") || "";
        if (state.mock) {
            var saved = null;
            try {
                saved = window.localStorage.getItem("psla-preview-layout");
            } catch (ignore) {
                saved = null;
            }
            return window.fetch(body.getAttribute("data-layout-url")).then(function (response) {
                return response.json();
            }).then(function (factory) {
                state.factory = factory;
                state.layout = saved ? JSON.parse(saved) : copy(factory);
                state.catalog = sampleCatalog();
                state.selectedId = state.layout.blocks && state.layout.blocks.length ? state.layout.blocks[0].id : null;
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
            state.factory = copy(result.body.layout);
            state.catalog = result.body.catalog || [];
            state.jiraHoursPerDay = result.body.jiraHoursPerDay || 8;
            state.jiraDaysPerWeek = result.body.jiraDaysPerWeek || 5;
            state.warning = result.body.warning || "";
            if (result.body.projectName) {
                state.projectName = result.body.projectName;
            }
            state.selectedId = state.layout.blocks && state.layout.blocks.length ? state.layout.blocks[0].id : null;
            return window.fetch((body.getAttribute("data-base") || "") + "/download/resources/com.portalsla.portal-sla:portal-sla-editor/default-layout.json").then(function (response) {
                if (!response.ok) {
                    return null;
                }
                return response.json();
            }).then(function (factory) {
                if (factory) {
                    state.factory = factory;
                }
            }).catch(function () {
                /* Reset falls back to the layout that was loaded. */
            });
        });
    }

    window.addEventListener("beforeunload", function (event) {
        if (!state.dirty) {
            return;
        }
        event.preventDefault();
        event.returnValue = "";
    });

    function boot() {
        load().then(shell).catch(function (error) {
            var root = document.getElementById("psla-editor");
            root.textContent = error && error.message ? error.message : "Portal SLA";
        });
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", boot);
    } else {
        boot();
    }
})(window, document);
