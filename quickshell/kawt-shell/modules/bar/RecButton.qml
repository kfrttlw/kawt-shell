import QtQuick
import qs.config
import qs.components
import qs.services
import qs.utils

// ● 0:42 while recording, the dot blinks. A click: stop
BarIcon {
    id: root

    property bool blink: true

    visible: Recorder.recording
    icon: blink ? "rec" : ""
    text: Fmt.mmss(Recorder.elapsed)
    textColor: Colors.accent
    tip: Strings.t("recording")
    onClicked: Recorder.stop()

    Timer {
        running: root.visible
        repeat: true
        interval: 600
        onTriggered: root.blink = !root.blink
    }
}
