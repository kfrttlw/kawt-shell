pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

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

    function fileName(path: string): string {
        return path.slice(path.lastIndexOf("/") + 1);
    }

    onDirChanged: refresh()
    Component.onCompleted: refresh()

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
