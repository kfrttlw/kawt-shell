import QtQuick
import qs.config

// A plain raised button with words: "Close", "Own theme…" (the dots: it opens another window)
BarBox {
    id: root

    property string text: ""

    plain: false
    implicitWidth: Math.max(Math.round(84 * Metrics.scale), words.implicitWidth + 20)
    implicitHeight: Metrics.fontSize + 13

    Label {
        id: words

        text: root.text
    }
}
