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
//     "matrix":   { "dark": { "bg": "#000000", "fg": "#00ff41", "dim": "#00802a", "border": "#003b00",
//                             "accent": "#b6ffc8", "warn": "#ff3b30", "hoverFill": "#061a0b" } },
//     "thinkpad": { "dark": { "accent": "#ffffff" } }
//   }
// Colors are #rrggbb or #rrggbbaa; a missing one comes from the theme of the same name (or
// thinkpad). A new theme given only "dark" (or "light") uses it for both. Names: lowercase
// letters, digits and -. "bar" (optional) is the bar's own color; without it, it's bg.
// "face", "hi", "lo" (optional) are the frames' face, light edge and dark edge; without them
// kawt makes them from the others.
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
                fg: "#dedcd6",
                dim: "#8e8b84",
                border: "#2b2b2b",
                accent: "#e2231a",
                warn: "#e2231a",
                hoverFill: "#3a3936",
                // graphite: the old system's grey, in the dark
                face: "#2b2a28",
                hi: "#5a5852",
                hi2: "#3a3936",
                lo: "#121211",
                deep: "#000000",
                field: "#0e0e0d",
                title: "#0c0c0c",
                titleInk: "#eceae4",
                titleOff: "#3a3936",
                tip: "#1c1c1b"
            },
            // paper and ink: a printed manual
            light: {
                bg: "#e8e5dd",
                fg: "#1d1c1a",
                dim: "#77736a",
                border: "#bdb8ac",
                accent: "#c41a12",
                warn: "#c41a12",
                hoverFill: "#e4e1da",
                // silver: the old system's grey
                face: "#cfccc4",
                hi: "#fbfaf6",
                hi2: "#e4e1da",
                lo: "#8b887f",
                deep: "#1d1c1a",
                field: "#f7f5ef",
                title: "#1d1c1a",
                titleInk: "#f2f0ea",
                titleOff: "#8b887f",
                tip: "#fffbe6"
            }
        }
    })

    // ---- ~/.config/kawt/themes.json
    // (face, hi, lo: the frames' own, made from the others when not given: see "the frames" below)
    readonly property list<string> keys: ["bg", "fg", "dim", "border", "accent", "warn", "hoverFill", "bar", "face", "hi", "hi2", "lo", "deep", "field", "title", "titleInk", "titleOff", "tip"]
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

    // ---- the frames (Settings.frames). "bevel" draws kawt like an old system: whatever stands
    // out has a light edge on the top and the left and a dark one on the bottom and the right,
    // whatever is sunk (fields, lists) the other way round (components/Bevel.qml). The edges come
    // from the theme's own colors, so every theme has them, yours and the wallpaper's too;
    // themes.json may still give face, hi and lo itself. Dark or light by the background, not by
    // the variant: a theme of your own may be black in both
    // the flat look went with kawt 98: an old "frames": "flat" in settings.json is left alone
    readonly property bool bevel: true
    // [ ] around what you can press (components/Bracket.qml): not with raised frames, a button's
    // own edge says it there
    readonly property bool brackets: false
    readonly property bool darkBg: luminance(bg) < 0.25
    readonly property color white: "#ffffff"
    readonly property color black: "#000000"
    readonly property color nearBlack: "#141414"
    readonly property color face: palette.face ?? (darkBg ? mix(bg, fg, 0.07) : bg) // buttons and panels
    readonly property color hi: palette.hi ?? (darkBg ? mix(bg, fg, 0.34) : mix(bg, white, 0.85)) // the light edge
    readonly property color hi2: palette.hi2 ?? (darkBg ? mix(bg, fg, 0.16) : mix(bg, white, 0.4)) // the light edge, inside
    readonly property color lo: palette.lo ?? (darkBg ? mix(bg, black, 0.6) : mix(bg, fg, 0.42)) // the dark edge, inside
    readonly property color deep: palette.deep ?? (darkBg ? black : fg) // the dark edge outside, and the hard shadow
    readonly property color well: palette.field ?? (darkBg ? mix(bg, black, 0.35) : mix(bg, white, 0.7)) // fields and lists
    readonly property color titleOff: palette.titleOff ?? (darkBg ? mix(bg, fg, 0.17) : mix(bg, fg, 0.4)) // a title bar away from the focus
    // a title bar in focus: black in kawt's own themes, with the red striped block on it
    readonly property color title: palette.title ?? (darkBg ? mix(bg, black, 0.3) : fg)
    readonly property color titleInk: palette.titleInk ?? (luminance(title) < 0.3 ? mix(fg, white, 0.6) : nearBlack)
    readonly property color tip: palette.tip ?? (darkBg ? mix(bg, fg, 0.08) : "#fffbe6") // a tooltip's paper
    // the pixel stickers' colors (components/PixIcon.qml, utils/pixicons.js): paper from the
    // words' color on dark themes (so a wallpaper theme tints them), a grey ramp down to the ink,
    // the accent for "this is kawt" and "look here", and a halo round the ink on a dark bar
    readonly property var icon: {
        const k = darkBg ? black : fg, w = darkBg ? fg : hi;
        return { k, w, l: mix(w, k, 0.2), g: mix(w, k, 0.42), d: mix(w, k, 0.68), r: accent, o: mix(accent, black, 0.4), y: w, h: darkBg ? mix(face, fg, 0.3) : Qt.rgba(0, 0, 0, 0) };
    }
    readonly property color titleOffText: darkBg ? mix(bg, fg, 0.62) : mix(bg, white, 0.6)
    // words on the light (a title bar in focus, what's picked in a list): white, or nearly black
    // where white would hardly show (a yellow light)
    readonly property color onAccent: contrast(accent, white) >= contrast(accent, nearBlack) * 0.8 ? white : nearBlack

    // a between b and c: 0 = b, 1 = c
    function mix(b: color, c: color, t: real): color {
        return Qt.rgba(b.r + (c.r - b.r) * t, b.g + (c.g - b.g) * t, b.b + (c.b - b.b) * t, 1);
    }

    // how bright a color looks, 0..1 (the wcag way)
    function luminance(c: color): real {
        const lin = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }

    function contrast(a: color, b: color): real {
        const x = luminance(a), y = luminance(b);
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
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
