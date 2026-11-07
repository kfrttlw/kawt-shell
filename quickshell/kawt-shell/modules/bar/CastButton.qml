import QtQuick
import Quickshell.Services.Pipewire
import qs.config
import qs.components

// while an app takes video (a screen share, a screen recorder, the webcam), so you always know
// when something is watching. Pipewire calls those streams "Stream/Input/Video" (kawt's own
// recording doesn't go through pipewire: that's the rec dot)
BarIcon {
    id: root

    readonly property list<PwNode> streams: Pipewire.nodes.values.filter(n => n.isStream && n.properties["media.class"] === "Stream/Input/Video")
    readonly property string app: {
        const p = streams[0]?.properties ?? {};
        return p["application.name"] || p["node.name"] || "app";
    }

    visible: streams.length > 0
    icon: "cast"
    tip: `${Strings.t("cast")}: ${streams.length > 1 ? streams.length : app}`
}
