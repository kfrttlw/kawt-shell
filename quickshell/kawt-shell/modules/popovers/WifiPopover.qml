import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import qs.config
import qs.components
import qs.services

Popover {
    id: root

    property var pskTarget: null // secured network waiting for a password
    property string status: ""

    name: "wifi"
    title: "wifi"
    cardWidth: 320

    function pick(net: var): void {
        if (net.connected || net.stateChanging)
            return;
        status = "";
        if (net.known || !Wifi.isSecure(net)) {
            pskTarget = null;
            net.connect();
        } else {
            pskTarget = net;
            psk.text = "";
            psk.input.forceActiveFocus();
        }
    }

    // scan only while the panel is open
    onPanelOpened: Wifi.scanning = true
    onPanelClosed: {
        Wifi.scanning = false;
        pskTarget = null;
        status = "";
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing

        BracketButton {
            label: Wifi.enabled ? "on" : "off"
            textColor: Wifi.enabled ? Colors.accent : Colors.dim
            onClicked: Wifi.setEnabled(!Wifi.enabled)
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Wifi.device?.name ?? "no wifi device"
            color: Colors.dim
        }

        BracketButton {
            visible: Wifi.active !== null
            label: "disconnect"
            onClicked: Wifi.active?.disconnect()
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Metrics.borderWidth
        color: Colors.border
    }

    Label {
        visible: Wifi.enabled && Wifi.sorted.length === 0
        text: "scanning..."
        color: Colors.dim
    }

    Repeater {
        model: Wifi.enabled ? Wifi.sorted.slice(0, 10) : []

        Item {
            id: row

            required property var modelData

            Layout.fillWidth: true
            implicitHeight: line.implicitHeight + 4

            Connections {
                target: row.modelData

                function onConnectionFailed(reason: int): void {
                    root.status = `failed: ${ConnectionFailReason.toString(reason)}`;
                    // saved password is wrong/missing -> ask for it (don't call pick(): it would retry a known net forever)
                    if (reason === ConnectionFailReason.NoSecrets) {
                        root.pskTarget = row.modelData;
                        psk.input.forceActiveFocus();
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: rowArea.containsMouse || root.pskTarget === row.modelData
                color: Colors.hoverFill
            }

            RowLayout {
                id: line

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                spacing: Metrics.spacing

                Label {
                    text: row.modelData.connected ? ">" : " "
                    color: Colors.accent
                }

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: row.modelData.name
                    color: row.modelData.connected ? Colors.accent : Colors.fg
                }

                Label {
                    text: row.modelData.stateChanging ? "..." : (row.modelData.known ? "saved " : "") + (Wifi.isSecure(row.modelData) ? "*" : " ")
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
                }

                Label {
                    text: Wifi.signalBars(row.modelData.signalStrength)
                    color: Colors.dim
                }
            }

            MouseArea {
                id: rowArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pick(row.modelData)
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.pskTarget !== null
        spacing: 2

        Label {
            Layout.topMargin: Metrics.spacing
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: `password for ${root.pskTarget?.name ?? ""}:`
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }

        TermInput {
            id: psk

            Layout.fillWidth: true
            prompt: "psk>"
            echoMode: TextInput.Password
            onAccepted: text => {
                if (!root.pskTarget || text.length === 0)
                    return;
                root.status = `connecting to ${root.pskTarget.name}...`;
                root.pskTarget.connectWithPsk(text);
                root.pskTarget = null;
                psk.text = "";
            }
        }
    }

    Label {
        visible: root.status !== ""
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: root.status
        color: root.status.startsWith("failed") ? Colors.warn : Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }
}
