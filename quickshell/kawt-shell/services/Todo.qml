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
//   every day  daily  weekdays  every week  weekly  every month  monthly
//                             it comes again: ticked off, it moves on to its next time (and a
//                             ticked-off copy stays for today's list)
// Each task also has an icon, a free-text note and steps of its own (subtasks), edited in the
// todo tab.
// When a task is due, a notification is sent (it shows up in [log] like any other).
// Times follow the shell clock (services/Time.qml), the same one the bar shows.
Singleton {
    id: root

    property bool loaded: false // the file is read: until then there are no tasks, not none done

    // older tasks (before folders/importance/icons/notes) get the defaults. Complete ones are
    // passed through as they are: the same object stays the same object, so the lists keep their
    // rows (ScriptModel) instead of building every one again on each change
    readonly property var tasks: adapter.tasks.map(t => t.folder !== undefined && t.prio !== undefined && t.icon !== undefined && t.note !== undefined && t.subs !== undefined && t.repeat !== undefined ? t : Object.assign({ folder: "inbox", prio: 0, icon: "", note: "", subs: [], repeat: "" }, t))
    readonly property list<string> folders: adapter.folders
    // nerd font glyphs to pick from: none, note, home, work, book, cart, heart, bolt, code, phone, star, bug
    readonly property list<string> icons: ["", "\uf0f6", "\uf015", "\uf0b1", "\uf02d", "\uf07a", "\uf004", "\uf0e7", "\uf121", "\uf095", "\uf005", "\uf188"]
    // open first; then important first; then by time (timed before untimed); then oldest first
    readonly property var sorted: tasks.slice().sort((a, b) => (a.done - b.done) || (b.prio - a.prio) || ((a.due || Infinity) - (b.due || Infinity)) || (a.id - b.id))
    readonly property int open: tasks.filter(t => !t.done).length
    // Time.day changes once a day: this isn't rebuilt every second
    readonly property var today: Time.day ? sorted.filter(t => !t.done && t.due && sameDay(new Date(t.due), new Date(Time.ms()))) : []

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
        let repeat = "";
        text = text.replace(/(^|\s)(every\s+(day|week|month)|daily|weekly|monthly|weekdays)(?=\s|$)/gi, (all, sp, word, unit) => {
            const w = word.toLowerCase();
            repeat = unit ? unit.toLowerCase() : w === "daily" ? "day" : w === "weekly" ? "week" : w === "monthly" ? "month" : "weekdays";
            return sp;
        });
        const parsed = parse(text.replace(/\s+/g, " ").trim());
        if (!parsed.text)
            return "";
        const target = tag || (folder && folder !== "all" ? folder : "inbox");
        if (!adapter.folders.includes(target))
            adapter.folders = [...adapter.folders, target];
        adapter.tasks = [...adapter.tasks, {
            id: newId(),
            text: parsed.text,
            due: parsed.due,
            done: false,
            notified: parsed.due > 0 && parsed.due <= Time.ms(),
            folder: target,
            prio,
            icon: "",
            note: "",
            subs: [],
            repeat
        }];
        return [`added to ${target}`, parsed.due ? `reminder ${when(parsed.due)}` : "", repeat ? `again ${repeatName(repeat)}` : ""].filter(s => s).join(" · ");
    }

    // the time it was made, as an id; one more if that's taken (several added at once: the ai's
    // [add 3 tasks]), or ticking one would tick them all
    function newId(): real {
        let id = Date.now();
        while (adapter.tasks.some(t => t.id === id))
            id++;
        return id;
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

    // ticked off: when, for "done today". One that comes again moves on to its next time instead,
    // and a ticked-off copy of it stays (today's list, the count). That copy unticked: a tick by
    // mistake, undone (the task back to the time it had, the copy gone)
    function toggle(id: real): void {
        const t = tasks.find(t => t.id === id);
        if (!t)
            return;
        const now = Time.ms();
        const from = t.done && t.of ? tasks.find(x => x.id === t.of && !x.done && x.repeat) : null;
        if (!t.done && t.repeat) {
            const copy = Object.assign({}, t, { id: newId(), done: true, doneAt: now, repeat: "", notified: true, of: id });
            adapter.tasks = [...adapter.tasks.map(x => x.id === id ? Object.assign({}, x, { due: nextTime(x), mday: x.repeat === "month" ? x.mday || (x.due ? new Date(x.due).getDate() : 0) : 0, notified: false, subs: (x.subs ?? []).map(st => ({ text: st.text, done: false })) }) : x), copy];
        } else if (from) {
            adapter.tasks = adapter.tasks.filter(x => x.id !== id).map(x => x.id === from.id ? Object.assign({}, x, { due: t.due, notified: t.due > 0 && t.due <= now, subs: t.subs }) : x);
        } else {
            update(id, { done: !t.done, doneAt: t.done ? 0 : now });
        }
        count(t.done ? -1 : 1, t.done ? t.doneAt : now);
    }

    // ---- what's done, per day, for "done today" and the streak (kept apart from the tasks:
    // clearing done ones doesn't undo the days). { "2026-10-28": 5 }, a year of them
    readonly property var doneDays: adapter.doneDays
    readonly property int doneTodayCount: Time.day ? doneDays[Time.day] ?? 0 : 0
    // days in a row with something done, up to today (or yesterday, while today has nothing yet)
    readonly property int streak: {
        const d = new Date(Time.ms());
        if (!doneDays[Time.day])
            d.setDate(d.getDate() - 1);
        let n = 0;
        while (doneDays[Qt.formatDate(d, "yyyy-MM-dd")] > 0) {
            n++;
            d.setDate(d.getDate() - 1);
        }
        return n;
    }

    function count(by: int, at: real): void {
        if (!at)
            return;
        const key = Qt.formatDate(new Date(at), "yyyy-MM-dd");
        const d = Object.assign({}, adapter.doneDays);
        d[key] = Math.max(0, (d[key] ?? 0) + by);
        if (!d[key])
            delete d[key];
        const keys = Object.keys(d).sort();
        for (const k of keys.slice(0, Math.max(0, keys.length - 370)))
            delete d[k];
        adapter.doneDays = d;
    }

    // ---- coming again: "day" | "weekdays" | "week" | "month"
    function repeatName(r: string): string {
        return r === "day" ? "every day" : r === "weekdays" ? "on weekdays" : r === "week" ? "every week" : r === "month" ? "every month" : "";
    }

    // the next time after this one, never in the past; one without a time gets 9:00. Monthly: on
    // the same day of the month (mday, the one it started on), the last day of a shorter month
    function nextTime(t: var): real {
        const now = new Date(Time.ms());
        const d = t.due ? new Date(t.due) : new Date(now.getFullYear(), now.getMonth(), now.getDate(), 9, 0);
        const mday = t.mday || d.getDate();
        do {
            if (t.repeat === "month") {
                d.setDate(1);
                d.setMonth(d.getMonth() + 1);
                d.setDate(Math.min(mday, new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()));
            } else if (t.repeat === "week")
                d.setDate(d.getDate() + 7);
            else
                d.setDate(d.getDate() + 1);
            while (t.repeat === "weekdays" && (d.getDay() === 0 || d.getDay() === 6))
                d.setDate(d.getDate() + 1);
        } while (d <= now);
        return d.getTime();
    }

    function setRepeat(id: real, r: string): void {
        const t = tasks.find(t => t.id === id);
        if (!t)
            return;
        // coming again needs a time to come at: 9:00, today's or tomorrow's, if it had none
        let due = t.due;
        if (r && !due) {
            const d = new Date(Time.ms());
            d.setHours(9, 0, 0, 0);
            if (d.getTime() <= Time.ms())
                d.setDate(d.getDate() + 1);
            due = d.getTime();
        }
        update(id, { repeat: r, due, notified: due <= Time.ms(), mday: 0 });
    }

    // ---- steps of a task: [{ text, done }]
    function addSub(id: real, text: string): void {
        text = text.trim();
        const t = tasks.find(t => t.id === id);
        if (t && text)
            update(id, { subs: [...t.subs, { text, done: false }] });
    }

    function toggleSub(id: real, i: int): void {
        const t = tasks.find(t => t.id === id);
        if (t && t.subs[i])
            update(id, { subs: t.subs.map((st, k) => k === i ? { text: st.text, done: !st.done } : st) });
    }

    function removeSub(id: real, i: int): void {
        const t = tasks.find(t => t.id === id);
        if (t)
            update(id, { subs: t.subs.filter((st, k) => k !== i) });
    }

    // ticked off today (Time.day: worked out once a day and on every change of the list)
    readonly property var doneToday: Time.day ? tasks.filter(t => t.done && t.doneAt && sameDay(new Date(t.doneAt), new Date(Time.ms()))) : []
    // open and due today or before
    readonly property var dueToday: Time.day ? sorted.filter(t => !t.done && t.due && t.due < new Date(new Date(Time.ms()).setHours(24, 0, 0, 0)).getTime()) : []

    function remove(id: real): void {
        if (id === noteDraftId)
            noteDraftId = 0;
        adapter.tasks = adapter.tasks.filter(t => t.id !== id);
    }

    // ---- a task's note while it's typed. Saved when the editor loses the focus (saving on every
    // key would rebuild the list under the cursor), or when the profile closes: the draft is
    // kept here, so it isn't lost with the window.
    property real noteDraftId: 0
    property string noteDraft: ""

    function editNote(id: real, text: string): void {
        if (noteDraftId && noteDraftId !== id)
            saveNote();
        noteDraftId = id;
        noteDraft = text;
    }

    function saveNote(): void {
        if (!noteDraftId)
            return;
        const id = noteDraftId;
        noteDraftId = 0;
        const t = tasks.find(t => t.id === id);
        if (t && t.note !== noteDraft)
            update(id, { note: noteDraft });
    }

    // the same, a moment later: for an editor that is being destroyed right now (its list
    // can't be rebuilt in the middle of that)
    function saveNoteSoon(): void {
        if (noteDraftId)
            noteSaver.restart();
    }

    Timer {
        id: noteSaver

        interval: 0
        onTriggered: root.saveNote()
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
            const day = parseInt(m[1]), month = parseInt(m[2]) - 1;
            const d = new Date(now.getFullYear(), month, day, c.h, c.m);
            if (d < now)
                d.setFullYear(d.getFullYear() + 1); // "05.01" in december means next january
            // a date that isn't one (31.02, 10.13) would roll over into another: none at all
            if (d.getMonth() === month && d.getDate() === day)
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

    // Reminders: one timer, set for the next one to the second. The clock's tick only checks
    // whether that one is overdue: the timer runs on the machine's own count, which stops during
    // a sleep, and the shell clock may have been moved (Settings.timeOffset)
    // a reminder went off (the companion rings a bell too)
    signal dueNow(string text)

    readonly property real nextDue: tasks.filter(t => !t.done && !t.notified && t.due > 0).reduce((m, t) => Math.min(m, t.due), Infinity)

    function remind(): void {
        const now = Time.ms();
        const due = root.tasks.filter(t => !t.done && !t.notified && t.due > 0 && t.due <= now);
        if (due.length === 0)
            return;
        for (const t of due) {
            Quickshell.execDetached(["notify-send", "-a", "todo", "-u", "critical", t.text, `due ${Time.fmt(new Date(t.due))}`]);
            root.dueNow(t.text);
        }
        const ids = due.map(t => t.id);
        adapter.tasks = adapter.tasks.map(t => ids.includes(t.id) ? Object.assign({}, t, { notified: true }) : t);
    }

    function schedule(): void {
        if (nextDue === Infinity) {
            reminder.stop();
            return;
        }
        reminder.interval = Math.max(1000, Math.min(3600000, nextDue - Time.ms()));
        reminder.restart();
    }

    onNextDueChanged: schedule()
    Component.onCompleted: {
        remind();
        schedule();
    }

    Timer {
        id: reminder

        onTriggered: {
            root.remind();
            root.schedule();
        }
    }

    Connections {
        target: Time

        function onNowChanged(): void {
            if (Time.ms() >= root.nextDue) {
                root.remind();
                root.schedule();
            }
        }

        // moved back, the timer would come too early: set again
        function onOffsetChanged(): void {
            root.schedule();
        }
    }

    FileView {
        path: `${Settings.dir}/todo.json`
        printErrors: false // missing on first run, created below
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            // tasks from an older kawt get their missing fields written in once: otherwise each
            // would be a new object on every change, and every row of the list made again
            if (adapter.tasks.some(t => t.subs === undefined || t.repeat === undefined || t.folder === undefined || t.prio === undefined || t.icon === undefined || t.note === undefined))
                adapter.tasks = root.tasks;
            root.loaded = true;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
            root.loaded = true;
        }

        JsonAdapter {
            id: adapter

            property var tasks: [] // [{ id, text, due (ms, 0 = none), done, doneAt (ms), notified, folder, prio 0-3, icon, note, subs: [{ text, done }], repeat, mday (monthly: its day), of (a ticked-off copy: the task's id) }]
            property var folders: ["inbox"]
            property var doneDays: ({}) // "yyyy-MM-dd" -> tasks ticked off that day
        }
    }
}
