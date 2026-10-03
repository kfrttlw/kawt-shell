import QtQuick
import qs.config

// Single-line input with a prompt and a blinking block cursor
Item {
    id: root

    property alias text: input.text
    property alias echoMode: input.echoMode
    property alias input: input
    property string prompt: ">"
    property string placeholder: ""

    signal accepted(string text)

    implicitHeight: input.implicitHeight + 6

    Rectangle {
        anchors.fill: parent
        color: input.activeFocus ? Colors.hoverFill : Colors.bg
        border.color: input.activeFocus ? Colors.dim : Colors.border
        border.width: Metrics.borderWidth
    }

    Label {
        id: promptText

        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: root.prompt
        color: Colors.accent
    }

    TextInput {
        id: input

        anchors.left: promptText.right
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: Colors.fg
        font.family: Metrics.fontFamily
        font.pixelSize: Metrics.fontSize
        selectByMouse: true
        selectionColor: Colors.accent
        selectedTextColor: Colors.bg
        onAccepted: root.accepted(text)

        cursorDelegate: BlockCursor {
            visible: input.activeFocus
        }

        Label {
            visible: !input.text && !input.activeFocus
            text: root.placeholder
            color: Colors.dim
        }
    }
}
