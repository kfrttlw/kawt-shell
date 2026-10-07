import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// One message in the chat:
//   you> what does this do?
//        14:32 · @notes.md                                   [edit]
//    ai> **it** prints the list:
//        ┌ python ───────────────────────── [copy]┐
//        │ for x in items: print(x)               │
//        └────────────────────────────────────────┘
//        14:32 · 3.2s · 24 tok/s           [copy] [note] [retry]
// Answers render markdown (bold, lists, headings); code blocks get a frame and a copy button.
// Text size follows Settings.aiZoom (ctrl + / ctrl - in the panel).
// While an answer streams in it's shown as plain text with a still █ at the end: markdown is
// laid out once, when it's complete, not ten times a second (Ai.partialShown) as it grows.
Item {
    id: root

    property string kind: "assistant" // user | assistant | error
    property string text: ""
    property bool streaming: false
    property real topPadding: 0
    property real time: 0
    property real took: 0
    property real tps: 0
    property var files: [] // attached to this message
    property string model: "" // which model answered (shown in compare mode)
    property bool showRetry: false
    property bool showEdit: false

    readonly property int size: Math.max(8, Metrics.fontSize + Settings.aiZoom)
    readonly property string meta: time ? [Time.fmt(new Date(time)), Settings.aiCompare && model ? model.replace(/:latest$/, "") : "", took ? `${(took / 1000).toFixed(1)}s` : "", tps ? `${Math.round(tps)} tok/s` : "", ...files.map(f => `@${f}`)].filter(s => s).join(" · ") : ""
    // text and ``` code ``` pieces, in order. An unclosed fence (still streaming) counts as code.
    readonly property var parts: {
        const out = [];
        const re = /```([\w+#.-]*)[^\n]*\n?([\s\S]*?)(```|$)/g;
        let last = 0, m;
        const t = text;
        while ((m = re.exec(t)) !== null) {
            if (m.index > last)
                out.push({ code: false, text: t.slice(last, m.index) });
            out.push({ code: true, lang: m[1], text: m[2].replace(/\n$/, "") });
            last = re.lastIndex;
            if (m[0].length === 0)
                break;
        }
        if (last < t.length)
            out.push({ code: false, text: t.slice(last) });
        return out.filter(p => p.code || p.text.trim() !== "");
    }

    signal retry
    signal edit
    signal toNote

    // An answer as markdown, made safe to show. Qt would load the pictures in it
    // (![x](http://...)) and render raw html (<img src=...>), so a prompt hidden in an attached
    // file could make the model write a link that sends your data somewhere as soon as the
    // answer is shown. Pictures become plain links, tags plain text; `code` is left as it is.
    function safeMarkdown(t: string): string {
        return t.split(/(`[^`\n]*`)/).map((piece, i) => i % 2 ? piece : piece.replace(/!\[/g, "\\![").replace(/<(?=[A-Za-z\/!?])/g, "&lt;")).join("");
    }

    implicitHeight: row.implicitHeight + topPadding

    function copy(t: string): void {
        try {
            Quickshell.clipboardText = t;
        } catch (e) {
            Quickshell.execDetached(["wl-copy", t]);
        }
    }

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: Metrics.spacing

        Label {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Math.max(Settings.aiUserLabel.length, Settings.aiBotLabel.length, 2) * root.size * 0.6 + root.size * 0.6
            horizontalAlignment: Text.AlignRight
            text: (root.kind === "user" ? Settings.aiUserLabel : root.kind === "error" ? "!!" : Settings.aiBotLabel) + ">"
            color: root.kind === "user" ? Colors.dim : root.kind === "error" ? Colors.warn : Colors.accent
            font.pixelSize: root.size
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            // a count, not the parts themselves: while an answer streams, the parts are new
            // objects on every update, and as a model they'd make every block again. With a
            // count the blocks stay, and only the text of the last one changes
            Repeater {
                model: Math.max(1, root.parts.length)

                Loader {
                    id: part

                    required property int index
                    readonly property var piece: root.parts[index] ?? { code: false, lang: "", text: "" }
                    readonly property bool lastPart: index === Math.max(1, root.parts.length) - 1

                    Layout.fillWidth: true
                    sourceComponent: part.piece.code ? codeBlock : textBlock

                    // plain text (yours) or markdown (answers)
                    Component {
                        id: textBlock

                        TextEdit {
                            readOnly: true
                            selectByMouse: !root.streaming
                            wrapMode: TextEdit.Wrap
                            textFormat: root.kind === "assistant" && !root.streaming ? TextEdit.MarkdownText : TextEdit.PlainText
                            text: root.kind === "assistant" && !root.streaming ? root.safeMarkdown(part.piece.text) : part.piece.text + (root.streaming && part.lastPart ? "█" : "")
                            color: root.kind === "error" ? Colors.dim : Colors.fg
                            selectionColor: Colors.accent
                            selectedTextColor: Colors.bg
                            font.family: Metrics.fontFamily
                            font.pixelSize: root.size
                        }
                    }

                    // ┌ python ──────── [copy]┐ a framed code block
                    Component {
                        id: codeBlock

                        Rectangle {
                            implicitHeight: codeCol.implicitHeight + 8
                            color: Colors.hoverFill
                            border.color: Colors.border
                            border.width: Metrics.borderWidth

                            ColumnLayout {
                                id: codeCol

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 4
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true

                                    Label {
                                        Layout.fillWidth: true
                                        text: part.piece.lang || "code"
                                        color: Colors.dim
                                        font.pixelSize: root.size - 3
                                    }

                                    BracketButton {
                                        id: copyCode

                                        property bool done: false

                                        label: done ? "copied" : "copy"
                                        bordered: false
                                        onClicked: {
                                            root.copy(part.piece.text);
                                            done = true;
                                            copiedTimer.restart();
                                        }

                                        Timer {
                                            id: copiedTimer

                                            interval: 1500
                                            onTriggered: copyCode.done = false
                                        }
                                    }
                                }

                                TextEdit {
                                    Layout.fillWidth: true
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: TextEdit.WrapAnywhere
                                    textFormat: TextEdit.PlainText
                                    text: part.piece.text + (root.streaming && part.lastPart ? "█" : "")
                                    color: Colors.fg
                                    selectionColor: Colors.accent
                                    selectedTextColor: Colors.bg
                                    font.family: Metrics.fontFamily
                                    font.pixelSize: root.size - 1
                                }
                            }
                        }
                    }
                }
            }

            // 14:32 · 3.2s · 24 tok/s                 [copy] [note] [retry]
            RowLayout {
                Layout.fillWidth: true
                visible: !root.streaming && (root.meta !== "" || root.kind !== "error")
                spacing: Metrics.spacing

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.meta
                    color: Colors.dim
                    font.pixelSize: root.size - 3
                }

                BracketButton {
                    visible: root.kind === "assistant"
                    label: "copy"
                    bordered: false
                    onClicked: root.copy(root.text)
                }

                BracketButton {
                    visible: root.kind === "assistant"
                    label: "note"
                    bordered: false
                    onClicked: root.toNote()
                }

                BracketButton {
                    visible: root.showRetry
                    label: "retry"
                    bordered: false
                    onClicked: root.retry()
                }

                BracketButton {
                    visible: root.showEdit
                    label: "edit"
                    bordered: false
                    onClicked: root.edit()
                }
            }
        }
    }
}
