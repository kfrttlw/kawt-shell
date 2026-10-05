import qs.config
import qs.components
import qs.services

// [wifi home], [wifi ▂▄▆_] or nothing, as picked in the profile's cfg tab
BracketButton {
    readonly property string ssid: Wifi.active?.name ?? ""

    visible: Wifi.device !== null && Settings.wifiStyle !== "hidden"
    tag: "wifi"
    label: !Wifi.enabled ? "off"
        : ssid === "" ? "--"
        : Settings.wifiStyle === "bars" ? Wifi.signalBars(Wifi.active.signalStrength)
        : ssid.length > 14 ? ssid.slice(0, 13) + "~" : ssid
    textColor: Wifi.enabled && ssid !== "" ? Colors.fg : Colors.dim
}
