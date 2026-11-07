import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Something happened and she's nowhere on the screen: she comes up out of the bottom-left
// corner for a few seconds, head and shoulders, says it, and goes back down (Companion.react).
// Never over a fullscreen window or in do not disturb. Called (super + h) she comes up the same
// way and stays until it's pressed again. A click on her: she talks; a double click: away.
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property real shows: 0.62 // how much of her comes up
    property real rise: 0 // 0 under the edge .. 1 up

    screen: forScreen
    color: "transparent"
    implicitWidth: Math.max(her.width, talk.maxWidth) + Metrics.padding
    implicitHeight: Math.round(her.height * shows) + Math.round(110 * Metrics.scale)

    WlrLayershell.namespace: "kawt-companion-peek"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.bottom: true
    anchors.left: true
    margins.bottom: Metrics.bottomGap
    margins.left: Metrics.padding * 2

    mask: Region {
        item: her
    }

    Component.onCompleted: rise = 1

    Behavior on rise {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutBack
        }
    }

    // going: down first (Bar.qml keeps the window this long after)
    Connections {
        target: Companion

        function onPeekingChanged(): void {
            root.rise = Companion.peeking || Companion.called ? 1 : 0;
        }

        function onCalledChanged(): void {
            root.rise = Companion.peeking || Companion.called ? 1 : 0;
        }
    }

    Item {
        anchors.fill: parent
        clip: true

        Her {
            id: her

            x: 0
            // from under the edge: only her head shows at first
            y: root.height - height * root.shows * root.rise
            size: Math.round(150 * Metrics.scale)
            forScreen: root.forScreen
            origin: Qt.point(root.margins.left, root.forScreen.height - Metrics.bottomGap - root.height)

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Companion.talkNow()
                onDoubleClicked: Companion.hide()
            }
        }

        Bubble {
            id: talk

            visible: text !== "" && root.rise > 0.9
            width: implicitWidth
            x: Math.min(her.width / 2, root.width - width)
            y: her.y + her.height * 0.12 - height
            tailX: her.width / 2 - x
        }
    }
}
