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
    title: "bluetooth"
    cardWidth: 340

    // stop searching when the panel closes, it drains the battery
    onPanelClosed: if (Bluetooth.defaultAdapter?.discovering)
        Bluetooth.defaultAdapter.discovering = false

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing

        BracketButton {
            label: "on"
            active: root.adapter?.enabled ?? false
            textColor: root.adapter?.enabled ? Colors.accent : Colors.dim
            onClicked: if (root.adapter)
                root.adapter.enabled = true
        }

        BracketButton {
            label: "off"
            active: !(root.adapter?.enabled ?? false)
            textColor: !root.adapter?.enabled ? Colors.accent : Colors.dim
            onClicked: if (root.adapter)
                root.adapter.enabled = false
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: root.adapter?.name ?? "no adapter"
            color: Colors.dim
        }

        BracketButton {
            visible: root.adapter?.enabled ?? false
            label: root.adapter?.discovering ? "scanning..." : "scan"
            textColor: root.adapter?.discovering ? Colors.accent : Colors.fg
            onClicked: root.adapter.discovering = !root.adapter.discovering
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Metrics.borderWidth
        color: Colors.border
    }

    Label {
        visible: root.adapter !== null && !root.adapter.enabled
        text: "-- bluetooth is off --"
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
            text: "the bluetooth service isn't running"
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
            text: "then restart kawt"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }
    }

    Label {
        visible: (root.adapter?.enabled ?? false) && root.devices.length === 0
        text: "-- no devices: [scan] to find some --"
        color: Colors.dim
    }

    Repeater {
        model: ScriptModel {
            values: root.adapter?.enabled ? root.devices.slice(0, 12) : []
        }

        Item {
            id: dev

            required property var modelData
            readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting || modelData.pairing

            Layout.fillWidth: true
            implicitHeight: devRow.implicitHeight + 4

            Rectangle {
                anchors.fill: parent
                visible: devArea.containsMouse
                color: Colors.hoverFill
            }

            RowLayout {
                id: devRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                spacing: Metrics.spacing

                Label {
                    text: dev.modelData.connected ? ">" : " "
                    color: Colors.accent
                }

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: dev.modelData.name.toLowerCase()
                    color: dev.modelData.connected ? Colors.accent : Colors.fg
                }

                Label {
                    visible: dev.modelData.connected && dev.modelData.batteryAvailable
                    text: `${Math.round(dev.modelData.battery * 100)}%`
                    color: dev.modelData.battery < 0.2 ? Colors.warn : Colors.dim
                }

                Label {
                    text: dev.busy ? "..." : dev.modelData.connected ? "connected" : dev.modelData.bonded ? "paired" : "new"
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
                }

                Label {
                    text: "x"
                    opacity: devArea.containsMouse && dev.modelData.bonded ? 1 : 0
                    color: Colors.warn
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
