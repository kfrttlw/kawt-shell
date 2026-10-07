pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

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

    FileView {
        path: `${root.configDir}/hyprland.lua`
        printErrors: false
        onLoaded: root.lua = true
        onLoadFailed: root.lua = false
    }
}
