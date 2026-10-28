pragma Singleton
import QtQuick

// Sizes. The font and the bar come from the settings (profile -> cfg -> bar, or
// ~/.local/state/kawt/settings.json), so they're yours without editing this file; the panels
// grow with the font.
QtObject {
    // the one picked, if it's installed: a missing one would leave qt to pick any font, often
    // not a monospace one, and kawt lines text up in columns. Then kawt's own, then the old one
    readonly property var installed: Qt.fontFamilies()
    readonly property string fontFamily: [Settings.fontFamily, "BlexMono Nerd Font Mono", "JetBrainsMono Nerd Font Mono"].find(f => f && installed.includes(f)) ?? (Settings.fontFamily || "monospace")
    readonly property int fontSize: Math.max(9, Math.min(28, Settings.fontSize || 13))
    readonly property real scale: fontSize / 13 // 1 at the standard 13 px
    readonly property int barHeight: Settings.barHeight > 0 ? Math.max(fontSize + 10, Settings.barHeight) : fontSize + 21
    readonly property bool barBottom: Settings.barBottom
    // the room the bar takes at the top / the bottom edge, for windows that line up with it
    // (none while it's tucked away: then it only comes out over the windows)
    readonly property int topGap: barBottom || Settings.barHidden ? 0 : barHeight
    readonly property int bottomGap: barBottom && !Settings.barHidden ? barHeight : 0
    readonly property int borderWidth: 1
    readonly property int radius: 0
    readonly property int padding: 8
    readonly property int spacing: 6
    readonly property int sectionGap: 24
    readonly property int sidebarWidth: Math.round(420 * scale)
    readonly property int toastWidth: Math.round(360 * scale)
}
