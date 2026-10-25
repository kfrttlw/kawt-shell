pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

// Notification daemon (org.freedesktop.Notifications). Don't run mako/dunst/swaync alongside.
// Everything stays in `list` (newest first) until dismissed; `popups` are the toasts on screen.
// Each notification is stamped with seconds since boot, dmesg-style.
// What the app asks for is kept:
//   notify-send -t 1500     the toast stays that long (-t 0: until it's clicked)
//   notify-send -e          transient: only a toast, never in the log
//   a replace tag           x-canonical-private-synchronous / x-dunst-stack-tag: a new one with
//                           the same tag takes the old one's place (volume scripts, window mode)
Singleton {
    id: root

    readonly property int maxPopups: 4
    readonly property int popupTimeout: 6000 // when the app doesn't say (-t)
    readonly property int maxHistory: 100 // older ones are dismissed: a chatty app can't fill the memory

    readonly property var list: server.trackedNotifications.values.filter(n => !n.transient).reverse()
    readonly property int count: list.length
    property var popups: []
    property int unread: 0
    property var stamps: ({}) // notification id -> seconds since boot
    property real bootTime: 0 // epoch seconds

    function stamp(n: var): string {
        const s = stamps[n?.id] ?? 0;
        return `[${s.toFixed(3).padStart(9)}]`;
    }

    function isCritical(n: var): bool {
        return n?.urgency === NotificationUrgency.Critical;
    }

    function hide(n: var): void {
        popups = popups.filter(p => p && p !== n);
    }

    // a toast's time ran out: a transient one goes for good, the rest stay in the log
    function expired(n: var): void {
        hide(n);
        if (n?.transient)
            drop(n);
    }

    // gone as timed out (not as "closed by the user", which some apps act on)
    function drop(n: var): void {
        if (typeof n.expire === "function")
            n.expire();
        else
            n.dismiss();
    }

    // how long the toast stays, in ms: the app's -t; -1 (not given) = ours, 0 = until handled.
    // The spec sends milliseconds; a value under 100 can only be seconds
    function timeoutOf(n: var): int {
        const t = n?.expireTimeout ?? -1;
        if (t < 0)
            return popupTimeout;
        if (t === 0)
            return 0;
        return Math.max(500, Math.round(t < 100 ? t * 1000 : t));
    }

    // "app|tag" for notifications that replace their own earlier one, "" for the rest
    function tagOf(n: var): string {
        const h = n?.hints ?? {};
        const tag = h["x-canonical-private-synchronous"] ?? h["x-dunst-stack-tag"] ?? h["synchronous"] ?? "";
        return tag ? `${n.appName}|${tag}` : "";
    }

    // run the "default" action if there is one (the app usually focuses itself), then drop it
    function activate(n: var): void {
        const action = n.actions.find(a => a.identifier === "default");
        if (action)
            action.invoke();
        else
            n.dismiss();
    }

    function clear(): void {
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
        popups = [];
    }

    // the log was opened: everything is seen, the toasts go too (they'd pop up again otherwise
    // once the log closes: the toast window isn't kept around while the log is open)
    function markRead(): void {
        unread = 0;
        for (const p of popups)
            if (p?.transient)
                drop(p);
        popups = [];
    }

    NotificationServer {
        id: server

        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: false
        persistenceSupported: true

        onNotification: n => {
            const toast = !Settings.dnd || root.isCritical(n);
            // a transient one with no toast to show has nowhere to go: left untracked, it's dropped
            if (n.transient && !toast)
                return;
            // the same tag again: the earlier one makes room (its toast goes with it)
            const tag = root.tagOf(n);
            const gone = [];
            if (tag) {
                for (const old of server.trackedNotifications.values.slice()) {
                    if (old !== n && root.tagOf(old) === tag) {
                        root.drop(old);
                        gone.push(old);
                    }
                }
            }
            const replaced = gone.length > 0;
            // stamp first: tracking it makes it appear in `list` right away
            root.stamps[n.id] = Date.now() / 1000 - root.bootTime;
            n.tracked = true;
            if (Panels.current !== "notifs" && !n.transient && !replaced)
                root.unread++;
            // (a replaced one is only deleted later: taken out of the toasts here, not left as an empty card)
            const next = [...(toast ? [n] : []), ...root.popups.filter(p => p && p !== n && !gone.includes(p))];
            // a transient one pushed out of the toasts has nowhere else to be: it goes
            for (const p of next.slice(root.maxPopups))
                if (p.transient)
                    root.drop(p);
            root.popups = next.slice(0, root.maxPopups);
            root.trim();
        }
    }

    // keep the newest maxHistory; and stamps only for what's still there
    function trim(): void {
        const all = server.trackedNotifications.values.slice(); // oldest first
        for (let i = 0; i < all.length - maxHistory; i++)
            all[i].dismiss();
        const kept = {};
        for (const n of server.trackedNotifications.values)
            if (stamps[n.id] !== undefined)
                kept[n.id] = stamps[n.id];
        stamps = kept;
    }

    FileView {
        path: "/proc/uptime"
        blockLoading: true
        onLoaded: root.bootTime = Date.now() / 1000 - parseFloat(text())
    }
}
