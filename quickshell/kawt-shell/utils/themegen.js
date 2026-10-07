.pragma library

// Turns a kawt theme ({ bg, fg, dim, border, accent, warn }) into a 16-color terminal palette
// and config snippets for other programs. Pure functions, no QML.

const names = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"];
// Three looks for the terminal colors, picked in the style panel, calm to bright:
//   crt:   an old monochrome monitor: everything in the theme's own ink, only a hint of hue
//   soft:  calm colors that belong to the theme: hues the theme has (its accent, the
//          wallpaper's colors) show, the others fade toward gray
//   vivid: bright, clearly colorful, but every hue still leans toward the theme's own
// Red is always the theme's own `warn`.
//   inks     crt only: green yellow blue magenta cyan as [hue, brightness on the dim -> fg
//            ramp, how much of the hue shows]
//   chroma   how colorful (OKLCH chroma) a color the theme has may get
//   floor    how much of that a color the theme lacks keeps (so ls / git / diff stay readable)
//   neutral  the same for a theme without any hue (mono)
//   pull     vivid: how far (degrees) a hue turns toward the theme's nearest hue
//   lum      [dark, light] perceived lightness (OKLCH L) of the colors
//   comment  color8: how far from dim toward fg
//   white    color7 on [dark, light]: how far from fg toward bg
//   extTint  how much hue the 256-color palette gets [plain theme, wallpaper theme]
const styles = {
    crt: {
        inks: [["#7cb36b", 1.0, 0.1], ["#d9b45b", 0.9, 0.12], ["#6a93d4", 0.75, 0.1], ["#b07ad1", 0.82, 0.1], ["#5fb2b0", 0.68, 0.1]],
        chroma: 0.05, floor: 0.2, neutral: 0.3, pull: 0, lum: [0.76, 0.45],
        comment: 0.3, white: [0.12, 0.15], extTint: [0.1, 0.4]
    },
    soft: {
        chroma: 0.085, floor: 0.35, neutral: 0.7, pull: 0, lum: [0.8, 0.47],
        comment: 0.15, white: [0.2, 0.25], extTint: [0.35, 0.6]
    },
    vivid: {
        chroma: 0.21, floor: 1, neutral: 1, pull: 15, lum: [0.8, 0.54],
        comment: 0.12, white: [0.15, 0.2], extTint: [0.65, 0.85]
    }
};
const styleNames = Object.keys(styles);

function rgb(h) {
    return [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
}

function mix(a, b, t) {
    const x = rgb(a), y = rgb(b);
    return "#" + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, "0")).join("");
}

function isLight(t) {
    const [r, g, b] = rgb(t.bg);
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.5;
}

// ---- hues: the terminal colors lean into the theme's own hues (the wallpaper's, or the accent)

function hsl(h, s, l) {
    h = ((h % 360) + 360) % 360;
    const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = l - c / 2;
    const [r, g, b] = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
    return "#" + [r, g, b].map(v => Math.round((v + m) * 255).toString(16).padStart(2, "0")).join("");
}

function hueOf(hex) {
    const [r, g, b] = rgb(hex).map(v => v / 255);
    const max = Math.max(r, g, b), d = max - Math.min(r, g, b);
    if (d === 0)
        return -1;
    const h = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
    return (h * 60 + 360) % 360;
}

function hueDist(a, b) {
    const d = Math.abs(a - b) % 360;
    return Math.min(d, 360 - d);
}

// the signed shortest turn from hue a to hue b, in degrees (-180..180)
function turn(a, b) {
    return ((b - a) % 360 + 540) % 360 - 180;
}

// a color slot (green 125, yellow 55, ...) in the wallpaper's gamut -> [hue, how much of its
// color it may show, 0..1]. A wallpaper hue near the slot is used, pulled a bit back toward
// the slot (green stays greenish). With none near, the slot keeps its own hue but fades toward
// the ink, down to `floor`: the terminal never shows a color the picture doesn't have.
// (Turning the slot toward the main hue instead invented new ones: on an ochre painting blue
// went through magenta to purple, and cyan through green.)
function wallHue(slot, hues, floor) {
    let best = hues[0];
    for (const h of hues)
        if (hueDist(h, slot) < hueDist(best, slot))
            best = h;
    const d = hueDist(best, slot);
    if (d <= 45)
        return [best + 0.2 * turn(best, slot), 1];
    return [slot, Math.max(floor, 1 - (d - 45) / 45)];
}

const slots = [125, 55, 220, 300, 185]; // green yellow blue magenta cyan

// ---- OKLCH: lightness that looks the same for every hue (in HSL a yellow looks much brighter
// than a blue of the same "lightness"), so a palette made in it looks even

function okLab(hex) {
    const lin = c => (c /= 255) <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    const [r, g, b] = rgb(hex).map(lin);
    const cbrt = x => x < 0 ? -Math.pow(-x, 1 / 3) : Math.pow(x, 1 / 3);
    const l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return [0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s, 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s];
}

// -> [r, g, b] 0..1, possibly outside 0..1 (out of the screen's gamut)
function okRgb(L, C, h) {
    const a = C * Math.cos(h * Math.PI / 180), b = C * Math.sin(h * Math.PI / 180);
    const l = Math.pow(L + 0.3963377774 * a + 0.2158037573 * b, 3);
    const m = Math.pow(L - 0.1055613458 * a - 0.0638541728 * b, 3);
    const s = Math.pow(L - 0.0894841775 * a - 1.291485548 * b, 3);
    return [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s];
}

// an OKLCH color as hex; too colorful for the screen -> the same hue and lightness, less chroma
function oklch(L, C, h) {
    let c = okRgb(L, C, h);
    for (let i = 0; i < 24 && c.some(v => v < -0.0005 || v > 1.0005); i++) {
        C *= 0.9;
        c = okRgb(L, C, h);
    }
    const enc = v => {
        v = Math.max(0, Math.min(1, v));
        return Math.round(255 * (v <= 0.0031308 ? 12.92 * v : 1.055 * Math.pow(v, 1 / 2.4) - 0.055));
    };
    return "#" + c.map(v => enc(v).toString(16).padStart(2, "0")).join("");
}

// an HSL hue (what the wallpaper analysis and the slots use) -> the OKLCH hue of that color
function okHue(h) {
    const [, a, b] = okLab(hsl(h, 0.7, 0.5));
    return (Math.atan2(b, a) * 180 / Math.PI + 360) % 360;
}

// the hues the theme itself has: the wallpaper's, else its accent's (none for mono)
function themeHues(t) {
    if (t.hues && t.hues.length > 0)
        return t.hues;
    const [r, g, b] = rgb(t.accent).map(v => v / 255);
    const max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2;
    const sat = max === min ? 0 : (max - min) / (1 - Math.abs(2 * l - 1));
    return sat > 0.25 ? [hueOf(t.accent)] : [];
}

// green / yellow / ... as this theme's version of it, at the style's lightness
function slotColor(slot, hues, st, light) {
    let h = slot, k = st.neutral;
    if (hues.length > 0) {
        [h, k] = wallHue(slot, hues, st.floor);
        // vivid keeps far colors colorful, but turns them a bit toward the theme
        if (st.pull > 0 && h === slot) {
            let best = hues[0];
            for (const x of hues)
                if (hueDist(x, slot) < hueDist(best, slot))
                    best = x;
            const d = turn(slot, best);
            h = slot + Math.sign(d) * Math.min(Math.abs(d) * 0.35, st.pull);
        }
    }
    return oklch(st.lum[light ? 1 : 0], st.chroma * k, okHue(h));
}

function ansi(t, style) {
    const st = styles[style] || styles.crt;
    const light = isLight(t);
    const hues = themeHues(t);
    // crt on a plain theme: the ink ramp, monochrome; everything else from the theme's hues
    const ramp = style === "crt" && !(t.hues && t.hues.length > 0);
    const normal = ramp
        ? [t.warn, ...st.inks.map(([hue, level, tint]) => mix(mix(t.dim, t.fg, level), hue, tint))]
        : [t.warn, ...slots.map(s => slotColor(s, hues, st, light))];
    // bright: toward the text color (more contrast on either background)
    const bright = normal.map(c => mix(c, t.fg, style === "vivid" ? 0.15 : 0.4));
    const comment = mix(t.dim, t.fg, st.comment);
    // color0 ("black") is still used as a text color by some programs, so it must stay
    // visible on the background instead of nearly matching it
    const black = mix(t.bg, t.fg, light ? 0.48 : 0.38);
    // Light: swap the roles (like PaperColor), since programs print "white" text assuming a
    // dark terminal. "white" becomes dark ink, "black" a light gray, so everything stays readable.
    return [black, ...normal, mix(t.fg, t.bg, st.white[light ? 1 : 0]), comment, ...bright, t.fg];
}

// color16..255: the xterm cube and gray ramp, recolored the same way. Programs that use the
// 256-color palette (powerlevel10k, eza, bat, btop...) would otherwise show xterm's own bright
// blues and pure white, which is what clashed with the theme. Each color keeps its brightness
// (dark stays dark, light stays light, so it still reads) but becomes the theme's ink, with a
// hint of the original hue. On light themes brightness flips, like the 16 colors do.
function extended(t, style) {
    const wall = t.hues && t.hues.length > 0;
    // the 256 colors of a wallpaper theme lean much more into its hues
    const tint = (styles[style] || styles.crt).extTint[wall ? 1 : 0];
    const light = isLight(t);
    const cube = [0, 95, 135, 175, 215, 255];
    const out = [];
    for (let i = 16; i < 256; i++) {
        let r, g, b;
        if (i < 232) {
            const n = i - 16;
            [r, g, b] = [cube[Math.floor(n / 36)], cube[Math.floor(n / 6) % 6], cube[n % 6]];
        } else {
            r = g = b = 8 + (i - 232) * 10;
        }
        const lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
        // never come close to the background: even the darkest color is used as text somewhere
        const ink = mix(t.bg, t.fg, 0.4 + 0.6 * lum);
        const hex = "#" + [r, g, b].map(v => v.toString(16).padStart(2, "0")).join("");
        let target = hex;
        if (wall && !(r === g && g === b)) {
            // the xterm color's hue moved into the wallpaper's gamut, at the ink's brightness
            const [h, k] = wallHue(hueOf(hex), t.hues, 0.2);
            const [ir, ig, ib] = rgb(ink);
            const l = (Math.max(ir, ig, ib) + Math.min(ir, ig, ib)) / 510;
            target = hsl(h, 0.6 * k, l);
        }
        out.push(r === g && g === b ? ink : mix(ink, target, tint * (light ? 0.8 : 1)));
    }
    return out;
}

function rgba(c, alpha) {
    return `rgba(${c.slice(1)}${alpha || "ff"})`;
}

// file name -> content
function files(name, t, style) {
    const a = ansi(t, style);
    const x = extended(t, style);
    const head = `kawt theme: ${name} (generated by kawt-shell, overwritten on theme change)`;
    const bare = c => c.slice(1);

    return {
        "colors.json": JSON.stringify(Object.assign({ name }, t, { ansi: a }), null, 2),

        "colors.sh": [
            `# ${head}`,
            "# usage: . ~/.local/state/kawt/theme/colors.sh",
            `KAWT_THEME=${name}`,
            ...["bg", "fg", "dim", "border", "accent", "warn"].map(k => `KAWT_${k.toUpperCase()}='${t[k]}'`),
            ...a.map((c, i) => `KAWT_COLOR${i}='${c}'`)
        ].join("\n"),

        "kitty.conf": [
            `# ${head}`,
            "# kitty.conf: include ~/.local/state/kawt/theme/kitty.conf",
            `foreground ${t.fg}`,
            `background ${t.bg}`,
            `cursor ${t.accent}`,
            `cursor_text_color ${t.bg}`,
            `selection_foreground ${t.bg}`,
            `selection_background ${t.accent}`,
            `url_color ${t.accent}`,
            `active_border_color ${t.accent}`,
            `inactive_border_color ${t.border}`,
            `tab_bar_background ${t.bg}`,
            `active_tab_foreground ${t.accent}`,
            `active_tab_background ${t.bg}`,
            `inactive_tab_foreground ${t.dim}`,
            `inactive_tab_background ${t.bg}`,
            ...a.map((c, i) => `color${i} ${c}`),
            ...x.map((c, i) => `color${i + 16} ${c}`)
        ].join("\n"),

        "foot.ini": [
            `# ${head}`,
            "# foot.ini: include=~/.local/state/kawt/theme/foot.ini",
            "[colors]",
            `foreground=${bare(t.fg)}`,
            `background=${bare(t.bg)}`,
            `selection-foreground=${bare(t.bg)}`,
            `selection-background=${bare(t.accent)}`,
            ...a.slice(0, 8).map((c, i) => `regular${i}=${bare(c)}`),
            ...a.slice(8).map((c, i) => `bright${i}=${bare(c)}`),
            ...x.map((c, i) => `${i + 16}=${bare(c)}`)
        ].join("\n"),

        "alacritty.toml": [
            `# ${head}`,
            '# alacritty.toml: [general] import = ["~/.local/state/kawt/theme/alacritty.toml"]',
            "[colors.primary]",
            `background = "${t.bg}"`,
            `foreground = "${t.fg}"`,
            "",
            "[colors.cursor]",
            `cursor = "${t.accent}"`,
            `text = "${t.bg}"`,
            "",
            "[colors.normal]",
            ...names.map((n, i) => `${n} = "${a[i]}"`),
            "",
            "[colors.bright]",
            ...names.map((n, i) => `${n} = "${a[i + 8]}"`),
            "",
            "[colors]",
            `indexed_colors = [${x.map((c, i) => `{ index = ${i + 16}, color = "${c}" }`).join(", ")}]`
        ].join("\n"),

        // a table, for hyprland.lua: local colors = dofile(".../hyprland_colors.lua")
        "hyprland_colors.lua": [
            `-- ${head}`,
            "return {",
            `    m_active = "${rgba(t.accent, "ee")}",`,
            `    m_inactive = "${rgba(t.border, "aa")}",`,
            `    m_shadow = "${rgba("#000000", isLight(t) ? "22" : "44")}",`,
            "}"
        ].join("\n"),

        "hyprland.conf": [
            `# ${head}`,
            "# hyprland.conf: source = ~/.local/state/kawt/theme/hyprland.conf",
            "general {",
            `    col.active_border = ${rgba(t.accent)}`,
            `    col.inactive_border = ${rgba(t.border)}`,
            "}"
        ].join("\n")
    };
}

// OSC escape sequences that recolor a running terminal (the pywal trick)
function sequences(t, style) {
    const osc = (code, c) => `\x1b]${code};${c}\x1b\\`;
    return [...ansi(t, style), ...extended(t, style)].map((c, i) => osc(`4;${i}`, c)).join("")
        + osc(10, t.fg) + osc(11, t.bg) + osc(12, t.accent) + osc(17, t.accent) + osc(19, t.bg);
}
