pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../utils/wallpalette.js" as WallPalette

// Every theme comes in a dark (CRT) and a light (paper / printout) variant;
// Settings.theme picks the theme, Settings.light the variant.
//
// Your own themes go to ~/.config/kawt/themes.json, not here (a git pull would take a change
// here back). A new name is a new theme; a name from below changes only the colors given:
//   {
//     "matrix":   { "dark": { "bg": "#000000", "fg": "#00ff41", "dim": "#00802a", "border": "#003b00",
//                             "accent": "#b6ffc8", "warn": "#ff3b30", "hoverFill": "#061a0b" } },
//     "phosphor": { "dark": { "accent": "#ffffff" } }
//   }
// Colors are #rrggbb or #rrggbbaa; a missing one comes from the theme of the same name (or
// thinkpad). A new theme given only "dark" (or "light") uses it for both. Names: lowercase
// letters, digits and -.
// The file is read again whenever it's saved.
Singleton {
    id: root

    // the fixed themes, your own over them, plus "wallpaper" once a palette was taken from the
    // wallpaper. That one is built from the analysed wallpaper + Settings.wallStrength, so
    // changing the strength recolors at once, without looking at the picture again
    readonly property var themes: (Settings.wallPalette?.version ?? 0) >= 4 ? Object.assign({}, fixed, custom, { wallpaper: WallPalette.build(Settings.wallPalette, Settings.wallStrength) }) : Object.assign({}, fixed, custom)

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
        // kawt's own: a black thinkpad, its one red light. Red is only for where you are and what's
        // chosen (the trackpoint, the lit dot on the lid); everything else is ink and grey
        thinkpad: {
            dark: {
                bg: "#0c0c0c",
                fg: "#d8d6d0",
                dim: "#74726c",
                border: "#2b2b2b",
                accent: "#e2231a",
                warn: "#e2231a",
                hoverFill: "#1c1c1c"
            },
            // paper and ink: a printed manual
            light: {
                bg: "#e8e5dd",
                fg: "#1d1c1a",
                dim: "#6b675e",
                border: "#bdb8ac",
                accent: "#c41a12",
                warn: "#c41a12",
                hoverFill: "#d5d1c6"
            }
        }
    })

    // ---- ~/.config/kawt/themes.json
    readonly property list<string> keys: ["bg", "fg", "dim", "border", "accent", "warn", "hoverFill"]
    property var user: ({}) // the file, parsed
    property string userError: "" // what's wrong with it, for the style window; "" = fine

    // only known keys with a real color
    function clean(v: var): var {
        const out = {};
        if (v && typeof v === "object")
            for (const k of keys)
                if (typeof v[k] === "string" && /^#([0-9a-f]{6}|[0-9a-f]{8})$/i.test(v[k]))
                    out[k] = v[k];
        return out;
    }

    readonly property var custom: {
        const out = {};
        for (const name of Object.keys(user)) {
            const t = user[name];
            if (!/^[a-z0-9-]{1,24}$/.test(name) || name === "wallpaper" || !t || typeof t !== "object")
                continue;
            const base = fixed[name] ?? fixed.thinkpad;
            let dark = Object.assign({}, base.dark, clean(t.dark));
            let light = Object.assign({}, base.light, clean(t.light));
            // a new theme given in one variant only: the other is the same. (New colors for one
            // of kawt's leave its other variant as it is)
            if (!fixed[name] && !t.light)
                light = dark;
            else if (!fixed[name] && !t.dark)
                dark = light;
            out[name] = { dark, light };
        }
        return out;
    }

    FileView {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/kawt/themes.json`
        printErrors: false // there's none until you make one
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const v = JSON.parse(text());
                const ok = v !== null && typeof v === "object" && !Array.isArray(v);
                root.user = ok ? v : {};
                root.userError = ok ? "" : 'themes.json: should look like { "name": { "dark": { ... } } }';
            } catch (e) {
                // a half-saved file: keep the last good themes until it's fixed
                root.userError = `themes.json: ${e.message}`;
            }
        }
        onLoadFailed: {
            root.user = {};
            root.userError = "";
        }
    }

    readonly property list<string> names: Object.keys(themes)
    readonly property string mode: themes[Settings.theme] ? Settings.theme : "thinkpad"
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
    // the [ ] around what you can press: a step dimmer than the words (components/Brackets.qml),
    // darker still around what's switched off
    readonly property color bracket: mix(dim, border, 0.3)
    readonly property color bracketOff: mix(dim, border, 0.75)

    // a between b and c: 0 = b, 1 = c
    function mix(b: color, c: color, t: real): color {
        return Qt.rgba(b.r + (c.r - b.r) * t, b.g + (c.g - b.g) * t, b.b + (c.b - b.b) * t, 1);
    }

    // a theme's palette in the current variant (for previews)
    function preview(name: string): var {
        return themes[name][variant];
    }
}
