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

// -> { hue (degrees), sat (0..1), colorful (bool) }
function dominant(px) {
    const bins = 24, weight = new Array(bins).fill(0), satSum = new Array(bins).fill(0);
    let total = 0, n = 0;
    for (let i = 0; i + 3 < px.length; i += 4) {
        if (px[i + 3] < 128)
            continue; // transparent
        const [h, s, v] = hsv(px[i], px[i + 1], px[i + 2]);
        n++;
        const w = s * s * v * v; // saturation and brightness both count twice: dark or grayish pixels barely vote
        const b = Math.floor(h / (360 / bins)) % bins;
        weight[b] += w;
        satSum[b] += w * s;
        total += w;
    }
    if (n === 0)
        return { hue: 0, sat: 0, colorful: false };
    // smooth over neighbouring bins, so a hue split across a bin edge still wins
    let best = 0, bestW = -1;
    for (let b = 0; b < bins; b++) {
        const w = weight[b] + 0.5 * (weight[(b + 1) % bins] + weight[(b + bins - 1) % bins]);
        if (w > bestW) {
            bestW = w;
            best = b;
        }
    }
    const sat = weight[best] > 0 ? satSum[best] / weight[best] : 0;
    // "colorful" if the winning hue carries a real share of the picture
    return { hue: (best + 0.5) * (360 / bins), sat, colorful: total / n > 0.004 };
}

function palette(px) {
    const d = dominant(px);
    const h = d.hue;
    // gray wallpaper: no tint, a light-gray accent like mono
    const tint = d.colorful ? 1 : 0;
    const accentSat = d.colorful ? Math.max(0.45, Math.min(0.8, d.sat)) : 0;
    return {
        dark: {
            bg: hsl2hex(h, 0.14 * tint, 0.06),
            fg: hsl2hex(h, 0.1 * tint, 0.87),
            dim: hsl2hex(h, 0.08 * tint, 0.5),
            border: hsl2hex(h, 0.12 * tint, 0.22),
            accent: d.colorful ? hsl2hex(h, accentSat, 0.62) : "#e6e6e2",
            warn: "#e06c60",
            hoverFill: hsl2hex(h, 0.12 * tint, 0.11)
        },
        light: {
            bg: hsl2hex(h, 0.18 * tint, 0.93),
            fg: hsl2hex(h, 0.12 * tint, 0.1),
            dim: hsl2hex(h, 0.08 * tint, 0.44),
            border: hsl2hex(h, 0.12 * tint, 0.74),
            accent: d.colorful ? hsl2hex(h, accentSat, 0.3) : "#121212",
            warn: "#b3261e",
            hoverFill: hsl2hex(h, 0.15 * tint, 0.86)
        }
    };
}
