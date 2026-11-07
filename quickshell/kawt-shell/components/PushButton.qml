import QtQuick
import qs.config

// A plain raised button with words: "Close", "Own theme…" (the dots: it opens another window);
// greyed out while it can't be pressed (enabled: false). `isDefault`: the one enter presses, with
// a dark line around it, as old dialogs had.
BarBox {
    id: root

    property string text: ""
    property int minWidth: Math.round(84 * Metrics.scale) // 0: as wide as its words
    property bool isDefault: false
    // the line around the default one (not in the row the words are in)
    property Item outline: Rectangle {
        parent: root
        visible: root.isDefault
        x: -1
        y: -1
        z: 1
        width: root.width + 2
        height: root.height + 2
        color: "transparent"
        border.color: Colors.fg
        border.width: 1
    }

    plain: false
    implicitWidth: Math.max(minWidth, words.implicitWidth + 20)
    implicitHeight: Metrics.fontSize + 13

    Label {
        id: words

        text: root.text
        color: root.enabled ? Colors.fg : Colors.dim // greyed out when it can't be pressed
    }
}
