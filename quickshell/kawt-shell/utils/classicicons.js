.pragma library

// kawt's "classic" icons (Settings.iconStyle, the standard): painted ones, as desktops had them in
// the early 2000s. A tan folder seen a little from above and in front, a sheet of paper in it and
// its sign big on its corner; an open metal bin with crumpled paper; a page with its corner
// folded and what kind of file it is drawn on it. 64 x 64, scalable; colors of their own, the
// same in every theme. Written into kawt's icon theme (places and mimetypes: thunar, the "open
// file" windows) and read from there by the desktop (modules/desktop). Every other icon still
// comes from Papirus underneath.

let n = 0;
const id = p => `${p}${++n}`;
const open = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">`;
const shade = (g, cx, cy, rx, ry, a) => `<radialGradient id="${g}" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#000" stop-opacity="${a}"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>`;

// a sign drawn twice: a white edge under it, so it reads on the folder and the page
function halo(inner) {
    return `<g stroke="#fff" stroke-width="3" stroke-linejoin="round" fill="#fff" opacity=".95">${inner}</g>${inner}`;
}

const signs = {
    home: halo(`<path d="M1.5 12.5L12 2.5l10.5 10" fill="none" stroke="#1d1c1a" stroke-width="3.2" stroke-linecap="round"/><rect x="4.5" y="11" width="15" height="12" fill="#2b2a27" stroke="none"/><rect x="15.6" y="3.5" width="2.6" height="5.5" fill="#1d1c1a" stroke="none"/>`) + `<rect x="10" y="15" width="5" height="8" fill="#d4211a"/><rect x="6.5" y="13.5" width="2.6" height="2.6" fill="#f2c94c"/>`,
    desktop: halo(`<rect x="1" y="2" width="22" height="15" rx="1.5" fill="#2b2a27" stroke="none"/><path d="M8 18h8l1.5 4h-11z" fill="#2b2a27" stroke="none"/>`) + `<rect x="3" y="4" width="18" height="11" fill="#6f98cf"/><path d="M3 4h18v4H3z" fill="#9cc0ea"/>`,
    download: halo(`<path d="M8 1h8v10h5L12 22 3 11h5z" fill="#3c8a3a" stroke="none"/>`) + `<path d="M9.5 2.5h5v10h3.2L12 19.5 6.3 12.5h3.2z" fill="#6fbf5c"/>`,
    documents: halo(`<path d="M3 1h12l5 5v17H3z" fill="#fff" stroke="none"/>`) + `<path d="M3 1h12l5 5v17H3z" fill="#fff" stroke="#77736a"/><path d="M6 9h11M6 12h11M6 15h11M6 18h8" stroke="#9e9b92"/>`,
    pictures: halo(`<rect x="1" y="3" width="22" height="18" fill="#fff" stroke="none"/>`) + `<rect x="1" y="3" width="22" height="18" fill="#fff" stroke="#77736a"/><rect x="3" y="5" width="18" height="14" fill="#8fbaea"/><path d="M3 19l6-7 4 4 3-3 5 6z" fill="#4f8a3a"/><circle cx="17" cy="8.5" r="2" fill="#f5d33a"/>`,
    music: halo(`<path d="M7 4l13-3v15" fill="none" stroke="#1d1c1a" stroke-width="2.4"/><ellipse cx="4.6" cy="19" rx="4" ry="3" fill="#1d1c1a" stroke="none"/><ellipse cx="17" cy="16" rx="4" ry="3" fill="#1d1c1a" stroke="none"/><path d="M8.2 19V4" stroke="#1d1c1a" stroke-width="2.4"/>`),
    videos: halo(`<rect x="1" y="3" width="22" height="17" fill="#2b2a27" stroke="none"/>`) + `<path d="M3 5h2M7 5h2M11 5h2M15 5h2M19 5h2M3 18h2M7 18h2M11 18h2M15 18h2M19 18h2" stroke="#e8e5dd"/><rect x="3" y="7.5" width="18" height="8" fill="#6f98cf"/><path d="M10 9l5 2.5-5 2.5z" fill="#fff"/>`,
    remote: halo(`<circle cx="12" cy="12" r="10" fill="#2f62a8" stroke="none"/>`) + `<path d="M2 12h20M12 2c-4 5-4 15 0 20M12 2c4 5 4 15 0 20M4 7h16M4 17h16" fill="none" stroke="#9ec4ef" stroke-width="1.2"/>`,
    audio: halo(`<path d="M7 4l13-3v15" fill="none" stroke="#c46a12" stroke-width="2.6"/><ellipse cx="4.6" cy="19" rx="4.2" ry="3.2" fill="#c46a12" stroke="none"/><ellipse cx="17" cy="16" rx="4.2" ry="3.2" fill="#c46a12" stroke="none"/><path d="M8.4 19V4" stroke="#c46a12" stroke-width="2.6"/>`),
    script: halo(`<rect x="0" y="2" width="25" height="19" rx="1.5" fill="#1d1c1a" stroke="none"/>`) + `<path d="M4 8l4 3-4 3" fill="none" stroke="#9fd08a" stroke-width="1.8"/><rect x="10" y="13" width="6" height="2" fill="#e2231a"/>`
};
const corner = s => `<g transform="translate(36 32)">${s}</g>`;

function folder(sign) {
    const b = id("b"), f = id("f"), p = id("p"), s = id("s");
    return `${open}<defs>
<linearGradient id="${b}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#c8aa70"/><stop offset="1" stop-color="#8c6a36"/></linearGradient>
<linearGradient id="${f}" x1="0" y1="0" x2=".15" y2="1"><stop offset="0" stop-color="#f5e9c9"/><stop offset=".45" stop-color="#e5cd99"/><stop offset="1" stop-color="#c29f62"/></linearGradient>
<linearGradient id="${p}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#e2ded4"/></linearGradient>
${shade(s, 0, 0, 0, 0, .5)}</defs>
<ellipse cx="33" cy="57.5" rx="27" ry="4.2" fill="url(#${s})"/>
<path d="M7 13.5q0-2.5 2.5-2.5h12q2.2 0 3.2 2l1.6 3h26.2q2.5 0 2.5 2.5V52H7z" fill="url(#${b})" stroke="#5e4521" stroke-width="1.2" stroke-linejoin="round"/>
<path d="M8.5 17.6h46" stroke="#e8d3a3" stroke-opacity=".55"/>
<path d="M12 20.5h39l-1.2 12H12.8z" fill="url(#${p})" stroke="#a9a597" stroke-width=".8"/>
<path d="M15 24h29M15 27h25" stroke="#c9c5ba" stroke-width=".9"/>
<path d="M4.5 27L56.2 23.6l2.4 30q.1 1.5-1.4 1.5H8q-1.4 0-1.6-1.4z" fill="url(#${f})" stroke="#6b4e24" stroke-width="1.2" stroke-linejoin="round"/>
<path d="M6.6 28.6l47.8-3.1" stroke="#fffaf0" stroke-opacity=".95" stroke-width="1.3"/>
<path d="M8.5 52.5h48" stroke="#8c6a36" stroke-opacity=".35" stroke-width="2"/>
${sign ? corner(signs[sign]) : ""}</svg>`;
}

// crumpled paper: a lumpy ball and its creases
function ball(x, y, r, turn) {
    return `<g transform="translate(${x} ${y}) rotate(${turn}) scale(${r / 7})"><path d="M-6.5-1.5l2.5-5 5-.8 4.8 2.6 1.2 4.6-2.7 4.6-5 1.3-4.7-2.2z" fill="#fbfaf6" stroke="#8e8b84" stroke-width="1" stroke-linejoin="round"/><path d="M-3-4l2 4 4-1.5M-4 2l3-2 1.5 4M3 1l2.5 2" fill="none" stroke="#b9b6ae" stroke-width=".9"/></g>`;
}

function trash(full) {
    const m = id("m"), i = id("i"), s = id("s");
    return `${open}<defs>
<linearGradient id="${m}" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#8a8a86"/><stop offset=".26" stop-color="#f4f4f0"/><stop offset=".5" stop-color="#d4d4d0"/><stop offset=".82" stop-color="#a2a29e"/><stop offset="1" stop-color="#6e6e6a"/></linearGradient>
<linearGradient id="${i}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2c2c2a"/><stop offset="1" stop-color="#62625e"/></linearGradient>
${shade(s, 0, 0, 0, 0, .5)}</defs>
<ellipse cx="32" cy="58.5" rx="19" ry="3.6" fill="url(#${s})"/>
<path d="M11 20L17.2 55q14.8 5.6 29.6 0L53 20z" fill="url(#${m})" stroke="#4d4b46" stroke-width="1.2" stroke-linejoin="round"/>
<path d="M19.5 24l3.6 31.2" stroke="#fff" stroke-opacity=".55" stroke-width="2.4"/>
<path d="M44 24l-2.6 31.8" stroke="#5c5c58" stroke-opacity=".35" stroke-width="2"/>
<ellipse cx="32" cy="20" rx="21" ry="6.6" fill="url(#${i})"/>
${full ? ball(25, 16.5, 7.5, -12) + ball(38.5, 14.5, 6.5, 24) + ball(31.5, 19.5, 6, 70) : ""}
<path d="M11 20a21 6.6 0 0 0 42 0" fill="none" stroke="#ececE8" stroke-width="2.6"/>
<path d="M11 20a21 6.6 0 0 1 42 0" fill="none" stroke="#bdbdb9" stroke-width="2.2"/>
<ellipse cx="32" cy="20" rx="22.3" ry="7.8" fill="none" stroke="#4d4b46" stroke-width="1"/></svg>`;
}

// "PDF" in square letters (no font needed where the icon is drawn)
const pdfWord = `<g fill="#fff"><path d="M12 45h3v1h1v2h-1v1h-2v2h-1zm1 1v2h2v-2z"/><path d="M18 45h3v1h1v4h-1v1h-3zm1 1v4h2v-4z"/><path d="M24 45h4v1h-3v2h2v1h-2v2h-1z"/></g>`;

function page(kind) {
    const p = id("p"), c = id("c"), s = id("s");
    let lines = `<path d="M18 21h22M18 26h26M18 31h26M18 36h26M18 41h18" stroke="#9e9b92" stroke-width="1.4"/>`;
    let mark = "";
    if (kind === "image") {
        lines = "";
        mark = `<rect x="15" y="17" width="30" height="24" fill="#8fbaea" stroke="#5f5c55"/><path d="M15.5 40.5l9-11 6 6 4-4 10 9z" fill="#4f8a3a"/><circle cx="37" cy="24" r="3.2" fill="#f5d33a"/>`;
    } else if (kind === "audio" || kind === "script") {
        mark = corner(signs[kind]);
    } else if (kind === "video") {
        mark = corner(signs.videos);
    } else if (kind === "pdf") {
        mark = `<path d="M8.5 43h28l-2 4 2 4h-28z" fill="#c41a12" stroke="#7a100b"/>${pdfWord}`;
    }
    return `${open}<defs>
<linearGradient id="${p}" x1="0" y1="0" x2=".6" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#e1ddd3"/></linearGradient>
<linearGradient id="${c}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#b9b6ae"/></linearGradient>
${shade(s, 0, 0, 0, 0, .45)}</defs>
<ellipse cx="32" cy="59" rx="20" ry="3.2" fill="url(#${s})"/>
<path d="M12.5 4.5h27l12 12v40h-39z" fill="url(#${p})" stroke="#7d7a72" stroke-width="1.1" stroke-linejoin="round"/>
<path d="M39.5 4.5v12h12" fill="url(#${c})" stroke="#7d7a72" stroke-width="1.1" stroke-linejoin="round"/>
<path d="M14 6v49" stroke="#fff" stroke-opacity=".9"/>
${lines}${mark}</svg>`;
}

// an archive: a cardboard box, taped, seen from above and in front
function box() {
    const t = id("t"), f = id("f"), s = id("s");
    return `${open}<defs>
<linearGradient id="${t}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#e8c58e"/><stop offset="1" stop-color="#c99a5a"/></linearGradient>
<linearGradient id="${f}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#c3904c"/><stop offset="1" stop-color="#9a6a30"/></linearGradient>
${shade(s, 0, 0, 0, 0, .5)}</defs>
<ellipse cx="32" cy="58" rx="25" ry="3.6" fill="url(#${s})"/>
<path d="M6 22L22 12h36L44 22z" fill="url(#${t})" stroke="#5e4521" stroke-width="1.1" stroke-linejoin="round"/>
<path d="M6 22h38v33H6z" fill="url(#${f})" stroke="#5e4521" stroke-width="1.1"/>
<path d="M44 22l14-10v32L44 55z" fill="#8a5d27" stroke="#5e4521" stroke-width="1.1" stroke-linejoin="round"/>
<path d="M14 22l16-10h8L22 22z" fill="#f1dfb8" stroke="#a37c43" stroke-width=".8"/>
<path d="M14 22h8v12h-8z" fill="#f1dfb8" stroke="#a37c43" stroke-width=".8"/>
<rect x="25" y="38" width="14" height="10" fill="#fbfaf6" stroke="#77736a"/><path d="M28 41.5h8M28 44.5h6" stroke="#9e9b92"/></svg>`;
}

// a program: a gear, kawt's red in its middle
function gear() {
    const g = id("g"), s = id("s");
    return `${open}<defs>
<linearGradient id="${g}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f4f2ec"/><stop offset=".5" stop-color="#b9b6ae"/><stop offset="1" stop-color="#6c6a64"/></linearGradient>
${shade(s, 0, 0, 0, 0, .45)}</defs>
<ellipse cx="32" cy="58" rx="18" ry="3.4" fill="url(#${s})"/>
<path d="M28 6h8l1.4 6.4 5.2 2.4 5.6-3.6 5.6 5.6-3.6 5.6 2.4 5.2L59 29v8l-6.4 1.4-2.4 5.2 3.6 5.6-5.6 5.6-5.6-3.6-5.2 2.4L36 60h-8l-1.4-6.4-5.2-2.4-5.6 3.6-5.6-5.6 3.6-5.6-2.4-5.2L5 37v-8l6.4-1.4 2.4-5.2-3.6-5.6 5.6-5.6 5.6 3.6 5.2-2.4z" transform="translate(0 -1) scale(1 .96)" fill="url(#${g})" stroke="#4d4b46" stroke-linejoin="round"/>
<circle cx="32" cy="31.6" r="8.5" fill="#2f2e2b" stroke="#4d4b46"/><circle cx="32" cy="31.6" r="3.4" fill="#e2231a"/></svg>`;
}

// the kinds of file the desktop tells apart (modules/desktop), each to its drawing
const kinds = {
    folder: () => folder(""), home: () => folder("home"), desktop: () => folder("desktop"),
    trash: () => trash(false), "trash-full": () => trash(true),
    text: () => page("text"), image: () => page("image"), audio: () => page("audio"), video: () => page("video"),
    pdf: () => page("pdf"), script: () => page("script"), archive: () => box(), app: () => gear()
};

// the icon theme's names for them: places, and the mime types file managers ask for first
// (a name kawt doesn't have would come from Papirus, in its own look)
const places = {
    "folder": "", "folder-open": "", "folder-drag-accept": "", "inode-directory": "",
    "user-home": "home", "folder-home": "home", "user-desktop": "desktop", "folder-desktop": "desktop",
    "folder-documents": "documents", "folder-download": "download", "folder-downloads": "download",
    "folder-music": "music", "folder-pictures": "pictures", "folder-videos": "videos",
    "folder-templates": "", "folder-publicshare": "", "folder-remote": "remote", "network-workgroup": "remote"
};
const mimes = {
    text: ["text-x-generic", "text-plain", "text-markdown", "text-x-markdown", "text-x-log", "text-x-readme", "text-x-changelog", "text-csv", "text-x-csrc", "text-x-chdr", "text-x-c++src", "text-x-c++hdr", "text-x-python", "text-x-python3", "text-x-java", "text-x-go", "text-rust", "text-x-rust", "text-javascript", "application-javascript", "text-x-javascript", "text-css", "text-html", "text-xml", "application-xml", "application-json", "application-x-yaml", "text-x-makefile", "text-x-cmake", "text-x-qml", "application-x-subrip", "application-x-desktop", "text-x-patch", "text-x-tex", "application-x-trash"],
    script: ["text-x-script", "application-x-shellscript", "text-x-shellscript", "application-x-perl", "application-x-ruby", "text-x-lua"],
    image: ["image-x-generic", "image-png", "image-jpeg", "image-gif", "image-webp", "image-bmp", "image-tiff", "image-svg+xml", "image-x-xcf", "image-avif", "image-heif", "image-x-icon"],
    audio: ["audio-x-generic", "audio-mpeg", "audio-ogg", "audio-x-vorbis+ogg", "audio-x-opus+ogg", "audio-flac", "audio-x-flac", "audio-x-wav", "audio-wav", "audio-mp4", "audio-x-m4a", "audio-aac"],
    video: ["video-x-generic", "video-mp4", "video-x-matroska", "video-webm", "video-quicktime", "video-x-msvideo", "video-mpeg", "video-ogg"],
    pdf: ["application-pdf", "application-x-pdf"],
    archive: ["package-x-generic", "application-zip", "application-x-zip", "application-x-tar", "application-x-compressed-tar", "application-x-bzip-compressed-tar", "application-x-xz-compressed-tar", "application-x-zstd-compressed-tar", "application-gzip", "application-x-gzip", "application-x-bzip", "application-x-xz", "application-zstd", "application-x-7z-compressed", "application-x-rar", "application-vnd.rar", "application-x-archive", "application-x-cpio"],
    app: ["application-x-executable", "application-x-sharedlib", "application-x-appimage"]
};

// file name (under the theme folder) -> content: the "kawt" icon theme in the classic look,
// and every kind once more by its own name for the desktop (icons/kawt/kawt-desk/<kind>.svg)
function files(light) {
    const out = {
        "icons/kawt/index.theme": [
            "[Icon Theme]",
            "Name=kawt",
            "Comment=kawt's classic folders, bin and files; everything else from Papirus",
            `Inherits=${light ? "Papirus-Light" : "Papirus-Dark"},Papirus,Adwaita,hicolor`,
            "Directories=scalable/places,scalable/mimetypes",
            "",
            "[scalable/places]",
            "Size=64",
            "MinSize=8",
            "MaxSize=512",
            "Type=Scalable",
            "Context=Places",
            "",
            "[scalable/mimetypes]",
            "Size=64",
            "MinSize=8",
            "MaxSize=512",
            "Type=Scalable",
            "Context=MimeTypes"
        ].join("\n")
    };
    for (const name in places)
        out[`icons/kawt/scalable/places/${name}.svg`] = folder(places[name]);
    out["icons/kawt/scalable/places/user-trash.svg"] = trash(false);
    out["icons/kawt/scalable/places/user-trash-full.svg"] = trash(true);
    for (const kind in mimes) {
        const svg = kinds[kind]();
        for (const name of mimes[kind])
            out[`icons/kawt/scalable/mimetypes/${name}.svg`] = svg;
    }
    for (const kind in kinds)
        out[`icons/kawt/kawt-desk/${kind}.svg`] = kinds[kind]();
    return out;
}
