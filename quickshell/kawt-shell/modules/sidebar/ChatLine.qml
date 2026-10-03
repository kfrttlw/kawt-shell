import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// you> / ai> / !!> line in the chat log
Item {
    id: root

    property string kind: "assistant" // user | assistant | error
    property string text: ""
    property bool streaming: false
    property real topPadding: 0
    property bool cursorOn: true

    implicitHeight: row.implicitHeight + topPadding

    Timer {
        running: root.streaming && root.visible
        repeat: true
        interval: 530
        onTriggered: root.cursorOn = !root.cursorOn
    }

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: Metrics.spacing

        Label {
            Layout.alignment: Qt.AlignTop
            text: root.kind === "user" ? "you>" : root.kind === "error" ? "!!>" : " ai>"
            color: root.kind === "user" ? Colors.dim : root.kind === "error" ? Colors.warn : Colors.accent
        }

        TextEdit {
            // read-only but selectable, so answers can be copied
            Layout.fillWidth: true
            readOnly: true
            selectByMouse: !root.streaming
            wrapMode: TextEdit.Wrap
            text: root.text + (root.streaming && root.cursorOn ? "█" : "")
            color: root.kind === "error" ? Colors.dim : Colors.fg
            selectionColor: Colors.accent
            selectedTextColor: Colors.bg
            font.family: Metrics.fontFamily
            font.pixelSize: Metrics.fontSize
        }
    }
}
