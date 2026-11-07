pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Throughput of physical interfaces (wl*, en*, eth*, ww*), sampled from /proc/net/dev.
// Virtual ones (lo, docker, veth, VPN tunnels) are skipped so traffic isn't counted twice.
// Paused while the screen is locked: the bar is behind the lock screen then. A quiet sample
// over a quiet graph changes nothing, so nothing is redrawn for it.
Singleton {
    id: root

    readonly property int historyLength: 60 // a minute: the bar shows the last few, the wifi panel all
    readonly property int interval: Settings.lite ? 2000 : 1000 // an old machine: half as often

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
                const rx = Math.max(0, rxTotal - root.lastRx) / secs;
                const tx = Math.max(0, txTotal - root.lastTx) / secs;
                const quiet = rx === 0 && tx === 0 && root.rxHistory.every(v => v === 0) && root.txHistory.every(v => v === 0);
                if (!quiet) {
                    root.rx = rx;
                    root.tx = tx;
                    root.rxHistory = [...root.rxHistory.slice(1), rx];
                    root.txHistory = [...root.txHistory.slice(1), tx];
                }
            }
            root.lastRx = rxTotal;
            root.lastTx = txTotal;
        }
    }

    Timer {
        running: !Panels.locked
        repeat: true
        interval: root.interval
        triggeredOnStart: true
        onTriggered: file.reload()
    }

    // after the lock the first sample would hold the whole locked time's traffic as one second
    Connections {
        target: Panels

        function onLockedChanged(): void {
            root.lastRx = -1;
            root.lastTx = -1;
        }
    }
}
