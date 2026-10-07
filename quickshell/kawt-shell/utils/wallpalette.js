.pragma library

// A kawt theme from a wallpaper. Takes the pixels of a tiny copy of the image
// ([r, g, b, a, r, g, b, a, ...], 0-255) and returns { dark: {...}, light: {...} } in the
// same shape as the themes in config/Colors.qml.
//
// The accent is the most *noticeable* hue, not the most common color: every pixel votes for
// its hue with weight saturation × brightness, so a small bright neon sign beats a large dark
// sky. Everything else (background, text, borders) stays near-neutral with a hint of that hue,
// so the theme keeps the kawt look. A gray / black-and-white wallpaper gives a plain gray theme.

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

// How the wallpaper's hue goes into the theme: [saturation, lightness] per role.
// The rule that makes it look good: big surfaces stay clean (almost white / deep and dark,
// only a breath of the hue), text is a dark or light shade of the hue instead of black or
// white, and the real color goes to the accent: borders, selection, highlights.
//   calm    barely there
//   strong  like a clean desktop matched to its wallpaper (the default)
//   full    surfaces carry the color too
const strengths = {
    calm: {
        dark: { bg: [0.18, 0.08], fg: [0.12, 0.88], dim: [0.1, 0.58], border: [0.18, 0.24], hoverFill: [0.2, 0.13] },
        light: { bg: [0.2, 0.97], fg: [0.25, 0.15], dim: [0.12, 0.46], border: [0.18, 0.82], hoverFill: [0.25, 0.92] }
    },
    strong: {
        dark: { bg: [0.3, 0.095], fg: [0.25, 0.9], dim: [0.16, 0.62], border: [0.35, 0.3], hoverFill: [0.38, 0.16] },
        light: { bg: [0.4, 0.965], fg: [0.45, 0.17], dim: [0.2, 0.47], border: [0.38, 0.8], hoverFill: [0.5, 0.9] }
    },
    full: {
        dark: { bg: [0.45, 0.13], fg: [0.3, 0.92], dim: [0.22, 0.65], border: [0.5, 0.36], hoverFill: [0.5, 0.2] },
        light: { bg: [0.55, 0.92], fg: [0.5, 0.15], dim: [0.25, 0.42], border: [0.5, 0.72], hoverFill: [0.6, 0.84] }
    }
};

// analysis + strength -> { dark, light } in the shape of the themes in config/Colors.qml
function build(a, strength) {
    const st = strengths[strength] || strengths.strong;
    const t = a && a.colorful ? 1 : 0;
    const h = a ? a.hue : 0;
    const accentSat = t ? Math.max(0.55, Math.min(0.75, a.sat + 0.15)) : 0;
    const hues = t ? a.hues : [];
    const make = (k, accent, warn) => {
        const out = { accent, warn, hues };
        for (const role in st[k])
            out[role] = hsl2hex(h, st[k][role][0] * t, st[k][role][1]);
        return out;
    };
    return {
        dark: make("dark", t ? hsl2hex(h, accentSat, 0.68) : "#e6e6e2", "#e8796d"),
        light: make("light", t ? hsl2hex(h, accentSat, h > 40 && h < 200 ? 0.3 : 0.4) : "#121212", "#c0392b")
    };
}

// kept for older callers: analyse + the default strength
function palette(px) {
    return build(analyse(px), "strong");
}
