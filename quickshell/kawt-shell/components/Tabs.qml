import QtQuick
import qs.config

// [Commits] Settings  — lazygit-style tab strip
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
                visible: tab.selected || area.containsMouse
                color: Colors.hoverFill
            }

            Label {
                id: text

                anchors.centerIn: parent
                text: tab.selected ? `[${tab.modelData}]` : ` ${tab.modelData} `
                color: tab.selected ? Colors.fg : Colors.dim
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
