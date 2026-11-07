import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

// Icon of a SystemTrayItem, grayscale unless `colored`
IconImage {
    id: root

    required property var item
    property bool colored: false

    asynchronous: true
    source: {
        // some apps (electron) send "name?path=/dir"; resolve via the theme first, then the dir
        let src = item?.icon ?? "";
        if (src.includes("?path=")) {
            const [name, path] = src.split("?path=");
            const file = name.slice(name.lastIndexOf("/") + 1);
            src = Quickshell.iconPath(file, true) || `file://${path}/${file}`;
        }
        return src;
    }
    layer.enabled: !colored
    layer.effect: MultiEffect {
        saturation: -1
    }
}
