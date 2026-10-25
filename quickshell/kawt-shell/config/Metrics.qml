pragma Singleton
import QtQuick

// Sizes. The font and the bar come from the settings (profile -> cfg -> bar, or
// ~/.local/state/kawt/settings.json), so they're yours without editing this file; the panels
// grow with the font.
QtObject {
    readonly property string fontFamily: Settings.fontFamily || "JetBrainsMono Nerd Font Mono"
    readonly property int fontSize: Math.max(9, Math.min(28, Settings.fontSize || 13))
    readonly property real scale: fontSize / 13 // 1 at the standard 13 px
    readonly property int barHeight: Settings.barHeight > 0 ? Math.max(fontSize + 10, Settings.barHeight) : fontSize + 21
    readonly property bool barBottom: Settings.barBottom
    // the room the bar takes at the top / the bottom edge, for windows that line up with it
    readonly property int topGap: barBottom ? 0 : barHeight
    readonly property int bottomGap: barBottom ? barHeight : 0
    readonly property int borderWidth: 1
    readonly property int radius: 0
    readonly property int padding: 8
    readonly property int spacing: 6
    readonly property int sectionGap: 24
    readonly property int sidebarWidth: Math.round(420 * scale)
    readonly property int toastWidth: Math.round(360 * scale)
}
