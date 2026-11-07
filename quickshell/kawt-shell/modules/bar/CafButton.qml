import QtQuick
import qs.config
import qs.components
import qs.services

// while caffeine keeps the screen on (no idle lock, services/Idle.qml). A click: off
BarIcon {
    visible: Idle.caffeine
    icon: "coffee"
    tip: Strings.t("caffeine")
    onClicked: Idle.caffeine = false
}
