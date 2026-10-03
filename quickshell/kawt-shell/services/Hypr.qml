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

    FileView {
        path: `${root.configDir}/hyprland.lua`
        printErrors: false
        onLoaded: root.lua = true
        onLoadFailed: root.lua = false
    }
}
