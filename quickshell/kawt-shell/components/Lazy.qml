import QtQuick
import Quickshell

// A window that exists only while it's needed: created when `when` turns true, destroyed
// `linger` ms after it turns false (time for a closing animation). A hidden PanelWindow still
// keeps its whole tree of items in memory, on every screen; this way a panel nobody opens
// costs nothing, and the shell starts faster.
//   Lazy { when: Panels.isOpen("dock", screen); DockPopover { ... } }
// The window inside is created already open: use components/OpenWatch.qml for what has to
// happen on open / close, not onOpenChanged (it doesn't fire for the first value).
LazyLoader {
    id: root

    property bool when: false
    property int linger: 0
    property bool held: false

    // `held` follows `when` but lets go late: whatever order the bindings update in, the
    // window never disappears before its time
    active: when || held

    // already open when created (a reload with the panel open)
    Component.onCompleted: held = when

    onWhenChanged: {
        if (when) {
            hold.stop();
            held = true;
        } else if (linger > 0) {
            hold.restart();
        } else {
            held = false;
        }
    }

    property Timer hold: Timer {
        interval: root.linger
        onTriggered: root.held = false
    }
}
