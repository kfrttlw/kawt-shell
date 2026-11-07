import qs.config
import qs.components
import qs.services

// [● voice 0:05] while you speak to the ai (super + alt + v), [~ writing] while whisper writes
// it down. Click: stop listening (services/Voice.qml)
BracketButton {
    visible: Panels.voice !== ""
    label: Panels.voice
    textColor: Colors.accent
    onClicked: Voice.toggle()
}
