//@ pragma IconTheme Papirus-Dark
// ^ icon theme for the launcher, dock and tray (apps without one show their first letter).
//   Overridden by the QS_ICON_THEME environment variable if that is set.
import QtQuick
import Quickshell
import qs.services
import "modules/bar"

ShellRoot {
    Bar {}

    // singletons start lazily; this one has to run without anything on screen using it
    Component.onCompleted: ThemeExport.dir
}
