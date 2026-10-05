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

            MicButton {}

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

        Wallpaper {
            forScreen: root.modelData
        }

        ProfilePopover {
            forScreen: root.modelData
            anchorItem: profile
        }

        DockPopover {
            forScreen: root.modelData
            anchorItem: dock
        }

        CalendarPopover {
            forScreen: root.modelData
            anchorItem: clock
        }

        PlayerPopover {
            forScreen: root.modelData
            anchorItem: player
        }

        WifiPopover {
            forScreen: root.modelData
            // with the wifi button hidden, the panel opens under the net graph
            anchorItem: wifi.visible ? wifi : netGraph
        }

        VolumePopover {
            forScreen: root.modelData
            anchorItem: volume
        }

        BrightnessPopover {
            forScreen: root.modelData
            anchorItem: brightness
        }

        BluetoothPopover {
            forScreen: root.modelData
            anchorItem: bluetooth
        }

        BatteryPopover {
            forScreen: root.modelData
            anchorItem: battery
        }

        NotifsPopover {
            forScreen: root.modelData
            anchorItem: notifs
        }

        TrayPopover {
            forScreen: root.modelData
            anchorItem: tray
        }

        AiSidebar {
            forScreen: root.modelData
        }

        Launcher {
            forScreen: root.modelData
        }

        StyleWindow {
            forScreen: root.modelData
        }

        Dashboard {
            forScreen: root.modelData
        }

        PowerMenu {
            forScreen: root.modelData
        }

        Toasts {
            forScreen: root.modelData
        }

        OsdWindow {
            forScreen: root.modelData
        }
    }
}
