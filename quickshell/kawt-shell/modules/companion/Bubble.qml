import QtQuick
import qs.config
import qs.components
import qs.services

// What he says, in a small box with a tail pointing down at him. Shown while there's
// something said (Companion.said); `text` can be given instead.
Item {
    id: root

    property string text: Companion.said
    property int maxWidth: Math.round(240 * Metrics.scale)
    property real tailX: width / 2 // where he is, under the box

    visible: text !== ""
    implicitWidth: Math.min(maxWidth, words.implicitWidth + Metrics.padding * 2)
    implicitHeight: box.height + tail.height

    Rectangle {
        id: box

        width: parent.width
        height: words.height + Metrics.spacing * 2
        color: Colors.bg
        border.color: Colors.border
        border.width: Metrics.borderWidth

        Label {
            id: words

            x: Metrics.padding
            y: Metrics.spacing
            width: root.width - Metrics.padding * 2
            wrapMode: Text.Wrap
            text: root.text
            color: Colors.fg
            font.pixelSize: Metrics.fontSize - 1
        }
    }

    // the tail: a little step of pixels
    Column {
        id: tail

        anchors.top: box.bottom
        anchors.topMargin: -Metrics.borderWidth
        x: Math.max(Metrics.padding, Math.min(root.width - Metrics.padding - width, root.tailX - width / 2))

        Rectangle {
            width: 6
            height: 3
            color: Colors.bg
            border.color: Colors.border
            border.width: Metrics.borderWidth
        }

        Rectangle {
            x: 1
            width: 3
            height: 3
            color: Colors.border
        }
    }
}
