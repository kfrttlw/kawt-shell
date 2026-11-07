import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// a page's name, big, and one dim line of what's on it
ColumnLayout {
    property string title: ""
    property string note: ""

    Layout.fillWidth: true
    Layout.bottomMargin: 4
    spacing: 0

    Label {
        text: parent.title
        font.pixelSize: Metrics.times(2)
    }

    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: parent.note
        color: Colors.dim
    }
}
