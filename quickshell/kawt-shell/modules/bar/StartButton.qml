import QtQuick
import qs.config
import qs.components

// The left end of the bar, like an old system's start button: kawt's red striped block and its
// name, raised; pressed in while the start menu is open (Bar.qml)
BarBox {
    id: root

    plain: false
    spacing: 4

    PixIcon {
        anchors.verticalCenter: parent.verticalCenter
        name: "logo"
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: Strings.t("start")
    }

    Tip {
        target: root
        text: Strings.t("startTip")
        hovered: root.hovered
    }
}
