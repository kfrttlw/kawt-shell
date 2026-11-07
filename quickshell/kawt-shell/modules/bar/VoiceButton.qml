import QtQuick
import qs.config
import qs.components
import qs.services

// while you speak to the ai (super + alt + v), and while whisper writes it down. A click: stop
// listening (services/Voice.qml)
BarIcon {
    visible: Panels.voice !== ""
    icon: "mic"
    text: Panels.voice
    textColor: Colors.accent
    tip: Panels.voice
    onClicked: Voice.toggle()
}
