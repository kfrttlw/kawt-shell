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

RowLayout {
    required property var profile

    id: notesTab

    readonly property var list: Notes.inFolder(profile.notesFolder, noteSearch.text)
    property bool loaded: false // the editor holds the opened note: from now on, typing saves it

    // open a note in the editor (0 = close). Saves the one being left first.
    function openNote(id: real): void {
        Notes.flush();
        loaded = false;
        profile.noteOpen = id;
        noteEdit.text = Notes.bodyOf(id);
        loaded = true;
        if (id)
            noteEdit.forceActiveFocus();
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
                                text: (noteRow.current ? "> " : "  ") + Notes.title(noteRow.modelData)
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

        // the editor of the opened note
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            visible: profile.noteOpen !== 0
            implicitHeight: profile.wide ? 300 : 220
            color: Colors.bg
            border.color: noteEdit.activeFocus ? Colors.dim : Colors.border
            border.width: Metrics.borderWidth

            Flickable {
                id: noteFlick

                anchors.fill: parent
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
                        visible: !noteEdit.text && !noteEdit.activeFocus
                        text: "first line = title\n..."
                        color: Colors.dim
                    }
                }
            }
        }

        // move to a folder · delete
        Flow {
            Layout.fillWidth: true
            visible: profile.noteOpen !== 0
            spacing: Metrics.spacing

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
            Layout.alignment: Qt.AlignRight
            text: `-- ${Notes.count("all")} notes · ~/.local/state/kawt/notes.json --`
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 3
        }
    }
}
