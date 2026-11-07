import QtQuick
import qs.config

// A plain raised button with words: "Close", "Own theme…" (the dots: it opens another window);
// greyed out while it can't be pressed (enabled: false). `isDefault`: the one enter presses, with
// a dark line around it, as old dialogs had. `small`: a low one, as wide as its words (in a chat
// line, under a step); `tag`: a dim key before the words ("1 Explain").
BarBox {
    id: root

    property string text: ""
    property string tag: ""
    property bool small: false
    property int minWidth: small ? 0 : Math.round(84 * Metrics.scale) // 0: as wide as its words
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
    implicitWidth: Math.max(minWidth, words.implicitWidth + (tagWord.visible ? tagWord.implicitWidth + 6 : 0) + (small ? 12 : 20))
    implicitHeight: Metrics.fontSize + (small ? 7 : 13)
    spacing: 6

    Label {
        id: tagWord

        visible: root.tag !== ""
        text: root.tag
        color: Colors.dim
    }

    Label {
        id: words

        text: root.text
        color: root.enabled ? Colors.fg : Colors.dim // greyed out when it can't be pressed
    }
}
