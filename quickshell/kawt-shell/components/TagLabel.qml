import QtQuick
import qs.config

// tag ▮▮▮▯▯ label: the words of a button on the console lock and the boot screen. The tag is
// dim before the label; `look` says what it is, as everywhere in kawt: "on" chosen (red),
// "off" switched off (dim), "warn" careful (red), "" just a button.
// A plain word without a button around it is something to read, not to press.
Row {
    id: root

    property string text: ""
    property string tag: ""
    property string look: "" // "" | "on" | "off" | "warn"
    property real meter: -1 // 0..1: a level in segments between the tag and the label (vol, br)
    property color ink: "transparent" // the label in its own color, whatever the look
    property alias font: label.font

    Label {
        visible: root.tag !== ""
        text: root.tag + " "
        color: Colors.dim
        font: label.font
    }

    Meter {
        visible: root.meter >= 0
        anchors.verticalCenter: parent.verticalCenter
        value: root.meter
    }

    Label {
        id: label

        leftPadding: root.meter >= 0 ? Metrics.spacing : 0
        text: root.text
        color: root.ink.a > 0 ? root.ink : root.look === "warn" ? Colors.warn : root.look === "off" ? Colors.dim : root.look === "on" ? Colors.accent : Colors.fg
    }
}
