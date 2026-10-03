pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Active keyboard layout of Hyprland's main keyboard, as an xkb code ("us", "ru").
// Read from `hyprctl devices -j` at start and again on every `activelayout` event.
Singleton {
    id: root

    property string code: ""
    property string name: "" // "English (US)"
    property int count: 0 // configured layouts

    function next(): void {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    function prev(): void {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "prev"]);
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
                    root.code = codes[kb.active_layout_index] ?? kb.active_keymap.slice(0, 2).toLowerCase();
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "activelayout")
                devices.running = true;
        }
    }
}
