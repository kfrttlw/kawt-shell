import qs.components
import qs.services

// [us] / [ru] — click or scroll to switch
BracketButton {
    visible: Keyboard.code !== ""
    label: Keyboard.code
    onClicked: Keyboard.next()
    onScrolled: steps => steps > 0 ? Keyboard.prev() : Keyboard.next()
}
