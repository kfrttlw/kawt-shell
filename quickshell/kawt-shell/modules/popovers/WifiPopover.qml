import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Networking
import qs.config
import qs.components
import qs.services
import qs.utils

Popover {
    id: root

    property var pskTarget: null // secured network waiting for a password
    property string status: ""
    property bool hiddenAsk: false // the lines for a hidden network are open
    property string hiddenSsid: "" // its name, typed: now the password is asked

    name: "wifi"
    title: "wifi"
    // [who's out]: who talks to the internet right now (WhoOut.qml), wider for its columns
    readonly property int page: pageTabs.current
    cardWidth: page === 1 ? 480 : 400

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
        pageTabs.current = 0; // the next time it's the networks again, nothing watched
        pskTarget = null;
        status = "";
        if (!Wifi.hiddenBusy)
            Wifi.hiddenStatus = "";
    }

    Tabs {
        id: pageTabs

        tabs: ["wifi", "who's out"]
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.page === 0
        spacing: Metrics.spacing

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

        // cable enp3s0 · vpn wg0
        Label {
            Layout.fillWidth: true
            visible: text !== ""
            elide: Text.ElideRight
            text: [NetLinks.wired ? `cable ${NetLinks.wired}` : "", NetLinks.vpn ? `vpn ${NetLinks.vpn}` : ""].filter(s => s).join(" · ")
            color: Colors.accent
        }

        // ---- the connection in use:
        //   > home   ▂▄▆█ 82%                 5 GHz · ch 36 · 866 Mb/s · WPA2
        //   ┌ the last minute ─────────────────────── ↓ 1.2M ↑ 34K ┐
        //   │ in, up from the line; out, down                      │
        //   └──────────────────────────────────────────────────────┘
        //   ip ........ 192.168.1.30/24     gateway ... 192.168.1.1
        //   dns ....... 192.168.1.1 · 1.1.1.1
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            visible: NetInfo.dev !== "" || Wifi.active !== null
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                visible: Wifi.active !== null
                spacing: Metrics.spacing

                Label {
                    text: `> ${Wifi.active?.name ?? ""}`
                    color: Colors.accent
                    font.bold: true
                }

                Label {
                    text: Wifi.active ? `${Wifi.signalBars(Wifi.active.signalStrength)} ${Math.round(Wifi.active.signalStrength * 100)}%` : ""
                    color: Colors.dim
                }

                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: NetInfo.wifiLine
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
                }
            }

            TitledBox {
                Layout.fillWidth: true
                Layout.topMargin: titleOverhang
                implicitHeight: graph.implicitHeight + Metrics.padding * 2 + titleOverhang
                title: "the last minute"
                hint: `↓${Fmt.rate(NetStats.rx)} ↑${Fmt.rate(NetStats.tx)}`

                TrafficGraph {
                    id: graph

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Metrics.padding
                    anchors.topMargin: Metrics.padding + parent.titleOverhang
                }
            }

            // name ...... value, the way the sys tab shows the machine
            Repeater {
                model: [["ip", NetInfo.ip], ["ipv6", NetInfo.ip6], ["gateway", NetInfo.gw], ["dns", NetInfo.dns], ["device", [NetInfo.dev, NetInfo.mac].filter(s => s).join(" · ")]].filter(r => r[1])

                RowLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        text: `${modelData[0]} ${".".repeat(Math.max(2, 10 - modelData[0].length))} `
                        color: Colors.dim
                    }

                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
                        text: modelData[1]
                    }
                }
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

        // ScriptModel: a new scan result moves rows instead of making them all again (the hover
        // and a failed-connection handler stay with their network)
        Repeater {
            model: ScriptModel {
                values: Wifi.enabled ? Wifi.sorted.slice(0, 10) : []
            }

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

        // a network that doesn't announce its name: typed in, then its password
        //   [+ hidden network]  ->  ssid> home  ->  psk> ****  (enter on an empty psk: an open one)
        BracketButton {
            visible: Wifi.enabled && Wifi.device !== null && !root.hiddenAsk
            Layout.topMargin: Metrics.spacing
            bordered: false
            label: "+ hidden network"
            textColor: Colors.dim
            onClicked: {
                root.pskTarget = null;
                root.hiddenSsid = "";
                root.hiddenAsk = true;
                ssidInput.text = "";
                ssidInput.input.forceActiveFocus();
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
                text: root.hiddenSsid ? `password for ${root.hiddenSsid} (empty: open network):` : "name of the hidden network:"
                color: Colors.dim
                font.pixelSize: Metrics.fontSize - 2
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
            color: shown.startsWith("failed") ? Colors.warn : Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }
    }

    // the connection's details: looked at while the networks page is open
    Binding {
        target: NetInfo
        property: "watching"
        value: root.open && root.page === 0
    }

    // made only while it's shown: it looks at the connections every few seconds
    Loader {
        Layout.fillWidth: true
        active: root.page === 1 && root.open
        visible: active

        sourceComponent: WhoOut {}
    }
}
