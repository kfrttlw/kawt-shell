import QtQuick
import qs.config
import qs.services

// stripes next to the coder (ai panel -> coder): she thinks while the model does, types while a
// tool runs, puts kawt's red block over her head when a diff waits for you, hops when it's
// applied, glitches on an error and after Undo. Idle, she's just herself.
Item {
    id: root

    property point origin: Qt.point(0, 0) // the panel's top left on its screen (for her eyes)
    property var forScreen: null
    readonly property var last: Coder.steps.length ? Coder.steps[Coder.steps.length - 1] : null
    readonly property string lastKey: last ? `${last.id}:${last.status}:${last.kind}` : ""

    implicitWidth: her.width + (talk.visible ? talk.width + Metrics.spacing : 0)
    implicitHeight: her.height

    function show(move: string, kind: string): void {
        if (move === "hop")
            her.hop();
        else
            Companion.glitch(700);
        if (kind)
            Companion.say(Companion.line(kind, ""), 2500);
    }

    onLastKeyChanged: {
        const s = last;
        if (!s)
            return;
        if (s.status === "applied")
            show("hop", "");
        else if (s.kind === "error")
            show("glitch", "oops");
        else if (s.kind === "answer")
            show("hop", "done");
        else if (s.kind === "info" && s.text.startsWith("undo"))
            show("glitch", "swept");
    }

    // a task wakes her
    Connections {
        target: Coder

        function onRunningChanged(): void {
            if (Coder.running)
                Companion.touch();
        }
    }

    Her {
        id: her

        size: Math.round(96 * Metrics.scale)
        forScreen: root.forScreen
        origin: root.origin
        anim: Coder.pending ? "flag" : Coder.thinking ? "think" : Coder.running ? "type" : Companion.base

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Companion.talkNow()
        }
    }

    Bubble {
        id: talk

        anchors.left: her.right
        anchors.leftMargin: Metrics.spacing
        anchors.verticalCenter: her.verticalCenter
        width: implicitWidth
        maxWidth: Math.round(220 * Metrics.scale)
        tailX: -10 // no tail: she's beside it
    }
}
