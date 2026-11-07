import QtQuick
import qs.config

// Tabs the old way: raised, open at the bottom, the open one a little taller and in the text
// color, the others dim.
//   Tabs { tabs: ["Today", "Tasks"]; current: 0 }
Row {
    id: root

    property list<string> tabs: []
    property int current: 0

    spacing: 0

    Repeater {
        model: root.tabs

        Item {
            id: tab

            required property string modelData
            required property int index
            readonly property bool selected: index === root.current

            implicitWidth: word.implicitWidth + Metrics.padding * 2
            implicitHeight: word.implicitHeight + 6

            // light on the top and the left, dark on the right, nothing below
            Rectangle {
                y: tab.selected ? 0 : 2
                width: parent.width
                height: parent.height - y
                color: area.containsMouse && !tab.selected ? Colors.mix(Colors.face, Colors.hi, 0.12) : Colors.face

                Rectangle {
                    width: parent.width - 1
                    height: 1
                    color: Colors.hi
                }

                Rectangle {
                    width: 1
                    height: parent.height
                    color: Colors.hi
                }

                Rectangle {
                    x: parent.width - 1
                    width: 1
                    height: parent.height
                    color: Colors.deep
                }

                Rectangle {
                    x: parent.width - 2
                    y: 1
                    width: 1
                    height: parent.height - 1
                    color: Colors.lo
                }

                Label {
                    id: word

                    anchors.centerIn: parent
                    text: tab.modelData
                    color: tab.selected ? Colors.fg : Colors.dim
                    font.bold: !Metrics.pixel && tab.selected
                }
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
