import QtQuick
import qs.config
import qs.components
import qs.services
import qs.utils

// [● rec 0:42] while recording; the dot blinks. click: stop
BracketButton {
    id: root

    property bool blink: true

    visible: Recorder.recording
    tag: blink ? "●" : " "
    label: `rec ${Fmt.mmss(Recorder.elapsed)}`
    textColor: Colors.accent
    onClicked: Recorder.stop()

    Timer {
        running: root.visible
        repeat: true
        interval: 600
        onTriggered: root.blink = !root.blink
    }
}
