import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services
import qs.utils
import "../popovers"

ColumnLayout {
    required property var profile

    spacing: Metrics.spacing
    Component.onCompleted: Ai.refresh()

    // pages, so it isn't one long list: look · screen · media · device · windows · kawt
    Tabs {
        id: cfgPages

        Layout.topMargin: Metrics.spacing
        tabs: ["look", "screen", "media", "device", "windows", "kawt"]
    }

    // ------------------------------------------------------------ page: look (font, the bar, the profile's header)
    ColumnLayout {
        Layout.fillWidth: true
        visible: cfgPages.current === 0
        spacing: Metrics.spacing

        RowLayout {
            Layout.topMargin: Metrics.spacing
            spacing: Metrics.spacing

            Label {
                text: `theme: ${Colors.fullName}`
                color: Colors.dim
            }

            BracketButton {
                label: "wallpaper & themes"
                textColor: Colors.accent
                onClicked: Panels.toggle("style", profile.forScreen)
            }
        }

        // ------------------------------------------------------------ look
        //  font  [-] 13px [+] [plex] [jetbrains]   font> BlexMono Nerd Font Mono
        //  brackets  [on] [off]
        // (in settings.json, not in the repo: a git pull never takes it back)
        Label {
            Layout.topMargin: Metrics.spacing
            text: "look"
            color: Colors.dim
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            Label {
                text: "font:"
                color: Colors.dim
            }

            BracketButton {
                label: "-"
                bordered: false
                onClicked: Settings.fontSize = Math.max(9, Metrics.fontSize - 1)
            }

            Label {
                text: `${Metrics.fontSize}px`
            }

            BracketButton {
                label: "+"
                bordered: false
                onClicked: Settings.fontSize = Math.min(28, Metrics.fontSize + 1)
            }

            // the two kawt knows, the ones installed (ibm plex mono is kawt's own)
            Repeater {
                model: [["BlexMono Nerd Font Mono", "plex"], ["JetBrainsMono Nerd Font Mono", "jetbrains"]].filter(f => Metrics.installed.includes(f[0]))

                BracketButton {
                    required property var modelData

                    label: modelData[1]
                    textColor: Metrics.fontFamily === modelData[0] ? Colors.accent : Colors.dim
                    onClicked: Settings.fontFamily = modelData[0]
                }
            }

            // a monospace one: kawt lines its text up in columns
            TermInput {
                Layout.fillWidth: true
                prompt: "font>"
                text: Settings.fontFamily
                placeholder: "a monospace font, as fc-list calls it"
                onAccepted: t => Settings.fontFamily = t.trim() || "BlexMono Nerd Font Mono"
            }
        }

        // [ ] around what you can press, or plain words (the chosen ones in the accent color)
        RowLayout {
            spacing: Metrics.spacing

            Label {
                text: "brackets:"
                color: Colors.dim
            }

            Repeater {
                model: [[true, "on"], [false, "off"]]

                BracketButton {
                    required property var modelData

                    label: modelData[1]
                    textColor: Settings.brackets === modelData[0] ? Colors.accent : Colors.dim
                    onClicked: Settings.brackets = modelData[0]
                }
            }

            Label {
                text: Settings.brackets ? "around what you can press, red: chosen" : "plain words, the chosen ones in color"
                color: Colors.dim
            }
        }

        // the old picture tube: the lock switches on and off like one; the check list at login
        Flow {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            BracketButton {
                tag: Settings.crt ? "x" : " "
                label: "crt: the lock switches on and off like an old tube"
                onClicked: Settings.crt = !Settings.crt
            }

            BracketButton {
                tag: Settings.bootScreen ? "x" : " "
                label: "boot screen: a bios-like check list at login (any key skips)"
                onClicked: Settings.bootScreen = !Settings.bootScreen
            }

            BracketButton {
                tag: Settings.scanlines ? "x" : " "
                label: "scanlines: faint lines over the screen (screenshots get them too)"
                onClicked: Settings.scanlines = !Settings.scanlines
            }

            // a t60, an x200: what costs the most goes
            BracketButton {
                tag: Settings.lite ? "x" : " "
                label: "old machine: no blur, shadows or animations, graphs half as often, no visualizer"
                onClicked: Settings.lite = !Settings.lite
            }
        }

        Label {
            Layout.topMargin: Metrics.spacing
            text: "bar"
            color: Colors.dim
        }

        // wifi button: [name] bars hidden
        RowLayout {
            spacing: Metrics.spacing

            Label {
                text: "wifi:"
                color: Colors.dim
            }

            Repeater {
                model: [["name", "name"], ["bars", "▂▄▆_"], ["hidden", "hidden (click the graph)"]]

                BracketButton {
                    required property var modelData

                    label: modelData[1]
                    active: Settings.wifiStyle === modelData[0]
                    textColor: Settings.wifiStyle === modelData[0] ? Colors.accent : Colors.dim
                    onClicked: Settings.wifiStyle = modelData[0]
                }
            }
        }

        // tucked away: a 2 px edge that takes no room, the pointer there brings it out
        BracketButton {
            tag: Settings.barHidden ? "x" : " "
            label: "tucked away: out when the pointer touches the edge (super+shift+b)"
            bordered: false
            onClicked: Settings.barHidden = !Settings.barHidden
        }

        //  at  [top] bottom   height  [-] auto [+]
        RowLayout {
            spacing: Metrics.spacing

            Label {
                text: "at:"
                color: Colors.dim
            }

            BracketButton {
                label: "top"
                active: !Settings.barBottom
                textColor: !Settings.barBottom ? Colors.accent : Colors.dim
                onClicked: Settings.barBottom = false
            }

            BracketButton {
                label: "bottom"
                active: Settings.barBottom
                textColor: Settings.barBottom ? Colors.accent : Colors.dim
                onClicked: Settings.barBottom = true
            }

            Label {
                Layout.leftMargin: Metrics.spacing
                text: "height:"
                color: Colors.dim
            }

            BracketButton {
                label: "-"
                bordered: false
                onClicked: Settings.barHeight = Math.max(Metrics.fontSize + 10, Metrics.barHeight - 2)
            }

            Label {
                text: Settings.barHeight > 0 ? `${Metrics.barHeight}px` : "auto"
            }

            BracketButton {
                label: "+"
                bordered: false
                onClicked: Settings.barHeight = Math.min(80, Metrics.barHeight + 2)
            }

            BracketButton {
                visible: Settings.barHeight > 0
                label: "auto"
                bordered: false
                textColor: Colors.dim
                onClicked: Settings.barHeight = 0
            }
        }

        //  [x ●]  [x $]  [x 1 2 3]  [x window title]  [x wifi] ...   which buttons the bar shows
        Flow {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            Repeater {
                model: [["profile", "●"], ["dock", "$"], ["workspaces", "1 2 3"], ["title", "window title"], ["wifi", "wifi"], ["net", "net"], ["vpn", "vpn"], ["clock", "clock"], ["player", "player"], ["tray", "tray"], ["kb", "kb"], ["bt", "bt"], ["mic", "mic"], ["vol", "vol"], ["br", "br"], ["bat", "bat"], ["log", "log"], ["home", "⌂"], ["ai", ">_"]]

                BracketButton {
                    required property var modelData

                    tag: Settings.barShows(modelData[0]) ? "x" : " "
                    label: modelData[1]
                    bordered: false
                    onClicked: Settings.toggleBar(modelData[0])
                }
            }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: "switched off, a button still works on its key (super + i: this panel). [● rec], [cast] and [caf] always show while they're on"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }

        // ------------------------------------------------------------ profile header
        Label {
            Layout.topMargin: Metrics.spacing
            text: "profile"
            color: Colors.dim
        }

        TermInput {
            Layout.fillWidth: true
            prompt: "motto>"
            text: Settings.motto
            placeholder: "a line under your name · fortune · empty = none"
            onAccepted: t => Settings.motto = t.trim()
        }

        RowLayout {
            spacing: Metrics.spacing

            Label {
                text: "picture:"
                color: Colors.dim
            }

            BracketButton {
                label: "~/.face as ascii"
                active: Settings.profileArt === "auto"
                textColor: Settings.profileArt === "auto" ? Colors.accent : Colors.dim
                onClicked: Settings.profileArt = "auto"
            }

            BracketButton {
                label: "machine"
                active: Settings.profileArt === "machine"
                textColor: Settings.profileArt === "machine" ? Colors.accent : Colors.dim
                onClicked: Settings.profileArt = "machine"
            }
        }
    }

    // ------------------------------------------------------------ page: screen (the lock, the screen going off, night light, the clock)
    ColumnLayout {
        Layout.fillWidth: true
        visible: cfgPages.current === 1
        spacing: Metrics.spacing

        // ------------------------------------------------------------- lock
        //  lock screen  [x] task, music, wifi   (anyone at the screen sees them)
        RowLayout {
            Layout.topMargin: Metrics.spacing
            spacing: Metrics.spacing

            Label {
                text: "lock screen"
                color: Colors.dim
            }

            BracketButton {
                tag: Settings.lockDetails ? "x" : " "
                label: "task, music, wifi" // and user@host, messages: LockSurface.qml
                bordered: false
                onClicked: Settings.lockDetails = !Settings.lockDetails
            }

            // services/Session.qml: the lid, systemctl suspend, loginctl lock-session
            BracketButton {
                visible: Session.available
                tag: Settings.lockOnSleep ? "x" : " "
                label: "before sleep"
                bordered: false
                onClicked: Settings.lockOnSleep = !Settings.lockOnSleep
            }
        }

        //  idle lock  off  5m  [10m]  30m  min> 15   (caf in the sys tab holds it off)
        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            Label {
                text: "idle lock"
                color: Colors.dim
            }

            Repeater {
                model: [[0, "off"], [5, "5m"], [10, "10m"], [30, "30m"]]

                BracketButton {
                    required property var modelData

                    label: modelData[1]
                    active: Settings.idleLock === modelData[0]
                    textColor: Settings.idleLock === modelData[0] ? Colors.accent : Colors.dim
                    bordered: false
                    onClicked: Settings.idleLock = modelData[0]
                }
            }

            // any other time, in minutes (0 = off)
            TermInput {
                id: idleInput

                readonly property bool custom: ![0, 5, 10, 30].includes(Settings.idleLock)

                Layout.fillWidth: true
                prompt: "min>"
                placeholder: custom ? `${Settings.idleLock}m (yours)` : "other"
                onAccepted: t => {
                    const m = parseInt(t);
                    if (/^\s*\d+\s*$/.test(t) && m <= 1440) {
                        Settings.idleLock = m;
                        idleInput.text = "";
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: text !== ""
            elide: Text.ElideRight
            text: Idle.caffeine ? "caf is on: no idle lock until it's off ([caf] in the sys tab)"
                : Settings.idleLock === 0 ? "the screen never locks by itself (only before sleep, if that's on)"
                : `locks after ${Settings.idleLock} min without input · a video or call holds it off`
            color: Idle.caffeine ? Colors.accent : Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }

        //  screen off  off  [1m]  2m  5m   (after the lock)   [x] dim before
        // only the picture goes: wifi, downloads, music keep running (services/Idle.qml)
        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            Label {
                text: "screen off"
                color: Colors.dim
            }

            Repeater {
                model: [[0, "off"], [1, "1m"], [2, "2m"], [5, "5m"]]

                BracketButton {
                    required property var modelData

                    label: modelData[1]
                    active: Settings.screenOff === modelData[0]
                    textColor: Settings.screenOff === modelData[0] ? Colors.accent : Colors.dim
                    bordered: false
                    onClicked: Settings.screenOff = modelData[0]
                }
            }

            // laptops: the backlight down to a third, 30 s before the idle lock
            BracketButton {
                visible: Brightness.available && Settings.idleLock > 0
                tag: Settings.dimBeforeLock ? "x" : " "
                label: "dim before"
                bordered: false
                onClicked: Settings.dimBeforeLock = !Settings.dimBeforeLock
            }
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Settings.screenOff > 0 ? `the picture goes ${Settings.screenOff} min after the lock; wifi, music, downloads keep going · a key brings it back` : "the screen stays on while locked"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }

        //  night light  [x] on   4500K  [-] [+]   (hyprsunset)
        RowLayout {
            visible: Night.available
            spacing: Metrics.spacing

            Label {
                text: "night light"
                color: Colors.dim
            }

            BracketButton {
                tag: Settings.nightLight ? "x" : " "
                label: "on"
                bordered: false
                onClicked: Settings.nightLight = !Settings.nightLight
            }

            Label {
                text: `${Night.temp}K`
                color: Settings.nightLight ? Colors.fg : Colors.dim
            }

            BracketButton {
                label: "warmer"
                bordered: false
                onClicked: Night.warmer()
            }

            BracketButton {
                label: "cooler"
                bordered: false
                onClicked: Night.cooler()
            }
        }

        // ------------------------------------------------------------ clock
        //  clock  [24h] 12h  [x] seconds  [ ] date
        //  time>  14:30 / +3h / -30m   [real time]
        Label {
            Layout.topMargin: Metrics.spacing
            text: "clock"
            color: Colors.dim
        }

        Flow {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            BracketButton {
                label: "24h"
                active: Settings.clock24
                textColor: Settings.clock24 ? Colors.accent : Colors.dim
                onClicked: Settings.clock24 = true
            }

            BracketButton {
                label: "12h"
                active: !Settings.clock24
                textColor: !Settings.clock24 ? Colors.accent : Colors.dim
                onClicked: Settings.clock24 = false
            }

            BracketButton {
                tag: Settings.clockSeconds ? "x" : " "
                label: "seconds"
                bordered: false
                onClicked: Settings.clockSeconds = !Settings.clockSeconds
            }

            BracketButton {
                tag: Settings.clockDate ? "x" : " "
                label: "date"
                bordered: false
                onClicked: Settings.clockDate = !Settings.clockDate
            }
        }

        // shell-only time: the system clock is never touched
        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            TermInput {
                id: clockInput

                property string error: ""

                Layout.fillWidth: true
                prompt: "time>"
                placeholder: "14:30 · 2:30pm · +3h · -30m  (only kawt's clock)"
                onAccepted: t => {
                    clockInput.error = Time.set(t);
                    if (!clockInput.error)
                        clockInput.text = "";
                }
            }

            BracketButton {
                visible: Time.offset !== 0
                label: "real time"
                onClicked: Time.reset()
            }
        }

        Label {
            Layout.fillWidth: true
            visible: text !== ""
            elide: Text.ElideRight
            text: clockInput.error !== "" ? clockInput.error
                : Time.offset !== 0 ? `kawt runs ${Time.offsetText} from the system clock (todo reminders too)` : ""
            color: clockInput.error !== "" ? Colors.warn : Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }
    }

    // ------------------------------------------------------------ page: media (screenshots, recordings, the player)
    ColumnLayout {
        Layout.fillWidth: true
        visible: cfgPages.current === 2
        spacing: Metrics.spacing

        Label {
            Layout.topMargin: Metrics.spacing
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: "screenshots  (print / super+shift+s: area · shift+print: screen · alt+print: window)"
            color: Colors.dim
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            TermInput {
                Layout.fillWidth: true
                prompt: "dir>"
                text: Settings.screenshotDir
                onAccepted: t => Settings.screenshotDir = t.trim() || Settings.screenshotDir
            }

            // on: a preview asks copy / save; off: saved and copied right away
            BracketButton {
                tag: Settings.screenshotAsk ? "x" : " "
                label: "ask"
                bordered: false
                onClicked: Settings.screenshotAsk = !Settings.screenshotAsk
            }

            // the screen stands still while an area is picked (hyprpicker)
            BracketButton {
                visible: Screenshot.canFreeze
                tag: Settings.screenshotFreeze ? "x" : " "
                label: "freeze"
                bordered: false
                onClicked: Settings.screenshotFreeze = !Settings.screenshotFreeze
            }
        }

        Label {
            Layout.topMargin: Metrics.spacing
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: "recordings  (super+shift+r area · super+alt+r screen · again: stop)"
            color: Colors.dim
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            TermInput {
                Layout.fillWidth: true
                prompt: "dir>"
                text: Settings.recordDir
                onAccepted: t => Settings.recordDir = t.trim() || Settings.recordDir
            }
        }

        //  sound  [off] mic  system  both    (system: what you hear; both: mixed)
        RowLayout {
            spacing: Metrics.spacing

            Label {
                text: "sound:"
                color: Colors.dim
            }

            Repeater {
                model: [["off", "off"], ["mic", "mic"], ["system", "what you hear"], ["both", "both"]]

                BracketButton {
                    required property var modelData

                    label: modelData[1]
                    active: Recorder.sound === modelData[0]
                    textColor: Recorder.sound === modelData[0] ? Colors.accent : Colors.dim
                    bordered: false
                    onClicked: Settings.recordSound = modelData[0]
                }
            }
        }

        Label {
            Layout.topMargin: Metrics.spacing
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: "player  (the music button in the bar; the media keys follow its tabs)"
            color: Colors.dim
        }

        // spotify's covers are on its servers; the local ones (firefox, mpv) always show
        BracketButton {
            tag: Settings.playerNetCovers ? "x" : " "
            label: "covers from the net (spotify's)"
            bordered: false
            onClicked: Settings.playerNetCovers = !Settings.playerNetCovers
        }
    }

    // ------------------------------------------------------------ page: device (keyboard, laptop or desktop)
    ColumnLayout {
        Layout.fillWidth: true
        visible: cfgPages.current === 3
        spacing: Metrics.spacing

        // ------------------------------------------------------------ keyboard
        //  keyboard  [x] a layout per window   (us, ru: alt + shift)
        RowLayout {
            Layout.topMargin: Metrics.spacing
            visible: Keyboard.count > 1
            spacing: Metrics.spacing

            Label {
                text: "keyboard"
                color: Colors.dim
            }

            // services/Keyboard.qml: leaving a window remembers its layout, coming back puts it back
            BracketButton {
                tag: Settings.layoutPerWindow ? "x" : " "
                label: "a layout per window"
                bordered: false
                onClicked: Settings.layoutPerWindow = !Settings.layoutPerWindow
            }
        }

        Label {
            Layout.fillWidth: true
            visible: Keyboard.count > 1
            elide: Text.ElideRight
            text: Settings.layoutPerWindow ? "each window keeps its own layout; a new one starts with the first" : "one layout for all windows"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }

        Label {
            Layout.topMargin: Metrics.spacing
            text: "device"
            color: Colors.dim
        }

        Flow {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            Repeater {
                model: ["auto", "laptop", "desktop"]

                BracketButton {
                    required property string modelData

                    label: modelData === "auto" ? `auto: ${SysInfo.detectedLaptop ? "laptop" : "desktop"}` : modelData
                    active: Settings.device === modelData
                    onClicked: Settings.device = modelData
                }
            }
        }
    }

    // ------------------------------------------------------------ page: windows
    ColumnLayout {
        Layout.fillWidth: true
        visible: cfgPages.current === 4
        spacing: Metrics.spacing

        //  find> fire
        //  [x] firefox          Mozilla Firefox
        //  [ ] kitty            ~/kawt
        // a picked app floats from the start, in the middle, at the size it asks for
        // (services/Hypr.qml writes the list, hypr/kawt.lua makes the rules)
        Label {
            Layout.topMargin: Metrics.spacing
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: "windows at their own size: a picked app floats from the start, in the middle, at the size it asks for instead of stretched by the layout. open ones change now; from then on, every time it opens"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }

        Label {
            Layout.fillWidth: true
            visible: !Hypr.lua
            wrapMode: Text.Wrap
            text: "[!] this needs a hyprland.lua: an old hyprland.conf can't load kawt's list"
            color: Colors.warn
        }

        TermInput {
            id: winFind

            Layout.fillWidth: true
            prompt: "find>"
            placeholder: "an app's name or its window's title"
        }

        ColumnLayout {
            id: winApps

            // each app once: the open ones (from hyprland), then the picked ones not open now
            readonly property var apps: {
                const seen = {}, out = [], q = winFind.text.trim().toLowerCase();
                for (const w of Hypr.windows) {
                    const c = Hypr.classOf(w);
                    if (c && !seen[c]) {
                        seen[c] = true;
                        out.push({ cls: c, title: w.title ?? "" });
                    }
                }
                for (const c of Hypr.floating)
                    if (!seen[c])
                        out.push({ cls: c, title: "(not open now)" });
                return out.filter(a => !q || `${a.cls} ${a.title}`.toLowerCase().includes(q));
            }

            Layout.fillWidth: true
            spacing: 0
            Component.onCompleted: Hypr.refreshWindows()

            Repeater {
                model: winApps.apps

                RowLayout {
                    id: winRow

                    required property var modelData
                    readonly property bool on: Hypr.floating.includes(modelData.cls)

                    Layout.fillWidth: true
                    spacing: Metrics.spacing

                    BracketButton {
                        tag: winRow.on ? "x" : " "
                        label: winRow.modelData.cls
                        textColor: winRow.on ? Colors.accent : Colors.fg
                        bordered: false
                        onClicked: Hypr.setFloating(winRow.modelData.cls, !winRow.on)
                    }

                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: winRow.modelData.title
                        color: Colors.dim
                    }
                }
            }

            Label {
                visible: winApps.apps.length === 0
                text: winFind.text ? "-- no match --" : "-- no windows open --"
                color: Colors.dim
            }
        }

        BracketButton {
            label: "look again"
            onClicked: Hypr.refreshWindows()
        }
    }

    // ------------------------------------------------------------ page: kawt (updates, the companion, help)
    ColumnLayout {
        Layout.fillWidth: true
        visible: cfgPages.current === 5
        spacing: Metrics.spacing

        // ------------------------------------------------------------ kawt
        //  kawt  2b47871 · 3 days ago            [check] [update 3]
        //  3 new: notifications keep -t...
        //  [x] look for updates once a week by itself (git fetch)
        Label {
            Layout.topMargin: Metrics.spacing
            text: "kawt"
            color: Colors.dim
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Update.repo ? `${Update.repo.replace(Quickshell.env("HOME"), "~")} · ${Update.version}` : "not a git clone: no updates from here"
                color: Colors.dim
            }

            // asks the remote once: nothing else of kawt's goes out by itself
            BracketButton {
                visible: Update.repo !== ""
                label: Update.checking ? "..." : "check"
                onClicked: Update.check(false)
            }

            // a terminal with ./install.sh --update: it shows what's new and asks first
            BracketButton {
                visible: Update.repo !== ""
                label: Update.behind > 0 ? `update ${Update.behind}` : "update"
                textColor: Update.behind > 0 ? Colors.accent : Colors.fg
                onClicked: {
                    Update.run();
                    Panels.close();
                }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: text !== ""
            elide: Text.ElideRight
            text: Update.status + (Update.news ? `: ${Update.news}` : "")
            color: Update.status.startsWith("couldn't") ? Colors.warn : Update.behind > 0 ? Colors.accent : Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }

        // one small request to github a week; off: nothing goes out unless [check] is pressed
        BracketButton {
            visible: Update.repo !== ""
            tag: Settings.updateAuto ? "x" : " "
            label: "look for updates once a week by itself (git fetch)"
            bordered: false
            onClicked: Settings.updateAuto = !Settings.updateAuto
        }

        // the ai has its own settings now, in its panel
        RowLayout {
            Layout.topMargin: Metrics.spacing
            spacing: Metrics.spacing

            Label {
                text: `ai: ${Ai.useApi ? "api" : "ollama"} · ${Ai.modelName}`
                color: Colors.dim
            }

            BracketButton {
                label: "ai settings"
                textColor: Colors.accent
                onClicked: {
                    Panels.sidebarScreen = profile.forScreen?.name ?? Panels.focusedScreen;
                    Panels.sidebarOpen = true;
                    Panels.aiTab = 3;
                    Panels.close();
                }
            }
        }

        // the companion: on / off here, the rest in his house
        RowLayout {
            Layout.topMargin: Metrics.spacing
            spacing: Metrics.spacing

            BracketButton {
                tag: Settings.companion ? "x" : " "
                label: Settings.companion ? `companion: ${Companion.name}` : "companion"
                bordered: false
                onClicked: Settings.companion = !Settings.companion
            }

            BracketButton {
                visible: Settings.companion
                label: "his house"
                textColor: Colors.accent
                onClicked: Panels.toggle("home", profile.forScreen ?? Quickshell.screens[0])
            }

            // the first start's hello and short tour, again
            BracketButton {
                label: "tour"
                onClicked: Panels.toggle("welcome", profile.forScreen ?? Quickshell.screens[0])
            }
        }

        Label {
            Layout.topMargin: Metrics.spacing
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: "[?] all keys: super + /"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: "[?] in the ai panel: /model <name>, /models"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }
    }
}
