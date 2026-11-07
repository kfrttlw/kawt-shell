import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// The windows of the workspace this screen shows, as raised buttons: an icon and the title, the
// one in focus pressed in on a dotted face, one that wants you (urgent) in red. A click goes to a
// window; on a floating desk a click on the one in focus puts it away, as old systems did. Put
// away (minimized) ones stay here, dim, after the others: a click brings one back.
// Many windows, in steps, so nothing is ever cut off unseen and nothing overlaps (the row only
// has the room between the start button and the desks, Bar.qml):
//   168 px each while they fit, then narrower, down to 96;
//   then icons only (the one in focus keeps its title);
//   then as many icons as fit and "+N ▾" with the rest in a list (red if one of them is urgent)
Item {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int desk: monitor?.activeWorkspace?.id ?? 0
    readonly property bool floats: Hypr.floatDesks.includes(desk)
    readonly property var windows: [...(monitor?.activeWorkspace?.toplevels?.values ?? []), ...Hypr.awayOn(desk)]
    readonly property int gap: 2
    readonly property int full: Math.round(168 * Metrics.scale)
    readonly property int narrow: Math.round(96 * Metrics.scale)
    readonly property int iconOnly: Metrics.barHeight
    readonly property int moreWidth: Math.round(44 * Metrics.scale)
    readonly property int n: windows.length
    readonly property int focusedIndex: windows.findIndex(w => Hyprland.activeToplevel === w && !Hypr.isAway(w))
    // the step: "titles" | "icons" | "more"
    readonly property string step: n * narrow + (n - 1) * gap <= width ? "titles" : (n - 1) * (iconOnly + gap) + narrow <= width ? "icons" : "more"
    readonly property int each: step === "titles" && n ? Math.min(full, Math.floor((width - (n - 1) * gap) / n)) : full
    // how many fit before "+N"
    readonly property int fits: step !== "more" ? n : Math.max(1, Math.floor((width - narrow - moreWidth - gap) / (iconOnly + gap)) + 1)
    // the shown ones: the first that fit, the one in focus always among them
    readonly property var shown: {
        if (step !== "more")
            return windows;
        const s = windows.slice(0, fits);
        if (focusedIndex >= fits)
            s[fits - 1] = windows[focusedIndex];
        return s;
    }
    readonly property var hidden: windows.filter(w => !shown.includes(w))

    function clsOf(w: var): string {
        return w?.wayland?.appId || w?.lastIpcObject?.class || "";
    }

    function isUrgent(w: var): bool {
        return w?.lastIpcObject?.urgent === true || w?.urgent === true;
    }

    function press(w: var): void {
        if (Hypr.isAway(w))
            Hypr.restore(w, desk);
        else if (Hyprland.activeToplevel === w && floats)
            Hypr.minimize(w);
        else
            Hypr.focusWindow(w);
    }

    implicitHeight: Metrics.barHeight - 6

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.gap

        Repeater {
            model: root.shown

            BarBox {
                id: task

                required property var modelData
                readonly property string cls: root.clsOf(modelData)
                readonly property string kawtIcon: Panels.windowIcon(cls, modelData.title ?? "")
                readonly property bool focused: Hyprland.activeToplevel === modelData
                readonly property bool isAway: Hypr.isAway(modelData)
                readonly property bool urgent: root.isUrgent(modelData) && !focused
                readonly property bool withTitle: root.step === "titles" || (focused && !isAway)

                plain: false
                width: root.step === "titles" ? root.each : withTitle ? root.narrow : root.iconOnly
                height: root.implicitHeight
                down: focused && !isAway
                dotted: down
                spacing: 4
                onClicked: root.press(modelData)

                // kawt's own windows (today, system): their pixel icon
                PixIcon {
                    visible: task.kawtIcon !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    name: task.kawtIcon
                    ink: task.isAway ? Colors.dim : "transparent"
                }

                AppIcon {
                    visible: task.kawtIcon === ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    icon: DesktopEntries.heuristicLookup(task.cls)?.icon ?? ""
                    name: task.cls || task.modelData.title || "?"
                    colored: !task.isAway
                }

                Label {
                    visible: task.withTitle
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, task.width - 16 - task.spacing - 12)
                    elide: Text.ElideRight
                    text: task.modelData.title || task.cls
                    color: task.isAway ? Colors.dim : task.urgent ? Colors.accent : Colors.fg
                }

                // an urgent one without its title: a red frame says it
                Rectangle {
                    parent: task
                    visible: task.urgent && !task.withTitle
                    anchors.fill: parent
                    anchors.margins: 2
                    color: "transparent"
                    border.color: Colors.accent
                }

                Tip {
                    target: task
                    text: task.modelData.title || task.cls
                    hovered: task.hovered
                }
            }
        }

        // the rest, in a list
        BarBox {
            id: more

            readonly property bool urgent: root.hidden.some(w => root.isUrgent(w))

            visible: root.step === "more" && root.hidden.length > 0
            plain: false
            width: root.moreWidth
            height: root.implicitHeight
            down: menu.shown
            onClicked: menu.shown ? menu.close() : menu.open()

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: `+${root.hidden.length} ▼`
                color: more.urgent ? Colors.accent : Colors.fg
            }

            BarMenu {
                id: menu

                target: more
                items: root.hidden.map(w => ({ text: (w.title || root.clsOf(w)).slice(0, 48), warn: root.isUrgent(w), action: () => root.press(w) }))
            }
        }
    }
}
