pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The cable and vpn links, for the bar: [eth] instead of [wifi --] on a cable, [vpn] while a
// tunnel is up (scripts/netlinks.sh says which). Nothing is polled: `ip monitor` sleeps until a
// link or an address changes, and only then the script looks again.
Singleton {
    id: root

    property bool available: false // ip (iproute2) is there
    property string wired: "" // the cable interface in use ("enp3s0"); "" = none
    property string vpn: "" // the tunnel ("wg0", "tun0", "tailscale0"); "" = none
    property bool pending: false // something changed while the script was running

    function look(): void {
        if (check.running)
            pending = true;
        else
            check.running = true;
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v ip"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim() !== "";
                if (root.available)
                    root.look();
            }
        }
    }

    Process {
        id: check

        command: ["sh", `${Quickshell.shellDir}/scripts/netlinks.sh`]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0)
                        v[line.slice(0, i)] = line.slice(i + 1).trim();
                }
                root.wired = v.wired ?? "";
                root.vpn = v.vpn ?? "";
            }
        }
        onExited: if (root.pending) {
            root.pending = false;
            Qt.callLater(root.look);
        }
    }

    // a burst of events (dhcp, a tunnel coming up) gives one look, a moment after the last
    Timer {
        id: settle

        interval: 400
        onTriggered: root.look()
    }

    // one line per change of a link or an address
    Process {
        id: monitor

        running: root.available
        command: ["ip", "-o", "monitor", "link", "address"]
        stdout: SplitParser {
            onRead: settle.restart()
        }
        onExited: if (root.available)
            restart.start()
    }

    Timer {
        id: restart

        interval: 5000
        onTriggered: {
            monitor.running = true;
            root.look(); // whatever changed while it wasn't watching
        }
    }
}
