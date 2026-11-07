import QtQuick
import qs.config
import qs.components
import qs.services
import "../../utils/pixicons.js" as Pix

// the network: wifi bars (red cross: none), or the cable (traffic takes the cable then:
// networkmanager ranks it above wifi). A click: the network panel, with the traffic graph
BarIcon {
    readonly property string ssid: Wifi.active?.name ?? ""
    readonly property bool wired: NetLinks.wired !== ""

    visible: Settings.barShows("wifi") && (Wifi.device !== null || wired) && Settings.wifiStyle !== "hidden"
    icon: wired ? "eth" : !Wifi.enabled || ssid === "" ? "wifi0" : Pix.wifi(Wifi.active.signalStrength * 100)
    tip: wired ? `${Strings.t("net")}: ${Strings.t("wired")} ${NetLinks.wired}` : !Wifi.enabled || ssid === "" ? Strings.t("noNet") : `${Strings.t("net")}: ${ssid} · ${Math.round(Wifi.active.signalStrength * 100)}%`
}
