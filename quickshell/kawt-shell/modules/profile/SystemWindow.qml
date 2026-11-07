import QtQuick
import qs.config
import qs.components
import qs.services
import qs.utils

// System (start -> System): the machine as its bios would tell it, the processes, who's on the
// net, the battery and power. A window of its own; the bar doesn't show the temperature, memory
// or disk any more, this does
AppWindow {
    id: root

    name: "system"
    icon: "chart"
    title: `${Strings.t("system")} — ${SysInfo.user}@${SysInfo.host}`
    bodyWidth: Math.round(Metrics.fontSize * 60)
    bodyHeight: Math.round(Metrics.fontSize * 36) // one size for every tab: a window doesn't jump when the tab changes
    status: [
        `cpu ${Math.round(SysInfo.cpu * 100)}%`,
        `${Strings.t("memory")} ${Math.round(SysInfo.mem * 100)}%`,
        `${Strings.t("upFor")} ${Fmt.uptime(SysInfo.uptime)}`
    ]

    Component.onCompleted: {
        if (Panels.systemTab !== "")
            content.show(Panels.systemTab);
        Panels.systemTab = "";
    }

    Connections {
        target: Panels

        function onSystemTabChanged(): void {
            if (Panels.systemTab === "")
                return;
            content.show(Panels.systemTab);
            Panels.systemTab = "";
        }
    }

    ProfileContent {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        open: true
        tabNames: ["sys", "top", "net", "power"]
    }
}
