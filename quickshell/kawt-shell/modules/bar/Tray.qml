import QtQuick
import Quickshell.Services.SystemTray
import qs.config
import qs.components

// ‹ the apps' own icons: they open in a list below (TrayPopover), so a crowded tray doesn't eat
// the bar. Red while an app needs attention
BarIcon {
    readonly property var items: SystemTray.items.values.filter(i => i.status !== Status.Passive)
    readonly property bool attention: items.some(i => i.status === Status.NeedsAttention)

    visible: Settings.barShows("tray") && items.length > 0
    text: active ? "▼" : "◄"
    textColor: attention ? Colors.accent : Colors.fg
    tip: `${Strings.t("hiddenIcons")}: ${items.length}`
}
