//@ pragma IconTheme Papirus-Dark
// ^ icon theme for the launcher, dock and tray (apps without one show their first letter).
//   Overridden by the QS_ICON_THEME environment variable if that is set.
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
// ^ fonts packed for the web (woff / woff2) are skipped: slow to load, heavy in memory, and
//   some packages put them on the system. kawt's own font is a plain ttf, untouched.
//   "Default": setting the variable yourself still wins.
import QtQuick
import Quickshell
import qs.services
import "modules/bar"
import "modules/lock"

ShellRoot {
    Bar {}

    Lock {}

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
    }
}
