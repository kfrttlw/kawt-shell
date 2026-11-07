import QtQuick
import qs.config

// [Commits] Settings  — lazygit-style tab strip: the open one in red brackets
// With raised frames (Settings.frames "bevel"), tabs the old way: raised, open at the bottom,
// the open one a little taller and in bold
Row {
    id: root

    property list<string> tabs: []
    property int current: 0

    spacing: Colors.bevel ? 0 : Metrics.spacing

    Repeater {
        model: root.tabs

        Item {
            id: tab

            required property string modelData
            required property int index
            readonly property bool selected: index === root.current

            implicitWidth: Colors.bevel ? word.implicitWidth + Metrics.padding * 2 : text.implicitWidth + 6
            implicitHeight: text.implicitHeight + (Colors.bevel ? 6 : 2)

            Rectangle {
                anchors.fill: parent
                visible: !Colors.bevel && area.containsMouse
                color: Colors.hoverFill
            }

            // the open one in red brackets, the others plain and dim (the same room: no jumping)
            Brackets {
                id: text

                visible: !Colors.bevel
                anchors.centerIn: parent
                text: tab.modelData
                look: tab.selected ? "on" : "off"
                shown: tab.selected
            }

            // bevel: light on the top and the left, dark on the right, nothing below
            Rectangle {
                visible: Colors.bevel
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
                    font.bold: !Metrics.pixel && (tab.selected)
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
