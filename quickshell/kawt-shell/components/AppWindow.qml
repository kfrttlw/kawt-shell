import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services

// One of kawt's own windows (today, system): a real window of hyprland, not a layer. It has a
// button on the taskbar, moves when its title is dragged, _ puts it away like any other (the
// taskbar brings it back), □ fills the screen and back, × or esc closes it. hypr/kawt.lua
// floats it at the size it asks for, without hyprland's border and shadow: the frame is
// KWindow's. Opened and closed through Panels.toggleWindow(name).
//   AppWindow { name: "today"; title: "Today"; icon: "check"; bodyWidth: 520; bodyHeight: …; … }
FloatingWindow {
    id: root

    required property string name // Panels' name for it: "today", "system"
    property string icon: "logo"
    property alias status: frame.status
    property alias pad: frame.pad
    // the room it needs inside the frame: the window opens at that size, and never gets smaller
    property int bodyWidth: 480
    property int bodyHeight: 320
    readonly property bool big: maximized || fullscreen
    readonly property int shadow: big ? 0 : 5
    readonly property alias active: frame.focused
    default property alias content: frame.content

    implicitWidth: bodyWidth + 6 + frame.pad * 2 + shadow
    implicitHeight: bodyHeight + frame.chrome + shadow
    minimumSize: Qt.size(implicitWidth, implicitHeight)
    color: "transparent"

    function close(): void {
        Panels.closeWindow(name);
    }

    // closed by hyprland (super + q, the taskbar's menu): kawt lets it go too
    onClosed: close()

    KWindow {
        id: frame

        width: parent.width - root.shadow
        height: parent.height - root.shadow
        title: root.title
        icon: root.icon
        focused: Window.active
        shadow: !root.big
        minimizable: true
        maximizable: true
        maximized: root.big
        focus: true
        // esc from anywhere inside that didn't take it itself
        Keys.onEscapePressed: root.close()
        onCloseClicked: root.close()
        onTitlePressed: root.startSystemMove()
        onTitleDoubleClicked: root.toggleBig()
        onMaximizeClicked: root.toggleBig()
        // like any app's own _: services/Hypr.qml puts it away, its taskbar button stays
        onMinimizeClicked: {
            const t = Hyprland.activeToplevel;
            if (t)
                Hypr.minimize(t);
            else
                root.minimized = true;
        }
    }

    // hyprland lets no app maximize itself (hypr/preset.lua), so kawt asks it to, for this one:
    // the one in focus, as its button was just clicked
    function toggleBig(): void {
        Hypr.dispatch(`hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })`, "fullscreen 1");
    }
}
