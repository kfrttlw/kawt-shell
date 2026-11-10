pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs.config
import qs.utils

// The desktop's files (modules/desktop/DeskIcons.qml), as KDE has them: what's in ~/Desktop (or
// where user-dirs.dirs says the desktop is), the home folder and the bin on top. Where each icon
// stands is kept in ~/.local/state/kawt/desktop.json, by name. What it does with the files goes
// through gio (glib, which kawt needs anyway): open with the app you chose for the kind, into the
// bin and out of it the way file managers do (~/.local/share/Trash), so thunar's "restore" works.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`
    property string dir: `${home}/Desktop`
    readonly property string trashDir: `${dataHome}/Trash/files`
    readonly property bool trashFull: trashModel.count > 0
    readonly property int trashCount: trashModel.count
    // the icons: kawt's own, written with the theme (utils/classicicons.js, utils/folders.js)
    readonly property string iconDir: `${ThemeExport.dir}/icons/kawt/kawt-desk`
    // false for a moment after every write of the theme's files, so the pictures are read again
    // (a new look, or the first one after the start: they're written then)
    property bool iconsReady: false

    Connections {
        target: ThemeExport

        function onWrittenChanged(): void {
            root.iconsReady = false;
            Qt.callLater(() => root.iconsReady = true);
        }
    }
    readonly property var cells: store.cells // name -> [column, row]
    readonly property string sort: store.sort
    // cut (not copied) files: moved, not copied, on the next paste here
    property var cutPaths: []

    // ---- where the desktop is: XDG_DESKTOP_DIR="$HOME/Desktop" (or a translated one)
    FileView {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || root.home + "/.config"}/user-dirs.dirs`
        printErrors: false
        onLoaded: {
            const m = /^XDG_DESKTOP_DIR="([^"]+)"/m.exec(text());
            if (m)
                root.dir = m[1].replace(/^\$HOME/, root.home).replace(/\/+$/, "");
        }
    }

    // made once if it isn't there: KDE and the file managers make it too
    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
    }

    FolderListModel {
        id: trashModel

        folder: `file://${root.trashDir}`
        showHidden: true
        showDotAndDotDot: false
    }

    // ---- what kind a file is, by its name: the icon it gets
    readonly property var byExt: ({
            txt: "text", md: "text", log: "text", csv: "text", json: "text", xml: "text", yaml: "text", yml: "text", toml: "text", ini: "text", conf: "text", cfg: "text", qml: "text", js: "text", ts: "text", py: "text", c: "text", h: "text", cpp: "text", rs: "text", go: "text", java: "text", lua: "text", html: "text", css: "text", tex: "text", srt: "text",
            sh: "script", bash: "script", zsh: "script", fish: "script",
            png: "image", jpg: "image", jpeg: "image", gif: "image", webp: "image", bmp: "image", svg: "image", tif: "image", tiff: "image", avif: "image", heic: "image", xcf: "image",
            mp3: "audio", ogg: "audio", oga: "audio", opus: "audio", flac: "audio", wav: "audio", m4a: "audio", aac: "audio",
            mp4: "video", mkv: "video", webm: "video", mov: "video", avi: "video", m4v: "video",
            pdf: "pdf",
            zip: "archive", tar: "archive", gz: "archive", tgz: "archive", xz: "archive", zst: "archive", bz2: "archive", "7z": "archive", rar: "archive",
            desktop: "app", appimage: "app", exe: "app"
        })
    // where the pixel look has no picture of its own: papirus's
    readonly property var papirus: ({ text: "text-x-generic", script: "text-x-script", image: "image-x-generic", audio: "audio-x-generic", video: "video-x-generic", pdf: "application-pdf", archive: "package-x-generic", app: "application-x-executable" })

    function kindOf(name: string, isDir: bool): string {
        if (isDir)
            return "folder";
        const dot = name.lastIndexOf(".");
        return dot > 0 ? byExt[name.slice(dot + 1).toLowerCase()] ?? "text" : "text";
    }

    // the icon's file; the papirus one where kawt has none (the pixel look's files)
    function iconOf(kind: string): string {
        if (Settings.iconStyle === "pixel" && papirus[kind])
            return Quickshell.iconPath(papirus[kind], true);
        return `file://${iconDir}/${kind}.svg`;
    }

    // ---- doing things
    function run(args: var): void {
        Quickshell.execDetached(args);
    }

    function open(path: string): void {
        if (path.endsWith(".desktop"))
            run(["gio", "launch", path]);
        else
            run(["gio", "open", path]);
    }

    function openTrash(): void {
        run(["gio", "open", "trash:///"]);
    }

    function emptyTrash(): void {
        run(["gio", "trash", "--empty"]);
    }

    function toTrash(paths: var): void {
        if (paths.length)
            run(["gio", "trash", "--", ...paths]);
    }

    function terminalIn(folder: string): void {
        Quickshell.execDetached({
            command: Apps.terminalCmd(),
            workingDirectory: folder
        });
    }

    // a name that isn't taken yet: "New folder", "New folder 2"...
    function freeName(base: string, ext: string, taken: var): string {
        let name = base + ext, i = 2;
        while (taken.includes(name))
            name = `${base} ${i++}${ext}`;
        return name;
    }

    function newFolder(name: string): void {
        run(["mkdir", "--", `${dir}/${name}`]);
    }

    function newFile(name: string): void {
        run(["sh", "-c", '[ -e "$1" ] || : > "$1"', "sh", `${dir}/${name}`]);
    }

    // a new name, in the same folder; one that's taken is left alone (mv -n)
    function rename(path: string, name: string): bool {
        name = name.trim();
        if (!name || name.includes("/") || name === "." || name === "..")
            return false;
        const to = `${path.slice(0, path.lastIndexOf("/"))}/${name}`;
        if (to === path)
            return false;
        run(["mv", "-n", "--", path, to]);
        const from = path.slice(path.lastIndexOf("/") + 1);
        if (store.cells[from]) {
            const c = Object.assign({}, store.cells);
            c[name] = c[from];
            delete c[from];
            store.cells = c;
        }
        return true;
    }

    // copy / cut: onto the clipboard the way gtk's file managers read it (thunar pastes them too)
    function copy(paths: var, cut: bool): void {
        if (!paths.length)
            return;
        cutPaths = cut ? paths : [];
        const list = paths.map(p => "file://" + encodeURI(p)).join("\n");
        run(["sh", "-c", 'printf "%s\\n%s" "$1" "$2" | wl-copy --type x-special/gnome-copied-files', "sh", cut ? "cut" : "copy", list]);
    }

    // what's on the clipboard (copied files, or links to them) into the desktop folder; cut ones
    // are moved. Nothing is written over: a name that's there already stays as it is
    function paste(): void {
        paster.command = ["sh", "-c", `
            t=$(wl-paste --list-types 2> /dev/null)
            if printf '%s\\n' "$t" | grep -qx x-special/gnome-copied-files; then
                data=$(wl-paste --no-newline --type x-special/gnome-copied-files)
                op=$(printf '%s\\n' "$data" | head -n 1); list=$(printf '%s\\n' "$data" | tail -n +2)
            elif printf '%s\\n' "$t" | grep -qx text/uri-list; then
                op=copy; list=$(wl-paste --no-newline --type text/uri-list)
            else
                exit 0
            fi
            printf '%s\\n' "$list" | tr -d '\\r' | while IFS= read -r u; do
                case $u in file://*) ;; *) continue ;; esac
                p=$(printf '%b' "$(printf '%s' "\${u#file://}" | sed 's/%/\\\\x/g')")
                [ -e "$p" ] || continue
                [ "\${p%/*}" = "$1" ] && continue
                if [ "$op" = cut ]; then mv -n -- "$p" "$1"/; else cp -rn -- "$p" "$1"/; fi
            done`, "sh", dir];
        paster.running = true;
        cutPaths = [];
    }

    Process {
        id: paster
    }

    // files dropped here from a file manager: copied in (the same folder: left alone)
    function copyIn(urls: var): void {
        const paths = urls.map(u => decodeURIComponent(String(u).replace(/^file:\/\//, ""))).filter(p => p && p.slice(0, p.lastIndexOf("/")) !== dir);
        if (paths.length)
            run(["cp", "-rn", "--", ...paths, `${dir}/`]);
    }

    // ---- where the icons stand
    function place(updates: var): void {
        store.cells = Object.assign({}, store.cells, updates);
    }

    // arranged again (by name, kind or date): everyone's place is made anew
    function arrange(by: string): void {
        store.sort = by;
        store.cells = {};
    }

    function setCells(cells: var): void {
        store.cells = cells;
    }

    FileView {
        path: `${Settings.dir}/desktop.json`
        printErrors: false // missing on first run, created below
        blockWrites: true
        property bool readable: true // see utils/Saved.qml
        watchChanges: !readable
        onFileChanged: reload()
        onAdapterUpdated: if (readable)
            writeAdapter()
        onLoaded: readable = Saved.readable(text(), path)
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: store

            property var cells: ({}) // file name -> [column, row]
            property string sort: "name" // how the ones without a place are lined up: name | kind | date
        }
    }
}
