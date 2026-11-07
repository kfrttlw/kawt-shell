import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// [tile] / [float]: how the desk this screen shows lays out its windows. Floating, it's like
// KDE's: windows where you put them, at any size, new ones in the middle. A click (or
// super + ctrl + v) switches (services/Hypr.qml). Lua configs only
BracketButton {
    id: root

    required property ShellScreen screen
    readonly property int desk: Hyprland.monitorFor(screen)?.activeWorkspace?.id ?? 0
    readonly property bool floats: Hypr.floatDesks.includes(desk)
    // Bar.qml shows it where the look has it
    readonly property bool wanted: Hypr.lua && desk > 0 && Settings.barShows("desk")

    label: floats ? "float" : "tile"
    onClicked: Hypr.setDeskFloating(desk, !floats)
}
