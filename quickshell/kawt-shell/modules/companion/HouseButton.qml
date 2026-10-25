import QtQuick
import qs.config
import qs.components
import qs.services

// [⌂] the companion's house in the bar, a few pixels: the window lit while he's home and
// awake, the door open while he's out on the desktop. After it: z asleep, ! when he wants
// something (food, a game, sleep), the minutes of a running pomodoro.
BarBox {
    id: root

    readonly property int cell: Math.max(1, Math.round(2 * Metrics.scale))
    readonly property bool out: Companion.deskViews > 0
    readonly property bool lit: !out && !Companion.sleeping
    readonly property string tag: Companion.pomoPhase ? `${Companion.pomoLeft}m` : Companion.wants || Companion.sulking ? "!" : Companion.sleeping ? "z" : ""
    readonly property var rows: [
        ".....#.....",
        "....###....",
        "...#####...",
        "..#######..",
        ".#########.",
        "..#.....#..",
        "..#LL.DD#..",
        "..#LL.DD#..",
        "..#######.."
    ]

    visible: Companion.enabled && Settings.barShows("home")
    spacing: Metrics.spacing

    onLitChanged: house.requestPaint()
    onOutChanged: house.requestPaint()

    Connections {
        target: Colors

        function onPaletteChanged(): void {
            house.requestPaint();
        }
    }

    Canvas {
        id: house

        width: 11 * root.cell
        height: 9 * root.cell
        anchors.verticalCenter: parent.verticalCenter

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const c = root.cell;
            const colors = {
                "#": Colors.fg.toString(),
                "L": (root.lit ? Colors.accent : Colors.border).toString(),
                "D": (root.out ? Colors.bg : Colors.dim).toString()
            };
            for (let y = 0; y < root.rows.length; y++)
                for (let x = 0; x < root.rows[y].length; x++) {
                    const ch = root.rows[y][x];
                    if (ch === ".")
                        continue;
                    ctx.fillStyle = colors[ch];
                    ctx.fillRect(x * c, y * c, c, c);
                }
        }
    }

    Label {
        visible: root.tag !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: root.tag
        color: root.tag === "!" ? Colors.warn : Colors.dim
    }
}
