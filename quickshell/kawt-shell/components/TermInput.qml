import QtQuick
import qs.config

// Single-line input with a prompt and a blinking block cursor.
// Optional completion, like a shell: give it `completions`, and the first one that starts
// with what's typed shows as gray text after the cursor; → or tab takes it. Entries listed
// in `highlight` (e.g. models you already have) show in the accent color instead.
Item {
    id: root

    property alias text: input.text
    property alias echoMode: input.echoMode
    property alias input: input
    property string prompt: ">"
    property string placeholder: ""
    property var completions: []
    property var highlight: []
    readonly property string suggestion: {
        const t = input.text;
        if (!t)
            return "";
        const hit = completions.find(c => c.startsWith(t) && c !== t);
        return hit ?? "";
    }

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

        // → at the end of the line, or tab: take the gray suggestion
        Keys.onPressed: event => {
            if (root.suggestion && (event.key === Qt.Key_Tab || (event.key === Qt.Key_Right && cursorPosition === text.length))) {
                text = root.suggestion;
                cursorPosition = text.length;
                event.accepted = true;
            }
        }

        cursorDelegate: BlockCursor {
            visible: input.activeFocus
        }

        Label {
            visible: !input.text && !input.activeFocus
            text: root.placeholder
            color: Colors.dim
        }

        // the rest of the suggestion, right after the typed text
        Label {
            visible: root.suggestion !== "" && input.activeFocus && input.cursorPosition === input.text.length
            x: input.contentWidth
            text: root.suggestion.slice(input.text.length)
            color: root.highlight.includes(root.suggestion) ? Colors.accent : Colors.dim
            opacity: 0.7
        }
    }
}
