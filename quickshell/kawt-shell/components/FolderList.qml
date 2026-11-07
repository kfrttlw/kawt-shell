import QtQuick
import QtQuick.Layouts
import qs.config

// Folders the old way (tasks, notes): a sunk list, the open one red, how many are in each on the
// right. A removable one shows × there under the pointer; a click on it removes the folder.
//   FolderList { folders: [...Todo.folders, "all"]; current: …; countOf: f => Todo.openIn(f)
//                removable: f => f !== "inbox"; onPicked: f => …; onRemoved: f => … }
Rectangle {
    id: root

    property var folders: []
    property string current: ""
    property var countOf: f => 0
    property var removable: f => false
    property var nameOf: f => f // the words shown for one ("all" in the chosen language)
    property var iconOf: f => f === "all" ? "apps" : "folder"
    readonly property int rowHeight: Metrics.fontSize + 9

    signal picked(string folder)
    signal removed(string folder)

    Layout.fillWidth: true
    implicitHeight: folders.length * rowHeight + 6
    color: Colors.well

    Bevel {
        style: "sunk"
    }

    Column {
        x: 3
        y: 3
        width: parent.width - 6

        Repeater {
            model: root.folders

            Rectangle {
                id: row

                required property string modelData
                readonly property bool open: modelData === root.current
                readonly property bool canGo: root.removable(modelData)

                width: parent.width
                height: root.rowHeight
                color: open ? Colors.accent : "transparent"

                PixIcon {
                    x: 3
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.iconOf(row.modelData)
                }

                Label {
                    x: 23
                    width: count.x - x - 4
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: root.nameOf(row.modelData)
                    color: row.open ? Colors.onAccent : Colors.fg
                }

                Label {
                    id: count

                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: area.containsMouse && row.canGo ? "×" : String(root.countOf(row.modelData) || "")
                    color: row.open ? Colors.onAccent : text === "×" ? Colors.warn : Colors.dim
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (row.canGo && mouse.x > width - 20)
                            root.removed(row.modelData);
                        else
                            root.picked(row.modelData);
                    }
                }
            }
        }
    }
}
