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
        // no window on this screen's workspace (nor a scratchpad over it): stripes may walk there.
        // Not while her window is open or she's next to the coder: she's there then
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

        // one strip across the screen, raised like an old taskbar: the buttons' face (unless the
        // theme gives the bar its own color), a light line on top, a dark one below
        Rectangle {
            anchors.fill: parent
            visible: !root.tucked
            color: Colors.palette.bar ?? Colors.face

            Rectangle {
                width: parent.width
                height: 1
                color: Colors.hi
            }

            Rectangle {
                y: parent.height - 2
                width: parent.width
                height: 1
                color: Colors.lo
            }

            Rectangle {
                y: parent.height - 1
                width: parent.width
                height: 1
                color: Colors.deep
            }
        }

        // left: the start button (programs, Today, the settings, shutting down), the pinned apps.
        // Every part can be switched off in the settings: Settings.barShows(name)
        Row {
            id: leftRow

            opacity: root.tucked ? 0 : 1
            anchors.left: parent.left
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            StartButton {
                id: start

                height: Metrics.barHeight - 6
                active: Panels.isOpen("menu", root.modelData)
                onClicked: Panels.toggle("menu", root.modelData)
            }

            // a narrow screen gives up the pinned apps first
            QuickLaunch {
                anchors.verticalCenter: parent.verticalCenter
                visible: Settings.barShows("quick") && Apps.pinned.length > 0 && root.width >= 1200
            }
        }

        // the windows of this desk: only the room between the start button and the desks, so
        // they never run over the tray (Tasks.qml steps down when they're many)
        Tasks {
            opacity: root.tucked ? 0 : 1
            screen: root.modelData
            anchors.left: leftRow.right
            anchors.leftMargin: 6
            anchors.right: deskSquares.visible ? deskSquares.left : trayWell.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
        }

        Workspaces {
            id: deskSquares

            visible: Settings.barShows("workspaces")
            opacity: root.tucked ? 0 : 1
            screen: root.modelData
            anchors.right: trayWell.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
        }

        // the tray, sunk in one well as old systems had it: the apps' icons behind a ‹, what
        // shows by itself while it's on (recording, the mic, a screen share, caffeine, vpn,
        // music, headphones), then network, sound, battery, messages, the layout, the clock.
        // Each says what it is under the pointer; a click opens its panel, pressed in while open
        Item {
            id: trayWell

            visible: !root.tucked
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: trayRow.implicitWidth + 6
            height: Metrics.barHeight - 6

            Bevel {
                style: "well"
            }

            Row {
                id: trayRow

                anchors.centerIn: parent
                spacing: 1

                Tray {
                    id: tray

                    active: Panels.isOpen("tray", root.modelData)
                    onClicked: Panels.toggle("tray", root.modelData)
                }

                // a groove after the apps' icons
                Rectangle {
                    visible: tray.visible
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: parent.height - 4
                    color: Colors.hi

                    Rectangle {
                        width: 1
                        height: parent.height
                        color: Colors.lo
                    }
                }

                RecButton {}

                VoiceButton {}

                CastButton {}

                CafButton {}

                // while a tunnel (wireguard, openvpn, tailscale...) is up; which one: in the network panel
                BarIcon {
                    visible: NetLinks.vpn !== "" && Settings.barShows("vpn")
                    icon: "shield"
                    tip: `${Strings.t("vpn")}: ${NetLinks.vpn}`
                    active: Panels.isOpen("wifi", root.modelData)
                    onClicked: Panels.toggle("wifi", root.modelData)
                }

                PlayerButton {
                    id: player

                    active: Panels.isOpen("player", root.modelData)
                    onClicked: Panels.toggle("player", root.modelData)
                }

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

                WifiButton {
                    id: wifi

                    active: Panels.isOpen("wifi", root.modelData)
                    onClicked: Panels.toggle("wifi", root.modelData)
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

                NotifButton {
                    id: notifs

                    visible: Settings.barShows("log")
                    active: Panels.isOpen("notifs", root.modelData)
                    onClicked: Panels.toggle("notifs", root.modelData)
                }

                KbButton {}

                ClockButton {
                    id: clock

                    visible: Settings.barShows("clock")
                    active: Panels.isOpen("calendar", root.modelData)
                    onClicked: Panels.toggle("calendar", root.modelData)
                }
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
                anchorItem: start
                barWindow: root
            }
        }

        Lazy {
            when: Panels.isOpen("dock", root.modelData)

            DockPopover {
                forScreen: root.modelData
                anchorItem: start
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
                // with the network icon hidden, the panel opens under the clock
                anchorItem: wifi.visible ? wifi : clock
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

            HerPopover {
                forScreen: root.modelData
                anchorItem: start
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

        // stripes out on an empty desktop, and in the corner: peeking when something happens
        // while she's nowhere on the screen, or called (super + h; services/Companion.qml)
        Lazy {
            when: root.companionOut

            DeskWindow {
                forScreen: root.modelData
            }
        }

        Lazy {
            when: root.focusedHere && (Companion.peeking || Companion.called) && Companion.enabled
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

        // the launcher in the middle, or as the start menu under the kawt button
        Lazy {
            when: Panels.isOpen("launcher", root.modelData) || Panels.isOpen("menu", root.modelData)

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
