import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import "../popovers"
import "../sidebar"
import "../notifs"
import "../launcher"
import "../style"
import "../background"
import "../osd"
import "../profile"
import "../power"
import "../help"
import "../shot"
import "../companion"

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: root

        required property ShellScreen modelData
        screen: modelData

        implicitHeight: tucked ? 2 : Metrics.barHeight
        color: "transparent"

        WlrLayershell.namespace: "kawt-bar"

        // tucked away (kawt bar, super+shift+b, or profile -> cfg): a 2 px edge that takes no
        // room from the windows. The pointer at that edge brings the bar out over them; it goes
        // again half a second after the pointer leaves, unless one of its panels is open
        property bool peeking: false
        readonly property bool tucked: Settings.barHidden && !peeking
        readonly property bool panelOpen: Panels.current !== "" && Panels.screen === modelData.name
        readonly property bool focusedHere: modelData.name === Panels.focusedScreen
        // no window on this screen's workspace (nor a scratchpad over it): the companion may walk.
        // Not while he's in his house or next to the coder: he's there then
        readonly property HyprlandMonitor hyprMonitor: Hyprland.monitorFor(modelData)
        readonly property bool emptyDesk: (hyprMonitor?.activeWorkspace?.toplevels?.values?.length ?? 1) === 0 && !(hyprMonitor?.lastIpcObject?.specialWorkspace?.name)
        readonly property bool companionOut: focusedHere && emptyDesk && Companion.onDesk && Panels.current !== "home" && !(Panels.sidebarOpen && Settings.aiMode === "coder")

        WlrLayershell.exclusionMode: Settings.barHidden ? ExclusionMode.Ignore : ExclusionMode.Auto
        onPanelOpenChanged: if (!panelOpen && !edge.hovered)
            leave.restart()

        HoverHandler {
            id: edge

            onHoveredChanged: {
                if (hovered) {
                    leave.stop();
                    root.peeking = true;
                } else {
                    leave.restart();
                }
            }
        }

        Timer {
            id: leave

            interval: 500
            onTriggered: root.peeking = edge.hovered || root.panelOpen
        }

        Connections {
            target: Settings

            function onBarHiddenChanged(): void {
                root.peeking = false;
            }
        }

        // the top edge, or the bottom one (profile -> cfg -> bar). Every button can be switched
        // off there too: Settings.barShows(name), with the names used below
        anchors.top: !Metrics.barBottom
        anchors.bottom: Metrics.barBottom
        anchors.left: true
        anchors.right: true

        // one strip across the screen in the theme's background, a line along its inner edge
        // (the buttons on it have no frames of their own: their brackets say what's pressable)
        Rectangle {
            anchors.fill: parent
            visible: !root.tucked
            color: Colors.bg

            Rectangle {
                width: parent.width
                height: Metrics.borderWidth
                y: Metrics.barBottom ? 0 : parent.height - height
                color: Colors.border
            }
        }

        // left: profile, pinned apps, workspaces
        RowLayout {
            opacity: root.tucked ? 0 : 1
            anchors.left: parent.left
            anchors.leftMargin: Metrics.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Metrics.spacing

            // [●] the lit dot on the lid: you, your settings
            BracketButton {
                id: profile
                visible: Settings.barShows("profile")
                label: "●"
                ink: Colors.accent
                active: Panels.isOpen("profile", root.modelData)
                onClicked: Panels.toggle("profile", root.modelData)
            }

            BracketButton {
                id: dock
                visible: Settings.barShows("dock")
                label: "$"
                active: Panels.isOpen("dock", root.modelData)
                onClicked: Panels.toggle("dock", root.modelData)
            }

            Workspaces {
                visible: Settings.barShows("workspaces")
                screen: root.modelData
            }

            BarSep {
                visible: title.visible
            }

            // the window you're in, dim: something to read, not to press (on the screen with the
            // focus; "desktop" when its workspace is empty)
            Label {
                id: title

                readonly property string shownTitle: root.emptyDesk ? "desktop" : (Hyprland.activeToplevel?.title ?? "")

                visible: Settings.barShows("title") && root.focusedHere && shownTitle !== ""
                Layout.maximumWidth: Math.round(root.width * 0.22)
                text: shownTitle
                color: Colors.dim
                elide: Text.ElideRight
            }
        }

        // the companion's house, then the network, up to the clock
        RowLayout {
            opacity: root.tucked ? 0 : 1
            anchors.right: clock.left
            anchors.rightMargin: Metrics.sectionGap
            anchors.verticalCenter: parent.verticalCenter
            spacing: Metrics.spacing

            // the companion's house (modules/companion)
            HouseButton {
                id: home
                active: Panels.isOpen("home", root.modelData)
                onClicked: Panels.toggle("home", root.modelData)
            }

            // while a tunnel (wireguard, openvpn, tailscale...) is up; which one: in the wifi panel
            BracketButton {
                visible: NetLinks.vpn !== "" && Settings.barShows("vpn")
                label: "vpn"
                textColor: Colors.accent
                active: Panels.isOpen("wifi", root.modelData)
                onClicked: Panels.toggle("wifi", root.modelData)
            }

            WifiButton {
                id: wifi
                active: Panels.isOpen("wifi", root.modelData)
                onClicked: Panels.toggle("wifi", root.modelData)
            }

            NetGraph {
                id: netGraph
                visible: Settings.barShows("net")
                active: Panels.isOpen("wifi", root.modelData)
                onClicked: Panels.toggle("wifi", root.modelData)
            }
        }

        ClockButton {
            id: clock
            visible: Settings.barShows("clock")
            opacity: root.tucked ? 0 : 1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            active: Panels.isOpen("calendar", root.modelData)
            onClicked: Panels.toggle("calendar", root.modelData)
        }

        // media follows the clock
        PlayerButton {
            id: player
            opacity: root.tucked ? 0 : 1
            anchors.left: clock.right
            anchors.leftMargin: Metrics.sectionGap
            anchors.verticalCenter: parent.verticalCenter
            active: Panels.isOpen("player", root.modelData)
            onClicked: Panels.toggle("player", root.modelData)
        }

        // right: tray, input/output, power, messages, ai
        RowLayout {
            opacity: root.tucked ? 0 : 1
            anchors.right: parent.right
            anchors.rightMargin: Metrics.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Metrics.spacing

            RecButton {}

            VoiceButton {}

            CastButton {}

            CafButton {}

            Tray {
                id: tray
                active: Panels.isOpen("tray", root.modelData)
                onClicked: Panels.toggle("tray", root.modelData)
            }

            KbButton {}

            BarSep {}

            BtButton {
                id: bluetooth
                active: Panels.isOpen("bluetooth", root.modelData)
                onClicked: Panels.toggle("bluetooth", root.modelData)
            }

            MicButton {
                id: mic
                active: Panels.isOpen("mic", root.modelData)
                onClicked: Panels.toggle("mic", root.modelData)
            }

            VolumeButton {
                id: volume
                visible: Settings.barShows("vol")
                active: Panels.isOpen("volume", root.modelData)
                onClicked: Panels.toggle("volume", root.modelData)
            }

            BrightnessButton {
                id: brightness
                active: Panels.isOpen("brightness", root.modelData)
                onClicked: Panels.toggle("brightness", root.modelData)
            }

            BatteryButton {
                id: battery
                active: Panels.isOpen("battery", root.modelData)
                onClicked: Panels.toggle("battery", root.modelData)
            }

            BarSep {}

            NotifButton {
                id: notifs
                visible: Settings.barShows("log")
                active: Panels.isOpen("notifs", root.modelData)
                onClicked: Panels.toggle("notifs", root.modelData)
            }

            BracketButton {
                visible: Settings.barShows("ai")
                label: ">_"
                active: Panels.isSidebarOpen(root.modelData)
                onClicked: Panels.toggleSidebar(root.modelData)
            }
        }

        // only when kawt draws the wallpaper itself: the image inside would otherwise be decoded
        // at screen size (8 MB at 1080p, 33 MB at 4K, per screen) even with awww drawing it
        Lazy {
            when: Wallpapers.backend === "kawt" && Settings.wallpaper !== ""

            Wallpaper {
                forScreen: root.modelData
            }
        }

        // the faint lines of an old tube over everything (cfg -> look -> scanlines)
        Lazy {
            when: Settings.scanlines

            Scanlines {
                forScreen: root.modelData
            }
        }

        // Panels are created when opened and destroyed when closed (components/Lazy.qml):
        // a hidden window would keep all its items in memory, on every screen.
        Lazy {
            when: Panels.isOpen("profile", root.modelData)

            ProfilePopover {
                forScreen: root.modelData
                anchorItem: profile
                barWindow: root
            }
        }

        Lazy {
            when: Panels.isOpen("dock", root.modelData)

            DockPopover {
                forScreen: root.modelData
                anchorItem: dock
                barWindow: root
            }
        }

        Lazy {
            when: Panels.isOpen("calendar", root.modelData)

            CalendarPopover {
                forScreen: root.modelData
                anchorItem: clock
                barWindow: root
            }
        }

        Lazy {
            when: Panels.isOpen("player", root.modelData)

            PlayerPopover {
                forScreen: root.modelData
                anchorItem: player
                barWindow: root
            }
        }

        Lazy {
            when: Panels.isOpen("wifi", root.modelData)

            WifiPopover {
                forScreen: root.modelData
                // with the wifi button hidden, the panel opens under the net graph
                anchorItem: wifi.visible ? wifi : netGraph
                barWindow: root
            }
        }

        Lazy {
            when: Panels.isOpen("volume", root.modelData)

            VolumePopover {
                forScreen: root.modelData
                anchorItem: volume
                barWindow: root
            }
        }

        Lazy {
            when: Panels.isOpen("brightness", root.modelData)

            BrightnessPopover {
                forScreen: root.modelData
                anchorItem: brightness
                barWindow: root
            }
        }

        Lazy {
            when: Panels.isOpen("mic", root.modelData)

            MicPopover {
                forScreen: root.modelData
                anchorItem: mic
                barWindow: root
            }
        }

        Lazy {
            when: Panels.isOpen("bluetooth", root.modelData)

            BluetoothPopover {
                forScreen: root.modelData
                anchorItem: bluetooth
                barWindow: root
            }
        }

        Lazy {
            when: Panels.isOpen("battery", root.modelData)

            BatteryPopover {
                forScreen: root.modelData
                anchorItem: battery
                barWindow: root
            }
        }

        Lazy {
            when: Panels.isOpen("notifs", root.modelData)

            NotifsPopover {
                forScreen: root.modelData
                anchorItem: notifs
                barWindow: root
            }
        }

        Lazy {
            when: Panels.isOpen("tray", root.modelData)

            TrayPopover {
                forScreen: root.modelData
                anchorItem: tray
                barWindow: root
            }
        }

        Lazy {
            when: Panels.isOpen("home", root.modelData)

            HousePopover {
                forScreen: root.modelData
                anchorItem: home
                barWindow: root
            }
        }

        // the first start's hello and tour (Panels opens it once)
        Lazy {
            when: Panels.isOpen("welcome", root.modelData)

            WelcomePopover {
                forScreen: root.modelData
                barWindow: root
            }
        }

        // the companion out on an empty desktop, and peeking from the corner when something
        // happens while he's nowhere on the screen (services/Companion.qml)
        Lazy {
            when: root.companionOut

            DeskWindow {
                forScreen: root.modelData
            }
        }

        Lazy {
            when: root.focusedHere && Companion.peeking && Companion.enabled
            linger: 300

            PeekWindow {
                forScreen: root.modelData
            }
        }

        // kept a moment after closing, for the slide out
        Lazy {
            when: Panels.isSidebarOpen(root.modelData)
            linger: 300

            AiSidebar {
                forScreen: root.modelData
            }
        }

        // super + alt + a: the ai on the text you marked (modules/sidebar/SelectionPopup.qml)
        Lazy {
            when: Panels.isOpen("selection", root.modelData)

            SelectionPopup {
                forScreen: root.modelData
            }
        }

        Lazy {
            when: Panels.isOpen("launcher", root.modelData)

            Launcher {
                forScreen: root.modelData
            }
        }

        Lazy {
            when: Panels.isOpen("style", root.modelData)

            StyleWindow {
                forScreen: root.modelData
            }
        }

        Lazy {
            when: Panels.isOpen("dashboard", root.modelData)

            Dashboard {
                forScreen: root.modelData
            }
        }

        Lazy {
            when: Panels.isOpen("power", root.modelData)

            PowerMenu {
                forScreen: root.modelData
            }
        }

        Lazy {
            when: Panels.isOpen("keys", root.modelData)

            KeysWindow {
                forScreen: root.modelData
            }
        }

        // only while there is something to show: otherwise every screen kept a toast stack and
        // an osd window around all the time (the osd lingers for its fade-out)
        Lazy {
            when: root.modelData.name === Panels.focusedScreen && Notifs.popups.length > 0 && !Panels.isOpen("notifs", root.modelData)

            Toasts {
                forScreen: root.modelData
            }
        }

        Lazy {
            when: root.modelData.name === Panels.focusedScreen && Osd.shown
            linger: 250

            OsdWindow {
                forScreen: root.modelData
            }
        }

        // a screenshot waiting for [copy] / [save] (services/Screenshot.qml)
        Lazy {
            when: root.modelData.name === Screenshot.screen && Screenshot.shot !== ""

            ShotPreview {
                forScreen: root.modelData
            }
        }
    }
}
