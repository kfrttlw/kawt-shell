import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Something happened and he's nowhere on the screen: he comes up out of the bottom-left
// corner for a few seconds, says it, and goes back down (Companion.react). Never over a
// fullscreen window or in do not disturb. A click on him: he talks.
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property int cell: Math.max(3, Math.round(4 * Metrics.scale))
    property real rise: 0 // 0 under the edge .. 1 up

    screen: forScreen
    color: "transparent"
    implicitWidth: Math.max(him.width, talk.maxWidth) + Metrics.padding
    implicitHeight: him.height + Math.round(70 * Metrics.scale)

    WlrLayershell.namespace: "kawt-companion-peek"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.bottom: true
    anchors.left: true
    margins.bottom: Metrics.bottomGap
    margins.left: Metrics.padding * 2

    mask: Region {
        item: him
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
            root.rise = Companion.peeking ? 1 : 0;
        }
    }

    Item {
        anchors.fill: parent
        clip: true

        Pet {
            id: him

            x: 0
            // from under the edge: only his upper part shows at first
            y: root.height - height * (0.25 + 0.75 * root.rise) + root.cell * 2
            cell: root.cell

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Companion.talkNow()
            }
        }

        Bubble {
            id: talk

            visible: text !== "" && root.rise > 0.9
            width: implicitWidth
            x: Math.min(him.width / 2, root.width - width)
            y: him.y - height + root.cell * 3
            tailX: him.width / 2 - x
        }
    }
}
