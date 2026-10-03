import QtQuick
import qs.config

Item {
    id: root

    property bool active: false
    readonly property int barCount: 5
    readonly property int barWidth: 3
    readonly property int barSpacing: 2
    property var levels: new Array(barCount).fill(0)

    implicitWidth: barCount * barWidth + (barCount - 1) * barSpacing
    implicitHeight: Metrics.fontSize

    onActiveChanged: if (!active) levels = new Array(barCount).fill(0)

    Timer {
        running: root.active
        repeat: true
        interval: 220
        triggeredOnStart: true
        onTriggered: root.levels = Array.from({ length: root.barCount }, () => 1 + Math.floor(Math.random() * 7))
    }

    Repeater {
        model: root.barCount

        Rectangle {
            required property int index

            x: index * (root.barWidth + root.barSpacing)
            width: root.barWidth
            height: Math.max(2, (root.levels[index] ?? 0) / 7 * root.implicitHeight)
            anchors.bottom: parent.bottom
            color: Colors.fg

            Behavior on height {
                NumberAnimation { duration: 150 }
            }
        }
    }
}
