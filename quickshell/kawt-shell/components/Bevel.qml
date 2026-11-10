import QtQuick
import qs.config

// A frame the old way: two lines on every side. Raised (a button, a panel): light on the top and
// the left, dark on the bottom and the right. Sunk (a field, a list) and pressed: the other way
// round. Etched: a groove, for a box of things inside a panel. Laid over its parent's area, it
// draws only the edges: the face under it is the parent's own.
// Inset: one dark line on the top and the left, one light on the bottom and the right (the
// bar's tray).
//
//   raised   hi  hi2 | lo  deep        sunk     lo  deep | hi2 hi
//   pressed  deep lo | hi2 hi          etched   lo  hi (each side: a dark line, a light one in it)
//   well     lo | hi (1 px: the tray)  bump     hi | lo (1 px: a tray icon under the pointer)
Item {
    id: root

    property string style: "raised" // "raised" | "sunk" | "pressed" | "etched" | "inset" (= "well") | "bump"
    // other edge colors than kawt's now ({ hi, hi2, lo, deep }: the theme editor's little desktop)
    property var colors: null
    readonly property var c: colors ?? Colors

    anchors.fill: parent

    // [outer top-left, outer bottom-right, inner top-left, inner bottom-right]
    readonly property var edges: style === "sunk" ? [c.lo, c.hi, c.deep, c.hi2] : style === "pressed" ? [c.deep, c.hi, c.lo, c.hi2] : style === "inset" || style === "well" ? [c.lo, c.hi, "transparent", "transparent"] : style === "bump" ? [c.hi, c.lo, "transparent", "transparent"] : [c.hi, c.deep, c.hi2, c.lo]

    // etched: a dark frame, and a light one a pixel in and to the right
    Item {
        anchors.fill: parent
        visible: root.style === "etched"

        Rectangle {
            x: 1
            y: 1
            width: parent.width - 1
            height: parent.height - 1
            color: "transparent"
            border.color: root.c.hi
            border.width: 1
        }

        Rectangle {
            width: parent.width - 1
            height: parent.height - 1
            color: "transparent"
            border.color: root.c.lo
            border.width: 1
        }
    }

    Item {
        anchors.fill: parent
        visible: root.style !== "etched"

        // the outer lines: top and left, then bottom and right over their corners
        Rectangle {
            width: parent.width
            height: 1
            color: root.edges[0]
        }

        Rectangle {
            width: 1
            height: parent.height
            color: root.edges[0]
        }

        Rectangle {
            y: parent.height - 1
            width: parent.width
            height: 1
            color: root.edges[1]
        }

        Rectangle {
            x: parent.width - 1
            width: 1
            height: parent.height
            color: root.edges[1]
        }

        // the inner lines, a pixel in
        Rectangle {
            x: 1
            y: 1
            width: parent.width - 2
            height: 1
            color: root.edges[2]
        }

        Rectangle {
            x: 1
            y: 1
            width: 1
            height: parent.height - 2
            color: root.edges[2]
        }

        Rectangle {
            x: 1
            y: parent.height - 2
            width: parent.width - 2
            height: 1
            color: root.edges[3]
        }

        Rectangle {
            x: parent.width - 2
            y: 1
            width: 1
            height: parent.height - 2
            color: root.edges[3]
        }
    }
}
