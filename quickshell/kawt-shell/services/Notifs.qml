pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

// Notification daemon (org.freedesktop.Notifications). Don't run mako/dunst/swaync alongside.
// Everything stays in `list` (newest first) until dismissed; `popups` are the toasts on screen.
// Each notification is stamped with seconds since boot, dmesg-style.
Singleton {
    id: root

    readonly property int maxPopups: 4
    readonly property int popupTimeout: 6000
    readonly property int maxHistory: 100 // older ones are dismissed: a chatty app can't fill the memory

    readonly property var list: server.trackedNotifications.values.slice().reverse()
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

    function markRead(): void {
        unread = 0;
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
            // stamp first: tracking it makes it appear in `list` right away
            root.stamps[n.id] = Date.now() / 1000 - root.bootTime;
            n.tracked = true;
            if (Panels.current !== "notifs")
                root.unread++;
            if (!Settings.dnd || root.isCritical(n))
                root.popups = [n, ...root.popups.filter(p => p)].slice(0, root.maxPopups);
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
