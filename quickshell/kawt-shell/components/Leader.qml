import QtQuick
import qs.config

// ······ a dotted line from a label to its value, like a table of contents or a bios screen
Canvas {
    implicitHeight: Metrics.fontSize
    implicitWidth: 0

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    Connections {
        target: Colors

        function onBorderChanged(): void {
            requestPaint();
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        ctx.fillStyle = Colors.border;
        // on the baseline: a little above the bottom of the line
        const y = Math.round(height * 0.72);
        for (let x = 1; x < width - 1; x += 4)
            ctx.fillRect(x, y, 1, 1);
    }
}
