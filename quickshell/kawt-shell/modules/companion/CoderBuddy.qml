import QtQuick
import qs.config
import qs.components
import qs.services

// The companion next to the coder (ai panel -> coder): he thinks while the model does, types
// while a tool runs, raises a flag when a diff waits for you, cheers when it's applied, holds
// his head on an error, sweeps up after [undo]. Idle, he's just himself.
Item {
    id: root

    readonly property int cell: Math.max(2, Math.round(3 * Metrics.scale))
    readonly property var last: Coder.steps.length ? Coder.steps[Coder.steps.length - 1] : null
    readonly property string lastKey: last ? `${last.id}:${last.status}:${last.kind}` : ""
    property string flash: "" // a moment's move after something happened

    implicitWidth: him.width + (talk.visible ? talk.width + Metrics.spacing : 0)
    implicitHeight: him.height

    function show(anim: string, kind: string): void {
        flash = anim;
        flashTimer.restart();
        if (kind)
            Companion.say(Companion.line(kind, ""), 2500);
    }

    Timer {
        id: flashTimer

        interval: 2200
        onTriggered: root.flash = ""
    }

    onLastKeyChanged: {
        const s = last;
        if (!s)
            return;
        if (s.status === "applied")
            show("happy", "");
        else if (s.kind === "error")
            show("error", "oops");
        else if (s.kind === "answer")
            show("happy", "done");
        else if (s.kind === "info" && s.text.startsWith("undo"))
            show("sweep", "swept");
    }

    // a task wakes him
    Connections {
        target: Coder

        function onRunningChanged(): void {
            if (Coder.running && Companion.sleeping)
                Companion.wake(false);
        }
    }

    Pet {
        id: him

        cell: root.cell
        anim: root.flash || (Coder.pending ? "flag" : Coder.thinking ? "think" : Coder.running ? "typing" : Companion.base)

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Companion.talkNow()
        }
    }

    Bubble {
        id: talk

        anchors.left: him.right
        anchors.leftMargin: Metrics.spacing
        anchors.verticalCenter: him.verticalCenter
        width: implicitWidth
        maxWidth: Math.round(220 * Metrics.scale)
        tailX: -10 // no tail: he's beside it
    }
}
