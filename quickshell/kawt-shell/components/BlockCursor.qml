import QtQuick
import qs.config

// █ blinking terminal cursor, for TextInput/TextEdit cursorDelegate
Rectangle {
    id: root

    width: Math.round(Metrics.fontSize * 0.6)
    color: Colors.accent

    SequentialAnimation on opacity {
        running: root.visible
        loops: Animation.Infinite

        PropertyAction { value: 0.7 }
        PauseAnimation { duration: 530 }
        PropertyAction { value: 0 }
        PauseAnimation { duration: 530 }
    }
}
