pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../utils/wallpalette.js" as WallPalette

// Images in Settings.wallpaperDir (and one level of subfolders), and setting one.
// If awww (or its old name swww) is installed it does the drawing, with its transitions;
// otherwise kawt draws the wallpaper itself (modules/background/Wallpaper.qml).
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

    function set(path: string): void {
        Settings.wallpaper = path;
        if (path && (backend === "awww" || backend === "swww"))
            Quickshell.execDetached([backend, "img", path]);
        // hyprlock (and other scripts) read the current wallpaper from here
        if (path)
            Quickshell.execDetached(["sh", "-c", 'mkdir -p ~/.cache && printf "%s" "$1" > ~/.cache/current_wallpaper.txt', "sh", path]);
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
            onStreamFinished: root.backend = text.trim().split("/").pop() || "kawt"
        }
    }

    Process {
        id: finder

        command: ["find", "-L", root.dir, "-maxdepth", "2", "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", "-o", "-iname", "*.bmp", ")"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.split("\n").filter(l => l).sort((a, b) => a.localeCompare(b));
                root.loading = false;
            }
        }
    }
}
