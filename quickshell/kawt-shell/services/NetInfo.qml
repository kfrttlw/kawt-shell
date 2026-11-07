pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The connection in use, for the wifi panel: its address, gateway, dns, the wifi's band, channel,
// speed and security (scripts/netinfo.sh). Looked at when the panel opens and when the network
// changes while it's open (`watching`), nothing in between: it only reads, never asks the network.
Singleton {
    id: root

    property bool watching: false
    property string dev: ""
    property string ip: ""
    property string ip6: ""
    property string gw: ""
    property string dns: ""
    property string mac: ""
    property string freq: "" // "5180 MHz"
    property string rate: "" // "866 Mbit/s"
    property string chan: ""
    property string security: ""
    // "5 GHz · ch 36 · 866 Mb/s · WPA2"
    readonly property string wifiLine: [freq ? (parseInt(freq) >= 5900 ? "6 GHz" : parseInt(freq) >= 4900 ? "5 GHz" : "2.4 GHz") : "", chan ? `ch ${chan}` : "", rate.replace("Mbit/s", "Mb/s"), security].filter(s => s).join(" · ")

    function refresh(): void {
        if (reader.running)
            again = true;
        else
            reader.running = true;
    }

    property bool again: false

    onWatchingChanged: if (watching)
        refresh()

    // a new network, a cable in or out, a vpn up: look again (a moment later: the address
    // comes after the connection)
    Connections {
        target: Wifi

        function onActiveChanged(): void {
            if (root.watching)
                later.restart();
        }
    }

    Connections {
        target: NetLinks

        function onWiredChanged(): void {
            if (root.watching)
                later.restart();
        }

        function onVpnChanged(): void {
            if (root.watching)
                later.restart();
        }
    }

    Timer {
        id: later

        interval: 1500
        onTriggered: root.refresh()
    }

    Process {
        id: reader

        command: ["sh", `${Quickshell.shellDir}/scripts/netinfo.sh`]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0)
                        v[line.slice(0, i)] = line.slice(i + 1).trim();
                }
                root.dev = v.dev ?? "";
                root.ip = v.ip ?? "";
                root.ip6 = v.ip6 ?? "";
                root.gw = v.gw ?? "";
                root.dns = (v.dns ?? "").split(/\s+/).filter(s => s).join(" · ");
                root.mac = v.mac ?? "";
                root.freq = v.freq ?? "";
                root.rate = v.rate ?? "";
                root.chan = v.chan ?? "";
                root.security = v.security && v.security !== "--" ? v.security : "";
            }
        }
        onExited: if (root.again) {
            root.again = false;
            root.refresh();
        }
    }
}
