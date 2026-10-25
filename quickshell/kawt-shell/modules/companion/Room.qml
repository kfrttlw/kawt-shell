import QtQuick
import qs.config
import qs.components
import qs.services

// His room in the house: a window (the sky as it is outside: day, or night with stars), his
// bed, his bowl (as full as he is), and him, wandering about. Asleep he's in bed; fed he goes
// to the bowl; a game brings out the ball; music, and he dances.
Item {
    id: root

    readonly property int cell: Math.max(2, Math.round(3 * Metrics.scale))
    readonly property int cols: Math.floor(width / cell)
    readonly property int rowsN: 26
    readonly property int floorY: rowsN - 3 // the floor's top row
    readonly property int bedX: 2
    readonly property int bedW: 20
    readonly property int bowlX: cols - 11
    readonly property bool dark: Companion.night || new Date(Companion.now).getHours() >= 22 || new Date(Companion.now).getHours() < 6
    readonly property int bowl: Companion.food > 0.6 ? 2 : Companion.food > 0.25 ? 1 : 0
    readonly property bool eating: Companion.act === "eat"
    readonly property bool playing: Companion.act === "jump"

    implicitHeight: rowsN * cell

    onDarkChanged: room.requestPaint()
    onBowlChanged: room.requestPaint()
    onColsChanged: room.requestPaint()

    Connections {
        target: Colors

        function onPaletteChanged(): void {
            room.requestPaint();
        }
    }

    Walker {
        id: walker

        min: root.bedX + root.bedW - 4
        max: Math.max(min + 1, root.bowlX - 14)
        x: min + 4
        free: Companion.base === "idle" && !Companion.music
    }

    Connections {
        target: Companion

        function onStepChanged(): void {
            walker.tick();
        }

        // fed: off to the bowl
        function onActChanged(): void {
            if (Companion.act === "eat")
                walker.goal = root.bowlX - 13;
        }
    }

    Canvas {
        id: room

        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            const c = root.cell, w = root.cols;
            const px = (x, y, wd, ht, col) => {
                ctx.fillStyle = col;
                ctx.fillRect(x * c, y * c, wd * c, ht * c);
            };
            const mix = (a, b, t) => Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1).toString();
            const wall = mix(Colors.bg, Colors.border, 0.25), line = Colors.border.toString();
            ctx.clearRect(0, 0, width, height);
            px(0, 0, w, root.floorY, wall);
            // the floor: planks
            px(0, root.floorY, w, 3, mix(Colors.bg, Colors.border, 0.7));
            for (let x = 3; x < w; x += 9)
                px(x, root.floorY + 1, 1, 2, line);
            px(0, root.floorY, w, 1, line);
            // the window, with the sky in it
            const wx = Math.floor(w / 2) - 7, wy = 3;
            px(wx - 1, wy - 1, 16, 11, line);
            px(wx, wy, 14, 9, root.dark ? Colors.bg.toString() : mix(Colors.bg, Colors.accent, 0.22));
            if (root.dark)
                for (const [sx, sy] of [[2, 2], [9, 1], [5, 5], [12, 4], [7, 7]])
                    px(wx + sx, wy + sy, 1, 1, Colors.accent.toString());
            else
                px(wx + 10, wy + 2, 2, 2, mix(Colors.bg, Colors.accent, 0.8)); // the sun
            px(wx + 7, wy, 1, 9, line);
            px(wx, wy + 4, 14, 1, line);
            // the bed: frame, mattress, blanket in his color, pillow
            const s = Companion.skin?.colors ?? {};
            const by = root.floorY - 4;
            px(root.bedX, by, root.bedW, 4, line);
            px(root.bedX + 1, by, root.bedW - 2, 2, mix(Colors.bg, Colors.fg, 0.3));
            px(root.bedX + 7, by, root.bedW - 8, 2, s.b ?? Colors.accent.toString());
            px(root.bedX + 2, by - 1, 4, 2, s.l ?? Colors.fg.toString());
            px(root.bedX, by - 3, 1, 7, line);
            px(root.bedX + root.bedW - 1, by - 1, 1, 5, line);
            // the bowl, and what's left in it
            const bx = root.bowlX, fy = root.floorY - 2;
            if (root.bowl > 0)
                px(bx + 1, fy - 1, root.bowl === 2 ? 5 : 3, 1, "#e0a040");
            px(bx, fy, 7, 1, Colors.dim.toString());
            px(bx + 1, fy + 1, 5, 1, Colors.dim.toString());
        }
    }

    // the clock of the pomodoro, on the wall
    Label {
        visible: Companion.pomoPhase !== ""
        x: root.cell * 3
        y: root.cell * 3
        text: Companion.pomoPhase === "break" ? `[break ${Companion.pomoLeft}m]` : `[${Companion.pomoLeft}m]`
        color: Companion.pomoPhase === "break" ? Colors.accent : Colors.fg
        font.pixelSize: Metrics.fontSize - 2
    }

    // do not disturb: a sign on the door
    Label {
        visible: Settings.dnd
        anchors.right: parent.right
        anchors.rightMargin: root.cell * 3
        y: root.cell * 3
        text: "[shh]"
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }

    Pet {
        id: him

        cell: root.cell
        // in bed asleep; walking, dancing, or whatever he's busy with
        x: Companion.sleeping ? (root.bedX + 3) * root.cell : walker.x * root.cell
        y: (Companion.sleeping ? root.floorY - 18 : root.floorY - 14) * root.cell
        facing: walker.facing
        anim: walker.moving ? "walk" : Companion.base === "idle" && Companion.music ? "dance" : Companion.base

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Companion.talkNow()
        }
    }

    // the ball, while he plays
    Rectangle {
        visible: root.playing
        width: root.cell * 2
        height: root.cell * 2
        color: "#e0a040"
        x: him.x + (Companion.step % 2 ? 13 : 1) * root.cell
        y: him.y + [10, 4, 1, 4, 10, 12][Companion.step % 6] * root.cell
    }

    // zzz, rising
    Label {
        visible: Companion.sleeping
        x: him.x + 11 * root.cell
        y: him.y - (Companion.step % 12) * root.cell / 4
        text: ["z", "z z", "z z Z"][Math.floor(Companion.step / 6) % 3]
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }

    // ♪ while something plays
    Label {
        visible: Companion.music && !Companion.sleeping
        x: him.x + (Companion.step % 4 < 2 ? 13 : 12) * root.cell
        y: him.y + (Companion.step % 4 < 2 ? 0 : 1) * root.cell
        text: "♪"
        color: Colors.accent
    }

    Bubble {
        width: implicitWidth
        x: Math.max(0, Math.min(root.width - width, him.x + him.width / 2 - width / 2))
        y: Math.max(0, him.y - height + root.cell * 2)
        tailX: him.x + him.width / 2 - x
        maxWidth: Math.min(root.width, Math.round(200 * Metrics.scale))
    }
}
