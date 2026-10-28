pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.utils

// App search for the launcher. Ranks by how well the name matches, plus how often
// each app was launched (counts saved in ~/.local/state/kawt/launcher.json).
// An app's own actions ("New Private Window" in firefox) are found by their names too.
Singleton {
    id: root

    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay)

    readonly property list<string> systemCategories: ["Settings", "System", "Monitor", "ConsoleOnly", "PackageManager", "HardwareSettings"]

    // settings panels, system tools and terminal programs (volume control, network editor,
    // htop...): hidden from the empty list, still found by searching, just ranked lower
    function isSystem(app: var): bool {
        const cats = app.categories ?? [];
        if (cats.includes("TerminalEmulator"))
            return false;
        return app.runInTerminal || cats.some(c => systemCategories.includes(c));
    }

    // The same keys in the other layout, for text typed with the wrong one on: "ашкуащч" (the
    // russian layout on) -> "firefox", and back: "ntvbyfk" -> "терминал". Ukrainian і ї є ґ
    // count as their russian neighbours. "" if nothing changes (no letter of either)
    readonly property string keysEn: "`qwertyuiop[]asdfghjkl;'zxcvbnm,."
    readonly property string keysRu: "ёйцукенгшщзхъфывапролджэячсмитьбю"
    readonly property var keysUa: ({ "і": "s", "ї": "]", "є": "'", "ґ": "`" })

    function otherLayout(text: string): string {
        let out = "";
        let changed = false;
        for (const c of text) {
            let i = keysRu.indexOf(c);
            let o = i >= 0 ? keysEn[i] : keysUa[c];
            if (o === undefined) {
                i = keysEn.indexOf(c);
                o = i >= 0 ? keysRu[i] : c;
            }
            changed = changed || o !== c;
            out += o;
        }
        return changed ? out : "";
    }

    // the actions of the apps (.desktop [Desktop Action] parts), as launcher entries:
    // { name: "Firefox: New Private Window", icon, app, action, isAction }
    function actionsOf(app: var): var {
        return (app?.actions ?? []).map(act => ({
            name: `${app.name}: ${act.name}`,
            icon: act.icon || app.icon,
            id: `${app.id}:${act.id}`,
            genericName: "",
            comment: "",
            keywords: [],
            categories: app.categories,
            runInTerminal: app.runInTerminal,
            app: app,
            action: act,
            isAction: true
        }));
    }
    readonly property var actions: apps.reduce((out, a) => out.concat(actionsOf(a)), [])

    function search(query: string): var {
        const q = query.trim().toLowerCase();
        // typed in the other layout: found too, a little below what matches as typed
        const alt = otherLayout(q);
        // actions only once something is typed, and below the apps themselves
        return (q ? apps.concat(actions) : apps.filter(a => !isSystem(a)))
            .map(a => ({ app: a, score: q ? Math.max(match(a, q), alt ? match(a, alt) - 5 : 0) - (a.isAction ? 10 : 0) : 1 }))
            .filter(r => r.score > 0)
            .map(r => ({ app: r.app, score: r.score + Math.min(20, (adapter.counts[r.app.id] ?? 0) * 2) - (isSystem(r.app) ? 25 : 0) }))
            .sort((x, y) => y.score - x.score || x.app.name.localeCompare(y.app.name))
            .map(r => r.app);
    }

    function match(app: var, q: string): int {
        const name = app.name.toLowerCase();
        if (name === q)
            return 100;
        if (name.startsWith(q))
            return 80;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            return 60;
        if (name.includes(q))
            return 50;
        const extra = [app.genericName, app.id, app.comment, ...(app.keywords ?? [])].join(" ").toLowerCase();
        if (extra.includes(q))
            return 30;
        // letters in order: "ffx" -> firefox
        let i = 0;
        for (const c of name)
            if (c === q[i])
                i++;
        return i === q.length ? 10 : 0;
    }

    // the typed letters marked in an app's name, as StyledText for the launcher:
    // "fire" in "Firefox" -> <b><font color=..>Fire</font></b>fox; letters in order ("ffx") too
    function highlight(name: string, query: string, color: string): string {
        const lower = name.toLowerCase();
        // the letters of q in name: as one piece, or in order; null if they aren't there
        const hits = q => {
            const hit = new Array(name.length).fill(false);
            const at = lower.indexOf(q);
            if (at >= 0) {
                for (let i = at; i < at + q.length; i++)
                    hit[i] = true;
                return hit;
            }
            let j = 0;
            for (let i = 0; i < name.length && j < q.length; i++) {
                if (lower[i] === q[j]) {
                    hit[i] = true;
                    j++;
                }
            }
            return j === q.length ? hit : null;
        };
        const q = query.trim().toLowerCase();
        const alt = q ? otherLayout(q) : "";
        const hit = (q ? hits(q) ?? (alt ? hits(alt) : null) : null) ?? new Array(name.length).fill(false);
        const esc = c => c === "&" ? "&amp;" : c === "<" ? "&lt;" : c === ">" ? "&gt;" : c;
        let out = "", on = false;
        for (let i = 0; i < name.length; i++) {
            if (hit[i] !== on) {
                out += hit[i] ? `<b><font color="${color}">` : "</font></b>";
                on = hit[i];
            }
            out += esc(name[i]);
        }
        return out + (on ? "</font></b>" : "");
    }

    readonly property var pinned: adapter.pinned.map(id => apps.find(a => a.id === id)).filter(a => a)

    function isPinned(app: var): bool {
        return adapter.pinned.includes(app?.id);
    }

    function togglePin(app: var): void {
        if (app?.isAction)
            return;
        adapter.pinned = isPinned(app) ? adapter.pinned.filter(id => id !== app.id) : [...adapter.pinned, app.id];
    }

    // ---- apps started without internet (ctrl+o in the launcher, [offline] in the wifi panel's
    // [who's out]): in a network of their own with nothing in it, unshare's, as the same user
    // (no root, no sandbox otherwise: files, sound, the screen as always). Only what kawt starts:
    // the launcher, the dock (an app started another way has the internet as usual). One that's
    // already running gets a new window from the running one, internet and all: it has to be
    // closed first
    readonly property list<string> offline: adapter.offline

    function isOffline(app: var): bool {
        return adapter.offline.includes(app?.isAction ? app.app?.id : app?.id);
    }

    function setOffline(id: string, on: bool): void {
        if (id && on !== adapter.offline.includes(id))
            adapter.offline = on ? [...adapter.offline, id] : adapter.offline.filter(i => i !== id);
    }

    function nameOf(id: string): string {
        return apps.find(a => a.id === id)?.name ?? id;
    }

    // a kernel without user namespaces for everyone (linux-hardened) can't do it: then the app
    // isn't started at all (rather than with the internet after all), and a message says why
    readonly property list<string> noNet: ["sh", "-c", 'unshare --net --map-current-user true 2> /dev/null || { notify-send -a kawt "not started" "$1: this system cannot start an app without internet (user namespaces are off)"; exit 1; }; exec unshare --net --map-current-user -- "$@"', "sh"]

    function launch(app: var): void {
        adapter.counts = Object.assign({}, adapter.counts, { [app.id]: (adapter.counts[app.id] ?? 0) + 1 });
        const off = isOffline(app);
        if (app.isAction) {
            if (typeof app.action.execute === "function" && !off)
                app.action.execute();
            else
                Quickshell.execDetached(off ? [...noNet, ...app.action.command] : app.action.command);
        } else if (app.runInTerminal)
            Quickshell.execDetached({
                command: [...terminalCmd(), ...(off ? noNet : []), ...app.command],
                workingDirectory: app.workingDirectory
            });
        else if (off)
            Quickshell.execDetached({
                command: [...noNet, ...app.command],
                workingDirectory: app.workingDirectory
            });
        else
            app.execute();
    }

    // `!cmd` in the launcher
    function run(cmd: string): void {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    // `>cmd` in the launcher: run in a terminal that stays open afterwards
    function runInTerminal(cmd: string): void {
        Quickshell.execDetached([...terminalCmd(), "sh", "-c", `${cmd}; exec "\${SHELL:-sh}"`]);
    }

    function terminalCmd(): list<string> {
        return Settings.terminal.split(/\s+/).filter(s => s);
    }

    // ---- `=` with qalc (package libqalculate): units, currencies, dates, percentages too
    //   =10 km/h to m/s   =100 usd to eur   =today + 3 weeks   =20% of 150   =sqrt(2)^2
    // In its own config dir, never told to update exchange rates: it uses the ones it has
    // (qalc -e downloads them, that goes online). A sum the plain calculator below can do comes
    // from it at once; qalc answers the rest a moment after typing stops.
    // It runs while you type, before any enter, so what reaches outside qalc never gets to it:
    // command() runs a program, plot() starts gnuplot, export / load / save write and read
    // files, and those take their names in quotes. A leading "-" would read as an option
    property bool hasQalc: false
    property string qalcAsked: ""
    property string qalcFor: "" // the expression qalcOut answers
    property string qalcOut: ""

    Process {
        running: true
        command: ["sh", "-c", "command -v qalc"]
        stdout: StdioCollector {
            onStreamFinished: root.hasQalc = text.trim() !== ""
        }
    }

    function qalc(expr: string): void {
        if (!hasQalc || expr === qalcAsked)
            return;
        qalcAsked = expr;
        qalcWait.restart();
    }

    Timer {
        id: qalcWait

        interval: 150
        onTriggered: {
            if (qalcJob.running) {
                restart();
                return;
            }
            if (!root.qalcAsked || /["'`]|\b(command|plot|export|load|save)\b/i.test(root.qalcAsked)) {
                root.qalcFor = root.qalcAsked;
                root.qalcOut = "";
                return;
            }
            qalcJob.expr = root.qalcAsked;
            qalcJob.command = ["env", `XDG_CONFIG_HOME=${Settings.dir}/qalc`, "qalc", "-t", "-s", "upxrates 0", " " + root.qalcAsked];
            qalcJob.running = true;
            qalcLimit.restart();
        }
    }

    // a sum that takes too long (10000!) is let go
    Timer {
        id: qalcLimit

        interval: 2000
        onTriggered: qalcJob.running = false
    }

    Job {
        id: qalcJob

        property string expr: ""

        onDone: (code, out) => {
            qalcLimit.stop();
            // the last line is the answer; "error: ..." and an echo of what was typed aren't
            const line = out.trim().split("\n").pop()?.trim() ?? "";
            const same = line.replace(/\s+/g, "") === expr.replace(/\s+/g, "");
            root.qalcFor = expr;
            root.qalcOut = code === 0 && line && !same && !/^(error|warning):/i.test(line) ? line : "";
        }
    }

    // `=2*(3+4)` in the launcher. Only digits and operators get through to eval.
    function calc(expr: string): string {
        expr = expr.replace(/\^/g, "**").replace(/,/g, ".");
        if (!/^[\d\s.+\-*\/%()]+$/.test(expr))
            return "";
        try {
            const v = Function(`"use strict"; return (${expr});`)();
            return typeof v === "number" && isFinite(v) ? String(Math.round(v * 1e10) / 1e10) : "";
        } catch (e) {
            return "";
        }
    }

    FileView {
        path: `${Settings.dir}/launcher.json`
        printErrors: false // missing on first run, created below
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property var counts: ({}) // desktop entry id -> launches
            property var pinned: [] // desktop entry ids, in dock order
            property var offline: [] // desktop entry ids started without internet
        }
    }
}
