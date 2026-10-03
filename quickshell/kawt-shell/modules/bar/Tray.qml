import Quickshell.Services.SystemTray
import qs.config
import qs.components

// [tray 5 v]  the icons themselves open in a list below (TrayPopover),
// so a crowded tray doesn't eat the bar. Lights up if an app needs attention.
BracketButton {
    readonly property var items: SystemTray.items.values.filter(i => i.status !== Status.Passive)
    readonly property bool attention: items.some(i => i.status === Status.NeedsAttention)

    visible: items.length > 0
    tag: "tray"
    label: `${items.length} ${active ? "^" : "v"}`
    textColor: attention ? Colors.accent : Colors.fg
}
