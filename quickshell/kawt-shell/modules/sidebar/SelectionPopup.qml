import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// ┌────────────────────────────────────────────────────┐
// │ ✦ AI on the selection                              │
// │ "the text you marked in any window, a few lines…"  │
// │ [1 Explain] [2 Translate] [3 Fix] [4 Summary]      │
// │ the answer, which you can select and copy          │
// │ [c Copy] [r Replace] [enter Chat]    llama3.2 · 3s │
// └────────────────────────────────────────────────────┘
// super + alt + a (kawt selection): the text you marked with the mouse, read without copying it
// (the primary selection; nothing marked: the clipboard). One answer, not into the chat:
// Replace types it over the marked text (with wtype), Chat carries both into the ai panel.
Popover {
    id: root

    name: "selection"
    title: Ai.selFromClipboard ? Strings.t("aiOnClipboard") : Strings.t("aiOnSelection")
    icon: "ai"
    note: Strings.t("aiSelKeys")
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
        text: Strings.t("aiReadingSel")
        color: Colors.dim
    }

    Flow {
        Layout.fillWidth: true
        visible: Ai.selText !== ""
        spacing: Metrics.spacing

        Repeater {
            model: Ai.selActions

            PushButton {
                required property var modelData
                required property int index

                small: true
                tag: `${index + 1}`
                text: Strings.t(`aiAct_${modelData[0]}`)
                active: Ai.selAction === modelData[0]
                onClicked: {
                    root.copied = false;
                    Ai.selDo(modelData[0]);
                }
            }
        }

        Label {
            visible: Ai.selText.length > 300
            text: Strings.t("aiChars").arg(Ai.selText.length)
            color: Colors.dim
            font.pixelSize: Metrics.size(-2)
        }
    }

    Rule {
        Layout.fillWidth: true
        visible: Ai.selAction !== "" || Ai.selError !== ""
    }

    Label {
        Layout.fillWidth: true
        visible: Ai.selBusy && Ai.selAction !== ""
        text: Strings.t("aiThinking").arg(Ai.modelName)
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
            renderType: Metrics.pixel ? Text.NativeRendering : Text.QtRendering
            font.pixelSize: Metrics.fontSize
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: Ai.selText !== ""
        spacing: Metrics.spacing

        PushButton {
            small: true
            visible: Ai.selAnswer !== ""
            tag: "c"
            text: root.copied ? Strings.t("copiedWord") : Strings.t("copyWord")
            onClicked: root.copy()
        }

        // typed over the marked text, in its window (only for translate / fix, with wtype)
        PushButton {
            small: true
            visible: root.canReplace
            tag: "r"
            text: Strings.t("aiReplace")
            onClicked: Ai.selReplace()
        }

        PushButton {
            small: true
            tag: "enter"
            text: Strings.t("aiToChat")
            onClicked: Ai.selToChat()
        }

        Item {
            Layout.fillWidth: true
        }

        Label {
            visible: Ai.selAnswer !== ""
            text: `${Ai.modelName} · ${(Ai.selTook / 1000).toFixed(1)}s`
            color: Colors.dim
            font.pixelSize: Metrics.size(-2)
        }
    }
}
