pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../utils/wallpalette.js" as WallPalette

// kawt's themes: thinkpad (black and its one red light, or paper and ink) and wallpaper (the same,
// lit in the wallpaper's color: utils/wallpalette.js). Each comes in a dark (black) and a light
// (white: paper) variant; Settings.theme picks the theme, Settings.light the variant.
//
// Your own themes go to ~/.config/kawt/themes.json, not here (a git pull would take a change
// here back). A new name is a new theme; "thinkpad" changes only the colors given:
//   {
//     "phosphor": { "dark": { "bg": "#000000", "fg": "#00ff41", "dim": "#00802a", "border": "#003b00",
//                             "accent": "#b6ffc8", "warn": "#ff3b30", "hoverFill": "#061a0b" } },
//     "thinkpad": { "dark": { "accent": "#ffffff" } }
//   }
// Colors are #rrggbb or #rrggbbaa; a missing one comes from the theme of the same name (or
// thinkpad). A new theme given only "dark" (or "light") uses it for both. Names: lowercase
// letters, digits and -. "bar" (optional) is the bar's own color; without it, it's bg.
// The file is read again whenever it's saved. The style window writes it too: [+ new] and
// [edit] there (modules/style/ThemeEditor.qml) make and change themes without typing json.
Singleton {
    id: root

    // the fixed themes, your own over them, plus "wallpaper" once a palette was taken from the
    // wallpaper. That one is built from the analysed wallpaper + Settings.wallStrength, so
    // changing the strength recolors at once, without looking at the picture again
    readonly property var themes: (Settings.wallPalette?.version ?? 0) >= 4 ? Object.assign({}, fixed, custom, { wallpaper: WallPalette.build(Settings.wallPalette, Settings.wallStrength, fixed.thinkpad) }) : Object.assign({}, fixed, custom)

    readonly property var fixed: ({
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
    readonly property list<string> keys: ["bg", "fg", "dim", "border", "accent", "warn", "hoverFill", "bar"]
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

    // ---- written from the theme editor. Yours whole, in both variants; kawt's own (thinkpad:
    // black and white) only in what differs from it, so a later kawt can still change the rest
    function saveTheme(name: string, dark: var, light: var): void {
        const u = Object.assign({}, user);
        if (fixed[name]) {
            const t = {};
            const d = differs(dark, fixed[name].dark), l = differs(light, fixed[name].light);
            if (Object.keys(d).length)
                t.dark = d;
            if (Object.keys(l).length)
                t.light = l;
            if (Object.keys(t).length)
                u[name] = t;
            else
                delete u[name];
        } else {
            u[name] = { dark: clean(dark), light: clean(light) };
        }
        writeUser(u);
    }

    function differs(v: var, base: var): var {
        const c = clean(v), out = {};
        for (const k in c)
            if (c[k].toLowerCase() !== (base[k] ?? "").toLowerCase())
                out[k] = c[k];
        return out;
    }

    // yours goes; for kawt's own, its colors come back
    function removeTheme(name: string): void {
        const u = Object.assign({}, user);
        delete u[name];
        if (Settings.theme === name && !fixed[name])
            Settings.theme = "thinkpad";
        writeUser(u);
    }

    function writeUser(u: var): void {
        user = u;
        userError = "";
        themesFile.setText(JSON.stringify(u, null, 2) + "\n");
    }

    FileView {
        id: themesFile

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
    readonly property color bar: palette.bar ?? palette.bg // the bar's own, if the theme has one
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

    // ---- the themes to pick, in order: black and white (the thinkpad theme, dark and light),
    // the wallpaper's once one was looked at (in the variant you're in), then your own. The style
    // window shows them all; [<] [>] in profile -> cfg and [ ] in the style window walk them
    readonly property var choices: [{ name: "black", theme: "thinkpad", light: false }, { name: "white", theme: "thinkpad", light: true }, ...names.filter(n => n !== "thinkpad").map(n => ({ name: n, theme: n, light: null }))]
    readonly property int chosen: choices.findIndex(c => isCurrent(c))
    readonly property string chosenName: choices[chosen]?.name ?? mode

    function isCurrent(c: var): bool {
        return mode === c.theme && (c.light === null || light === c.light);
    }

    function choose(c: var): void {
        Settings.theme = c.theme;
        if (c.light !== null)
            Settings.light = c.light;
    }

    function step(d: int): void {
        const n = choices.length;
        choose(choices[((chosen < 0 ? 0 : chosen) + d + n) % n]);
    }
}
