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
    property alias termColors: adapter.termColors
    property alias clock24: adapter.clock24
    property alias clockSeconds: adapter.clockSeconds
    property alias clockDate: adapter.clockDate
    property alias timeOffset: adapter.timeOffset
    property alias motto: adapter.motto
    property alias profileArt: adapter.profileArt
    property alias screenshotDir: adapter.screenshotDir
    property alias wifiStyle: adapter.wifiStyle
    property alias wallPalette: adapter.wallPalette
    property alias recordDir: adapter.recordDir
    property alias aiProvider: adapter.aiProvider
    property alias aiCtx: adapter.aiCtx
    property alias aiThreads: adapter.aiThreads
    property alias aiGpuLayers: adapter.aiGpuLayers
    property alias aiKeepAlive: adapter.aiKeepAlive
    property alias aiTemperature: adapter.aiTemperature
    property alias aiHistory: adapter.aiHistory
    property alias aiSystem: adapter.aiSystem
    property alias apiUrl: adapter.apiUrl
    property alias apiModel: adapter.apiModel
    property alias aiWide: adapter.aiWide
    property alias aiFolder: adapter.aiFolder
    property alias aiPersona: adapter.aiPersona
    property alias aiMaxAnswer: adapter.aiMaxAnswer
    property alias aiCompare: adapter.aiCompare
    property alias aiCompareModel: adapter.aiCompareModel
    property alias aiZoom: adapter.aiZoom
    property alias aiSide: adapter.aiSide
    property alias aiUserLabel: adapter.aiUserLabel
    property alias aiBotLabel: adapter.aiBotLabel
    property alias recordAudio: adapter.recordAudio
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
            property string termColors: "soft" // terminal colors: "soft" | "crt" (utils/themegen.js)
            property bool clock24: true
            property bool clockSeconds: false
            property bool clockDate: false // weekday and date in the bar clock
            property int timeOffset: 0 // minutes the shell clock runs ahead (+) or behind (-) the system clock
            property string motto: "stay curious" // profile header line; "fortune" = a new one each time, "" = none
            property string profileArt: "auto" // "auto": ~/.face as ascii if it exists, "machine": always the thinkpad/pc
            property string screenshotDir: "~/Pictures/screenshots"
            property string wifiStyle: "name" // the bar's wifi button: "name" | "bars" (signal only) | "hidden" (the net graph opens wifi)
            property var wallPalette: ({}) // the "wallpaper" theme: { source, dark, light } from utils/wallpalette.js
            property string recordDir: "~/Videos/recordings"
            // ai (services/Ai.qml): provider, and how much the local model may take
            property string aiProvider: "ollama" // "ollama" | "api"
            property int aiCtx: 4096 // context window (num_ctx): memory grows with it
            property int aiThreads: 0 // cpu threads for ollama, 0 = it decides
            property int aiGpuLayers: -1 // layers on the gpu, -1 = ollama decides, 0 = cpu only
            property string aiKeepAlive: "5m" // how long the model stays loaded after an answer; "0" = free at once
            property real aiTemperature: 0.7
            property int aiHistory: 20 // earlier messages sent along as context
            property string aiSystem: "Answer briefly and informatively. Get straight to the point, skip filler and repetition. Use a list or a code block only when it really helps. Answer in the language of the question." // system prompt
            property string apiUrl: "https://api.openai.com/v1" // any OpenAI-compatible service
            property string apiModel: "gpt-4o-mini"
            property bool aiWide: false // the ai panel opened wide, with the files column
            property string aiFolder: "" // the only folder the ai panel can attach files from
            property string aiPersona: "short" // Ai.personas; "custom" = aiSystem
            property int aiMaxAnswer: 2048 // longest answer in tokens (num_predict)
            property bool aiCompare: false // ask a second model the same question
            property string aiCompareModel: ""
            property int aiZoom: 0 // chat text size: ctrl + / ctrl - / ctrl 0 in the panel
            property string aiSide: "right" // "right" | "left"
            property string aiUserLabel: "you"
            property string aiBotLabel: "ai"
            property bool recordAudio: false // record the microphone too
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
