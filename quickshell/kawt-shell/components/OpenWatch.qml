import QtQuick

// opened() / closed(), exactly once per change of `open`, also when the window is created
// already open or destroyed while still open (windows are made by components/Lazy.qml).
// A plain onOpenChanged misses both: things like the wifi scan would never start, or never stop.
QtObject {
    id: root

    property bool open: false
    property bool was: false

    signal opened
    signal closed

    function sync(): void {
        if (open === was)
            return;
        was = open;
        if (open)
            opened();
        else
            closed();
    }

    onOpenChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (was) {
        was = false;
        closed();
    }
}
