pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Tasks with optional reminders, saved in ~/.local/state/kawt/todo.json.
// A task is typed as one line, the time is read from its start:
//   14:30 call mom            today at 14:30 (tomorrow if that already passed)
//   2:30pm call mom / 9am gym the same in 12-hour form
//   +30m tea  /  +2h meeting  in 30 minutes / 2 hours
//   05.10 10:00 dentist       on 5 october at 10:00
//   buy milk                  no time
// Tags anywhere in the line:
//   #work                     put it in the "work" folder (created if it doesn't exist)
//   !  !!  !!!                importance: low / medium / high
// Each task also has an icon and a free-text note, edited in the todo tab.
// When a task is due, a notification is sent (it shows up in [log] like any other).
// Times follow the shell clock (services/Time.qml), the same one the bar shows.
Singleton {
    id: root

    // older tasks (before folders/importance/icons/notes) get the defaults
    readonly property var tasks: adapter.tasks.map(t => Object.assign({ folder: "inbox", prio: 0, icon: "", note: "" }, t))
    readonly property list<string> folders: adapter.folders
    // nerd font glyphs to pick from: none, note, home, work, book, cart, heart, bolt, code, phone, star, bug
    readonly property list<string> icons: ["", "\uf0f6", "\uf015", "\uf0b1", "\uf02d", "\uf07a", "\uf004", "\uf0e7", "\uf121", "\uf095", "\uf005", "\uf188"]
    // open first; then important first; then by time (timed before untimed); then oldest first
    readonly property var sorted: tasks.slice().sort((a, b) => (a.done - b.done) || (b.prio - a.prio) || ((a.due || Infinity) - (b.due || Infinity)) || (a.id - b.id))
    readonly property int open: tasks.filter(t => !t.done).length
    readonly property var today: sorted.filter(t => !t.done && t.due && sameDay(new Date(t.due), Time.now))

    // tasks of one folder; "all" = every folder
    function inFolder(folder: string): var {
        return folder === "all" ? sorted : sorted.filter(t => t.folder === folder);
    }

    function openIn(folder: string): int {
        return inFolder(folder).filter(t => !t.done).length;
    }

    // add a task from one typed line; `folder` is where it goes unless the line has a #tag
    function add(line: string, folder: string): string {
        let text = line.trim();
        let prio = 0;
        let tag = "";
        text = text.replace(/(^|\s)#([^\s#]+)/g, (all, sp, name) => {
            tag = name.toLowerCase();
            return sp;
        });
        text = text.replace(/(^|\s)(!{1,3})(?=\s|$)/g, (all, sp, marks) => {
            prio = marks.length;
            return sp;
        });
        const parsed = parse(text.replace(/\s+/g, " ").trim());
        if (!parsed.text)
            return "";
        const target = tag || (folder && folder !== "all" ? folder : "inbox");
        if (!adapter.folders.includes(target))
            adapter.folders = [...adapter.folders, target];
        adapter.tasks = [...adapter.tasks, {
            id: Date.now(), // just a unique id, real time is fine
            text: parsed.text,
            due: parsed.due,
            done: false,
            notified: parsed.due > 0 && parsed.due <= Time.ms(),
            folder: target,
            prio,
            icon: "",
            note: ""
        }];
        return [`added to ${target}`, parsed.due ? `reminder ${when(parsed.due)}` : ""].filter(s => s).join(" · ");
    }

    // change some fields of a task: update(id, { note: "...", prio: 2 })
    function update(id: real, fields: var): void {
        adapter.tasks = adapter.tasks.map(t => t.id === id ? Object.assign({}, t, fields) : t);
    }

    function addFolder(name: string): void {
        name = name.trim().toLowerCase().replace(/\s+/g, "-");
        if (name && name !== "all" && !adapter.folders.includes(name))
            adapter.folders = [...adapter.folders, name];
    }

    // the folder's tasks move to inbox, nothing is lost
    function removeFolder(name: string): void {
        if (name === "inbox")
            return;
        adapter.tasks = adapter.tasks.map(t => t.folder === name ? Object.assign({}, t, { folder: "inbox" }) : t);
        adapter.folders = adapter.folders.filter(f => f !== name);
    }

    function toggle(id: real): void {
        const t = tasks.find(t => t.id === id);
        if (t)
            update(id, { done: !t.done });
    }

    function remove(id: real): void {
        adapter.tasks = adapter.tasks.filter(t => t.id !== id);
    }

    function clearDone(folder: string): void {
        adapter.tasks = adapter.tasks.filter(t => !t.done || (folder !== "all" && (t.folder ?? "inbox") !== folder));
    }

    // "14:30 text" | "+30m text" | "+2h text" | "05.10 10:00 text" | "text"  ->  { due (ms, 0 = none), text }
    function parse(line: string): var {
        const now = new Date(Time.ms());
        let m;
        if ((m = line.match(/^\+(\d+)\s*(m|min|h)\s+(.+)$/i))) {
            const ms = parseInt(m[1]) * (m[2].toLowerCase() === "h" ? 3600000 : 60000);
            return { due: now.getTime() + ms, text: m[3] };
        }
        // a time token: 14:30 · 2:30pm · 2:30 pm · 9am  (checked by Time.parseClock)
        const tm = "(\\d{1,2}(?::\\d{2})?(?:\\s*(?:am|pm|a\\.m\\.|p\\.m\\.))?)";
        let c;
        if ((m = line.match(new RegExp(`^(\\d{1,2})\\.(\\d{1,2})\\s+${tm}\\s+(.+)$`, "i"))) && (c = Time.parseClock(m[3]))) {
            const d = new Date(now.getFullYear(), parseInt(m[2]) - 1, parseInt(m[1]), c.h, c.m);
            if (d < now)
                d.setFullYear(d.getFullYear() + 1); // "05.01" in december means next january
            return { due: d.getTime(), text: m[4] };
        }
        if ((m = line.match(new RegExp(`^${tm}\\s+(.+)$`, "i"))) && (c = Time.parseClock(m[1]))) {
            const d = new Date(now.getFullYear(), now.getMonth(), now.getDate(), c.h, c.m);
            if (d < now)
                d.setDate(d.getDate() + 1);
            return { due: d.getTime(), text: m[2] };
        }
        return { due: 0, text: line };
    }

    function sameDay(a: date, b: date): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    // "14:30", "tomorrow 09:00", "05.10 10:00"
    function when(ms: real): string {
        const d = new Date(ms), now = Time.now;
        const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        const time = Time.fmt(d);
        if (sameDay(d, now))
            return time;
        if (sameDay(d, tomorrow))
            return `tomorrow ${time}`;
        return `${Qt.formatDate(d, "dd.MM")} ${time}`;
    }

    // check every 15 s whether something is due
    Timer {
        running: true
        repeat: true
        interval: 15000
        triggeredOnStart: true
        onTriggered: {
            const now = Time.ms();
            const due = root.tasks.filter(t => !t.done && !t.notified && t.due > 0 && t.due <= now);
            if (due.length === 0)
                return;
            for (const t of due)
                Quickshell.execDetached(["notify-send", "-a", "todo", "-u", "critical", t.text, `due ${Time.fmt(new Date(t.due))}`]);
            const ids = due.map(t => t.id);
            adapter.tasks = adapter.tasks.map(t => ids.includes(t.id) ? Object.assign({}, t, { notified: true }) : t);
        }
    }

    FileView {
        path: `${Settings.dir}/todo.json`
        printErrors: false // missing on first run, created below
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property var tasks: [] // [{ id, text, due (ms, 0 = none), done, notified, folder, prio 0-3, icon, note }]
            property var folders: ["inbox"]
        }
    }
}
