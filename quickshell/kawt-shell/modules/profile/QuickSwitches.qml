import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services
import qs.utils

// The switches you reach for most, on top of the profile, a click each:
//   [wifi home] [bt] [dnd] [night] [caf] [mic]                 bat 72% ▮▮▮▮▮▮▮▯▯▯ 3h left
// lit (red brackets) = on. bt and night only where there's bluetooth / hyprsunset; the battery
// only on a laptop
RowLayout {
    id: root

    readonly property var bt: Bluetooth.defaultAdapter

    spacing: Metrics.spacing

    BracketButton {
        label: !Wifi.enabled ? "wifi off" : Wifi.active ? `wifi ${Wifi.active.name.slice(0, 14)}` : "wifi"
        textColor: Wifi.enabled ? Colors.accent : Colors.dim
        onClicked: Wifi.setEnabled(!Wifi.enabled)
    }

    BracketButton {
        visible: root.bt !== null
        label: "bt"
        textColor: root.bt?.enabled ? Colors.accent : Colors.dim
        onClicked: root.bt.enabled = !root.bt.enabled
    }

    BracketButton {
        label: "dnd"
        textColor: Settings.dnd ? Colors.accent : Colors.dim
        onClicked: Settings.dnd = !Settings.dnd
    }

    BracketButton {
        visible: Night.available
        label: "night"
        textColor: Settings.nightLight ? Colors.accent : Colors.dim
        onClicked: Settings.nightLight = !Settings.nightLight
    }

    // caffeine: no idle lock, the screen stays on
    BracketButton {
        label: "caf"
        textColor: Idle.caffeine ? Colors.accent : Colors.dim
        onClicked: Idle.caffeine = !Idle.caffeine
    }

    BracketButton {
        visible: Audio.source !== null
        label: Audio.source?.audio?.muted ? "mic off" : "mic"
        textColor: Audio.source?.audio?.muted ? Colors.dim : Colors.accent
        onClicked: Audio.toggleMicMute()
    }

    Item {
        Layout.fillWidth: true
    }

    // the battery
    Row {
        readonly property var dev: UPower.displayDevice
        readonly property bool plugged: dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged

        visible: dev.isLaptopBattery
        spacing: Metrics.spacing

        Label {
            text: "bat"
            color: Colors.dim
        }

        Label {
            text: `${Math.round(parent.dev.percentage * 100)}%${parent.plugged ? "+" : ""}`
            color: parent.dev.percentage <= 0.15 && !parent.plugged ? Colors.warn : Colors.fg
        }

        Meter {
            anchors.verticalCenter: parent.verticalCenter
            count: 10
            value: parent.dev.percentage
        }

        Label {
            visible: !parent.plugged && parent.dev.timeToEmpty > 0
            text: `${Fmt.uptime(parent.dev.timeToEmpty)} left`
            color: Colors.dim
        }
    }
}
