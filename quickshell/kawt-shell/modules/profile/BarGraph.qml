import QtQuick
import qs.config

// ▁▂▅▇▆▃ as solid bars: one per sample (values 0..1), newest on the right
Canvas {
    id: root

    property var values: []
    property color barColor: Colors.accent
    property int gap: 1

    implicitHeight: 36

    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onBarColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        const n = values.length;
        if (n === 0)
            return;
        const w = Math.max(1, (width - gap * (n - 1)) / n);
        // a faint baseline so an idle machine still shows a graph
        ctx.fillStyle = Colors.border;
        ctx.fillRect(0, height - 1, width, 1);
        ctx.fillStyle = barColor;
        for (let i = 0; i < n; i++) {
            const h = Math.round(Math.max(0, Math.min(1, values[i])) * (height - 1));
            if (h > 0)
                ctx.fillRect(Math.round(i * (w + gap)), height - 1 - h, Math.ceil(w), h);
        }
    }
}
