import QtQuick
import Quickshell
import qs.config

// A tooltip: what this is and what a click or the wheel does. Shown under the item it's in (over
// it with the bar at the bottom) after half a second of hovering, gone when the pointer leaves.
//   Tip { text: "Sound 44%"; hovered: area.containsMouse }
Item {
    id: root

    property string text: ""
    property bool hovered: false
    property Item target: parent
    property bool shown: false

    onHoveredChanged: if (!hovered)
        shown = false
    onTextChanged: if (text === "")
        shown = false

    Timer {
        running: root.hovered && root.text !== "" && !root.shown
        interval: 500
        onTriggered: root.shown = true
    }

    PopupWindow {
        visible: root.shown && root.target !== null && root.target.visible
        anchor.item: root.target
        anchor.rect.x: 0
        anchor.rect.y: -3
        anchor.rect.width: root.target?.width ?? 0
        anchor.rect.height: (root.target?.height ?? 0) + 6
        anchor.edges: Metrics.barBottom ? Edges.Top : Edges.Bottom
        anchor.gravity: Metrics.barBottom ? Edges.Top : Edges.Bottom
        implicitWidth: words.implicitWidth + 10
        implicitHeight: words.implicitHeight + 6
        color: Colors.deep

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: Colors.tip
        }

        Label {
            id: words

            anchors.centerIn: parent
            text: root.text
            color: Colors.fg
        }
    }
}
