import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// ┌─ai: the selection──────────────────────────────esc┐
// │ "the text you marked in any window, a few lines…"  │
// │ [1 explain] [2 translate] [3 fix] [4 summary]      │
// │ the answer, which you can select and copy          │
// │ [c copy] [r replace] [enter chat]    llama3.2 · 3s │
// └────────────────────────────────────────────────────┘
// super + alt + a (kawt selection): the text you marked with the mouse, read without copying it
// (the primary selection; nothing marked: the clipboard). One answer, not into the chat:
// [replace] types it over the marked text (with wtype), [chat] carries both into the ai panel.
Popover {
    id: root

    name: "selection"
    title: Ai.selFromClipboard ? "ai: the clipboard" : "ai: the selection"
    cardWidth: 520

    readonly property bool canReplace: Ai.canType && Ai.selAnswer !== "" && (Ai.selActions.find(a => a[0] === Ai.selAction) ?? [])[2] === true
    property bool copied: false

    onPanelOpened: {
        copied = false;
        Ai.selRead();
    }
    onPanelClosed: Ai.selStop()

    function copy(): void {
        if (!Ai.selAnswer)
            return;
        // no keyboard focus is needed for wl-copy (the clipboard of a surface without it can't be set)
        Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", Ai.selAnswer]);
        copied = true;
    }

    // 1-4: an action · c: copy · r: replace · enter: on into the chat
    onCardKey: event => {
        const n = event.key - Qt.Key_1;
        if (n >= 0 && n < Ai.selActions.length) {
            copied = false;
            Ai.selDo(Ai.selActions[n][0]);
        } else if (event.key === Qt.Key_C && !(event.modifiers & Qt.ControlModifier)) {
            copy();
        } else if (event.key === Qt.Key_R && canReplace) {
            Ai.selReplace();
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            Ai.selToChat();
        } else {
            return;
        }
        event.accepted = true;
    }

    Label {
        Layout.fillWidth: true
        visible: Ai.selText !== ""
        wrapMode: Text.Wrap
        maximumLineCount: 4
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: `"${Ai.selText.trim()}"`
        color: Colors.dim
    }

    Label {
        Layout.fillWidth: true
        visible: Ai.selText === "" && Ai.selError === ""
        text: "reading the selection..."
        color: Colors.dim
    }

    Flow {
        Layout.fillWidth: true
        visible: Ai.selText !== ""
        spacing: Metrics.spacing

        Repeater {
            model: Ai.selActions

            BracketButton {
                required property var modelData
                required property int index

                tag: `${index + 1}`
                label: modelData[0]
                active: Ai.selAction === modelData[0]
                textColor: Ai.selAction === modelData[0] ? Colors.accent : Colors.fg
                onClicked: {
                    root.copied = false;
                    Ai.selDo(modelData[0]);
                }
            }
        }

        Label {
            visible: Ai.selText.length > 300
            text: `${Ai.selText.length} characters`
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Metrics.borderWidth
        visible: Ai.selAction !== "" || Ai.selError !== ""
        color: Colors.border
    }

    Label {
        Layout.fillWidth: true
        visible: Ai.selBusy && Ai.selAction !== ""
        text: `~ ${Ai.modelName} is thinking...`
        color: Colors.accent
    }

    Label {
        Layout.fillWidth: true
        visible: Ai.selError !== ""
        wrapMode: Text.Wrap
        text: `!! ${Ai.selError}`
        color: Colors.warn
    }

    // the answer: long ones scroll
    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(answer.implicitHeight, Math.round((root.forScreen?.height ?? 900) * 0.4))
        visible: Ai.selAnswer !== ""
        clip: true
        contentHeight: answer.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        TextEdit {
            id: answer

            width: parent.width
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            text: Ai.selAnswer
            color: Colors.fg
            selectionColor: Colors.accent
            selectedTextColor: Colors.bg
            font.family: Metrics.fontFamily
            font.pixelSize: Metrics.fontSize
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: Ai.selText !== ""
        spacing: Metrics.spacing

        BracketButton {
            visible: Ai.selAnswer !== ""
            tag: "c"
            label: root.copied ? "copied" : "copy"
            textColor: root.copied ? Colors.accent : Colors.fg
            onClicked: root.copy()
        }

        // typed over the marked text, in its window (only for translate / fix, with wtype)
        BracketButton {
            visible: root.canReplace
            tag: "r"
            label: "replace"
            onClicked: Ai.selReplace()
        }

        BracketButton {
            tag: "enter"
            label: "chat"
            onClicked: Ai.selToChat()
        }

        Item {
            Layout.fillWidth: true
        }

        Label {
            visible: Ai.selAnswer !== ""
            text: `${Ai.modelName} · ${(Ai.selTook / 1000).toFixed(1)}s`
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }
    }
}
