import qs.config
import qs.components
import qs.services

// [wifi home], [wifi ▂▄▆_] or nothing, as picked in the profile's cfg tab; [eth] on a cable
// (traffic takes the cable then: networkmanager ranks it above wifi)
BracketButton {
    readonly property string ssid: Wifi.active?.name ?? ""
    readonly property bool wired: NetLinks.wired !== ""

    visible: Settings.barShows("wifi") && (Wifi.device !== null || wired) && Settings.wifiStyle !== "hidden"
    tag: wired ? "" : "wifi"
    label: wired ? "eth"
        : !Wifi.enabled ? "off"
        : ssid === "" ? "--"
        : Settings.wifiStyle === "bars" ? Wifi.signalBars(Wifi.active.signalStrength)
        : ssid.length > 14 ? ssid.slice(0, 13) + "~" : ssid
    textColor: wired || (Wifi.enabled && ssid !== "") ? Colors.fg : Colors.dim
}
