import QtQuick
import qs.config
import qs.services

// The network over the last minute, big: what comes in as bars up from the middle line (ink),
// what goes out as bars down (grey), each to its own scale: the busiest second of each fills its
// half, so a small upload still shows its shape (the numbers are in the box's title)
//   ▂▃▅▇█▇▅▃▂▁▁▂▃▅▇▆▅▃▂
//   ───────────────────
//   ▁ ▁▂ ▁    ▁▂▃▂▁
Canvas {
    id: root

    property var rx: NetStats.rxHistory
    property var tx: NetStats.txHistory
    // the busiest second of the minute (a quiet one: 1K, so a trickle stays small)
    function peak(values: var): real {
        let m = 1024;
        for (let i = 0; i < values.length; i++)
            m = Math.max(m, values[i]);
        return m;
    }

    implicitHeight: Math.round(Metrics.fontSize * 5)

    onRxChanged: requestPaint()
    onTxChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    Connections {
        target: Colors

        function onPaletteChanged(): void {
            root.requestPaint();
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        const n = Math.max(rx.length, tx.length);
        if (n === 0)
            return;
        const mid = Math.round(height * 0.62); // more room for what comes in
        const gap = 1;
        const w = Math.max(1, (width - gap * (n - 1)) / n);
        const inPeak = peak(rx), outPeak = peak(tx);
        ctx.fillStyle = Colors.border;
        ctx.fillRect(0, mid, width, 1);
        for (let i = 0; i < n; i++) {
            const x = Math.round(i * (w + gap));
            const up = Math.round(Math.min(1, (rx[i] ?? 0) / inPeak) * (mid - 1));
            const down = Math.round(Math.min(1, (tx[i] ?? 0) / outPeak) * (height - mid - 2));
            if (up > 0) {
                ctx.fillStyle = Colors.fg;
                ctx.fillRect(x, mid - up, Math.ceil(w), up);
            }
            if (down > 0) {
                ctx.fillStyle = Colors.dim;
                ctx.fillRect(x, mid + 2, Math.ceil(w), down);
            }
        }
    }
}
