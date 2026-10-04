pragma Singleton
import QtQuick

// Every theme comes in a dark (CRT) and a light (paper / printout) variant;
// Settings.theme picks the theme, Settings.light the variant.
QtObject {
    id: root

    // the fixed themes, plus "wallpaper" once a palette was taken from the wallpaper
    readonly property var themes: Settings.wallPalette?.dark ? Object.assign({}, fixed, { wallpaper: { dark: Settings.wallPalette.dark, light: Settings.wallPalette.light } }) : fixed

    readonly property var fixed: ({
        mono: {
            dark: {
                bg: "#0a0a0a",
                fg: "#e6e6e2",
                dim: "#727270",
                border: "#3a3a38",
                accent: "#e6e6e2",
                warn: "#c9564a",
                hoverFill: "#1c1c1a"
            },
            light: {
                bg: "#ecebe6",
                fg: "#121212",
                dim: "#75736c",
                border: "#bcb9b0",
                accent: "#121212",
                warn: "#b3261e",
                hoverFill: "#dcdad2"
            }
        },
        amber: {
            dark: {
                bg: "#100f0d",
                fg: "#d9d3c7",
                dim: "#736c5e",
                border: "#39352c",
                accent: "#d97a3d",
                warn: "#d97a3d",
                hoverFill: "#211f1a"
            },
            // sepia paper
            light: {
                bg: "#f2ead8",
                fg: "#2b2418",
                dim: "#857a63",
                border: "#cbbf9f",
                accent: "#b4541a",
                warn: "#b4541a",
                hoverFill: "#e6dcc3"
            }
        },
        phosphor: {
            dark: {
                bg: "#050a06",
                fg: "#8ee6a0",
                dim: "#3d6b48",
                border: "#1e3a25",
                accent: "#c8ffd4",
                warn: "#ff6b5e",
                hoverFill: "#0d1a10"
            },
            // green-bar printer paper
            light: {
                bg: "#e8f0e6",
                fg: "#0f2a16",
                dim: "#5f7a64",
                border: "#b3c9b5",
                accent: "#1f7a3a",
                warn: "#c0392b",
                hoverFill: "#d6e4d6"
            }
        },
        thinkpad: {
            dark: {
                bg: "#0b0b0b",
                fg: "#d6d6d6",
                dim: "#6a6a6a",
                border: "#2e2e2e",
                accent: "#e2231a",
                warn: "#e2231a",
                hoverFill: "#1a1a1a"
            },
            light: {
                bg: "#e9e9e9",
                fg: "#151515",
                dim: "#6e6e6e",
                border: "#bdbdbd",
                accent: "#d81e13",
                warn: "#d81e13",
                hoverFill: "#d9d9d9"
            }
        }
    })

    readonly property list<string> names: Object.keys(themes)
    readonly property string mode: themes[Settings.theme] ? Settings.theme : "mono"
    readonly property bool light: Settings.light
    readonly property string variant: light ? "light" : "dark"
    readonly property string fullName: `${mode}-${variant}`
    readonly property var palette: themes[mode][variant]

    readonly property color bg: palette.bg
    readonly property color fg: palette.fg
    readonly property color dim: palette.dim
    readonly property color border: palette.border
    readonly property color accent: palette.accent
    readonly property color warn: palette.warn
    readonly property color hoverFill: palette.hoverFill

    // a theme's palette in the current variant (for previews)
    function preview(name: string): var {
        return themes[name][variant];
    }
}
