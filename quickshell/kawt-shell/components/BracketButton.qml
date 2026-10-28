import QtQuick
import qs.config

// [tag label]: the basic bar/popover button. `tag` is drawn dimmed. textColor says what it is,
// as everywhere in kawt: accent = chosen / on, dim = off, warn = careful, fg = just a button.
// components/Brackets.qml draws it so.
BarBox {
    id: root

    property string label: ""
    property string tag: ""
    property color textColor: Colors.fg
    // open (its panel is) counts as chosen
    readonly property string look: Qt.colorEqual(textColor, Colors.accent) || active ? "on" : Qt.colorEqual(textColor, Colors.warn) ? "warn" : Qt.colorEqual(textColor, Colors.dim) ? "off" : ""

    Brackets {
        text: root.label
        tag: root.tag
        look: root.look
    }
}
