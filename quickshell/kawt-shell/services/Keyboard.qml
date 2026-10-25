pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Active keyboard layout of Hyprland's main keyboard, as an xkb code ("us", "ru").
// Read from `hyprctl devices -j` at start and again on every `activelayout` event.
//
// Settings.layoutPerWindow (profile -> cfg): each window keeps its own layout. Leaving a
// window remembers its layout, coming back puts it back; a window seen for the first time
// starts with the first layout (us). Forgotten when the window closes, and with the shell.
//
// `caps`: caps lock, for the lock screen. Read when asked (checkCaps), from the keyboards'
// leds (/sys, any keyboard), or from hyprctl where there are none.
Singleton {
    id: root

    property string code: ""
    property string name: "" // "English (US)"
    property int count: 0 // configured layouts
    property int index: 0 // the active one's place among them
    property bool caps: false

    property var perWindow: ({}) // window address -> layout index
    property string window: "" // the focused window's address

    function next(): void {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    function prev(): void {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "prev"]);
    }

    function setIndex(i: int): void {
        if (i !== index && i >= 0 && i < count)
            Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(i)]);
    }

    // a moment after the key: the led follows it
    function checkCaps(): void {
        capsLater.restart();
    }

    Process {
        id: devices

        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards;
                    const kb = kbs.find(k => k.main) ?? kbs[0];
                    const codes = kb.layout.split(",").map(s => s.trim());
                    root.name = kb.active_keymap;
                    root.count = codes.length;
                    root.index = kb.active_layout_index ?? 0;
                    root.code = codes[kb.active_layout_index] ?? kb.active_keymap.slice(0, 2).toLowerCase();
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "activelayout") {
                devices.running = true;
            } else if (event.name === "activewindowv2") {
                // "activewindowv2>>55d1c0a87e40", empty with no window focused
                const a = event.data.split(",")[0];
                if (!Settings.layoutPerWindow || root.count < 2 || a === root.window)
                    return;
                if (root.window)
                    root.perWindow[root.window] = root.index;
                root.window = a;
                if (a)
                    root.setIndex(root.perWindow[a] ?? 0);
            } else if (event.name === "closewindow") {
                delete root.perWindow[event.data];
            }
        }
    }

    // switched off: forget, so switching it on again starts clean
    Connections {
        target: Settings

        function onLayoutPerWindowChanged(): void {
            root.perWindow = {};
            root.window = "";
        }
    }

    Timer {
        id: capsLater

        interval: 80
        onTriggered: capsRead.running = true
    }

    // "1" per led that's on ("0" off); no leds: hyprctl's "capsLock": true / false
    Process {
        id: capsRead

        command: ["sh", "-c", 'set -- /sys/class/leds/*::capslock/brightness; if [ -e "$1" ]; then cat "$@"; else hyprctl devices -j | grep -o "\\"capsLock\\": *[a-z]*"; fi']
        stdout: StdioCollector {
            onStreamFinished: root.caps = /(^|\s)[1-9]|true/.test(text)
        }
    }
}
