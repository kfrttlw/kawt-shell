pragma Singleton
import QtQuick

// Sizes. The font and the bar come from the settings (profile -> cfg -> bar, or
// ~/.local/state/kawt/settings.json), so they're yours without editing this file; the panels
// grow with the font.
QtObject {
    // kawt's own font: Departure Mono (fonts/, OFL), a pixel one with cyrillic. It comes with kawt,
    // nothing to install. Pixel fonts are sharp only at whole multiples of their grid (11, 22 px):
    // Label draws them without smoothing (components/Label.qml)
    readonly property FontLoader departure: FontLoader {
        source: Qt.resolvedUrl("../fonts/DepartureMono-Regular.otf")
    }
    readonly property string kawtFont: departure.status === FontLoader.Ready ? departure.name : "Departure Mono"
    // the one picked, if it's there: a missing one would leave qt to pick any font, often not a
    // monospace one, and kawt lines text up in columns. Then kawt's own, then the old one
    readonly property var installed: [kawtFont, ...Qt.fontFamilies()]
    readonly property string fontFamily: [Settings.fontFamily === "Departure Mono" ? kawtFont : Settings.fontFamily, kawtFont, "BlexMono Nerd Font Mono"].find(f => f && installed.includes(f)) ?? "monospace"
    readonly property bool pixel: fontFamily === kawtFont || fontFamily.startsWith("DepartureMono")
    // a smooth font for long text (notes, the ai's answers): plex, or the picked one when "plex
    // everywhere" is on
    readonly property string longFamily: Qt.fontFamilies().includes("BlexMono Nerd Font Mono") ? "BlexMono Nerd Font Mono" : fontFamily
    readonly property int longSize: 13
    readonly property int fontSize: pixel ? (Settings.fontSize >= 17 ? 22 : 11) : Math.max(9, Math.min(28, Settings.fontSize || 13))
    // 1 at the font's own standard size (11 for the pixel font, 13 for the others): panels grow
    // with the font
    readonly property real scale: fontSize / (pixel ? 11 : 13)
    // a font size near the standard one: d px more or less, or f times it. The pixel font has only
    // 11 and 22 sharp, so there smaller and bigger text keep to those (dim the words instead)
    function size(d: int): int {
        return pixel ? fontSize : fontSize + d;
    }

    function times(f: real): int {
        return pixel ? Math.max(11, Math.round(fontSize * f / 11) * 11) : Math.round(fontSize * f);
    }

    readonly property int barHeight: Settings.barHeight > 0 ? Math.max(fontSize + 10, Settings.barHeight) : pixel ? fontSize * 2 + 6 : fontSize + 21
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
