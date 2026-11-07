import QtQuick
import qs.config
import "../utils/pixicons.js" as Pix

// One of kawt's pixel stickers (utils/pixicons.js), whole pixels only: 16 px, or 32 at size 32.
// The colors are the theme's (Colors.icon), so it's redrawn when the theme changes. `ink` paints
// every non-empty pixel one color instead (a disabled look, or an icon on the accent).
Canvas {
    id: root

    property string name: ""
    property int size: 16
    property color ink: "transparent"

    readonly property var map: Pix.get(name)

    implicitWidth: size
    implicitHeight: size
    width: implicitWidth
    height: implicitHeight
    visible: map !== null
    smooth: false
    antialiasing: false
    renderStrategy: Canvas.Immediate

    onMapChanged: requestPaint()
    onInkChanged: requestPaint()
    onSizeChanged: requestPaint()
    Connections {
        target: Colors

        function onIconChanged(): void {
            root.requestPaint();
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const m = map;
        if (!m)
            return;
        const px = size / 16, pal = Colors.icon, solid = ink.a > 0;
        // the halo first: empty pixels touching ink
        if (!solid && pal.h.a > 0) {
            ctx.fillStyle = pal.h;
            for (let y = 0; y < 16; y++)
                for (let x = 0; x < 16; x++) {
                    if (m[y][x] !== ".")
                        continue;
                    let near = false;
                    for (let j = -1; j <= 1 && !near; j++)
                        for (let i = -1; i <= 1 && !near; i++)
                            near = y + j >= 0 && y + j < 16 && m[y + j][x + i] === "k";
                    if (near)
                        ctx.fillRect(x * px, y * px, px, px);
                }
        }
        // then each run of one color in a row
        for (let y = 0; y < 16; y++) {
            const row = m[y];
            let x = 0;
            while (x < 16) {
                const c = row[x];
                if (c === ".") {
                    x++;
                    continue;
                }
                let w = 1;
                while (x + w < 16 && row[x + w] === c)
                    w++;
                ctx.fillStyle = solid ? ink : (pal[c] ?? pal.k);
                ctx.fillRect(x * px, y * px, w * px, px);
                x += w;
            }
        }
    }
}
