pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Scratchpad notes, saved to ~/.local/state/kawt/notes.txt (debounced)
Singleton {
    id: root

    property string text: ""
    property bool loaded: false

    function set(t: string): void {
        if (t === text)
            return;
        text = t;
        saveTimer.restart();
    }

    FileView {
        id: file

        path: `${Settings.dir}/notes.txt`
        blockLoading: true
        printErrors: false
        onLoaded: {
            root.text = text();
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }

    Timer {
        id: saveTimer

        interval: 600
        onTriggered: file.setText(root.text)
    }
}
