import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// The screen's brightness (the backlight, or the monitors over ddc) and the night light
Popover {
    name: "brightness"
    title: Strings.t("brightnessTitle")
    icon: "sun"
    cardWidth: 340
    settingsPage: "screen"
    note: Brightness.device

    BrightnessRow {}
}
