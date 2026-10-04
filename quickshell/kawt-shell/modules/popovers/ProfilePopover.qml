import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import "../profile"

// [~] in the bar
Popover {
    id: root

    name: "profile"
    title: `${SysInfo.user}@${SysInfo.host}`
    cardWidth: 600

    ProfileContent {
        Layout.fillWidth: true
        open: root.open
        forScreen: root.forScreen
    }
}
