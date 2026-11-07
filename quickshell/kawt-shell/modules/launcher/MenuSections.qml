import QtQuick
import qs.config
import qs.components

// The start menu's left side: its sections, one under another, the way old start menus listed
// theirs. A click opens one (pointing only lights it: the mouse passing over shouldn't swap what
// you're reading). Below the line: the profile and the settings, what the bar's [●] had.
Well {
    id: root

    property string current: "apps"
    readonly property var items: ["apps", "today", "notes", "system", "desks", "", "profile", "settings"] // "": a line between
    readonly property int rowHeight: Math.round(Metrics.fontSize * 2.3)

    signal picked(string name)

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 3

        Repeater {
            model: root.items

            Item {
                id: row

                required property string modelData
                readonly property bool selected: modelData === root.current

                width: parent.width
                height: modelData ? root.rowHeight : Metrics.spacing * 2

                // a line between the sections and power: a groove with raised frames
                Rectangle {
                    visible: !row.modelData
                    x: Metrics.spacing
                    width: parent.width - Metrics.spacing * 2
                    height: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colors.bevel ? Colors.lo : Colors.border

                    Rectangle {
                        visible: Colors.bevel
                        y: 1
                        width: parent.width
                        height: 1
                        color: Colors.hi
                    }
                }

                // the open one in the light, as a picked row (flat: filled like a hovered one)
                Rectangle {
                    anchors.fill: parent
                    visible: row.modelData !== "" && (row.selected || area.containsMouse)
                    color: row.selected && Colors.bevel ? Colors.accent : Colors.hoverFill
                }

                Label {
                    visible: row.modelData !== ""
                    anchors.left: parent.left
                    anchors.leftMargin: Metrics.padding
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData
                    color: row.selected ? (Colors.bevel ? Colors.onAccent : Colors.accent) : Colors.fg
                    font.bold: !Metrics.pixel && (row.selected)
                }

                Label {
                    visible: row.modelData !== ""
                    anchors.right: parent.right
                    anchors.rightMargin: Metrics.padding
                    anchors.verticalCenter: parent.verticalCenter
                    text: "▸"
                    color: row.selected && Colors.bevel ? Colors.onAccent : Colors.dim
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    enabled: row.modelData !== ""
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(row.modelData)
                }
            }
        }
    }
}
