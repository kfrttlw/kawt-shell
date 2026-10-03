import qs.config
import qs.components
import qs.services

BracketButton {
    readonly property string ssid: Wifi.active?.name ?? ""

    visible: Wifi.device !== null
    tag: "wifi"
    label: !Wifi.enabled ? "off" : ssid === "" ? "--" : ssid.length > 14 ? ssid.slice(0, 13) + "~" : ssid
    textColor: Wifi.enabled && ssid !== "" ? Colors.fg : Colors.dim
}
