//@ pragma IconTheme Papirus-Dark
// ^ icon theme for the launcher, dock and tray (apps without one show their first letter).
//   Overridden by the QS_ICON_THEME environment variable if that is set.
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
// ^ don't load the huge fallback fonts (color emoji, CJK) fontconfig would pull in: tens of MB
//   for glyphs kawt never draws. "Default": setting the variable yourself still wins.
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
