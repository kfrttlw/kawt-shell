pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// App search for the launcher. Ranks by how well the name matches, plus how often
// each app was launched (counts saved in ~/.local/state/kawt/launcher.json).
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

    function search(query: string): var {
        const q = query.trim().toLowerCase();
        return apps.filter(a => q || !isSystem(a))
            .map(a => ({ app: a, score: q ? match(a, q) : 1 }))
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
        const q = query.trim().toLowerCase();
        const lower = name.toLowerCase();
        const hit = new Array(name.length).fill(false);
        if (q) {
            const at = lower.indexOf(q);
            if (at >= 0) {
                for (let i = at; i < at + q.length; i++)
                    hit[i] = true;
            } else {
                let j = 0;
                for (let i = 0; i < name.length && j < q.length; i++) {
                    if (lower[i] === q[j]) {
                        hit[i] = true;
                        j++;
                    }
                }
                if (j < q.length)
                    hit.fill(false);
            }
        }
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
        adapter.pinned = isPinned(app) ? adapter.pinned.filter(id => id !== app.id) : [...adapter.pinned, app.id];
    }

    function launch(app: var): void {
        adapter.counts = Object.assign({}, adapter.counts, { [app.id]: (adapter.counts[app.id] ?? 0) + 1 });
        if (app.runInTerminal)
            Quickshell.execDetached({
                command: [...terminalCmd(), ...app.command],
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
        }
    }
}
