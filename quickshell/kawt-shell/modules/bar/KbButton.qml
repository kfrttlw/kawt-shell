import qs.components
import qs.services
import qs.config

// [us] / [ru] — click or scroll to switch
BracketButton {
    visible: Settings.barShows("kb") && (Keyboard.code !== "")
    label: Keyboard.code
    onClicked: Keyboard.next()
    onScrolled: steps => steps > 0 ? Keyboard.prev() : Keyboard.next()
}
