pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../utils/wallpalette.js" as WallPalette

// Images in Settings.wallpaperDir (and one level of subfolders), and setting one.
// If awww (or its old name swww) is installed it does the drawing, with its transitions;
// otherwise kawt draws the wallpaper itself (modules/background/Wallpaper.qml).
// awww's daemon is started by kawt (scripts/wallpaper.sh): at login, once a wallpaper was
// picked here, and whenever one is set while it isn't running. No line in hyprland's config
// needed. Never picked one here (hyprpaper and the like draw it): kawt leaves awww alone.
// A new one by itself every Settings.wallpaperEvery minutes if you like (super+w), the next in
// the folder or a random one, with awww's transition picked there (crt: drawn in from the top).
// Dithered (Settings.wallDither, on by default): what's on screen is a copy in the theme's few
// tones, made by scripts/dither.sh, and made again when the theme changes.
Singleton {
    id: root

    readonly property string dir: Settings.expand(Settings.wallpaperDir)
    property string backend: "" // "awww" | "swww" | "kawt", detected at start
    property list<string> files: []
    property bool loading: false

    function refresh(): void {
        loading = true;
        finder.running = true;
    }

    // ---- thumbnails for the style window: 320 px jpgs in ~/.cache/kawt/thumbs, made by ffmpeg
    // once per picture (and again if the picture changes). Opening super+w then reads small
    // files instead of decoding every wallpaper at full size. Without ffmpeg, or until a
    // thumbnail exists, the style window shows the picture itself.
    readonly property string thumbDir: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/kawt/thumbs`
    property int thumbsVersion: 0 // goes up when new thumbnails are ready: the grid loads them

    function thumb(path: string): string {
        return `${thumbDir}/${Qt.md5(path)}.jpg`;
    }

    // args: the dir, then pairs of picture and thumbnail; only missing or outdated ones are made.
    // Prints 1 if it made any
    readonly property string thumbScript: 'command -v ffmpeg >/dev/null || exit 0; mkdir -p "$1"; shift; made=0; while [ $# -ge 2 ]; do if [ ! -s "$2" ] || [ "$1" -nt "$2" ]; then ffmpeg -v error -nostdin -y -i "$1" -frames:v 1 -vf "scale=320:-2" -q:v 4 "$2" && made=1; fi; shift 2; done; echo $made'

    function makeThumbs(): void {
        if (thumbnailer.running || files.length === 0)
            return;
        const args = ["sh", "-c", thumbScript, "sh", thumbDir];
        for (const f of files)
            args.push(f, thumb(f));
        thumbnailer.command = args;
        thumbnailer.running = true;
    }

    Process {
        id: thumbnailer

        stdout: StdioCollector {
            onStreamFinished: if (text.trim() === "1")
                root.thumbsVersion++
        }
    }

    readonly property string script: `${Quickshell.shellDir}/scripts/wallpaper.sh`

    function set(path: string): void {
        Settings.wallpaper = path;
        show(Settings.wallpaperTransition);
    }

    // ---- what's on screen: the picture, or its dithered copy once that's made
    property string shown: ""

    // the copy: the picture in five tones between lo and hi (black and white become them) and
    // its reds in the accent. Dark themes go from the background up to a dim ink, light ones from
    // ink up to the paper: a wallpaper stays behind the windows either way
    readonly property var tones: Colors.light ? ({ lo: Colors.mix(Colors.bg, Colors.fg, 0.85), hi: Colors.bg, gamma: 1 }) : ({ lo: Colors.bg, hi: Colors.mix(Colors.bg, Colors.fg, 0.85), gamma: 1.3 })
    // the dots are two pixels big: half the biggest screen, doubled back to it
    readonly property size ditherSize: {
        let w = 0, h = 0;
        for (const s of Quickshell.screens) {
            w = Math.max(w, s.width * (s.devicePixelRatio || 1));
            h = Math.max(h, s.height * (s.devicePixelRatio || 1));
        }
        return Qt.size(Math.ceil(w / 2) || 960, Math.ceil(h / 2) || 540);
    }
    readonly property string ditherDir: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/kawt/dither`
    readonly property var ditherArgs: [ditherSize.width, ditherSize.height, String(tones.lo), String(tones.hi), String(Colors.accent), String(tones.gamma)]
    property string pendingTransition: ""

    // the picture, or its copy (made first if it isn't there yet: one per picture, theme and
    // screen size; the 30 newest are kept)
    function show(transition: string): void {
        const path = Settings.wallpaper;
        if (!path) {
            shown = "";
            return;
        }
        if (!Settings.wallDither) {
            display(path, transition);
            return;
        }
        const out = `${ditherDir}/${Qt.md5([path, ...ditherArgs].join("|"))}.png`;
        pendingTransition = transition;
        ditherer.command = ["sh", "-c", '[ -s "$2" ] || { mkdir -p "${2%/*}" && sh "$0" "$@" && { cd "${2%/*}" && ls -t | tail -n +31 | xargs -r rm -f; }; } && [ -s "$2" ] && echo "$2"', `${Quickshell.shellDir}/scripts/dither.sh`, path, out, ...ditherArgs.map(String)];
        ditherer.running = true;
    }

    function display(file: string, transition: string): void {
        shown = file;
        if (backend === "awww" || backend === "swww")
            Quickshell.execDetached(["sh", script, backend, file, transition, Settings.wallDither ? "nearest" : ""]);
        // hyprlock (and other scripts) read the current wallpaper from here
        Quickshell.execDetached(["sh", "-c", 'mkdir -p ~/.cache && printf "%s" "$1" > ~/.cache/current_wallpaper.txt', "sh", file]);
    }

    // a newer request while one is being made: Process runs again with the newest command once
    // this one is done, and only a finished copy is ever shown (its path is what the script prints)
    Process {
        id: ditherer

        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out)
                    root.display(out, root.pendingTransition);
                else
                    root.display(Settings.wallpaper, root.pendingTransition); // no ffmpeg, or a picture it can't read
            }
        }
    }

    // ---- the style window's preview: the picked one as it would look, small. Dithered in the
    // theme's tones when that's on (made on the fly, a fraction of a second; kept with the other
    // copies), the picture itself otherwise
    property string previewFor: ""
    property string preview: ""
    property string previewOut: ""

    function makePreview(path: string): void {
        previewFor = path;
        if (!path || !Settings.wallDither) {
            preview = path;
            return;
        }
        const args = [480, 270, String(tones.lo), String(tones.hi), String(Colors.accent), String(tones.gamma)];
        previewOut = `${ditherDir}/preview-${Qt.md5([path, ...args].join("|"))}.png`;
        previewer.command = ["sh", "-c", '[ -s "$2" ] || { mkdir -p "${2%/*}" && sh "$0" "$@" && { cd "${2%/*}" && ls -t | tail -n +41 | xargs -r rm -f; }; } && [ -s "$2" ] && echo "$2"', `${Quickshell.shellDir}/scripts/dither.sh`, path, previewOut, ...args.map(String)];
        previewer.running = true;
    }

    // a newer pick while one is made: Process runs again with the newest command; only the copy
    // of the one picked last is shown
    Process {
        id: previewer

        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out && out === root.previewOut)
                    root.preview = out;
                else if (!out)
                    root.preview = root.previewFor; // no ffmpeg, or a picture it can't read
            }
        }
    }

    // a new theme (or light / dark): the copy is made again in its colors, drawn in like a new
    // wallpaper. Only once something is on screen (not the theme settling in at login)
    Timer {
        id: recolor

        interval: 300
        onTriggered: {
            if (root.shown !== "" && Settings.wallDither)
                root.show(Settings.wallpaperTransition);
            if (root.previewFor)
                root.makePreview(root.previewFor);
        }
    }

    Connections {
        target: Colors

        function onPaletteChanged(): void {
            recolor.restart();
        }
    }

    // "next" | "prev" | "random" | "none" | a path (ipc: kawt wallpaper <arg>)
    function pick(arg: string): void {
        const n = files.length;
        if (arg === "none") {
            set("");
        } else if (arg === "next" || arg === "prev" || arg === "random") {
            if (n === 0)
                return;
            const i = files.indexOf(Settings.wallpaper);
            let j;
            if (arg === "random") {
                j = Math.floor(Math.random() * n);
                if (n > 1 && j === i)
                    j = (j + 1) % n; // always a different one
            } else if (i < 0) {
                j = arg === "next" ? 0 : n - 1;
            } else {
                j = (i + (arg === "next" ? 1 : -1) + n) % n;
            }
            set(files[j]);
        } else if (arg) {
            set(Settings.expand(arg));
        }
    }

    // the next one by itself; not behind the lock, and only once one was picked here. Picking
    // one by hand starts the wait again
    Timer {
        id: every

        running: Settings.wallpaperEvery > 0 && Settings.wallpaper !== "" && root.files.length > 1 && !Panels.locked
        interval: Math.max(1, Settings.wallpaperEvery) * 60000
        repeat: true
        onTriggered: root.pick(Settings.wallpaperOrder === "random" ? "random" : "next")
    }

    Connections {
        target: Settings

        function onWallpaperChanged(): void {
            if (every.running)
                every.restart();
        }

        function onWallDitherChanged(): void {
            root.show(Settings.wallpaperTransition);
            if (root.previewFor)
                root.makePreview(root.previewFor);
        }

        function onLoadedChanged(): void {
            root.start();
        }
    }

    // at login: the daemon up and the last wallpaper on it (awww usually keeps that itself), once
    // both the backend and the settings are known
    property bool started: false

    function start(): void {
        if (started || backend === "" || !Settings.loaded)
            return;
        started = true;
        if (Settings.wallpaper)
            show("start");
        else
            first.reload();
    }

    // the one picked in the installer (one of kawt's own), put on at the first start; read once
    FileView {
        id: first

        path: `${Settings.dir}/first-wallpaper`
        preload: false
        printErrors: false
        onLoaded: {
            const p = text().trim();
            Quickshell.execDetached(["rm", "-f", path]);
            if (p && !Settings.wallpaper)
                root.set(Settings.expand(p));
        }
    }

    function fileName(path: string): string {
        return path.slice(path.lastIndexOf("/") + 1);
    }

    onDirChanged: refresh()
    Component.onCompleted: {
        refresh();
        measure();
    }

    // ---- the wallpaper theme: the picture analysed into Settings.wallPalette
    // (utils/wallpalette.js) whenever the wallpaper changes, however it was changed.
    // ffmpeg (there anyway for wf-recorder) shrinks it to 48x27 and od prints the pixels as
    // numbers: nothing has to be on screen. Without ffmpeg the style window's canvas does it
    // (modules/style/WallpaperSampler.qml), whenever super+w is open.
    readonly property int paletteVersion: 4 // palettes made by an older kawt are made again
    readonly property string unmeasured: Settings.wallpaper !== "" && (Settings.wallPalette?.source !== Settings.wallpaper || Settings.wallPalette?.version !== paletteVersion) ? Settings.wallpaper : ""
    property string failed: "" // ffmpeg couldn't read this one: left to the canvas
    property bool reading: false // the output isn't parsed yet (it can end after the process)

    // the next one starts only when the last one has both exited and been read
    function measure(): void {
        if (!unmeasured || unmeasured === failed || measurer.running || reading)
            return;
        measurer.source = unmeasured;
        reading = true;
        measurer.running = true;
    }

    onUnmeasuredChanged: measure()

    Process {
        id: measurer

        property string source: ""

        command: ["sh", "-c", 'ffmpeg -v error -nostdin -i "$1" -frames:v 1 -vf scale=48:27 -f rawvideo -pix_fmt rgba - | od -An -v -tu1', "sh", source]
        stdout: StdioCollector {
            onStreamFinished: {
                const px = text.trim().split(/\s+/).map(Number);
                if (px.length === 48 * 27 * 4)
                    Settings.wallPalette = Object.assign({ source: measurer.source, version: root.paletteVersion }, WallPalette.analyse(px));
                else
                    root.failed = measurer.source;
                root.reading = false;
                // the wallpaper may have changed while this one was measured
                Qt.callLater(root.measure);
            }
        }
        onExited: Qt.callLater(root.measure)
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v awww || command -v swww || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.backend = text.trim().split("/").pop() || "kawt";
                root.start();
            }
        }
    }

    Process {
        id: finder

        command: ["find", "-L", root.dir, "-maxdepth", "2", "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", "-o", "-iname", "*.bmp", ")"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.split("\n").filter(l => l).sort((a, b) => a.localeCompare(b));
                root.loading = false;
                root.makeThumbs();
            }
        }
    }
}
