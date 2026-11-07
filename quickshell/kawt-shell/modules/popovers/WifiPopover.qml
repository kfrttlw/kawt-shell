import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Networking
import qs.config
import qs.components
import qs.services
import qs.utils
import "../../utils/pixicons.js" as Pix

// The network, the old way: Wi-Fi switched on the right of the head; the networks nearby in a
// sunk list, the one in use red ("connected"), a lock on the ones with a password, "open" on the
// ones without; the traffic of the last minute between ↓ and ↑; ip, gateway, the band; then
// [Disconnect] [Who's on the net…] (the system window's network tab) and […] (a hidden network).
Popover {
    id: root

    property var pskTarget: null // secured network waiting for a password
    property string status: ""
    property bool hiddenAsk: false // the lines for a hidden network are open
    property string hiddenSsid: "" // its name, typed: now the password is asked
    readonly property int rowHeight: Metrics.fontSize + 9

    name: "wifi"
    title: Strings.t("net")
    icon: Wifi.active ? Pix.wifi(Wifi.active.signalStrength * 100) : NetLinks.wired ? "eth" : "wifi0"
    cardWidth: 400
    switchText: Wifi.device !== null ? "Wi-Fi" : ""
    switchOn: Wifi.enabled
    onSwitchToggled: Wifi.setEnabled(!Wifi.enabled)

    function pick(net: var): void {
        if (net.connected || net.stateChanging)
            return;
        status = "";
        Wifi.hiddenStatus = "";
        hiddenAsk = false;
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
        if (!Wifi.hiddenBusy)
            Wifi.hiddenStatus = "";
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing

        // cable enp3s0 · vpn wg0
        Label {
            Layout.fillWidth: true
            visible: text !== ""
            elide: Text.ElideRight
            text: [NetLinks.wired ? `${Strings.t("wired")} ${NetLinks.wired}` : "", NetLinks.vpn ? `vpn ${NetLinks.vpn}` : ""].filter(s => s).join(" · ")
            color: Colors.accent
        }

        Label {
            visible: Wifi.device === null
            text: Strings.t("noWifi")
            color: Colors.dim
        }

        Label {
            visible: Wifi.device !== null && !Wifi.enabled
            text: Strings.t("wifiOff")
            color: Colors.dim
        }

        Label {
            visible: Wifi.enabled && Wifi.sorted.length === 0
            text: Strings.t("scanning")
            color: Colors.dim
        }

        // the networks nearby, sunk in a field
        Rectangle {
            Layout.fillWidth: true
            visible: Wifi.enabled && Wifi.sorted.length > 0
            implicitHeight: nets.implicitHeight + 6
            color: Colors.well

            Bevel {
                style: "sunk"
            }

            Column {
                id: nets

                x: 3
                y: 3
                width: parent.width - 6

                // ScriptModel: a new scan result moves rows instead of making them all again
                // (the hover and a failed-connection handler stay with their network)
                Repeater {
                    model: ScriptModel {
                        values: Wifi.enabled ? Wifi.sorted.slice(0, 8) : []
                    }

                    Rectangle {
                        id: row

                        required property var modelData
                        readonly property bool inUse: modelData.connected
                        readonly property color ink: inUse ? Colors.onAccent : Colors.fg

                        width: parent.width
                        height: root.rowHeight
                        color: inUse ? Colors.accent : rowArea.containsMouse || root.pskTarget === modelData ? Colors.hoverFill : "transparent"

                        Connections {
                            target: row.modelData

                            function onConnectionFailed(reason: int): void {
                                root.status = Strings.t("wifiFailed").arg(ConnectionFailReason.toString(reason));
                                // saved password is wrong/missing -> ask for it (don't call pick(): it would retry a known net forever)
                                if (reason === ConnectionFailReason.NoSecrets) {
                                    root.pskTarget = row.modelData;
                                    psk.input.forceActiveFocus();
                                }
                            }
                        }

                        PixIcon {
                            id: bars

                            x: 3
                            anchors.verticalCenter: parent.verticalCenter
                            name: Pix.wifi(row.modelData.signalStrength * 100)
                            ink: row.inUse ? Colors.onAccent : "transparent"
                        }

                        Label {
                            x: bars.x + bars.width + 6
                            width: what.x - x - 6
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: row.modelData.name
                            color: row.ink
                        }

                        // in use: "connected"; a password: a lock; none: "open" (others nearby can
                        // see what goes over it unencrypted)
                        Label {
                            id: what

                            visible: !lock.visible
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.stateChanging ? "…" : row.inUse ? Strings.t("connected") : !Wifi.isSecure(row.modelData) ? Strings.t("openNet") : row.modelData.known ? Strings.t("savedNet") : ""
                            color: row.inUse ? Colors.onAccent : !Wifi.isSecure(row.modelData) ? Colors.warn : Colors.dim
                        }

                        PixIcon {
                            id: lock

                            visible: !row.inUse && !row.modelData.stateChanging && Wifi.isSecure(row.modelData) && !row.modelData.known
                            anchors.right: parent.right
                            anchors.rightMargin: 3
                            anchors.verticalCenter: parent.verticalCenter
                            name: "lock"
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
            }
        }

        // the last minute: ↓ 1.3 MB/s [graph] ↑ 41 KB/s
        RowLayout {
            Layout.fillWidth: true
            visible: NetInfo.dev !== "" || Wifi.active !== null
            spacing: Metrics.spacing

            Label {
                text: `↓ ${Fmt.rate(NetStats.rx).trim()}`
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.round(Metrics.fontSize * 2.6)
                color: Colors.well

                Bevel {
                    style: "sunk"
                }

                TrafficGraph {
                    x: 2
                    y: 2
                    width: parent.width - 4
                    height: parent.height - 4
                }
            }

            Label {
                text: `↑ ${Fmt.rate(NetStats.tx).trim()}`
            }
        }

        // ip · gateway · the band and channel
        Label {
            Layout.fillWidth: true
            visible: text !== ""
            wrapMode: Text.Wrap
            text: [NetInfo.ip ? `ip ${NetInfo.ip}` : "", NetInfo.gw ? `${Strings.t("gateway")} ${NetInfo.gw}` : "", Wifi.active ? NetInfo.wifiLine : ""].filter(s => s).join(" · ")
            color: Colors.dim
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            PushButton {
                visible: Wifi.active !== null
                minWidth: 0
                text: Strings.t("disconnect")
                onClicked: Wifi.active?.disconnect()
            }

            PushButton {
                minWidth: 0
                text: Strings.t("whoOnNet")
                onClicked: Panels.openWindow("system", "net")
            }

            Item {
                Layout.fillWidth: true
            }

            // a network that doesn't announce its name: typed in, then its password
            //   ssid> home  ->  psk> ****  (enter on an empty psk: an open one)
            PushButton {
                visible: Wifi.enabled && Wifi.device !== null
                minWidth: 26
                text: "…"
                active: root.hiddenAsk
                onClicked: {
                    root.pskTarget = null;
                    root.hiddenSsid = "";
                    root.hiddenAsk = !root.hiddenAsk;
                    ssidInput.text = "";
                    if (root.hiddenAsk)
                        ssidInput.input.forceActiveFocus();
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
                text: Strings.t("passwordFor").arg(root.pskTarget?.name ?? "")
                color: Colors.dim
                font.pixelSize: Metrics.size(-2)
            }

            TermInput {
                id: psk

                Layout.fillWidth: true
                prompt: "psk>"
                echoMode: TextInput.Password
                onAccepted: text => {
                    if (!root.pskTarget || text.length === 0)
                        return;
                    root.status = Strings.t("connectingTo").arg(root.pskTarget.name);
                    root.pskTarget.connectWithPsk(text);
                    root.pskTarget = null;
                    psk.text = "";
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.hiddenAsk
            spacing: 2

            Label {
                Layout.topMargin: Metrics.spacing
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root.hiddenSsid ? Strings.t("hiddenPassword").arg(root.hiddenSsid) : Strings.t("hiddenName")
                color: Colors.dim
                font.pixelSize: Metrics.size(-2)
            }

            TermInput {
                id: ssidInput

                Layout.fillWidth: true
                visible: root.hiddenSsid === ""
                prompt: "ssid>"
                onAccepted: text => {
                    if (!text.trim())
                        return;
                    root.hiddenSsid = text.trim();
                    hiddenPsk.text = "";
                    hiddenPsk.input.forceActiveFocus();
                }
                Keys.onEscapePressed: root.hiddenAsk = false
            }

            TermInput {
                id: hiddenPsk

                Layout.fillWidth: true
                visible: root.hiddenSsid !== ""
                prompt: "psk>"
                echoMode: TextInput.Password
                onAccepted: text => {
                    Wifi.connectHidden(root.hiddenSsid, text);
                    hiddenPsk.text = "";
                    root.hiddenSsid = "";
                    root.hiddenAsk = false;
                }
                Keys.onEscapePressed: root.hiddenAsk = false
            }
        }

        Label {
            readonly property string shown: Wifi.hiddenStatus || root.status

            visible: shown !== ""
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: shown
            color: shown.startsWith(Strings.t("wifiFailed").split("%1")[0]) ? Colors.warn : Colors.dim
            font.pixelSize: Metrics.size(-2)
        }
    }

    // the connection's details: looked at while the networks page is open
    Binding {
        target: NetInfo
        property: "watching"
        value: root.open
    }
}
