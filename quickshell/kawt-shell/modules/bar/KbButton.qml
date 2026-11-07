import QtQuick
import qs.config
import qs.components
import qs.services

// RU / EN, only with more than one layout: a click or the wheel switches
BarIcon {
    visible: Settings.barShows("kb") && Keyboard.code !== "" && Keyboard.count > 1
    text: Keyboard.code.toUpperCase()
    tip: `${Keyboard.name} · ${Strings.t("layout")}`
    onClicked: Keyboard.next()
    onScrolled: steps => steps > 0 ? Keyboard.prev() : Keyboard.next()
}
