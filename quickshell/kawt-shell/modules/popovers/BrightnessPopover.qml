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

    // [night on]  4500K            [warmer] [cooler]   (hyprsunset, services/Night.qml)
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        visible: Night.available
        spacing: Metrics.spacing

        BracketButton {
            tag: "night"
            label: Settings.nightLight ? "on" : "off"
            textColor: Settings.nightLight ? Colors.accent : Colors.fg
            onClicked: Settings.nightLight = !Settings.nightLight
        }

        Label {
            Layout.fillWidth: true
            text: `${Night.temp}K`
            color: Settings.nightLight ? Colors.fg : Colors.dim
        }

        BracketButton {
            label: "warmer"
            bordered: false
            onClicked: Night.warmer()
        }

        BracketButton {
            label: "cooler"
            bordered: false
            onClicked: Night.cooler()
        }
    }
}
