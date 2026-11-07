import QtQuick
import qs.config
import qs.components
import qs.services

// stripes herself: shaders/stripes.frag on a layer of 72 x 108, stretched soft to `size`. While
// one of these is on the screen her clock runs (Companion.viewers); with none, nothing ticks.
// `anim` is what she's doing:
//   ""      herself              walk   leaning the way she goes (`facing`)
//   sleep   slumped, eyes shut   yawn   half of that, for a moment
//   think   hot, looking up      type   hotter, looking down
//   flag    kawt's red block over her head: something waits for you
//   alarm   torn by glitches     dance  swaying
// A hop (Companion.hopped, or hop()) and a glitch (Companion.glitch) come on top of any of them.
// Her eyes follow the pointer: the host says where its window is (`origin`, `forScreen`).
Item {
    id: root

    property string anim: Companion.base
    property int facing: 1
    property int size: Math.round(150 * Metrics.scale) // her height
    property point origin: Qt.point(0, 0) // her window's top left on its screen
    property var forScreen: null // that screen (ShellScreen): the pointer comes in the layout's coordinates
    property vector2d gaze: Qt.vector2d(0, 0) // to the pointer, -1 .. 1
    property real rise: 0 // a hop, 0 .. 1

    implicitWidth: Math.round(size * 2 / 3)
    implicitHeight: size

    function hop(): void {
        if (anim !== "sleep")
            hopping.restart();
    }

    SequentialAnimation {
        id: hopping

        NumberAnimation {
            target: root
            property: "rise"
            to: 1
            duration: 150
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: root
            property: "rise"
            to: 0
            duration: 220
            easing.type: Easing.InQuad
        }
    }

    Connections {
        target: Companion

        function onHopped(): void {
            root.hop();
        }

        function onCursorChanged(): void {
            root.aim();
        }
    }

    // where the pointer is from her eyes: near, as far as it is; further off, just the way
    function aim(): void {
        const c = Companion.cursor;
        if (!c || !forScreen) {
            gaze = Qt.vector2d(0, 0);
            return;
        }
        const p = mapToItem(null, width / 2, height * 0.25);
        const dx = c.x - forScreen.x - origin.x - p.x, dy = c.y - forScreen.y - origin.y - p.y;
        const k = 1 / Math.max(120 * Metrics.scale, Math.hypot(dx, dy));
        gaze = Qt.vector2d(dx * k, dy * k);
    }

    ShaderEffect {
        id: fx

        width: root.width
        height: root.height
        y: -root.rise * root.height * 0.08

        // drawn at the grid's own size, then stretched: smooth, that's her soft edge
        layer.enabled: true
        layer.textureSize: Qt.size(72, 108)
        layer.smooth: true

        fragmentShader: Qt.resolvedUrl("../../shaders/stripes.frag.qsb")

        property real time: Companion.t
        property real fit: Math.max(Companion.fit, root.anim === "alarm" ? 0.3 + 0.3 * Math.max(0, Math.sin(Companion.t * 5)) : 0)
        property real blink: (Companion.blink || root.anim === "sleep" || root.anim === "yawn") ? 1 : 0
        property real sleep: root.anim === "sleep" ? 1 : root.anim === "yawn" ? 0.5 : 0
        property real heat: root.anim === "type" ? 1 : root.anim === "think" || root.anim === "dance" ? 0.5 : 0
        property real lean: root.anim === "walk" ? 0.7 * root.facing : root.anim === "dance" ? 0.5 * Math.sin(Companion.t * 4) : 0
        property real bars: Companion.look === "stripes" ? 1 : 0
        property real steps: Companion.ramp.n
        // busy, she looks at her work; walking, ahead; otherwise at the pointer
        property vector2d gaze: root.anim === "sleep" ? Qt.vector2d(0, 0) : root.anim === "think" || root.anim === "flag" ? Qt.vector2d(-0.5, -1) : root.anim === "type" ? Qt.vector2d(0, 1) : root.anim === "walk" ? Qt.vector2d(root.facing, 0) : root.gaze
        property vector4d eye: Companion.eyeColor
        property vector4d c0: Companion.ramp.c[0]
        property vector4d c1: Companion.ramp.c[1]
        property vector4d c2: Companion.ramp.c[2]
        property vector4d c3: Companion.ramp.c[3]
        property vector4d c4: Companion.ramp.c[4]
        property vector4d c5: Companion.ramp.c[5]
        property vector4d c6: Companion.ramp.c[6]
        property vector4d c7: Companion.ramp.c[7]
        property vector4d c8: Companion.ramp.c[8]

        Behavior on sleep {
            NumberAnimation {
                duration: 600
            }
        }
    }

    // something waits for you: kawt's red block over her head, blinking
    RedBlock {
        visible: root.anim === "flag"
        anchors.horizontalCenter: parent.horizontalCenter
        y: fx.y - height
        mode: "wait"
        barWidth: Math.round(root.width * 0.16)
    }

    // zzz, rising
    Label {
        visible: root.anim === "sleep"
        x: root.width * 0.68
        y: root.height * 0.12 - (Companion.step % 12) * root.height * 0.01
        text: ["z", "z z", "z z Z"][Math.floor(Companion.step / 6) % 3]
        color: Colors.dim
        font.pixelSize: Metrics.size(-2)
    }

    // she's on the screen: her clock runs
    readonly property bool counting: visible && Companion.enabled
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
