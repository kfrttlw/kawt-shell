import QtQuick
import qs.config
import qs.services

// ▂▅▃▇▂ next to the player: the real sound from cava (services/Cava.qml). Without cava it
// just moves to show that something plays.
Item {
    id: root

    property bool active: false
    readonly property bool real: Cava.available
    readonly property int barCount: Cava.bars
    readonly property int barWidth: 3
    readonly property int barSpacing: 2
    property var fake: new Array(barCount).fill(0)
    readonly property var levels: !active ? new Array(barCount).fill(0) : real ? Cava.levels : fake

    implicitWidth: barCount * barWidth + (barCount - 1) * barSpacing
    implicitHeight: Metrics.fontSize

    // the fallback without cava
    Timer {
        running: root.active && !root.real
        repeat: true
        interval: 220
        triggeredOnStart: true
        onTriggered: root.fake = Array.from({ length: root.barCount }, () => 1 + Math.floor(Math.random() * 7))
    }

    Repeater {
        model: root.barCount

        Rectangle {
            required property int index

            x: index * (root.barWidth + root.barSpacing)
            width: root.barWidth
            height: Math.max(2, (root.levels[index] ?? 0) / Cava.max * root.implicitHeight)
            anchors.bottom: parent.bottom
            color: Colors.fg

            // cava already sends 20 smooth frames a second: easing between them would only
            // make the bar redraw at full refresh rate for nothing
            Behavior on height {
                enabled: !root.real

                NumberAnimation {
                    duration: 150
                }
            }
        }
    }
}
