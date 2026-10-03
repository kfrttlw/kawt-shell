import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.config

// App icon from the icon theme, grayscale unless `colored`. Falls back to the
// app's first letter when the theme has no icon for it.
Item {
    id: root

    property string icon: ""
    property string name: ""
    property bool colored: false
    readonly property string source: icon === "" ? "" : icon.startsWith("/") ? `file://${icon}` : Quickshell.iconPath(icon, true)

    IconImage {
        anchors.fill: parent
        visible: root.source !== ""
        source: root.source
        asynchronous: true
        layer.enabled: !root.colored
        layer.effect: MultiEffect {
            saturation: -1
        }
    }

    Label {
        anchors.centerIn: parent
        visible: root.source === ""
        text: root.name.charAt(0).toLowerCase()
        color: root.colored ? Colors.accent : Colors.dim
        font.pixelSize: Math.round(root.height * 0.75)
    }
}
