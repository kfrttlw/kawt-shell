import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Popover {
    name: "brightness"
    title: "backlight"
    cardWidth: 260

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing

        Label {
            text: `${Brightness.pct}%`
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Brightness.device
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }

        BracketButton {
            label: "-"
            onClicked: Brightness.step(-0.1)
        }

        BracketButton {
            label: "+"
            onClicked: Brightness.step(0.1)
        }
    }

    LevelSlider {
        Layout.fillWidth: true
        value: Brightness.value
        onMoved: v => Brightness.set(v)
    }
}
