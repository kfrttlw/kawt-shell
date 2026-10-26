.pragma library

// kawt's folder icons: pixel folders 16 x 16 in the theme's colors, for thunar and the "open
// file" windows (an icon theme of their own, "kawt": ~/.local/share/icons/kawt links to
// ~/.local/state/kawt/theme/icons/kawt, written again on every theme switch). Only folders and
// the trash are kawt's; every other icon comes from Papirus underneath.
//   b  the folder's back and tab      f  its front      l  the front's top edge
//   g  the sign on it (the theme's background, cut out of the front)
//   p  paper in the full trash

const folder = [
    "................",
    "................",
    ".bbbbb..........",
    ".bbbbbb.........",
    ".bbbbbbbbbbbbbb.",
    ".llllllllllllll.",
    ".ffffffffffffff.",
    ".ffffffffffffff.",
    ".ffffffffffffff.",
    ".ffffffffffffff.",
    ".ffffffffffffff.",
    ".ffffffffffffff.",
    ".ffffffffffffff.",
    ".ffffffffffffff.",
    "................",
    "................"
];

// the signs, 6 x 6, in the middle of the front
const signs = {
    home: ["..gg..", ".gggg.", "gggggg", ".gggg.", ".g..g.", ".g..g."],
    download: ["..gg..", "..gg..", "..gg..", "gggggg", ".gggg.", "..gg.."],
    documents: ["gggggg", "......", "gggg..", "......", "gggggg", "......"],
    music: ["..gg..", "..ggg.", "..g.gg", "..g...", "ggg...", "ggg..."],
    pictures: ["....gg", "....gg", "......", ".g....", "ggg.g.", "gggggg"],
    videos: [".g....", ".ggg..", ".ggggg", ".ggggg", ".ggg..", ".g...."],
    desktop: ["gggggg", "g....g", "g....g", "gggggg", "..gg..", ".gggg."],
    templates: ["gg..gg", "g....g", "......", "......", "g....g", "gg..gg"],
    public: ["..gg..", "..gg..", "......", ".gggg.", "gggggg", "gggggg"],
    remote: [".gggg.", "g.gg.g", "gggggg", "g.gg.g", ".gggg.", "......"]
};

const trash = [
    "................",
    "......bbbb......",
    "..bbbbbbbbbbbb..",
    "................",
    "...ffffffffff...",
    "...ff.ffff.ff...",
    "...ff.ffff.ff...",
    "...ff.ffff.ff...",
    "...ff.ffff.ff...",
    "...ff.ffff.ff...",
    "...ff.ffff.ff...",
    "...ff.ffff.ff...",
    "....ffffffff....",
    "................",
    "................",
    "................"
];

const trashFull = [
    "......bbbb......",
    "..bbbbbbbbbbbb..",
    ".....pp.ppp.....",
    "....ppppppp.....",
    "...ffffffffff...",
    "...ff.ffff.ff...",
    "...ff.ffff.ff...",
    "...ff.ffff.ff...",
    "...ff.ffff.ff...",
    "...ff.ffff.ff...",
    "...ff.ffff.ff...",
    "...ff.ffff.ff...",
    "....ffffffff....",
    "................",
    "................",
    "................"
];

// icon name -> its picture (the names gtk asks for)
const icons = {
    "folder": folder,
    "folder-open": folder,
    "folder-drag-accept": folder,
    "inode-directory": folder,
    "user-home": withSign("home"),
    "folder-home": withSign("home"),
    "user-desktop": withSign("desktop"),
    "folder-desktop": withSign("desktop"),
    "folder-documents": withSign("documents"),
    "folder-download": withSign("download"),
    "folder-downloads": withSign("download"),
    "folder-music": withSign("music"),
    "folder-pictures": withSign("pictures"),
    "folder-videos": withSign("videos"),
    "folder-templates": withSign("templates"),
    "folder-publicshare": withSign("public"),
    "folder-remote": withSign("remote"),
    "user-trash": trash,
    "user-trash-full": trashFull
};

function withSign(name) {
    const s = signs[name];
    return folder.map((row, y) => {
        const r = s[y - 7];
        if (!r)
            return row;
        return row.slice(0, 5) + [...r].map((c, i) => c === "g" ? "g" : row[5 + i]).join("") + row.slice(11);
    });
}

function rgb(h) {
    return [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
}

function mix(a, b, t) {
    const x = rgb(a), y = rgb(b);
    return "#" + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, "0")).join("");
}

// rows of letters -> an svg, one rect for each run of a color in a row
function svg(rows, colors) {
    let out = "";
    rows.forEach((row, y) => {
        for (let x = 0; x < row.length;) {
            let w = 1;
            while (row[x + w] === row[x])
                w++;
            if (colors[row[x]])
                out += `<rect x="${x}" y="${y}" width="${w}" height="1" fill="${colors[row[x]]}"/>`;
            x += w;
        }
    });
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="16" height="16" shape-rendering="crispEdges">${out}</svg>`;
}

// file name (under the theme folder) -> content, for a kawt theme ({ bg, fg, accent, ... })
function files(name, t, light) {
    const colors = {
        f: t.accent,
        l: mix(t.accent, t.fg, 0.35),
        b: mix(t.accent, t.bg, 0.45),
        g: t.bg,
        p: t.fg
    };
    const out = {
        "icons/kawt/index.theme": [
            "[Icon Theme]",
            "Name=kawt",
            `Comment=kawt's folders in the theme's colors (${name}); everything else from Papirus`,
            `Inherits=${light ? "Papirus-Light" : "Papirus-Dark"},Papirus,Adwaita,hicolor`,
            "Directories=scalable/places",
            "",
            "[scalable/places]",
            "Size=48",
            "MinSize=8",
            "MaxSize=512",
            "Type=Scalable",
            "Context=Places"
        ].join("\n")
    };
    for (const icon in icons)
        out[`icons/kawt/scalable/places/${icon}.svg`] = svg(icons[icon], colors);
    return out;
}
