import QtQuick
import qs.config

// A status icon in the bar's tray: a pixel sticker, a few words after it if any. Hovered it comes
// up a little and says what it is after half a second; pressed (or its panel open) it's sunk.
// Shows only while it has something to say: `visible` is the caller's.
Item {
    id: root

    property string icon: ""
    property string text: ""
    property color textColor: Colors.fg
    property string tip: ""
    property bool active: false
    property color ink: "transparent" // the whole icon in one color (red: something listens)
    readonly property bool hovered: area.containsMouse

    signal clicked
    signal rightClicked
    signal scrolled(int steps) // +1 = wheel up

    implicitWidth: row.implicitWidth + 6
    implicitHeight: Metrics.barHeight - 10

    Bevel {
        visible: root.hovered || root.active || area.pressed
        style: root.active || area.pressed ? "well" : "bump"
    }

    Row {
        id: row

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.active || area.pressed ? 1 : 0
        anchors.verticalCenterOffset: root.active || area.pressed ? 1 : 0
        spacing: 3

        PixIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            ink: root.ink
        }

        Label {
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.textColor
        }
    }

    MouseArea {
        id: area

        property real wheelAcc: 0

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => mouse.button === Qt.RightButton ? root.rightClicked() : root.clicked()
        onWheel: wheel => {
            wheelAcc += wheel.angleDelta.y;
            while (Math.abs(wheelAcc) >= 120) {
                root.scrolled(wheelAcc > 0 ? 1 : -1);
                wheelAcc -= wheelAcc > 0 ? 120 : -120;
            }
        }
    }

    Tip {
        text: root.tip
        hovered: root.hovered
    }
}
