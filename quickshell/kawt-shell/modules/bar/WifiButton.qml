import qs.config
import qs.components
import qs.services

// [wifi home] or, with the name hidden in cfg, [wifi ▂▄▆_]
BracketButton {
    readonly property string ssid: Wifi.active?.name ?? ""

    visible: Wifi.device !== null
    tag: "wifi"
    label: !Wifi.enabled ? "off"
        : ssid === "" ? "--"
        : !Settings.wifiName ? Wifi.signalBars(Wifi.active.signalStrength)
        : ssid.length > 14 ? ssid.slice(0, 13) + "~" : ssid
    textColor: Wifi.enabled && ssid !== "" ? Colors.fg : Colors.dim
}
