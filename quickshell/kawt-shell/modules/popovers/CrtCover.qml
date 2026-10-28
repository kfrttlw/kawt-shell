import QtQuick
import qs.config

// The album cover as an old phosphor screen shows it: a few big pixels in four shades of the
// theme's text color (ordered dithering; green on phosphor, ink on thinkpad), a dark line under every row of them, drawn top to bottom
// when the cover changes. Painted once per cover and theme, nothing moves meanwhile.
// Without a cover (or one only online, while those aren't allowed): a note in the same pixels.
Item {
    id: root

    property string source: ""
    property int cells: 24 // pixels across and down: covers are square (others are cut to it)
    readonly property int cell: Math.max(3, Math.round(4 * Metrics.scale))
    readonly property bool hasPicture: picture.status === Image.Ready
    readonly property color tint: Colors.fg
    readonly property color base: Colors.bg
    readonly property bool light: Colors.light

    // ordered dithering, 4x4 bayer
    readonly property var bayer: [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
    property int rows: cells // rows drawn so far: a new cover comes in a row at a time
    readonly property var note: ["............", "......####..", "......#####.", "......#..##.", "......#...#.", "......#.....", "......#.....", "...####.....", "..#####.....", "..#####.....", "...###......", "............"]

    implicitWidth: cells * cell
    implicitHeight: cells * cell

    onTintChanged: canvas.requestPaint()
    onBaseChanged: canvas.requestPaint()
    onLightChanged: canvas.requestPaint()

    Image {
        id: picture

        visible: false
        source: root.source
        asynchronous: true
        sourceSize.width: root.cells * 4
        onStatusChanged: if (status === Image.Ready || status === Image.Null || status === Image.Error)
            canvas.redraw()
    }

    Canvas {
        id: canvas

        anchors.fill: parent

        function redraw(): void {
            requestPaint();
            wipe.restart();
        }

        onPaint: {
            const ctx = getContext("2d");
            const n = root.cells, c = root.cell;
            ctx.clearRect(0, 0, width, height);
            // the shade of each pixel, 0..1
            let shade = [];
            if (root.hasPicture) {
                // the middle square of it, n x n, to read the pixels from
                const w = picture.implicitWidth, h = picture.implicitHeight, s = Math.min(w, h);
                ctx.drawImage(picture, (w - s) / 2, (h - s) / 2, s, s, 0, 0, n, n);
                const px = ctx.getImageData(0, 0, n, n).data;
                ctx.clearRect(0, 0, width, height);
                for (let i = 0; i < n * n; i++) {
                    let l = (0.299 * px[i * 4] + 0.587 * px[i * 4 + 1] + 0.114 * px[i * 4 + 2]) / 255;
                    if (root.light)
                        l = 1 - l;
                    // four levels; the bayer threshold spreads what falls between them
                    const t = (root.bayer[(Math.floor(i / n) % 4) * 4 + i % n % 4] + 0.5) / 16;
                    shade.push(Math.min(3, Math.floor(l * 3 + t)) / 3);
                }
            } else {
                // the note, centered: 12 x 12 scaled to the cells
                for (let i = 0; i < n * n; i++) {
                    const y = Math.floor(Math.floor(i / n) * 12 / n), x = Math.floor(i % n * 12 / n);
                    shade.push(root.note[y][x] === "#" ? 0.5 : 0);
                }
            }
            const mix = (a, b, t) => Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
            // even the darkest pixel shows a little: the screen is on
            const shades = [0, 1, 2, 3].map(k => mix(root.base, root.tint, 0.07 + k / 3 * 0.93).toString());
            for (let i = 0; i < n * n; i++) {
                ctx.fillStyle = shades[Math.round(shade[i] * 3)];
                // one pixel row less: the dark line between the rows
                ctx.fillRect(i % n * c, Math.floor(i / n) * c, c, c - 1);
            }
        }
    }

    // the rows not drawn yet
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: (root.cells - root.rows) * root.cell
        color: Colors.bg
    }

    NumberAnimation {
        id: wipe

        target: root
        property: "rows"
        from: 0
        to: root.cells
        duration: 280
    }

    Component.onCompleted: canvas.requestPaint()

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Colors.border
        border.width: Metrics.borderWidth
    }
}
