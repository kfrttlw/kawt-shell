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

    // go to a window: through the wayland toplevel (switches the workspace too), or the dispatcher
    function focusWindow(t: var): void {
        if (t?.wayland) {
            t.wayland.activate();
            return;
        }
        const a = String(t?.address ?? "");
        if (!a)
            return;
        const addr = a.startsWith("0x") ? a : `0x${a}`;
        dispatch(`hl.dsp.focus({ window = "address:${addr}" })`, `focuswindow address:${addr}`);
    }

    // the special workspace (scratchpad) shown on a monitor: monitors' IPC data has it, and that
    // data is only sent on request, so ask again whenever it may have changed
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "activespecial")
                Hyprland.refreshMonitors();
        }
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
            const a = String(w.address ?? "");
            if (classOf(w) !== cls || !a)
                continue;
            const sel = `window = "address:${a.startsWith("0x") ? a : `0x${a}`}"`;
            dispatch(`hl.dsp.window.float({ action = "${on ? "on" : "off"}", ${sel} })`, "");
            if (on)
                dispatch(`hl.dsp.window.center({ ${sel} })`, "");
        }
    }

    // a class as a lua string holding the regex ^(class)$: regex signs escaped, then lua's
    function rule(cls: string): string {
        const escaped = cls.replace(/[.*+?^$|()[\]{}\\]/g, "\\$&");
        const re = "^(" + escaped + ")$";
        return '"' + re.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
    }

    function writeRules(): void {
        const lines = ["-- written by kawt (profile -> cfg -> windows): these float at their own size, in the middle", "return {"];
        // a class with a line break or a control sign can't be one: left out
        for (const c of floating)
            if (!/[\x00-\x1f]/.test(c))
                lines.push(`    ${rule(c)},`);
        lines.push("}", "");
        rulesJob.command = ["sh", "-c", 'mkdir -p "${1%/*}" && printf "%s" "$2" > "$1" && { hyprctl reload > /dev/null 2>&1; true; }', "sh", rulesPath, lines.join("\n")];
        rulesJob.running = true;
    }

    Process {
        id: rulesJob
    }

    FileView {
        path: `${root.configDir}/hyprland.lua`
        printErrors: false
        onLoaded: root.lua = true
        onLoadFailed: root.lua = false
    }
}
