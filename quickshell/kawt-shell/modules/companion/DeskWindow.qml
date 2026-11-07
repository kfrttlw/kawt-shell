import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Her out on the desktop: along the bottom edge, under the windows (made only while the
// workspace has none: Bar.qml), where she walks about, dances to music, and falls asleep when
// nothing happens. Only she takes clicks: the rest of the screen lets them through to the desktop.
// Click: she talks (asleep: she wakes). Drag: along the edge (the pointer may go anywhere above).
// Double click: away for an hour.
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property int stepPx: Math.max(3, Math.round(5 * Metrics.scale)) // one step of hers

    screen: forScreen
    color: "transparent"

    WlrLayershell.namespace: "kawt-companion"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // the whole screen, though only she and what she says are drawn: dragged, she follows the
    // pointer anywhere above (on an empty desktop nothing has the focus, and hyprland keeps the
    // pointer on a surface only then). A strip that grew for the drag had her jump up for a
    // frame each time: hyprland showed the strip's last picture at the top of the bigger window
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    margins.bottom: Metrics.bottomGap

    // only she takes the pointer (what she says lets it through); all of the screen while the
    // button is down
    mask: Region {
        item: grab.pressed ? whole : grab
    }

    Item {
        id: whole

        anchors.fill: parent
    }

    // a new empty desktop: she's up to see it (at night she sleeps on)
    Component.onCompleted: {
        Companion.deskViews += 1;
        if (!Companion.night)
            Companion.touch();
    }
    Component.onDestruction: Companion.deskViews -= 1

    // where she was left last time (a share of the width: the screen may be another one now)
    property bool placed: false

    onWidthChanged: if (!placed && width > 0) {
        placed = true;
        walker.x = Math.round(Math.max(0, Math.min(1, Companion.deskAt)) * walker.max);
    }

    Walker {
        id: walker

        min: 0
        max: Math.max(1, Math.floor((root.width - her.width) / root.stepPx))
        free: Companion.base === "" && !Companion.music && !grab.dragging
    }

    Connections {
        target: Companion

        function onStepChanged(): void {
            if (!grab.dragging)
                walker.tick();
        }
    }

    // she and what she says
    Item {
        id: actor

        x: walker.x * root.stepPx
        y: root.height - height
        width: Math.max(her.width, talk.visible ? talk.width : 0)
        // the bubble a little into the air over her hair
        height: her.height + (talk.visible ? Math.max(0, talk.height - her.height * 0.1) : 0)

        // kept on the screen at the right edge
        Bubble {
            id: talk

            width: implicitWidth
            x: Math.min(0, root.width - actor.x - width)
            tailX: her.width / 2 - x
        }

        Her {
            id: her

            anchors.bottom: parent.bottom
            size: Math.round(162 * Metrics.scale)
            facing: walker.facing
            forScreen: root.forScreen
            anim: grab.dragging ? "alarm" : walker.moving ? "walk" : Companion.base === "" && Companion.music ? "dance" : Companion.base
        }
    }

    // her, not the air around her hair: the only part that takes the pointer (a child of the
    // window itself, so the mask follows it as she walks)
    MouseArea {
        id: grab

        property real startX: 0
        property real startY: 0
        property real startStep: 0
        property bool dragging: false

        function keep(): void {
            Companion.deskAt = walker.max > 0 ? walker.x / walker.max : 0;
        }

        x: actor.x + her.width * 0.2
        y: root.height - her.height * 0.88
        width: her.width * 0.6
        height: her.height * 0.86
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        onPressed: mouse => {
            const p = mapToGlobal(mouse.x, mouse.y);
            startX = p.x;
            startY = p.y;
            startStep = walker.x;
        }
        onPositionChanged: mouse => {
            const p = mapToGlobal(mouse.x, mouse.y), dx = p.x - startX;
            if (!dragging && (Math.abs(dx) > 6 || Math.abs(p.y - startY) > 6))
                dragging = true;
            if (dragging)
                walker.x = Math.max(walker.min, Math.min(walker.max, Math.round(startStep + dx / root.stepPx)));
        }
        // a drag isn't a click: the flag goes only after the click that follows it
        onReleased: {
            if (dragging)
                keep();
            Qt.callLater(() => grab.dragging = false);
        }
        onClicked: if (!dragging)
            Companion.talkNow()
        // the pointer was taken away (over the bar): she stays where she got to
        onCanceled: {
            if (dragging)
                keep();
            dragging = false;
        }
        onDoubleClicked: Companion.hide()
    }
}
