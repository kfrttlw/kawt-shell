import QtQuick
import qs.config

// [tag label] — the basic bar/popover button. `tag` is drawn dimmed.
BarBox {
    id: root

    property string label: ""
    property string tag: ""
    property color textColor: Colors.fg

    Label {
        text: "["
        color: root.textColor
    }

    Label {
        visible: root.tag !== ""
        text: root.tag + " "
        color: Colors.dim
    }

    Label {
        text: root.label
        color: root.textColor
    }

    Label {
        text: "]"
        color: root.textColor
    }
}
