pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The launcher's emoji (its `.` mode): data/emoji.tsv, made by tools/emoji-list.py from
// unicode's own names, english and russian. Read the first time the mode opens, not at start.
// Enter copies one; with wtype installed it's typed into the window you came from too. The ones
// you pick come first next time (counts in ~/.local/state/kawt/emoji.json).
Singleton {
    id: root

    property bool wanted: false // set by the launcher when the mode opens
    property var all: [] // [{ e, en, ru, other }]
    property var byEmoji: ({})
    property bool canType: false
    // shown before anything is typed, after the ones you picked
    readonly property list<string> popular: ["😂", "❤️", "👍", "😭", "🙏", "😊", "🔥", "🥲", "😅", "🤔", "👀", "✨", "🎉", "💀", "😍", "🙂", "😁", "😎", "🤝", "👋", "✅", "❌", "⭐", "🚀", "💯", "😢", "😡", "🤯", "🥳", "😴", "🤷", "👌", "💪", "🫡", "☕", "🍕"]

    FileView {
        path: root.wanted ? `${Quickshell.shellDir}/data/emoji.tsv` : ""
        onLoaded: {
            const list = [], by = {};
            for (const line of text().split("\n")) {
                if (!line || line.startsWith("#"))
                    continue;
                const f = line.split("\t");
                const item = {
                    e: f[0],
                    en: f[1] ?? "",
                    ru: f[2] ?? "",
                    other: f[3] ?? ""
                };
                list.push(item);
                by[item.e] = item;
            }
            root.byEmoji = by;
            root.all = list;
        }
    }

    Process {
        running: root.wanted
        command: ["sh", "-c", "command -v wtype"]
        stdout: StdioCollector {
            onStreamFinished: root.canType = text.trim() !== ""
        }
    }

    // a word of the name starts with it: 80, the name has it: 50, another name: 30
    function score(item: var, q: string): int {
        let best = 0;
        for (const name of [item.en, item.ru]) {
            if (name === q)
                return 100;
            if (name.split(" ").some(w => w.startsWith(q)))
                best = Math.max(best, 80);
            else if (name.includes(q))
                best = Math.max(best, 50);
        }
        return best || (item.other.includes(q) ? 30 : 0);
    }

    function search(query: string): var {
        const q = query.trim().toLowerCase();
        const counts = adapter.counts;
        if (!q) {
            const mine = Object.keys(counts).sort((a, b) => counts[b] - counts[a]).slice(0, 24);
            return [...mine, ...popular.filter(e => !mine.includes(e))].map(e => byEmoji[e]).filter(x => x).slice(0, 60);
        }
        // typed in the other layout: found too, a little below (services/Apps.qml)
        const alt = Apps.otherLayout(q);
        return all.map(item => ({ item, s: Math.max(score(item, q), alt ? score(item, alt) - 5 : 0) }))
            .filter(r => r.s > 0)
            .map(r => ({ item: r.item, s: r.s + Math.min(20, (counts[r.item.e] ?? 0) * 2) }))
            .sort((x, y) => y.s - x.s || x.item.en.length - y.item.en.length)
            .slice(0, 60)
            .map(r => r.item);
    }

    // onto the clipboard, and typed in where you were (the launcher closes first)
    function pick(item: var): void {
        if (!item)
            return;
        adapter.counts = Object.assign({}, adapter.counts, { [item.e]: (adapter.counts[item.e] ?? 0) + 1 });
        Quickshell.clipboardText = item.e;
        if (canType)
            Quickshell.execDetached(["sh", "-c", 'sleep 0.2; wtype -- "$1"', "sh", item.e]);
    }

    FileView {
        path: root.wanted ? `${Settings.dir}/emoji.json` : ""
        printErrors: false // missing until the first pick
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter

            property var counts: ({}) // emoji -> times picked
        }
    }
}
