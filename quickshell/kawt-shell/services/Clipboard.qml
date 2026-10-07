pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history through cliphist. While kawt runs it keeps a watcher that stores every
// copy (text and images); the launcher's ":" mode lists them, enter copies one back.
// If you already run `wl-paste --watch cliphist store` from hyprland, that's fine too:
// cliphist skips an entry that is the same as the last one.
Singleton {
    id: root

    property bool available: false
    property var entries: [] // [{ line, id, text }] newest first
    property bool loading: false

    function refresh(): void {
        if (!available || lister.running)
            return;
        loading = true;
        lister.running = true;
    }

    // entries matching a search text (case-insensitive)
    function search(q: string): var {
        q = q.trim().toLowerCase();
        return q ? entries.filter(e => e.text.toLowerCase().includes(q)) : entries;
    }

    // put an entry back on the clipboard
    function copy(entry: var): void {
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "sh", entry.line]);
    }

    function remove(entry: var): void {
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist delete', "sh", entry.line]);
        entries = entries.filter(e => e.line !== entry.line);
    }

    function wipe(): void {
        Quickshell.execDetached(["cliphist", "wipe"]);
        entries = [];
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v cliphist && command -v wl-paste"]
        stdout: StdioCollector {
            onStreamFinished: root.available = text.trim().split("\n").length === 2
        }
    }

    // Stores one copy, unless it's a password: password managers (KeePassXC, Bitwarden, ...)
    // mark those with the x-kde-passwordManagerHint type, and newer wl-clipboard also says so
    // in CLIPBOARD_STATE. Skipped copies are still read to the end, or wl-paste would stop.
    readonly property string store: 'case "$CLIPBOARD_STATE" in sensitive | clear) cat > /dev/null; exit 0 ;; esac; if wl-paste --list-types 2> /dev/null | grep -qx x-kde-passwordManagerHint; then cat > /dev/null; exit 0; fi; exec cliphist store'

    // the watchers: one for text, one for images. Restarted if they ever exit.
    Process {
        id: textWatch

        running: root.available
        command: ["wl-paste", "--type", "text", "--watch", "sh", "-c", root.store]
        onExited: restart.start()
    }

    Process {
        id: imageWatch

        running: root.available
        command: ["wl-paste", "--type", "image", "--watch", "sh", "-c", root.store]
        onExited: restart.start()
    }

    Timer {
        id: restart

        interval: 3000
        onTriggered: {
            if (!root.available)
                return;
            textWatch.running = true;
            imageWatch.running = true;
        }
    }

    // `cliphist list`: "<id>\t<preview>" per line, newest first
    Process {
        id: lister

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.includes("\t")).slice(0, 200).map(l => {
                    const tab = l.indexOf("\t");
                    return { line: l, id: l.slice(0, tab), text: l.slice(tab + 1) };
                });
                root.loading = false;
            }
        }
    }
}
