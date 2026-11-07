import qs.config
import qs.components
import qs.services

// [caf on] while caffeine keeps the screen on (no idle lock, services/Idle.qml). Click: off.
// Switched on from the profile ([caf]) or `qs -c kawt-shell ipc call kawt caffeine`
BracketButton {
    visible: Idle.caffeine
    tag: "caf"
    label: "on"
    textColor: Colors.accent
    onClicked: Idle.caffeine = false
}
