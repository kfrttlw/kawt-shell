import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// The start menu's notes: the last few (pinned ones first), one of them open below to read and
// write in. It's kept as you type, as in the profile's notes tab (services/Notes.qml saves a
// moment after the last key); folders and search are there.
ColumnLayout {
    id: root

    readonly property var recent: Notes.sorted.slice(0, 5)
    property real noteId: 0
    property bool loading: false // the text is being put in, not typed: not an edit

    function open(id: real): void {
        Notes.flush();
        noteId = id;
        loading = true;
        page.text = Notes.bodyOf(id);
        loading = false;
    }

    spacing: Metrics.spacing

    Component.onCompleted: open(Notes.sorted[0]?.id ?? 0)
    Component.onDestruction: Notes.flush()

    RowLayout {
        Layout.fillWidth: true

        Label {
            Layout.fillWidth: true
            text: `notes · ${Notes.notes.length}`
            font.bold: true
        }

        BracketButton {
            label: "+ new"
            onClicked: {
                root.open(Notes.create("notes"));
                page.forceActiveFocus();
            }
        }
    }

    Well {
        Layout.fillWidth: true
        implicitHeight: Math.max(1, root.recent.length) * (Metrics.fontSize + 10) + 6

        Column {
            anchors.fill: parent
            anchors.margins: 3

            Repeater {
                model: root.recent

                Item {
                    id: note

                    required property var modelData
                    readonly property bool current: modelData.id === root.noteId

                    width: parent.width
                    height: Metrics.fontSize + 10

                    Rectangle {
                        anchors.fill: parent
                        visible: note.current || area.containsMouse
                        color: note.current && Colors.bevel ? Colors.accent : Colors.hoverFill
                    }

                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: Metrics.spacing
                        anchors.right: date.left
                        anchors.rightMargin: Metrics.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: (note.modelData.pinned ? "* " : "") + Notes.title(note.modelData)
                        color: note.current ? (Colors.bevel ? Colors.onAccent : Colors.accent) : Colors.fg
                    }

                    Label {
                        id: date

                        anchors.right: parent.right
                        anchors.rightMargin: Metrics.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDate(new Date(note.modelData.updated), "dd.MM")
                        color: note.current && Colors.bevel ? Colors.onAccent : Colors.dim
                        font.pixelSize: Metrics.fontSize - 2
                    }

                    MouseArea {
                        id: area

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.open(note.modelData.id)
                    }
                }
            }
        }

        Label {
            anchors.centerIn: parent
            visible: root.recent.length === 0
            text: "no notes yet: + new"
            color: Colors.dim
        }
    }

    Well {
        Layout.fillWidth: true
        Layout.fillHeight: true

        TextEdit {
            id: page

            anchors.fill: parent
            anchors.margins: Metrics.spacing
            enabled: root.noteId !== 0
            clip: true
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            selectByMouse: true
            color: Colors.fg
            selectionColor: Colors.accent
            selectedTextColor: Colors.onAccent
            font.family: Metrics.fontFamily
            font.pixelSize: Metrics.fontSize
            onTextChanged: if (!root.loading && root.noteId !== 0)
                Notes.edit(root.noteId, text)
            Keys.onEscapePressed: Panels.close()
        }
    }

    Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: "kept as you type · folders and search: the profile's notes"
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }
}
