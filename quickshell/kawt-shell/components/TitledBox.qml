import QtQuick
import qs.config

// ┌─title──────────┐  box with the title sitting on the top border line
// With Settings.frames "bevel" the line is a groove (a group of things inside a panel), unless
// it's a `window`: then it's one of kawt's own windows, a raised frame with a title bar along its
// top (in the light while `focused`) and the dotted shadow under it.
// Lay the inside out from `contentTop` (the room the title takes in the box); `titleOverhang` is
// how far the title sticks out above it; leave `shadowRoom` free to the right and below.
Rectangle {
    id: root

    property string title: ""
    property string hint: ""
    property bool window: false
    property bool focused: true
    readonly property bool titleBar: window
    readonly property real titleOverhang: !titleBar && title !== "" ? titleText.implicitHeight / 2 : 0
    readonly property int barHeight: Math.round(Metrics.fontSize * 1.7)
    readonly property real contentTop: titleBar ? barHeight + 3 : titleOverhang
    readonly property int shadowRoom: titleBar ? shadow.depth : 0
    // what's under the title on the line, to cut it out
    readonly property color ground: Colors.face

    color: titleBar ? Colors.face : ground
    border.color: Colors.border
    border.width: 0
    radius: Metrics.radius

    // under the window, behind it
    DotShadow {
        id: shadow

        z: -1
        visible: root.titleBar
        width: root.width
        height: root.height
    }

    Bevel {
        style: root.titleBar ? "raised" : "etched"
        flatLine: false
    }

    // ---- a window: the title bar
    Rectangle {
        visible: root.titleBar
        x: 3
        y: 3
        width: parent.width - 6
        height: root.barHeight
        color: root.focused ? Colors.title : Colors.titleOff

        // kawt's red striped block on every title
        PixIcon {
            id: titleLogo

            x: 3
            anchors.verticalCenter: parent.verticalCenter
            name: "logo"
        }

        Label {
            anchors.left: titleLogo.right
            anchors.leftMargin: 4
            anchors.right: barHint.left
            anchors.rightMargin: Metrics.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: root.focused ? Colors.titleInk : Colors.titleOffText
            font.bold: !Metrics.pixel
            elide: Text.ElideRight
        }

        Label {
            id: barHint

            anchors.right: parent.right
            anchors.rightMargin: Metrics.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: root.hint
            color: root.focused ? Colors.titleInk : Colors.titleOffText
            opacity: 0.8
            font.pixelSize: Metrics.size(-2)
        }
    }

    // ---- a box: the title and the hint on the line
    Rectangle {
        visible: !root.titleBar && root.title !== ""
        x: Metrics.padding
        y: -height / 2
        width: titleText.implicitWidth + 4
        height: titleText.implicitHeight
        color: root.ground

        Label {
            id: titleText

            anchors.centerIn: parent
            text: root.title
            color: Colors.fg
        }
    }

    Rectangle {
        visible: !root.titleBar && root.hint !== ""
        anchors.right: parent.right
        anchors.rightMargin: Metrics.padding
        y: -height / 2
        width: hintText.implicitWidth + 4
        height: hintText.implicitHeight
        color: root.ground

        Label {
            id: hintText

            anchors.centerIn: parent
            text: root.hint
            color: Colors.dim
            font.pixelSize: Metrics.size(-2)
        }
    }
}
