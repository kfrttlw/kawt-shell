import QtQuick
import qs.config

// An old picture tube around its content: turnOn() opens it from a bright line across the
// middle, turnOff() pulls it into that line and then into a dot, and says offDone. With
// Settings.crt off both are instant (offDone comes at once).
Item {
    id: root

    default property alias content: tube.data
    readonly property bool animated: Settings.crt

    signal offDone

    function turnOn(): void {
        offAnim.stop();
        if (!animated) {
            tubeScale.xScale = 1;
            tubeScale.yScale = 1;
            return;
        }
        tubeScale.xScale = 0.04;
        tubeScale.yScale = 0.006;
        glow.fade = 1;
        onAnim.restart();
    }

    function turnOff(): void {
        onAnim.stop();
        glow.fade = 1;
        if (!animated) {
            offDone();
            return;
        }
        offAnim.restart();
    }

    Item {
        id: tube

        anchors.fill: parent

        transform: Scale {
            id: tubeScale

            origin.x: root.width / 2
            origin.y: root.height / 2
        }
    }

    // the beam: as wide and as tall as the open part, bright while it's a thin line and fading
    // as it opens (or brightening as it closes)
    Rectangle {
        id: glow

        property real fade: 1

        anchors.centerIn: parent
        width: root.width * tubeScale.xScale
        height: Math.max(2, root.height * tubeScale.yScale)
        color: Colors.fg
        opacity: onAnim.running || offAnim.running ? Math.pow(1 - tubeScale.yScale, 6) * fade : 0
    }

    // the line spreads across, then opens top and bottom while the glow fades
    SequentialAnimation {
        id: onAnim

        NumberAnimation {
            target: tubeScale
            property: "xScale"
            to: 1
            duration: 90
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: tubeScale
            property: "yScale"
            to: 1
            duration: 280
            easing.type: Easing.OutCubic
        }
    }

    // into a line (brightening), the line into a dot, then nothing
    SequentialAnimation {
        id: offAnim

        NumberAnimation {
            target: tubeScale
            property: "yScale"
            to: 0.006
            duration: 160
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: tubeScale
            property: "xScale"
            to: 0.01
            duration: 110
            easing.type: Easing.InQuad
        }

        NumberAnimation {
            target: glow
            property: "fade"
            to: 0
            duration: 80
        }

        ScriptAction {
            script: root.offDone()
        }
    }
}
