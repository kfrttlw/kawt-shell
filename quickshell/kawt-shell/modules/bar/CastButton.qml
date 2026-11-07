import QtQuick
import Quickshell.Services.Pipewire
import qs.config
import qs.components

// [cast ● discord] while an app takes video: a screen share, a screen recorder, the webcam.
// Like [mic ●], so you always know when something is watching. Pipewire calls those streams
// "Stream/Input/Video" (kawt's own recording doesn't go through pipewire: that's [● rec])
BracketButton {
    id: root

    readonly property list<PwNode> streams: Pipewire.nodes.values.filter(n => n.isStream && n.properties["media.class"] === "Stream/Input/Video")
    readonly property string app: {
        const p = streams[0]?.properties ?? {};
        const name = (p["application.name"] || p["node.name"] || "app").toLowerCase();
        return name.length > 12 ? name.slice(0, 11) + "~" : name;
    }

    visible: streams.length > 0
    tag: "cast"
    label: streams.length > 1 ? `● ${streams.length}` : `● ${app}`
    textColor: Colors.accent
}
