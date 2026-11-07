pragma Singleton
import QtQuick
import Quickshell

// kawt's own json files (todo, notes, chats, settings...) and a broken one. Quickshell reads a
// file it can't parse as an empty one and still says it loaded, so the next change wrote the
// empty list over everything that was in it (one comma too many in a hand edit was enough).
// So each of them asks here when it loads, and writes only while the file is readable; while
// it's not, it watches the file and comes back by itself once it's fixed:
//   property bool readable: true
//   watchChanges: !readable      onFileChanged: reload()
//   onLoaded: readable = Saved.readable(text(), path)
//   onAdapterUpdated: if (readable) writeAdapter()
QtObject {
    // json with an object at the top (or nothing at all: nothing to lose there); otherwise a
    // notification says what happened, once each time it's found broken
    function readable(text: string, path: string): bool {
        if (text.trim() === "")
            return true;
        try {
            const json = JSON.parse(text);
            if (json !== null && typeof json === "object" && !Array.isArray(json))
                return true;
        } catch (e) {}
        Quickshell.execDetached(["notify-send", "-a", "kawt", "-u", "critical", "--", `${path.split("/").pop()} can't be read`, `kawt won't save to it until it's fixed, and what changes meanwhile won't be kept. It's here: ${path}`]);
        return false;
    }
}
