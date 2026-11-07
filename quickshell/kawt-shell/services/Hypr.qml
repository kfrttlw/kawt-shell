pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Hyprland 0.55+ with hyprland.lua evaluates `dispatch` arguments as Lua (hl.dsp.*);
// older / hyprlang setups want the classic "workspace 3" syntax. Pick by which config exists.
Singleton {
    id: root

    readonly property string configDir: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/hypr`
    property bool lua: false

    function dispatch(luaExpr: string, legacy: string): void {
        Hyprland.dispatch(lua ? luaExpr : legacy);
    }

    function focusWorkspace(id: int): void {
        dispatch(`hl.dsp.focus({ workspace = ${id} })`, `workspace ${id}`);
    }

    function exit(): void {
        dispatch("hl.dsp.exit()", "exit");
    }

    // open windows, for the launcher's window mode (";"); the class comes from IPC data that
    // Hyprland sends on request (refreshWindows)
    readonly property var windows: Hyprland.toplevels.values

    function refreshWindows(): void {
        Hyprland.refreshToplevels();
    }

    // go to a window: through the wayland toplevel (switches the workspace too), or the dispatcher.
    // One put away (minimized) comes back to its own desk first
    function focusWindow(t: var): void {
        if (isAway(t)) {
            restore(t, 0);
            return;
        }
        if (t?.wayland) {
            t.wayland.activate();
            return;
        }
        const a = addr(t);
        if (a)
            dispatch(`hl.dsp.focus({ ${sel(a)} })`, `focuswindow address:${a}`);
    }

    // the special workspace (scratchpad) shown on a monitor: monitors' IPC data has it, and that
    // data is only sent on request, so ask again whenever it may have changed
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "activespecial")
                Hyprland.refreshMonitors();
            else if (event.name === "openwindow")
                root.opened(event.data);
            else if (event.name === "movewindowv2")
                root.moved(event.data);
            else if (event.name === "closewindow")
                root.forget(root.norm(event.data));
            else if (event.name === "changefloatingmode")
                root.floatChanged(event.data);
            else if (event.name === "minimized")
                root.minimizeAsked(event.data);
        }
    }

    // "55d1c0a87e40" (events) or "0x55d1c0a87e40" (toplevels): one form, to compare and keep
    function norm(a: string): string {
        a = String(a ?? "");
        return !a || a.startsWith("0x") ? a : `0x${a}`;
    }

    function addr(t: var): string {
        return norm(t?.address);
    }

    function sel(a: string): string {
        return `window = "address:${a}"`;
    }

    function byAddress(a: string): var {
        return windows.find(t => addr(t) === a) ?? null;
    }

    function activeDesk(): int {
        return Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
    }

    // hyprland sends where windows are only on request: ask, then do fn with fresh data. There is
    // no word when the answer is in, so fn returns false while what it needs isn't there yet (a
    // new window not known), and it is asked again, a few times
    property var queued: []

    function afterRefresh(fn: var): void {
        queued = [...queued, { fn, left: 4 }];
        Hyprland.refreshToplevels();
        settle.restart();
    }

    Timer {
        id: settle

        interval: 250
        onTriggered: {
            const q = root.queued;
            root.queued = [];
            const again = q.filter(j => j.fn() === false && --j.left > 0);
            if (again.length) {
                root.queued = [...again, ...root.queued];
                Hyprland.refreshToplevels();
                settle.restart();
            }
        }
    }

    // the room a monitor leaves for windows, in layout pixels: without the bar (reserved) and
    // turned if the monitor is
    function roomOf(m: var): var {
        const o = m?.lastIpcObject ?? {};
        const scale = o.scale || m?.scale || 1;
        const turned = (o.transform ?? 0) % 2 === 1;
        const pw = o.width ?? m?.width ?? 1920, ph = o.height ?? m?.height ?? 1080;
        const r = o.reserved ?? [0, 0, 0, 0]; // left, top, right, bottom
        return {
            x: (o.x ?? m?.x ?? 0) + r[0],
            y: (o.y ?? m?.y ?? 0) + r[1],
            w: (turned ? ph : pw) / scale - r[0] - r[2],
            h: (turned ? pw : ph) / scale - r[1] - r[3]
        };
    }

    // ---- floating desks, like KDE (the bar's [tile] / [float], super + ctrl + v, the start
    // menu's desks): every window of such a desk floats, where you put it, at any size.
    // hypr/kawt.lua makes a rule for each desk in windows.lua, so a new window opens floating
    // there, wider than tall, in the middle, each next one a step down and right; one moved in
    // floats on its way (kawt, from hyprland's events), and when a desk switches, kawt floats
    // (or tiles again) the ones already on it. Lua configs only
    readonly property var floatDesks: lua ? Settings.floatDesks ?? [] : []
    // the windows floating for their desk (kawt floated them, or they opened on a floating desk):
    // only these go back to tiles on a tiled desk; an app you float yourself stays floating
    property var deskFloated: ({})
    property var desksAfterReload: [] // desks just switched to floating: their windows once hyprland has the new rules

    function deskFloats(id: int): bool {
        return floatDesks.includes(id);
    }

    function mark(a: string, on: bool): void {
        if (!a || !!deskFloated[a] === on)
            return;
        const m = Object.assign({}, deskFloated);
        if (on)
            m[a] = true;
        else
            delete m[a];
        deskFloated = m;
    }

    function setDeskFloating(id: int, on: bool): void {
        if (!lua || id < 1 || on === deskFloats(id))
            return;
        Settings.floatDesks = on ? [...floatDesks, id].sort((a, b) => a - b) : floatDesks.filter(d => d !== id);
        if (!on) {
            // tiles at once
            for (const w of windows) {
                const a = addr(w);
                if (w.workspace?.id === id && deskFloated[a]) {
                    mark(a, false);
                    dispatch(`hl.dsp.window.float({ action = "off", ${sel(a)} })`, "");
                }
            }
            writeRules();
            return;
        }
        // floating after the reload, whose rule floats the desk's windows itself: so the tiled
        // ones are marked first, while they still read as tiled
        afterRefresh(() => {
            for (const w of windows)
                if (w.workspace?.id === id && w.lastIpcObject?.floating === false && !isFloating(classOf(w)))
                    mark(addr(w), true);
            desksAfterReload = [...desksAfterReload, id];
            writeRules();
        });
    }

    function floatDesk(id: int): void {
        afterRefresh(() => {
            for (const w of windows) {
                const a = addr(w);
                if (w.workspace?.id === id && a && w.lastIpcObject?.floating === false && !isFloating(classOf(w))) {
                    mark(a, true);
                    dispatch(`hl.dsp.window.float({ action = "on", ${sel(a)} })`, "");
                }
            }
            // just floated, they'd all lie on top of each other
            cascade(id);
        });
    }

    // the marks live only while kawt runs: started again, every window floating on a floating
    // desk counts as the desk's (but for the classes that float anyway), so [tile] tiles it
    function markAgain(): void {
        afterRefresh(() => {
            if (!Settings.loaded || windows.some(w => w.lastIpcObject?.floating === undefined))
                return false;
            for (const w of windows)
                if (deskFloats(w.workspace?.id ?? 0) && w.lastIpcObject?.floating === true && !isFloating(classOf(w)))
                    mark(addr(w), true);
        });
    }

    onLuaChanged: {
        if (lua)
            markAgain();
    }

    // the size a window gets on a floating desk: wider than tall (16:10), as windows were on old
    // systems, under two thirds of the screen's width and 70% of its height
    function sizeIn(room: var): var {
        const w = Math.min(960, room.w * 0.62);
        return { w: Math.round(w), h: Math.round(Math.min(w * 0.625, room.h * 0.7)) };
    }

    // where the k-th window on a floating desk goes: the first in the middle, each next one a
    // step down and right, as old systems opened them; after five, the middle again
    // (hypr/kawt.lua steps the new ones the same way). x, y: a place on the whole layout, as
    // hyprctl's `at` gives it
    readonly property int step: 25

    function placeOf(room: var, size: var, k: int): point {
        const d = (k % 5) * step;
        return Qt.point(Math.round(room.x + (room.w - size.w) / 2 + d), Math.round(room.y + (room.h - size.h) / 2 + d));
    }

    function placeWindow(a: string, room: var, size: var, k: int): void {
        const p = placeOf(room, size, k);
        dispatch(`hl.dsp.window.resize({ ${sel(a)}, x = ${size.w}, y = ${size.h}, relative = false })`, "");
        dispatch(`hl.dsp.window.move({ ${sel(a)}, x = ${p.x}, y = ${p.y}, relative = false })`, "");
    }

    // how many windows the desk has besides this one
    function othersOn(id: int, t: var): int {
        return windows.filter(w => w !== t && w.workspace?.id === id).length;
    }

    // one window floats for its desk, at that size, a step past the others
    function floatOne(t: var): void {
        const a = addr(t), id = t?.workspace?.id ?? 0;
        const room = roomOf(t?.workspace?.monitor ?? t?.monitor);
        mark(a, true);
        dispatch(`hl.dsp.window.float({ action = "on", ${sel(a)} })`, "");
        placeWindow(a, room, sizeIn(room), othersOn(id, t));
    }

    // a floating desk grown messy: every window back on the screen at the one size, from the
    // middle down and right
    function cascade(id: int): void {
        if (!lua || id < 1)
            return;
        Hyprland.refreshMonitors();
        afterRefresh(() => {
            const room = roomOf(Hyprland.workspaces.values.find(w => w.id === id)?.monitor);
            // the floating ones (those kawt floated a moment ago may still read as tiled here)
            const wins = windows.filter(w => w.workspace?.id === id && (w.lastIpcObject?.floating === true || deskFloated[addr(w)]) && !w.lastIpcObject?.fullscreen && !w.lastIpcObject?.pinned);
            wins.forEach((w, k) => placeWindow(addr(w), room, sizeIn(room), k));
        });
    }

    // a window to another desk, staying where you are (the start menu's desks); it floats or
    // tiles there as that desk does (moved())
    function moveToDesk(t: var, id: int): void {
        const a = addr(t);
        if (!a || id < 1)
            return;
        dispatch(`hl.dsp.window.move({ ${sel(a)}, workspace = ${id}, follow = false })`, `movetoworkspacesilent ${id},address:${a}`);
    }

    // "openwindow>>ADDR,WSNAME,CLASS,TITLE": the rule floated it already and kawt.lua stepped it
    // past the others; whatever of that didn't take in this hyprland, kawt does now
    function opened(data: string): void {
        const p = data.split(","), a = norm(p[0]), id = parseInt(p[1]);
        if (!lua || !deskFloats(id) || isFloating(p[2] ?? ""))
            return;
        mark(a, true);
        afterRefresh(() => {
            const t = byAddress(a), o = t?.lastIpcObject ?? {};
            if (!t || o.floating === undefined)
                return false;
            const room = roomOf(t.workspace?.monitor ?? t.monitor), size = sizeIn(room), k = othersOn(id, t);
            const middle = placeOf(room, size, 0), at = o.at ?? [0, 0];
            if (o.floating === false)
                floatOne(t);
            else if (k % 5 > 0 && Math.abs(at[0] - middle.x) <= 2 && Math.abs(at[1] - middle.y) <= 2)
                placeWindow(a, room, size, k); // still in the middle: not stepped
        });
    }

    // "movewindowv2>>ADDR,WSID,WSNAME": in to a floating desk it floats, back to a tiled one the
    // ones that floated for their desk tile again. Put away (minimized) or back: nothing changes
    function moved(data: string): void {
        const p = data.split(","), a = norm(p[0]), id = parseInt(p[1]), name = p.slice(2).join(",");
        if (name === away)
            return;
        if (minimized[a] !== undefined)
            forgetAway(a);
        if (!lua || id < 1)
            return;
        if (deskFloats(id)) {
            afterRefresh(() => {
                const t = byAddress(a);
                if (t?.lastIpcObject?.floating === undefined)
                    return false;
                if (t.lastIpcObject.floating === false && !isFloating(classOf(t)))
                    floatOne(t);
            });
        } else if (deskFloated[a]) {
            mark(a, false);
            dispatch(`hl.dsp.window.float({ action = "off", ${sel(a)} })`, "");
        }
    }

    // "changefloatingmode>>ADDR,0": tiled, by kawt or by you (super + v): no longer the desk's
    function floatChanged(data: string): void {
        const p = data.split(",");
        if (p[1] === "0")
            mark(norm(p[0]), false);
    }

    function forget(a: string): void {
        mark(a, false);
        forgetAway(a);
    }

    // ---- windows put away (minimized): hyprland has no such thing, so kawt keeps them on a
    // special desk of its own that nothing shows, their buttons still in the bar
    // (modules/bar/Tasks.qml). A click there, or going to one from anywhere (the launcher's
    // windows), brings it back to its desk
    readonly property string away: "special:kawt-min"
    property var minimized: ({}) // address -> the desk it came from (none known: shown on every desk)

    function isAway(t: var): bool {
        return t?.workspace?.name === away;
    }

    // the desk a window put away came from; 0: not known (kawt started again since)
    function awayFrom(t: var): int {
        return minimized[addr(t)] ?? 0;
    }

    // the windows put away from a desk; from one kawt doesn't know: on every desk
    function awayOn(id: int): var {
        return Hyprland.toplevels.values.filter(t => isAway(t) && (awayFrom(t) || id) === id);
    }

    function minimize(t: var): void {
        const a = addr(t);
        if (!a || isAway(t))
            return;
        const from = t.workspace?.id ?? 0; // a special one (the scratchpad, < 0): not known
        minimized = Object.assign({}, minimized, { [a]: from > 0 ? from : 0 });
        dispatch(`hl.dsp.window.move({ ${sel(a)}, workspace = "${away}", follow = false })`, `movetoworkspacesilent ${away},address:${a}`);
    }

    // back to `id` (0: the desk it came from, or the one you're on), and in focus
    function restore(t: var, id: int): void {
        const a = addr(t);
        if (!a)
            return;
        const to = id > 0 ? id : awayFrom(t) || activeDesk();
        forgetAway(a);
        dispatch(`hl.dsp.window.move({ ${sel(a)}, workspace = ${to}, follow = false })`, `movetoworkspacesilent ${to},address:${a}`);
        dispatch(`hl.dsp.focus({ ${sel(a)} })`, `focuswindow address:${a}`);
    }

    function forgetAway(a: string): void {
        if (minimized[a] === undefined)
            return;
        const m = Object.assign({}, minimized);
        delete m[a];
        minimized = m;
    }

    // "minimized>>ADDR,1": an app's own _ button: put away, its taskbar button brings it back
    function minimizeAsked(data: string): void {
        const p = data.split(",");
        const t = byAddress(norm(p[0]));
        if (p[1] === "1" && t)
            minimize(t);
    }

    // ---- windows that float at their own size (profile -> cfg -> windows)
    // hypr/kawt.lua makes a rule for each class in windows.lua: floating from the start, in the
    // middle, at the size the app asks for instead of stretched by the layout. The file is
    // written again on every change and hyprland reads its config again. Lua configs only
    readonly property var floating: Settings.floatClasses ?? []
    readonly property string rulesPath: `${Settings.dir}/windows.lua`

    function classOf(w: var): string {
        return w?.lastIpcObject?.class ?? "";
    }

    function isFloating(cls: string): bool {
        return floating.includes(cls);
    }

    function setFloating(cls: string, on: bool): void {
        if (!cls || on === isFloating(cls))
            return;
        Settings.floatClasses = on ? [...floating, cls].sort() : floating.filter(c => c !== cls);
        writeRules();
        if (!lua)
            return;
        // the open ones change now too (their own size comes the next time they open)
        for (const w of windows) {
            const a = addr(w);
            if (classOf(w) !== cls || !a)
                continue;
            dispatch(`hl.dsp.window.float({ action = "${on ? "on" : "off"}", ${sel(a)} })`, "");
            if (on)
                dispatch(`hl.dsp.window.center({ ${sel(a)} })`, "");
        }
    }

    // a class as a lua string holding the regex ^(class)$: regex signs escaped, then lua's
    function rule(cls: string): string {
        const escaped = cls.replace(/[.*+?^$|()[\]{}\\]/g, "\\$&");
        const re = "^(" + escaped + ")$";
        return '"' + re.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
    }

    function writeRules(): void {
        if (rulesJob.running) {
            rulesAgain = true;
            return;
        }
        const lines = ["-- written by kawt (profile -> cfg -> windows): these float at their own size, in the middle", "return {"];
        // a class with a line break or a control sign can't be one: left out
        for (const c of floating)
            if (!/[\x00-\x1f]/.test(c))
                lines.push(`    ${rule(c)},`);
        // and the floating desks (the bar's [tile] / [float]), each with the size a new window
        // gets there (its screen's)
        const desks = floatDesks.filter(id => Number.isInteger(id) && id > 0).map(id => {
            const size = sizeIn(roomOf(Hyprland.workspaces.values.find(w => w.id === id)?.monitor ?? Hyprland.focusedMonitor));
            return `[${id}] = { ${size.w}, ${size.h} }`;
        });
        lines.push(`    desks = { ${desks.join(", ")} },`);
        lines.push("}", "");
        rulesJob.command = ["sh", "-c", 'mkdir -p "${1%/*}" && printf "%s" "$2" > "$1" && { hyprctl reload > /dev/null 2>&1; true; }', "sh", rulesPath, lines.join("\n")];
        rulesJob.running = true;
    }

    // asked while a write runs (a fast second toggle): once it ends, with what's wanted by then
    property bool rulesAgain: false

    Process {
        id: rulesJob

        onExited: {
            if (root.rulesAgain) {
                root.rulesAgain = false;
                root.writeRules();
                return;
            }
            const desks = root.desksAfterReload;
            root.desksAfterReload = [];
            for (const id of desks)
                if (root.deskFloats(id))
                    root.floatDesk(id);
        }
    }

    FileView {
        path: `${root.configDir}/hyprland.lua`
        printErrors: false
        onLoaded: root.lua = true
        onLoadFailed: root.lua = false
    }
}
