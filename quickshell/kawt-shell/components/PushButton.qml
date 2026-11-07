import QtQuick
import qs.config

// A plain raised button with words: "Close", "Own theme…" (the dots: it opens another window);
// greyed out while it can't be pressed (enabled: false)
BarBox {
    id: root

    property string text: ""
    property int minWidth: Math.round(84 * Metrics.scale) // 0: as wide as its words

    plain: false
    implicitWidth: Math.max(minWidth, words.implicitWidth + 20)
    implicitHeight: Metrics.fontSize + 13

    Label {
        id: words

        text: root.text
        color: root.enabled ? Colors.fg : Colors.dim // greyed out when it can't be pressed
    }
}
