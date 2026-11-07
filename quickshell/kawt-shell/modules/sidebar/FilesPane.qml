import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// The files column of the wide ai panel:
//   dir> ~/projects/kawt
//   / filter
//   + notes.md          (attached: goes with the next message)
//     sub/a.txt
// The model only ever sees files attached from here: kawt reads them and puts the text into
// your message. Nothing outside the folder can be attached (see Ai.attach).
ColumnLayout {
    id: root

    spacing: Metrics.spacing

    readonly property var shown: {
        const q = filter.text.trim().toLowerCase();
        return q ? Ai.files.filter(f => f.toLowerCase().includes(q)) : Ai.files;
    }

    Component.onCompleted: Ai.refreshFiles()

    Label {
        text: Strings.t("aiFolder")
    }

    TermInput {
        Layout.fillWidth: true
        prompt: ""
        text: Settings.aiFolder
        placeholder: "~/some/folder"
        onAccepted: t => {
            Settings.aiFolder = t.trim();
            Ai.attachments = [];
            Ai.refreshFiles();
        }
    }

    TermInput {
        id: filter

        Layout.fillWidth: true
        visible: Ai.files.length > 0
        prompt: "/"
        placeholder: Strings.t("aiFilter")
    }

    Label {
        Layout.fillWidth: true
        visible: !Settings.aiFolder
        wrapMode: Text.Wrap
        text: Strings.t("aiFolderNote")
        color: Colors.dim
    }

    Label {
        Layout.fillWidth: true
        visible: Ai.fileStatus !== ""
        elide: Text.ElideRight
        text: Ai.fileStatus
        color: Colors.warn
        font.pixelSize: Metrics.size(-2)
    }

    // the files, sunk; the attached ones red
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Colors.well

        Bevel {
            style: "sunk"
        }

    Flickable {
        id: list

        anchors.fill: parent
        anchors.margins: 3
        clip: true
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col

            width: list.width

            Repeater {
                model: root.shown

                Item {
                    id: file

                    required property string modelData
                    readonly property bool on: Ai.attached(modelData)

                    width: col.width
                    implicitHeight: name.implicitHeight + 4

                    Rectangle {
                        anchors.fill: parent
                        visible: fileArea.containsMouse || file.on
                        color: file.on ? Colors.accent : Colors.hoverFill
                    }

                    Label {
                        id: name

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideMiddle
                        text: file.modelData
                        color: file.on ? Colors.onAccent : Colors.fg
                    }

                    MouseArea {
                        id: fileArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: file.on ? Ai.detach(file.modelData) : Ai.attach(file.modelData)
                    }
                }
            }
        }
    }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: Settings.aiFolder !== ""

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Strings.t("aiFilesAttach").arg(Strings.count(Ai.files.length, "file"))
            color: Colors.dim
        }

        PushButton {
            small: true
            text: Strings.t("aiReload")
            onClicked: Ai.refreshFiles()
        }
    }
}
