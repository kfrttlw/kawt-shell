pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent user settings, stored as JSON in ~/.local/state/kawt/settings.json
Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/kawt`

    property alias theme: adapter.theme
    property alias light: adapter.light
    property alias ollamaUrl: adapter.ollamaUrl
    property alias ollamaModel: adapter.ollamaModel
    property alias device: adapter.device
    property alias dnd: adapter.dnd
    property alias terminal: adapter.terminal
    property alias wallpaper: adapter.wallpaper
    property alias wallpaperDir: adapter.wallpaperDir
    property alias themeTerminals: adapter.themeTerminals

    // "~/x" -> "/home/user/x"
    function expand(path: string): string {
        return path.startsWith("~/") ? Quickshell.env("HOME") + path.slice(1) : path;
    }

    FileView {
        path: `${root.dir}/settings.json`
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property string theme: "mono"
            property bool light: false // light (paper) variant of the theme
            property string ollamaUrl: "http://localhost:11434"
            property string ollamaModel: "llama3.2"
            property string device: "auto" // auto | laptop | desktop
            property bool dnd: false // do not disturb: no notification toasts
            property string terminal: "kitty" // command is appended; for alacritty use "alacritty -e"
            property string wallpaper: "" // empty: kawt draws no wallpaper (use hyprpaper/swww)
            property string wallpaperDir: "~/Pictures/wallpapers"
            property bool themeTerminals: true // recolor open terminals on theme change
        }
    }
}
