pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Notes in folders, saved to ~/.local/state/kawt/notes.json.
// A note's title is simply its first line. Pinned ones come first. Inside a note, lines like
//   # a heading        - [ ] a box to tick (- [x] ticked)        - a point
// are drawn as such while it's read (profile -> notes), and the boxes tick with a click. The old single scratchpad (notes.txt) becomes
// the first note the first time this runs; the file itself is left in place.
Singleton {
    id: root

    readonly property var notes: adapter.notes
    readonly property list<string> folders: adapter.folders
    // pinned first, then the newest edit
    readonly property var sorted: notes.slice().sort((a, b) => (!!b.pinned - !!a.pinned) || b.updated - a.updated)

    // notes of a folder ("all" = every folder), optionally filtered by a search text
    function inFolder(folder: string, search: string): var {
        const q = (search || "").trim().toLowerCase();
        return sorted.filter(n => (folder === "all" || n.folder === folder) && (!q || n.body.toLowerCase().includes(q)));
    }

    function count(folder: string): int {
        return folder === "all" ? notes.length : notes.filter(n => n.folder === folder).length;
    }

    function title(note: var): string {
        const first = (note?.body ?? "").split("\n").find(l => l.trim() !== "") ?? "";
        return first.trim().replace(/^#+\s*/, "") || "untitled";
    }

    // returns the new note's id (the time it was made; one more if that's taken)
    function create(folder: string): real {
        let id = Date.now();
        while (adapter.notes.some(n => n.id === id))
            id++;
        adapter.notes = [...adapter.notes, {
            id,
            body: "",
            folder: folder && folder !== "all" ? folder : "notes",
            updated: id
        }];
        return id;
    }

    function update(id: real, fields: var): void {
        adapter.notes = adapter.notes.map(n => n.id === id ? Object.assign({}, n, fields, { updated: Date.now() }) : n);
    }

    // pinned or not: not an edit, the date stays
    function togglePin(id: real): void {
        adapter.notes = adapter.notes.map(n => n.id === id ? Object.assign({}, n, { pinned: !n.pinned }) : n);
    }

    // the box on line i of a note ticked or not: "- [ ] x" <-> "- [x] x"
    function toggleBox(id: real, i: int): void {
        flush();
        const lines = bodyOf(id).split("\n");
        const m = /^(\s*(?:[-*]\s+)?\[)([ xX])(\].*)$/.exec(lines[i] ?? "");
        if (!m)
            return;
        lines[i] = m[1] + (m[2] === " " ? "x" : " ") + m[3];
        update(id, { body: lines.join("\n") });
    }

    // a new note with this text (the clipboard's): returns its id
    function createWith(folder: string, body: string): real {
        const id = create(folder);
        update(id, { body });
        return id;
    }

    function remove(id: real): void {
        if (id === draftId)
            saveTimer.stop();
        adapter.notes = adapter.notes.filter(n => n.id !== id);
    }

    // ---- the editor's text, saved half a second after the last key.
    // The timer lives here and not in the profile: the profile window is destroyed the moment
    // it closes, and a timer inside it would die with the last words unsaved.
    property real draftId: 0
    property string draftBody: ""

    function edit(id: real, body: string): void {
        if (saveTimer.running && id !== draftId)
            flush(); // another note is still waiting: save that one first
        draftId = id;
        draftBody = body;
        saveTimer.restart();
    }

    // save now instead of in a moment
    function flush(): void {
        if (!saveTimer.running)
            return;
        saveTimer.stop();
        update(draftId, { body: draftBody });
    }

    // a note's text, including what's typed but not saved yet
    function bodyOf(id: real): string {
        if (saveTimer.running && id === draftId)
            return draftBody;
        return notes.find(n => n.id === id)?.body ?? "";
    }

    Timer {
        id: saveTimer

        interval: 500
        onTriggered: root.update(root.draftId, { body: root.draftBody })
    }

    function addFolder(name: string): string {
        name = name.trim().toLowerCase().replace(/\s+/g, "-");
        if (name && name !== "all" && !adapter.folders.includes(name))
            adapter.folders = [...adapter.folders, name];
        return name;
    }

    // its notes move to "notes", nothing is lost
    function removeFolder(name: string): void {
        if (name === "notes")
            return;
        adapter.notes = adapter.notes.map(n => n.folder === name ? Object.assign({}, n, { folder: "notes" }) : n);
        adapter.folders = adapter.folders.filter(f => f !== name);
    }

    FileView {
        path: `${Settings.dir}/notes.json`
        printErrors: false // missing on first run
        blockWrites: true // at once: in the background a quick second change was undone (config/Settings.qml)
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                writeAdapter();
                legacy.reload();
            }
        }

        JsonAdapter {
            id: adapter

            property var notes: [] // [{ id, body, folder, updated (ms), pinned }]
            property var folders: ["notes"]
        }
    }

    // the scratchpad from before folders: imported once, when notes.json doesn't exist yet
    FileView {
        id: legacy

        path: `${Settings.dir}/notes.txt`
        preload: false
        printErrors: false
        onLoaded: {
            const body = text();
            if (body.trim() !== "")
                adapter.notes = [...adapter.notes, { id: Date.now(), body, folder: "notes", updated: Date.now() }];
        }
    }
}
