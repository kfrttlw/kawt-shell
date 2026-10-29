import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Him out on the desktop: along the bottom edge, under the windows (made only while the
// workspace has none: Bar.qml), where he walks about, naps, sulks, dances to music.
// Only he takes clicks: the rest of the screen lets them through to the desktop.
// Click: he talks. Drag: along the edge (the pointer may go anywhere above). Double click: home
// for an hour.
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property int cell: Math.max(3, Math.round(4 * Metrics.scale))

    screen: forScreen
    color: "transparent"

    WlrLayershell.namespace: "kawt-companion"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // the whole screen, though only he and what he says are drawn: dragged, he follows the
    // pointer anywhere above (on an empty desktop nothing has the focus, and hyprland keeps the
    // pointer on a surface only then). A strip that grew for the drag had him jump up for a
    // frame each time: hyprland showed the strip's last picture at the top of the bigger window
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    margins.bottom: Metrics.bottomGap

    // only he takes the pointer; all of the screen while the button is down
    mask: Region {
        item: grab.pressed ? whole : actor
    }

    Item {
        id: whole

        anchors.fill: parent
    }

    Component.onCompleted: Companion.deskViews += 1
    Component.onDestruction: Companion.deskViews -= 1

    // where he was left last time (a share of the width: the screen may be another one now)
    property bool placed: false

    onWidthChanged: if (!placed && width > 0) {
        placed = true;
        walker.x = Math.round(Math.max(0, Math.min(1, Companion.deskAt)) * walker.max);
    }

    Walker {
        id: walker

        min: 0
        max: Math.max(1, Math.floor(root.width / root.cell) - 16)
        free: Companion.base === "idle" && !Companion.music && !grab.dragging
    }

    Connections {
        target: Companion

        function onStepChanged(): void {
            if (!grab.dragging)
                walker.tick();
        }
    }

    // him and what he says: the only part that takes the pointer
    Item {
        id: actor

        x: walker.x * root.cell
        y: root.height - height
        width: Math.max(him.width, talk.visible ? talk.width : 0)
        height: him.height + (talk.visible ? talk.height : 0)

        // kept on the screen at the right edge
        Bubble {
            id: talk

            width: implicitWidth
            x: Math.min(0, root.width - actor.x - width)
            tailX: him.width / 2 - x
        }

        Pet {
            id: him

            anchors.bottom: parent.bottom
            cell: root.cell
            facing: walker.facing
            anim: grab.dragging ? "wave" : walker.moving ? "walk" : Companion.base === "idle" && Companion.music ? "dance" : Companion.base

            MouseArea {
                id: grab

                property real startX: 0
                property real startY: 0
                property real startCell: 0
                property bool dragging: false

                function keep(): void {
                    Companion.deskAt = walker.max > 0 ? walker.x / walker.max : 0;
                }

                anchors.fill: parent
                cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                onPressed: mouse => {
                    const p = mapToGlobal(mouse.x, mouse.y);
                    startX = p.x;
                    startY = p.y;
                    startCell = walker.x;
                }
                onPositionChanged: mouse => {
                    const p = mapToGlobal(mouse.x, mouse.y), dx = p.x - startX;
                    if (!dragging && (Math.abs(dx) > 6 || Math.abs(p.y - startY) > 6))
                        dragging = true;
                    if (dragging)
                        walker.x = Math.max(walker.min, Math.min(walker.max, Math.round(startCell + dx / root.cell)));
                }
                // a drag isn't a click: the flag goes only after the click that follows it
                onReleased: {
                    if (dragging)
                        keep();
                    Qt.callLater(() => grab.dragging = false);
                }
                onClicked: if (!dragging)
                    Companion.talkNow()
                // the pointer was taken away (over the bar): he stays where he got to
                onCanceled: {
                    if (dragging)
                        keep();
                    dragging = false;
                }
                onDoubleClicked: Companion.hide()
            }
        }
    }
}
