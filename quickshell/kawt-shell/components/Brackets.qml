import QtQuick
import qs.config

// [label]: how kawt marks what you can press. The brackets are a step dimmer than the words,
// red around what's chosen (look "on"), darker around what's switched off ("off"), red with red
// words for a warning ("warn"). Settings.brackets off: no brackets, the chosen ones red instead.
// A plain word without them is something to read, not to press.
Row {
    id: root

    property string text: ""
    property string tag: "" // [tag label]: the tag dim before the label
    property string look: "" // "" | "on" | "off" | "warn"
    property bool shown: true // false: the room stays, the brackets don't (tabs that line up)
    property real meter: -1 // 0..1: a level in segments between the tag and the label (vol, br)
    property color ink: "transparent" // the label in its own color (the profile's red dot)
    property alias font: label.font

    Bracket {
        look: root.look
        shown: root.shown
        font: label.font
    }

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
        color: root.ink.a > 0 ? root.ink : root.look === "warn" ? Colors.warn : root.look === "off" ? Colors.dim : root.look === "on" && !Settings.brackets ? Colors.accent : Colors.fg
    }

    Bracket {
        closing: true
        look: root.look
        shown: root.shown
        font: label.font
    }
}
