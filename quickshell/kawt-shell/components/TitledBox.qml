import QtQuick
import qs.config

// ┌─title──────────┐  box with the title sitting on the top border line
Rectangle {
    id: root

    property string title: ""
    property string hint: ""
    readonly property real titleOverhang: title !== "" ? titleText.implicitHeight / 2 : 0

    color: Colors.bg
    border.color: Colors.border
    border.width: Metrics.borderWidth
    radius: Metrics.radius

    Rectangle {
        visible: root.title !== ""
        x: Metrics.padding
        y: -height / 2
        width: titleText.implicitWidth + 4
        height: titleText.implicitHeight
        color: Colors.bg

        Label {
            id: titleText

            anchors.centerIn: parent
            text: root.title
            color: Colors.accent
        }
    }

    Rectangle {
        visible: root.hint !== ""
        anchors.right: parent.right
        anchors.rightMargin: Metrics.padding
        y: -height / 2
        width: hintText.implicitWidth + 4
        height: hintText.implicitHeight
        color: Colors.bg

        Label {
            id: hintText

            anchors.centerIn: parent
            text: root.hint
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }
    }
}
