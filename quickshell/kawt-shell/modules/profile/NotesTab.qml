import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services
import qs.utils
import "../popovers"

// The notes tab:
//
//   folders        │ / search█                       [+ new] [from clipboard]
//   > notes     4  │ * shopping list                  28.10 14:30     (* pinned, on top)
//     ideas     2  │ > kawt ideas                     27.10 09:12
//     all       6  │ ┌───────────────────────────────────────────────┐
//   + folder       │ │ kawt ideas                                    │  read: # headings bold,
//                  │ │ [x] quick switches on top                     │  - [ ] boxes tick with a
//                  │ │ [ ] focus timer with thinky                   │  click; a click elsewhere
//                  │ └───────────────────────────────────────────────┘  writes in it
//                  │ [pin] [make a task]  notes ideas         [delete]
RowLayout {
    id: notesTab

    required property var profile
    readonly property var list: Notes.inFolder(profile.notesFolder, noteSearch.text)
    property bool loaded: false // the editor holds the opened note: from now on, typing saves it
    property bool editing: false // the note is written in; otherwise it's read (boxes, headings)
    readonly property var note: Notes.notes.find(n => n.id === profile.noteOpen) ?? null
    property string said: ""

    // open a note (0 = close). Saves the one being left first. One with text is shown to read,
    // an empty one to write in
    function openNote(id: real): void {
        Notes.flush();
        loaded = false;
        profile.noteOpen = id;
        noteEdit.text = Notes.bodyOf(id);
        loaded = true;
        editing = id !== 0 && noteEdit.text.trim() === "";
        if (editing)
            noteEdit.forceActiveFocus();
    }

    // the text again first: boxes ticked while reading changed it
    function write(): void {
        loaded = false;
        noteEdit.text = Notes.bodyOf(profile.noteOpen);
        loaded = true;
        editing = true;
        noteEdit.forceActiveFocus();
        noteEdit.cursorPosition = noteEdit.length;
    }

    function say(text: string): void {
        said = text;
        saidTimer.restart();
    }

    Timer {
        id: saidTimer

        interval: 3000
        onTriggered: notesTab.said = ""
    }

    // [from clipboard]: its text as a new note
    Process {
        id: paste

        command: ["wl-paste", "--no-newline", "--type", "text"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "") {
                    notesTab.say("nothing to paste: the clipboard has no text");
                    return;
                }
                notesTab.openNote(Notes.createWith(notesTab.profile.notesFolder, text));
            }
        }
    }

    spacing: Metrics.padding

    // made again each time the tab is shown: put the opened note back into the editor
    Component.onCompleted: {
        noteEdit.text = Notes.bodyOf(profile.noteOpen);
        loaded = true;
    }

    // folders
    ColumnLayout {
        Layout.preferredWidth: profile.wide ? 190 : 140
        Layout.maximumWidth: profile.wide ? 190 : 140
        Layout.alignment: Qt.AlignTop
        spacing: 0

        Label {
            text: "folders"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }

        Repeater {
            model: [...Notes.folders, "all"]

            Item {
                id: nfRow

                required property string modelData
                readonly property bool current: profile.notesFolder === modelData
                readonly property bool removable: modelData !== "notes" && modelData !== "all"

                Layout.fillWidth: true
                implicitHeight: nfLabel.implicitHeight + 4

                Rectangle {
                    anchors.fill: parent
                    visible: nfRow.current || nfArea.containsMouse
                    color: Colors.hoverFill
                }

                Label {
                    id: nfLabel

                    anchors.left: parent.left
                    anchors.right: nfCount.left
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: (nfRow.current ? "> " : "  ") + nfRow.modelData
                    color: nfRow.current ? Colors.accent : Colors.fg
                }

                Label {
                    id: nfCount

                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: nfArea.containsMouse && nfRow.removable ? "x" : String(Notes.count(nfRow.modelData) || "")
                    color: text === "x" ? Colors.warn : Colors.dim
                }

                MouseArea {
                    id: nfArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (nfRow.removable && mouse.x > width - 20) {
                            if (profile.notesFolder === nfRow.modelData)
                                profile.notesFolder = "notes";
                            Notes.removeFolder(nfRow.modelData);
                        } else {
                            profile.notesFolder = nfRow.modelData;
                        }
                    }
                }
            }
        }

        TermInput {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            prompt: "+"
            placeholder: "folder"
            onAccepted: t => {
                const name = Notes.addFolder(t);
                if (name)
                    profile.notesFolder = name;
                text = "";
            }
        }
    }

    Rectangle {
        Layout.fillHeight: true
        implicitWidth: Metrics.borderWidth
        color: Colors.border
    }

    // list + editor
    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        Layout.alignment: Qt.AlignTop
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            TermInput {
                id: noteSearch

                Layout.fillWidth: true
                prompt: "/"
                placeholder: "search"
            }

            BracketButton {
                label: "+ new"
                textColor: Colors.accent
                onClicked: notesTab.openNote(Notes.create(profile.notesFolder))
            }

            BracketButton {
                label: "from clipboard"
                onClicked: paste.running = true
            }
        }

        Label {
            visible: notesTab.list.length === 0
            Layout.topMargin: Metrics.spacing
            text: noteSearch.text ? "-- nothing found --" : "-- no notes here: [+ new] --"
            color: Colors.dim
        }

        // the list: title · date · x
        Flickable {
            id: notesFlick

            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            Layout.preferredHeight: Math.min(profile.wide ? 200 : 132, notesListCol.implicitHeight)
            visible: notesTab.list.length > 0
            clip: true
            contentHeight: notesListCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: notesListCol

                width: notesFlick.width

                Repeater {
                    model: ScriptModel {
                        values: notesTab.list
                    }

                    Item {
                        id: noteRow

                        required property var modelData
                        readonly property bool current: profile.noteOpen === modelData.id

                        width: notesListCol.width
                        implicitHeight: noteTitle.implicitHeight + 6

                        Rectangle {
                            anchors.fill: parent
                            visible: noteRow.current || noteArea.containsMouse
                            color: Colors.hoverFill
                        }

                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 2
                            anchors.rightMargin: 4
                            spacing: Metrics.spacing

                            Label {
                                id: noteTitle

                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                textFormat: Text.StyledText
                                text: `<font color="${Colors.accent}">${noteRow.modelData.pinned ? "*" : noteRow.current ? ">" : "&nbsp;"}</font>&nbsp;` + Notes.title(noteRow.modelData).replace(/&/g, "&amp;").replace(/</g, "&lt;")
                                color: noteRow.current ? Colors.accent : Colors.fg
                            }

                            Label {
                                visible: profile.notesFolder === "all"
                                text: noteRow.modelData.folder
                                color: Colors.dim
                                font.pixelSize: Metrics.fontSize - 2
                            }

                            Label {
                                text: Qt.formatDateTime(new Date(noteRow.modelData.updated), "dd.MM hh:mm")
                                color: Colors.dim
                                font.pixelSize: Metrics.fontSize - 2
                            }

                            Label {
                                text: "x"
                                opacity: noteArea.containsMouse ? 1 : 0
                                color: Colors.warn
                            }
                        }

                        // click: open · the x on the right: delete
                        MouseArea {
                            id: noteArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.x > width - 20) {
                                    if (profile.noteOpen === noteRow.modelData.id)
                                        notesTab.openNote(0);
                                    Notes.remove(noteRow.modelData.id);
                                } else {
                                    notesTab.openNote(noteRow.modelData.id);
                                }
                            }
                        }
                    }
                }
            }
        }

        // the opened note: read (boxes, headings) or written in
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            visible: profile.noteOpen !== 0
            implicitHeight: profile.wide ? 300 : 220
            color: Colors.bg
            border.color: noteEdit.activeFocus ? Colors.dim : Colors.border
            border.width: Metrics.borderWidth

            // read: a line each; - [ ] boxes tick, a click anywhere else writes in it
            Flickable {
                id: readFlick

                anchors.fill: parent
                anchors.margins: Metrics.spacing
                visible: !notesTab.editing
                clip: true
                contentHeight: readCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                MouseArea {
                    width: readFlick.width
                    height: Math.max(readFlick.height, readCol.implicitHeight)
                    cursorShape: Qt.IBeamCursor
                    onClicked: notesTab.write()
                }

                Column {
                    id: readCol

                    width: readFlick.width
                    spacing: 2

                    Repeater {
                        model: notesTab.editing ? [] : Notes.bodyOf(profile.noteOpen).split("\n")

                        Item {
                            id: line

                            required property string modelData
                            required property int index
                            readonly property var box: /^\s*(?:[-*]\s+)?\[([ xX])\]\s?(.*)$/.exec(modelData)
                            readonly property var heading: /^(#{1,3})\s+(.*)$/.exec(modelData)
                            readonly property var point: /^\s*[-*]\s+(.*)$/.exec(modelData)

                            width: readCol.width
                            implicitHeight: modelData.trim() === "" ? Metrics.fontSize * 0.6 : Math.max(lineText.implicitHeight, boxMark.implicitHeight)

                            Brackets {
                                id: boxMark

                                visible: line.box !== null
                                text: line.box && line.box[1] !== " " ? "x" : " "
                                look: line.box && line.box[1] !== " " ? "off" : ""
                            }

                            Label {
                                id: lineText

                                x: line.box ? boxMark.width + Metrics.spacing : line.point ? Metrics.fontSize : 0
                                width: parent.width - x
                                wrapMode: Text.Wrap
                                // the first line is the title
                                text: line.box ? line.box[2] : line.heading ? line.heading[2] : line.point ? `· ${line.point[1]}` : line.modelData
                                color: line.box && line.box[1] !== " " ? Colors.dim : Colors.fg
                                font.strikeout: line.box !== null && line.box[1] !== " "
                                font.bold: line.heading !== null || line.index === 0
                                font.pixelSize: line.heading && line.heading[1] === "#" ? Metrics.fontSize + 1 : Metrics.fontSize
                            }

                            MouseArea {
                                visible: line.box !== null
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notes.toggleBox(profile.noteOpen, line.index)
                            }
                        }
                    }
                }
            }

            Flickable {
                id: noteFlick

                anchors.fill: parent
                visible: notesTab.editing
                anchors.margins: Metrics.spacing
                clip: true
                contentHeight: noteEdit.contentHeight
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: noteEdit

                    textFormat: TextEdit.PlainText // a saved ai answer is text, never html
                    width: noteFlick.width
                    color: Colors.fg
                    font.family: Metrics.fontFamily
                    font.pixelSize: Metrics.fontSize
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    selectionColor: Colors.accent
                    selectedTextColor: Colors.bg
                    cursorDelegate: BlockCursor {
                        visible: noteEdit.activeFocus
                    }

                    // the text is set only when a note is opened (notesTab.openNote), never
                    // bound: a binding would jump the cursor on every save. Saving is done by
                    // Notes, which outlives this window: closing it never loses the last words
                    onTextChanged: if (notesTab.loaded && profile.noteOpen)
                        Notes.edit(profile.noteOpen, text)

                    // keep the cursor in view while typing
                    onCursorRectangleChanged: {
                        if (cursorRectangle.y < noteFlick.contentY)
                            noteFlick.contentY = cursorRectangle.y;
                        else if (cursorRectangle.y + cursorRectangle.height > noteFlick.contentY + noteFlick.height)
                            noteFlick.contentY = cursorRectangle.y + cursorRectangle.height - noteFlick.height;
                    }

                    Label {
                        visible: !noteEdit.text
                        text: "first line = title\n# a heading · - [ ] a box · - a point"
                        color: Colors.dim
                    }

                    // done writing (esc, or a click elsewhere): read it again
                    Keys.onEscapePressed: notesTab.editing = false
                    onActiveFocusChanged: if (!activeFocus && text.trim() !== "")
                        notesTab.editing = false
                }
            }
        }

        // pin · a task of it · move to a folder · delete
        Flow {
            Layout.fillWidth: true
            visible: profile.noteOpen !== 0
            spacing: Metrics.spacing

            BracketButton {
                label: notesTab.note?.pinned ? "unpin" : "pin"
                active: !!notesTab.note?.pinned
                onClicked: Notes.togglePin(profile.noteOpen)
            }

            // its title becomes a task, the rest of it the task's note
            BracketButton {
                label: "make a task"
                onClicked: {
                    Notes.flush();
                    const body = Notes.bodyOf(profile.noteOpen);
                    const said = Todo.add(Notes.title(notesTab.note), "inbox");
                    const t = Todo.tasks.slice().sort((a, b) => b.id - a.id)[0];
                    if (said && t)
                        Todo.update(t.id, { note: body.split("\n").slice(1).join("\n").trim() });
                    notesTab.say(said ? `task ${said}` : "the note has no title to make a task of");
                }
            }

            Label {
                text: " "
            }

            Repeater {
                model: Notes.folders

                BracketButton {
                    required property string modelData
                    readonly property var note: Notes.notes.find(n => n.id === profile.noteOpen)

                    label: modelData
                    bordered: false
                    active: note?.folder === modelData
                    textColor: note?.folder === modelData ? Colors.accent : Colors.dim
                    onClicked: Notes.update(profile.noteOpen, { folder: modelData })
                }
            }

            BracketButton {
                label: "delete"
                textColor: Colors.warn
                bordered: false
                onClicked: {
                    const id = profile.noteOpen;
                    notesTab.openNote(0);
                    Notes.remove(id);
                }
            }
        }

        Label {
            visible: notesTab.said !== ""
            text: notesTab.said
            color: Colors.accent
            font.pixelSize: Metrics.fontSize - 2
        }

        Label {
            Layout.alignment: Qt.AlignRight
            text: `-- ${Notes.count("all")} notes · ~/.local/state/kawt/notes.json --`
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 3
        }
    }
}
