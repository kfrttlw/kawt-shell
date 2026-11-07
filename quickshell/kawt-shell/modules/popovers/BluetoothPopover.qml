import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.config
import qs.components

// [on] off  adapter name  [scan]
// > airpods pro    80%  connected     click: connect / disconnect, new ones: pair
//   mx keys             paired     x  x: forget
Popover {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    // connected first, then paired, then the rest; by name
    readonly property var devices: [...Bluetooth.devices.values].filter(d => d.name).sort((a, b) => (b.connected - a.connected) || (b.bonded - a.bonded) || a.name.localeCompare(b.name))

    name: "bluetooth"
    title: Strings.t("bluetooth")
    icon: "bt"
    cardWidth: 340
    settingsPage: "device"
    switchText: root.adapter ? Strings.t("micOn") : ""
    switchOn: root.adapter?.enabled ?? false
    onSwitchToggled: if (root.adapter)
        root.adapter.enabled = !root.adapter.enabled
    readonly property int rowHeight: Metrics.fontSize + 9

    // stop searching when the panel closes, it drains the battery
    onPanelClosed: if (Bluetooth.defaultAdapter?.discovering)
        Bluetooth.defaultAdapter.discovering = false

    // the adapter, and the search for new ones
    RowLayout {
        Layout.fillWidth: true
        visible: root.adapter !== null
        spacing: Metrics.spacing

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: root.adapter?.name ?? ""
            color: Colors.dim
        }

        PushButton {
            visible: root.adapter?.enabled ?? false
            minWidth: 0
            text: root.adapter?.discovering ? Strings.t("btSearching") : Strings.t("btSearch")
            active: root.adapter?.discovering ?? false
            onClicked: root.adapter.discovering = !root.adapter.discovering
        }
    }

    Label {
        visible: root.adapter !== null && !root.adapter.enabled
        text: Strings.t("btOff")
        color: Colors.dim
    }

    // no adapter: almost always the bluetooth service isn't installed or running
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.adapter === null
        spacing: 2

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Strings.t("btNoService")
            color: Colors.warn
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: "sudo pacman -S --needed bluez bluez-utils"
            color: Colors.fg
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: "sudo systemctl enable --now bluetooth"
            color: Colors.fg
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Strings.t("thenRestart")
            color: Colors.dim
            font.pixelSize: Metrics.size(-2)
        }
    }

    Label {
        visible: (root.adapter?.enabled ?? false) && root.devices.length === 0
        text: Strings.t("btNone")
        color: Colors.dim
    }

    // the devices, sunk in a field: connected ones first, red
    Rectangle {
        Layout.fillWidth: true
        visible: (root.adapter?.enabled ?? false) && root.devices.length > 0
        implicitHeight: devList.implicitHeight + 6
        color: Colors.well

        Bevel {
            style: "sunk"
        }

        Column {
            id: devList

            x: 3
            y: 3
            width: parent.width - 6

            Repeater {
                model: ScriptModel {
                    values: root.adapter?.enabled ? root.devices.slice(0, 12) : []
                }

                Rectangle {
                    id: dev

                    required property var modelData
                    readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting || modelData.pairing
                    readonly property bool on: modelData.connected

                    width: parent.width
                    height: root.rowHeight
                    color: on ? Colors.accent : devArea.containsMouse ? Colors.hoverFill : "transparent"

                    RowLayout {
                        id: devRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 2
                        anchors.rightMargin: 2
                        spacing: Metrics.spacing

                        PixIcon {
                            name: "bt"
                            ink: dev.on ? Colors.onAccent : "transparent"
                        }

                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: dev.modelData.name
                            color: dev.on ? Colors.onAccent : Colors.fg
                        }

                        Label {
                            visible: dev.modelData.connected && dev.modelData.batteryAvailable
                            text: `${Math.round(dev.modelData.battery * 100)}%`
                            color: dev.on ? Colors.onAccent : dev.modelData.battery < 0.2 ? Colors.warn : Colors.dim
                        }

                        Label {
                            text: dev.busy ? "…" : dev.modelData.connected ? Strings.t("connected") : dev.modelData.bonded ? Strings.t("btPaired") : Strings.t("btNew")
                            color: dev.on ? Colors.onAccent : Colors.dim
                        }

                        Label {
                            text: "×"
                            opacity: devArea.containsMouse && dev.modelData.bonded ? 1 : 0
                            color: dev.on ? Colors.onAccent : Colors.warn
                        }
                    }

                    // click: connect / disconnect (a new device gets paired first) · x: forget it
                    MouseArea {
                        id: devArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            const d = dev.modelData;
                            if (dev.busy)
                                return;
                            if (d.bonded && mouse.x > width - 20)
                                d.forget();
                            else if (!d.bonded)
                                d.pair();
                            else
                                d.connected = !d.connected;
                        }
                    }
                }
            }
        }
    }
}
