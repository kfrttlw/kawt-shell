pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Throughput of physical interfaces (wl*, en*, eth*, ww*), sampled from /proc/net/dev.
// Virtual ones (lo, docker, veth, VPN tunnels) are skipped so traffic isn't counted twice.
Singleton {
    id: root

    readonly property int historyLength: 24
    readonly property int interval: 1000

    property real rx: 0 // bytes/s
    property real tx: 0
    property list<real> rxHistory: new Array(historyLength).fill(0)
    property list<real> txHistory: new Array(historyLength).fill(0)

    property real lastRx: -1
    property real lastTx: -1

    FileView {
        id: file

        path: "/proc/net/dev"
        onLoaded: {
            let rxTotal = 0, txTotal = 0;
            for (const line of text().split("\n").slice(2)) {
                const [iface, rest] = line.split(":");
                if (!rest || !/^\s*(wl|en|eth|ww)/.test(iface))
                    continue;
                const f = rest.trim().split(/\s+/);
                rxTotal += Number(f[0]);
                txTotal += Number(f[8]);
            }

            if (root.lastRx >= 0) {
                const secs = root.interval / 1000;
                root.rx = Math.max(0, rxTotal - root.lastRx) / secs;
                root.tx = Math.max(0, txTotal - root.lastTx) / secs;
                root.rxHistory = [...root.rxHistory.slice(1), root.rx];
                root.txHistory = [...root.txHistory.slice(1), root.tx];
            }
            root.lastRx = rxTotal;
            root.lastTx = txTotal;
        }
    }

    Timer {
        running: true
        repeat: true
        interval: root.interval
        triggeredOnStart: true
        onTriggered: file.reload()
    }
}
