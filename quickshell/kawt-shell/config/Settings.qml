pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent user settings, stored as JSON in ~/.local/state/kawt/settings.json
Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/kawt`
    property bool loaded: false // the file is read (or there was none): what's here is yours

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
    property alias screenshotAsk: adapter.screenshotAsk
    property alias screenshotFreeze: adapter.screenshotFreeze
    property alias wifiStyle: adapter.wifiStyle
    property alias wallPalette: adapter.wallPalette
    property alias wallStrength: adapter.wallStrength
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
    property alias aiMode: adapter.aiMode
    property alias aiCoderSteps: adapter.aiCoderSteps
    property alias aiVisionModel: adapter.aiVisionModel
    property alias aiTodo: adapter.aiTodo
    property alias aiVoiceModel: adapter.aiVoiceModel
    property alias aiVoiceSend: adapter.aiVoiceSend
    property alias aiRun: adapter.aiRun
    property alias aiSandbox: adapter.aiSandbox
    property alias aiSandboxImage: adapter.aiSandboxImage
    property alias aiRunSecs: adapter.aiRunSecs
    property alias recordAudio: adapter.recordAudio
    property alias recordSound: adapter.recordSound
    property alias mediaPlayer: adapter.mediaPlayer
    property alias playerNetCovers: adapter.playerNetCovers
    property alias ollamaUrl: adapter.ollamaUrl
    property alias ollamaModel: adapter.ollamaModel
    property alias device: adapter.device
    property alias dnd: adapter.dnd
    property alias lockDetails: adapter.lockDetails
    property alias lockOnSleep: adapter.lockOnSleep
    property alias idleLock: adapter.idleLock
    property alias screenOff: adapter.screenOff
    property alias dimBeforeLock: adapter.dimBeforeLock
    property alias nightLight: adapter.nightLight
    property alias nightTemp: adapter.nightTemp
    property alias terminal: adapter.terminal
    property alias wallpaper: adapter.wallpaper
    property alias wallpaperDir: adapter.wallpaperDir
    property alias wallpaperEvery: adapter.wallpaperEvery
    property alias wallpaperOrder: adapter.wallpaperOrder
    property alias wallpaperTransition: adapter.wallpaperTransition
    property alias wallDither: adapter.wallDither
    property alias themeTerminals: adapter.themeTerminals
    property alias fetchLogo: adapter.fetchLogo
    property alias fontFamily: adapter.fontFamily
    property alias fontSize: adapter.fontSize
    property alias brackets: adapter.brackets
    property alias crt: adapter.crt
    property alias bootScreen: adapter.bootScreen
    property alias lite: adapter.lite
    property alias scanlines: adapter.scanlines
    property alias barHeight: adapter.barHeight
    property alias barBottom: adapter.barBottom
    property alias barHide: adapter.barHide
    property alias floatClasses: adapter.floatClasses
    property alias barHidden: adapter.barHidden
    property alias layoutPerWindow: adapter.layoutPerWindow
    property alias companion: adapter.companion
    property alias companionMode: adapter.companionMode
    property alias companionAsks: adapter.companionAsks
    property alias companionSkin: adapter.companionSkin
    property alias companionName: adapter.companionName
    property alias companionLang: adapter.companionLang
    property alias companionQuotes: adapter.companionQuotes
    property alias welcomed: adapter.welcomed
    property alias updateAuto: adapter.updateAuto
    property alias updateCheckedAt: adapter.updateCheckedAt
    property alias updateNotified: adapter.updateNotified
    property alias lookVersion: adapter.lookVersion

    // kawt's look changed: thinkpad black and red, ibm plex mono. Settings still at the old
    // look's standard (theme mono, jetbrains mono) come along once; a theme or a font you picked
    // yourself stays. Your own colors, fonts and themes are never touched
    // Then the themes became two: thinkpad (black or white) and wallpaper (mono, amber and
    // phosphor went: a theme that isn't there any more shows as thinkpad, config/Colors.qml), and
    // the wallpaper theme is the thinkpad's with the wallpaper's color as its light ("calm", the
    // new standard)
    function newLook(): void {
        if (lookVersion >= 3)
            return;
        if (lookVersion < 2 && theme === "mono")
            theme = "thinkpad";
        if (lookVersion < 2 && fontFamily === "JetBrainsMono Nerd Font Mono")
            fontFamily = "BlexMono Nerd Font Mono";
        if (wallStrength === "strong")
            wallStrength = "calm";
        lookVersion = 3;
    }

    // "~/x" -> "/home/user/x"
    function expand(path: string): string {
        return path.startsWith("~/") ? Quickshell.env("HOME") + path.slice(1) : path;
    }

    // a bar button the user hasn't switched off (profile -> cfg -> bar); names: Bar.qml
    function barShows(name: string): bool {
        return !(barHide ?? []).includes(name);
    }

    function toggleBar(name: string): void {
        barHide = barShows(name) ? [...(barHide ?? []), name] : barHide.filter(n => n !== name);
    }

    FileView {
        path: `${root.dir}/settings.json`
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            root.newLook();
            root.loaded = true;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
            root.newLook();
            root.loaded = true;
        }

        JsonAdapter {
            id: adapter

            property string theme: "thinkpad"
            property bool light: false // light (paper) variant of the theme
            property string termColors: "soft" // terminal colors: "crt" | "soft" | "vivid" (utils/themegen.js)
            property bool clock24: true
            property bool clockSeconds: false
            property bool clockDate: false // weekday and date in the bar clock
            property int timeOffset: 0 // minutes the shell clock runs ahead (+) or behind (-) the system clock
            property string motto: "stay curious" // profile header line; "fortune" = a new one each time, "" = none
            property string profileArt: "auto" // "auto": ~/.face as ascii if it exists, "machine": always the thinkpad/pc
            property string screenshotDir: "~/Pictures/screenshots"
            property bool screenshotAsk: true // a preview in the corner asks: copy / save (services/Screenshot.qml); false = saved and copied at once
            property bool screenshotFreeze: true // the screen stands still while an area is picked (needs hyprpicker)
            property string wifiStyle: "name" // the bar's wifi button: "name" | "bars" (signal only) | "hidden" (the net graph opens wifi)
            property var wallPalette: ({}) // the wallpaper, analysed: { source, version, hue, sat, colorful, hues } (utils/wallpalette.js)
            property string wallStrength: "calm" // how much of the wallpaper's color the wallpaper theme takes: "calm" (only its light) | "strong" | "full"
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
            property string aiMode: "chat" // "chat" | "coder" (services/Coder.qml)
            property int aiCoderSteps: 15 // the coder stops after this many steps; 0 = never
            property string aiVoiceModel: "base" // whisper.cpp model for speaking to the ai: "tiny" | "base" | "small"
            property bool aiVoiceSend: false // what you said is sent at once, instead of into the input
            property bool aiTodo: false // your open tasks go along with every chat question ([x] tasks)
            property string aiVisionModel: "" // ollama: the model that gets pictures (a screenshot's [ask]); "" = the chat's
            property bool aiRun: true // the coder may ask to run commands (each one waits for [run]), in a sandbox
            property string aiSandbox: "bwrap" // "bwrap" (bubblewrap) | "podman" (with aiSandboxImage)
            property string aiSandboxImage: "" // podman: an image you pulled yourself (kawt never pulls one)
            property int aiRunSecs: 120 // a command is stopped after this long
            property bool recordAudio: false // record the microphone too (older kawt; recordSound wins when set)
            property string recordSound: "" // "off" | "mic" | "system" (what you hear) | "both"; "" = recordAudio decides
            property string mediaPlayer: "" // the player picked in the player popover's tabs (services/Media.qml)
            property bool playerNetCovers: false // covers that are online (spotify's): fetched only with this on
            property string ollamaUrl: "http://localhost:11434"
            property string ollamaModel: "llama3.2"
            property string device: "auto" // auto | laptop | desktop
            property bool dnd: false // do not disturb: no notification toasts
            property bool lockDetails: true // the lock screen shows the next task, what's playing, the wifi name, messages and user@host (anyone at the screen sees them)
            property bool lockOnSleep: true // lock before the machine sleeps and on `loginctl lock-session` (services/Session.qml)
            property int idleLock: 10 // lock after this many minutes without input, 0 = never (services/Idle.qml)
            property int screenOff: 1 // the picture off this many minutes after the lock, 0 = never (only the picture: the rest keeps running)
            property bool dimBeforeLock: true // the backlight down to a third 30 s before the idle lock
            property bool nightLight: false // warmer colors through hyprsunset (services/Night.qml)
            property int nightTemp: 4500 // night light color temperature, kelvin
            property string terminal: "kitty" // command is appended; for alacritty use "alacritty -e"
            property string wallpaper: "" // empty: kawt draws no wallpaper (use hyprpaper/swww)
            property string wallpaperDir: "~/Pictures/wallpapers"
            property int wallpaperEvery: 0 // minutes until the next one comes by itself, 0 = never (services/Wallpapers.qml)
            property string wallpaperOrder: "next" // "next" (the folder's order) | "random"
            property string wallpaperTransition: "crt" // with awww: "crt" | "fade" | "grow" | "random" | "none" (scripts/wallpaper.sh)
            property bool wallDither: true // the wallpaper in the theme's few tones, dithered like an old screen (scripts/dither.sh); off: the picture as it is
            property bool themeTerminals: true // recolor open terminals on theme change
            property string fetchLogo: "distro" // fastfetch's logo: "distro" (your system's, in the theme's colors) | "kawt" | "trackpoint" | "stripes" (utils/themegen.js)
            // the look, yours without editing the repo (config/Metrics.qml reads these)
            property string fontFamily: "BlexMono Nerd Font Mono" // a monospace one: kawt lines text up in columns (BlexMono = ibm plex mono)
            property int fontSize: 13 // px; panels grow with it
            property bool brackets: true // [ ] around what you can press; off: plain words, the chosen ones in the accent color
            property bool crt: true // the lock (and the boot screen) switch on and off like an old picture tube (components/CrtTube.qml)
            property bool bootScreen: true // a bios-like check list once at login, any key skips it (modules/boot)
            property bool lite: false // an old machine (a t60, an x200): no blur, shadows or animations in hyprland, graphs half as often, no visualizer
            property bool scanlines: false // faint dark lines over the whole screen, like an old tube's (modules/background/Scanlines.qml)
            property int barHeight: 0 // px, 0 = fits the font
            property bool barBottom: false // the bar at the bottom edge instead of the top
            property bool barHidden: false // tucked away: a 2 px edge, the pointer there brings it out (kawt bar, super+shift+b)
            property var barHide: [] // bar buttons switched off: "profile", "dock", "workspaces", "title", "vpn", "wifi", "net", "clock", "player", "tray", "kb", "bt", "mic", "vol", "br", "bat", "log", "home", "ai"
            property var floatClasses: [] // window classes that float at their own size (profile -> cfg -> windows)
            property bool layoutPerWindow: false // each window keeps its own keyboard layout; new ones start with the first (services/Keyboard.qml)
            // the companion (services/Companion.qml): his house is [⌂] in the bar
            property bool companion: true // off: no house, no walks, no peeks
            property string companionMode: "auto" // "home" | "walk" (an empty desktop is his) | "auto" (he decides)
            property bool companionAsks: true // asks for food and play in a notification, 3 a day at most
            property string companionSkin: "floppy" // utils/companions.js, or yours in ~/.config/kawt/companions.json
            property string companionName: "" // "" = the look's own
            property string companionLang: "en" // "en" | "ru": what he says
            property bool companionQuotes: true // wise words now and then on a click (fortune-mod's too, in english)
            property bool welcomed: false // the first start's hello and short tour was shown (modules/companion/WelcomePopover.qml)
            // kawt's own updates (services/Update.qml): [check] asks github once
            property bool updateAuto: true // and once a week by itself (one git fetch); off: only [check]
            property real updateCheckedAt: 0 // ms, the last check that got an answer
            property string updateNotified: "" // the upstream commit the last notification was about
            property int lookVersion: 0 // which of kawt's looks the settings were last brought up to (newLook)
        }
    }
}
