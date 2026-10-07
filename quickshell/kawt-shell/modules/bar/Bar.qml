import QtQuick
import QtQuick.Layouts
import Quickshell
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

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: root

        required property ShellScreen modelData
        screen: modelData

        implicitHeight: Metrics.barHeight
        color: "transparent"

        WlrLayershell.namespace: "kawt-bar"

        anchors.top: true
        anchors.left: true
        anchors.right: true

        // left: profile, pinned apps, workspaces
        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: Metrics.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Metrics.spacing

            BracketButton {
                id: profile
                label: "~"
                active: Panels.isOpen("profile", root.modelData)
                onClicked: Panels.toggle("profile", root.modelData)
            }

            BracketButton {
                id: dock
                label: "$"
                textColor: Colors.accent
                active: Panels.isOpen("dock", root.modelData)
                onClicked: Panels.toggle("dock", root.modelData)
            }

            Workspaces {
                screen: root.modelData
            }
        }

        // network leads up to the clock
        RowLayout {
            anchors.right: clock.left
            anchors.rightMargin: Metrics.sectionGap
            anchors.verticalCenter: parent.verticalCenter
            spacing: Metrics.spacing

            WifiButton {
                id: wifi
                active: Panels.isOpen("wifi", root.modelData)
                onClicked: Panels.toggle("wifi", root.modelData)
            }

            NetGraph {
                id: netGraph
                active: Panels.isOpen("wifi", root.modelData)
                onClicked: Panels.toggle("wifi", root.modelData)
            }
        }

        ClockButton {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            active: Panels.isOpen("calendar", root.modelData)
            onClicked: Panels.toggle("calendar", root.modelData)
        }

        // media follows the clock
        PlayerButton {
            id: player
            anchors.left: clock.right
            anchors.leftMargin: Metrics.sectionGap
            anchors.verticalCenter: parent.verticalCenter
            active: Panels.isOpen("player", root.modelData)
            onClicked: Panels.toggle("player", root.modelData)
        }

        // right: tray, input/output, power, messages, ai
        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: Metrics.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Metrics.spacing

            RecButton {}

            CastButton {}

            CafButton {}

            Tray {
                id: tray
                active: Panels.isOpen("tray", root.modelData)
                onClicked: Panels.toggle("tray", root.modelData)
            }

            KbButton {}

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
                active: Panels.isOpen("notifs", root.modelData)
                onClicked: Panels.toggle("notifs", root.modelData)
            }

            BracketButton {
                label: ">_"
                textColor: Colors.accent
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

        // kept a moment after closing, for the slide out
        Lazy {
            when: Panels.isSidebarOpen(root.modelData)
            linger: 300

            AiSidebar {
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
    }
}
