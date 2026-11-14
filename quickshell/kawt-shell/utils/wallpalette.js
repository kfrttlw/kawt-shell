.pragma library

// A kawt theme from a wallpaper. Takes the pixels of a tiny copy of the image
// ([r, g, b, a, r, g, b, a, ...], 0-255) and returns { dark: {...}, light: {...} } in the
// same shape as the themes in config/Colors.qml.
//
// The accent is the most *noticeable* hue, not the most common color: every pixel votes for
// its hue with weight saturation × brightness, so a small bright neon sign beats a large dark
// sky. It becomes the one light; everything else (background, text, borders) is the thinkpad
// theme's, with a breath of the hue if you like (build). A grey or black-and-white wallpaper
// keeps the thinkpad's red.

function hsv(r, g, b) {
    r /= 255;
    g /= 255;
    b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
    let h = 0;
    if (d > 0) {
        if (max === r)
            h = ((g - b) / d) % 6;
        else if (max === g)
            h = (b - r) / d + 2;
        else
            h = (r - g) / d + 4;
        h = (h * 60 + 360) % 360;
    }
    return [h, max === 0 ? 0 : d / max, max];
}

function hsl2hex(h, s, l) {
    const c = (1 - Math.abs(2 * l - 1)) * s;
    const x = c * (1 - Math.abs((h / 60) % 2 - 1));
    const m = l - c / 2;
    const [r, g, b] = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
    return "#" + [r, g, b].map(v => Math.round((v + m) * 255).toString(16).padStart(2, "0")).join("");
}

// -> { hue (degrees), sat (0..1), colorful (bool), hues: up to 4 [hue, sat] peaks, strongest first }
//
// Near-black pixels don't vote: a dark background often has a faint tint of its own (a navy
// black) that would win over the picture people actually see. Only if almost everything is
// dark does the bar drop, so a very dark wallpaper still gets its color.
// "colorful" = enough of the visible pixels have a real hue; a gray or b/w picture is not.
function dominant(px) {
    const bins = 24;
    const cells = [];
    for (let i = 0; i + 3 < px.length; i += 4)
        if (px[i + 3] >= 128)
            cells.push(hsv(px[i], px[i + 1], px[i + 2]));
    if (cells.length === 0)
        return { hue: 0, sat: 0, colorful: false, hues: [] };
    let vmin = 0.12;
    if (cells.filter(c => c[2] >= vmin).length < cells.length * 0.01)
        vmin = 0.03;

    const weight = new Array(bins).fill(0), satSum = new Array(bins).fill(0);
    let visible = 0, colored = 0;
    for (const [h, s, v] of cells) {
        if (v < vmin)
            continue;
        visible++;
        if (s < 0.12)
            continue; // gray
        colored++;
        const w = s * s * v; // saturation counts twice: grayish pixels barely vote
        const b = Math.floor(h / (360 / bins)) % bins;
        weight[b] += w;
        satSum[b] += w * s;
    }
    const colorful = colored >= 3 && colored >= visible * 0.05;

    // smooth over neighbouring bins, so a hue split across a bin edge still wins
    const smooth = weight.map((w, b) => w + 0.5 * (weight[(b + 1) % bins] + weight[(b + bins - 1) % bins]));
    let best = 0;
    for (let b = 1; b < bins; b++)
        if (smooth[b] > smooth[best])
            best = b;
    const satOf = b => weight[b] > 0 ? satSum[b] / weight[b] : 0;
    // the other noticeable hues: local peaks with at least 8% of the winner's weight,
    // at least 3 bins (45°) away from every hue already taken
    const peaks = [];
    for (let b = 0; b < bins; b++) {
        const l = smooth[(b + bins - 1) % bins], r = smooth[(b + 1) % bins];
        if (smooth[b] > 0 && smooth[b] >= l && smooth[b] >= r && smooth[b] >= 0.08 * smooth[best])
            peaks.push(b);
    }
    peaks.sort((a, b) => smooth[b] - smooth[a]);
    const taken = [];
    for (const b of peaks) {
        if (taken.every(t => Math.min(Math.abs(t - b), bins - Math.abs(t - b)) >= 3))
            taken.push(b);
        if (taken.length === 4)
            break;
    }
    return { hue: (best + 0.5) * (360 / bins), sat: satOf(best), colorful, hues: taken.map(b => [(b + 0.5) * (360 / bins), satOf(b)]) };
}

// the picture, analysed once: what Settings.wallPalette keeps
function analyse(px) {
    const d = dominant(px);
    return { hue: d.hue, sat: d.sat, colorful: d.colorful, hues: d.colorful ? d.hues.map(x => x[0]) : [] };
}

// How the wallpaper's hue (or your own color's: the "own" theme) goes into the theme, kawt's
// way: the one light is that color instead of red: where you are, what's chosen.
// [saturation, lightness] per role:
//   calm    the thinkpad's colors as they are, only the light changes (the default)
//   strong  the greys take a breath of the hue (the frames stay graphite)
//   full    everything in the color: the windows, their title bars, the bar, the fields, the
//           terminals, and the wallpaper drawn in it (services/Wallpapers.qml: "tinted")
// A grey or black-and-white picture keeps the thinkpad's red.
// (Before kawt 6 there was a "strong" barely off calm, and "full" was what strong is now:
// config/Settings.qml moves the setting along, so nobody's colors change by themselves)
const strengths = {
    strong: {
        dark: { bg: [0.35, 0.075], fg: [0.2, 0.86], dim: [0.16, 0.47], border: [0.3, 0.2], hoverFill: [0.32, 0.135] },
        light: { bg: [0.4, 0.875], fg: [0.35, 0.13], dim: [0.18, 0.38], border: [0.3, 0.69], hoverFill: [0.4, 0.785] }
    },
    full: {
        dark: { bg: [0.42, 0.15], fg: [0.45, 0.92], dim: [0.25, 0.66], border: [0.38, 0.3], hoverFill: [0.4, 0.25], bar: [0.45, 0.21], title: [0.55, 0.4], field: [0.45, 0.1] },
        light: { bg: [0.5, 0.86], fg: [0.45, 0.12], dim: [0.2, 0.38], border: [0.35, 0.66], hoverFill: [0.45, 0.78], bar: [0.45, 0.8], title: [0.55, 0.38] }
    }
};
// the thinkpad's own frames (graphite or silver): full makes them from its colors instead
// (config/Colors.qml does, from bg and fg)
const frames = ["face", "hi", "hi2", "lo", "deep", "field", "title", "titleInk", "titleOff", "tip"];

// how far apart two colors read (WCAG's contrast: 1 the same .. 21 black on white)
function contrast(a, b) {
    const lum = h => {
        const c = [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16) / 255).map(v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4));
        return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
    };
    const x = lum(a), y = lum(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}

// the hue at lightness l, made lighter (on black) or darker (on paper) until it reads as well
// as the thinkpad's red does there (about 4:1): a deep blue on black, a yellow on paper
function readable(h, s, l, bg, dark) {
    let c = hsl2hex(h, s, l);
    for (let i = 0; i < 40 && contrast(c, bg) < 4.2; i++) {
        l = Math.max(0, Math.min(1, l + (dark ? 0.01 : -0.01)));
        c = hsl2hex(h, s, l);
    }
    return c;
}

// #rrggbb -> [h (degrees), s, l] (0..1)
function toHsl(hex) {
    const [r, g, b] = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255);
    const max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2, d = max - min;
    const s = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1));
    return [hsv(r * 255, g * 255, b * 255)[0], Math.min(1, s), l];
}

// a between b and c (#rrggbb): 0 = b, 1 = c
function mix(b, c, t) {
    const x = [1, 3, 5].map(i => parseInt(b.slice(i, i + 2), 16)), y = [1, 3, 5].map(i => parseInt(c.slice(i, i + 2), 16));
    return "#" + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, "0")).join("");
}

function isColor(c) {
    return typeof c === "string" && /^#[0-9a-fA-F]{6}$/.test(c);
}

// the hue the theme takes: the wallpaper's main one, or another it found that was picked in the
// style window (a new picture forgets it: its analysis is new)
function hueOf(a) {
    return typeof a.pick === "number" && (a.hues || []).includes(a.pick) ? a.pick : a.hue;
}

// the light a hue gives (a swatch of the colors found in the wallpaper)
function swatch(h) {
    return hsl2hex(h, 0.75, h > 40 && h < 200 ? 0.5 : 0.6);
}

// analysis + strength + the thinkpad theme (config/Colors.qml) -> { dark, light } in the shape
// of the themes there. own ({ color, bg }, the "own" theme): a color you gave instead of the
// wallpaper's, kept as it is wherever it reads; and a background of your own, if given (then
// both variants are the same: dark or light is the background's)
function build(a, strength, base, own) {
    const mine = own && isColor(own.color);
    const t = mine || (a && a.colorful) ? 1 : 0;
    if (!t)
        return { dark: Object.assign({ hues: [] }, base.dark), light: Object.assign({ hues: [] }, base.light) };
    const [oh, os, ol] = mine ? toHsl(own.color) : [0, 0, 0];
    const h = mine ? oh : hueOf(a);
    const sat = mine ? Math.max(0.35, Math.min(0.9, os)) : Math.max(0.6, Math.min(0.85, a.sat + 0.2));
    // a grey of your own: greys, no hue in them
    const chroma = mine ? Math.min(1, os / 0.35) : 1;
    const hues = mine ? [h] : a.hues;
    // yellows and greens look far brighter than reds and blues at the same lightness
    const bright = h > 40 && h < 200;
    const st = strengths[strength];
    const make = (k, l) => {
        const out = Object.assign({}, base[k], { hues });
        if (strength === "full") {
            for (const f of frames)
                delete out[f];
            out.titleInk = "#ffffff";
            out.tinted = true;
        }
        if (st)
            for (const role in st[k]) {
                // the title bar: darker for the bright hues, so white words still read on it
                const lt = role === "title" && bright ? st[k][role][1] - 0.1 : st[k][role][1];
                out[role] = hsl2hex(h, st[k][role][0] * chroma, lt);
            }
        out.accent = mine && contrast(own.color.toLowerCase(), out.bg) >= 3 ? own.color.toLowerCase() : readable(h, sat, mine ? ol : l, out.bg, k === "dark");
        return out;
    };
    const dark = make("dark", bright ? 0.5 : (strength === "full" ? 0.66 : 0.58));
    const light = make("light", bright ? 0.3 : 0.4);
    if (!(own && isColor(own.bg)))
        return { dark, light };
    // your background: the variant it's like, its words and lines made again around it
    const bg = own.bg.toLowerCase();
    const isDark = contrast(bg, "#000000") < contrast(bg, "#ffffff");
    const p = Object.assign({}, isDark ? dark : light, { bg });
    for (const f of frames)
        if (f !== "title" || strength !== "full")
            delete p[f];
    if (strength === "full")
        p.titleInk = "#ffffff";
    if (contrast(p.fg, bg) < 7)
        p.fg = isDark ? hsl2hex(h, 0.3 * chroma, 0.92) : hsl2hex(h, 0.4 * chroma, 0.12);
    if (contrast(p.fg, bg) < 4.5)
        p.fg = isDark ? "#f2f2f2" : "#111111";
    p.dim = mix(bg, p.fg, 0.55);
    p.border = mix(bg, p.fg, 0.22);
    p.hoverFill = mix(bg, p.fg, 0.14);
    if (strength === "full")
        p.bar = mix(bg, p.fg, 0.07);
    else
        delete p.bar;
    p.accent = contrast(own.color.toLowerCase(), bg) >= 3 ? own.color.toLowerCase() : readable(h, sat, ol, bg, isDark);
    return { dark: p, light: p };
}
