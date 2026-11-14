//@ pragma IconTheme Papirus-Dark
// ^ icon theme for the launcher, dock and tray (apps without one show their first letter).
//   Overridden by the QS_ICON_THEME environment variable if that is set.
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
// ^ fonts packed for the web (woff / woff2) are skipped: slow to load, heavy in memory, and
//   some packages put them on the system. kawt's own font is a plain ttf, untouched.
//   "Default": setting the variable yourself still wins.
import QtQuick
import Quickshell
import qs.config
import qs.services
import "modules/bar"
import "modules/lock"
import "modules/boot"
import "modules/profile"
import "modules/settings"
import "modules/style"
import qs.components

ShellRoot {
    Bar {}

    Lock {}

    Boot {}

    // kawt's own windows, one each, on the screen hyprland opens them on
    Lazy {
        when: Panels.isWindowOpen("today")

        TodayWindow {}
    }

    Lazy {
        when: Panels.isWindowOpen("system")

        SystemWindow {}
    }

    Lazy {
        when: Panels.isWindowOpen("settings")

        SettingsWindow {}
    }

    Lazy {
        when: Panels.isWindowOpen("style")

        StyleWindow {}
    }

    // singletons start lazily; these have to run without anything on screen using them
    // (theme files for other apps, todo reminders, the wallpaper theme, locking)
    Component.onCompleted: {
        ThemeExport.dir;
        Todo.open;
        Clipboard.available; // starts the clipboard history watcher
        Wallpapers.unmeasured; // measures each new wallpaper for the wallpaper theme
        Session.enabled; // locks before sleep and on `loginctl lock-session`
        Idle.caffeine; // locks after Settings.idleLock minutes without input
        Night.on; // the night light, if it was on
        Hypr.lua; // keeps the special workspace in the bar up to date
        Rates.wanted; // once: a monitor running slower than it can (services/Rates.qml)
        Cursor.theme; // kawt's cursor to hyprland, if one is picked (settings -> look)
        KittyFont.font; // kitty's pixel font written again when the screen's scale changes
        if (Settings.updateAuto)
            Update.repo; // the weekly update check (one git fetch to github; off in settings -> kawt)
    }
}
