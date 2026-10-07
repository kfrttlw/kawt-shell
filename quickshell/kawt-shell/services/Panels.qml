pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Which popover / sidebar is open, and on which screen.
// Only one popover can be open at a time; the sidebar is independent.
//
//   qs -c kawt-shell ipc call kawt toggle launcher|dock|style|tray|profile|dashboard|power|keys|calendar|player|volume|brightness|battery|mic|bluetooth|wifi|notifs
//   qs -c kawt-shell ipc call kawt sidebar
//   qs -c kawt-shell ipc call kawt run | clipboard
//   qs -c kawt-shell ipc call kawt lock | lockTest
//   qs -c kawt-shell ipc call kawt screenshot region|window|screen
//   qs -c kawt-shell ipc call kawt record region|screen   (again: stop)
//   qs -c kawt-shell ipc call kawt close
//   qs -c kawt-shell ipc call kawt dnd
//   qs -c kawt-shell ipc call kawt toggleLight
//   qs -c kawt-shell ipc call kawt wallpaper next|prev|random|none|<path>
//   qs -c kawt-shell ipc call kawt clearNotifs
Singleton {
    id: root

    property string current: ""
    property string launcherPrefix: "" // the launcher opens with this typed in ("!" = run mode)
    property int aiTab: 0 // the ai panel's open tab: 0 chat, 1 chats, 2 models, 3 cfg
    property bool locked: false // modules/lock: the session lock screen
    property bool lockTest: false // that lock unlocks by itself after 30 s
    property string screen: ""
    property bool sidebarOpen: false
    property string sidebarScreen: ""

    readonly property string focusedScreen: Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? ""

    function isOpen(name: string, s: ShellScreen): bool {
        return current === name && screen === s?.name;
    }

    function toggle(name: string, s: ShellScreen): void {
        if (isOpen(name, s)) {
            close();
        } else {
            screen = s.name;
            current = name;
        }
    }

    function close(): void {
        current = "";
    }

    // open the launcher with a mode prefix typed in, or close it if it's open
    function launcherWith(prefix: string): void {
        if (current === "launcher" && screen === focusedScreen) {
            close();
        } else {
            launcherPrefix = prefix;
            screen = focusedScreen;
            current = "launcher";
        }
    }

    function isSidebarOpen(s: ShellScreen): bool {
        return sidebarOpen && sidebarScreen === s?.name;
    }

    function toggleSidebar(s: ShellScreen): void {
        if (isSidebarOpen(s)) {
            sidebarOpen = false;
        } else {
            sidebarScreen = s.name;
            sidebarOpen = true;
        }
    }

    IpcHandler {
        target: "kawt"

        function toggle(name: string): void {
            if (root.current === name && root.screen === root.focusedScreen) {
                root.close();
            } else {
                root.screen = root.focusedScreen;
                root.current = name;
            }
        }

        function close(): void {
            root.close();
            root.sidebarOpen = false;
        }

        // win+r: the launcher straight in run mode, like the Windows "Run" box
        function run(): void {
            root.launcherWith("!");
        }

        // the launcher straight in clipboard history mode
        function clipboard(): void {
            root.launcherWith(":");
        }

        function lock(): void {
            root.lockTest = false;
            root.locked = true;
        }

        // locks, then unlocks by itself after 30 s: try the lock screen safely
        function lockTest(): void {
            root.lockTest = true;
            root.locked = true;
        }

        function record(mode: string): void {
            Recorder.toggle(mode || "region");
        }

        function screenshot(mode: string): void {
            Screenshot.take(mode || "region");
        }

        function toggleLight(): void {
            Settings.light = !Settings.light;
        }

        function wallpaper(arg: string): void {
            Wallpapers.pick(arg || "next");
        }

        function dnd(): void {
            Settings.dnd = !Settings.dnd;
        }

        function clearNotifs(): void {
            Notifs.clear();
        }

        function sidebar(): void {
            if (root.sidebarOpen && root.sidebarScreen === root.focusedScreen) {
                root.sidebarOpen = false;
            } else {
                root.sidebarScreen = root.focusedScreen;
                root.sidebarOpen = true;
            }
        }
    }
}
