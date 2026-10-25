import QtQuick
import qs.config
import qs.services
import "../../utils/companions.js" as Art

// The companion's pixels (utils/companions.js): one frame of him, painted only when it
// changes. While one of these is on the screen he moves (Companion.viewers); with none,
// nothing ticks. `live: false` is a still picture (the looks to pick from).
Item {
    id: root

    property string anim: Companion.base
    property int facing: 1 // -1: looking left
    property int look: 0
    property var skin: Companion.skin
    property int cell: Math.max(2, Math.round(3 * Metrics.scale))
    property bool live: true
    readonly property var rows: Art.frame(skin, {
        anim: live ? anim : "idle",
        step: live ? Companion.step : 0,
        blink: live && Companion.blink,
        look: look,
        facing: facing
    })
    readonly property string key: rows.join("")
    readonly property var colors: Companion.paletteOf(skin)

    implicitWidth: Art.W * cell
    implicitHeight: Art.H * cell
    opacity: skin?.alpha ?? 1

    // the ghost sways, half a pixel at a time
    transform: Translate {
        x: root.live && root.skin?.sway ? [0, 1, 1, 0, 0, -1, -1, 0][Companion.step % 8] * root.cell / 2 : 0
    }

    onKeyChanged: canvas.requestPaint()
    onColorsChanged: canvas.requestPaint()
    onCellChanged: canvas.requestPaint()

    Canvas {
        id: canvas

        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const c = root.cell, rows = root.rows, colors = root.colors;
            for (let y = 0; y < rows.length; y++) {
                const r = rows[y];
                for (let x = 0; x < r.length; x++) {
                    const ch = r[x];
                    if (ch === ".")
                        continue;
                    ctx.fillStyle = colors[ch] ?? colors.o ?? "#ff00ff";
                    ctx.fillRect(x * c, y * c, c, c);
                }
            }
        }
    }

    // he's on the screen: he moves (a still picture doesn't count)
    readonly property bool counting: live && visible && Companion.enabled
    property bool counted: false

    function sync(): void {
        if (counting === counted)
            return;
        counted = counting;
        Companion.viewers += counted ? 1 : -1;
    }

    onCountingChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (counted)
        Companion.viewers -= 1
}
