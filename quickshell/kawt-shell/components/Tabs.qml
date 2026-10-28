import QtQuick
import qs.config

// [Commits] Settings  — lazygit-style tab strip: the open one in red brackets
Row {
    id: root

    property list<string> tabs: []
    property int current: 0

    spacing: Metrics.spacing

    Repeater {
        model: root.tabs

        Item {
            id: tab

            required property string modelData
            required property int index
            readonly property bool selected: index === root.current

            implicitWidth: text.implicitWidth + 6
            implicitHeight: text.implicitHeight + 2

            Rectangle {
                anchors.fill: parent
                visible: area.containsMouse
                color: Colors.hoverFill
            }

            // the open one in red brackets, the others plain and dim (the same room: no jumping)
            Brackets {
                id: text

                anchors.centerIn: parent
                text: tab.modelData
                look: tab.selected ? "on" : "off"
                shown: tab.selected
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.current = tab.index
            }
        }
    }
}
