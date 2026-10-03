import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Wallpaper on the background layer, used when neither awww nor swww is installed.
// Only shown once one is picked in the style panel, so a hyprpaper setup keeps working until then.
PanelWindow {
    id: root

    required property ShellScreen forScreen

    screen: forScreen
    visible: Wallpapers.backend === "kawt" && Settings.wallpaper !== ""
    color: Colors.bg

    WlrLayershell.namespace: "kawt-wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    Image {
        anchors.fill: parent
        source: Settings.wallpaper ? `file://${Settings.wallpaper}` : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // decode at screen resolution, not the file's (a 6K jpg would eat ~100MB otherwise)
        sourceSize.width: root.width * (root.devicePixelRatio || 1)
        sourceSize.height: root.height * (root.devicePixelRatio || 1)
        opacity: status === Image.Ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }
    }
}
