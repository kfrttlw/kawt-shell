import QtQuick
import qs.config
import qs.components

// The left end of the bar with raised frames, like an old system's start button: kawt's red
// block and its name, raised even on the bar. It opens the launcher (Bar.qml)
BarBox {
    id: root

    plain: false
    spacing: Math.round(Metrics.spacing * 1.2)

    RedBlock {
        anchors.verticalCenter: parent.verticalCenter
        mode: "lit"
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: "kawt"
        font.bold: !Metrics.pixel
    }
}
