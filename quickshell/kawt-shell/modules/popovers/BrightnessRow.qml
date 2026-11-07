import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// The screen's brightness and the night light, the old way (the power panel and the
// brightness panel both show it):
//   ☼ ──────■──── 60%
//   [x] Night light · warmer after sunset            [Warmer] [Cooler]
ColumnLayout {
    Layout.fillWidth: true
    spacing: Metrics.spacing

    RowLayout {
        Layout.fillWidth: true
        visible: Brightness.available
        spacing: Metrics.spacing

        PixIcon {
            name: "sun"
        }

        LevelSlider {
            Layout.fillWidth: true
            value: Brightness.value
            onMoved: v => Brightness.set(v)
        }

        Label {
            Layout.preferredWidth: Math.round(Metrics.fontSize * 0.6 * 4)
            horizontalAlignment: Text.AlignRight
            text: `${Brightness.pct}%`
        }
    }

    // hyprsunset (services/Night.qml)
    RowLayout {
        Layout.fillWidth: true
        visible: Night.available
        spacing: Metrics.spacing

        Check {
            Layout.fillWidth: true
            text: Strings.t("nightLight")
            note: `${Strings.t("nightNote")} · ${Night.temp}K`
            checked: Settings.nightLight
            onToggled: Settings.nightLight = !Settings.nightLight
        }

        PushButton {
            visible: Settings.nightLight
            minWidth: 0
            text: Strings.t("warmer")
            onClicked: Night.warmer()
        }

        PushButton {
            visible: Settings.nightLight
            minWidth: 0
            text: Strings.t("cooler")
            onClicked: Night.cooler()
        }
    }

    Label {
        visible: !Brightness.available && !Night.available
        text: Strings.t("noBacklight")
        color: Colors.dim
    }
}
