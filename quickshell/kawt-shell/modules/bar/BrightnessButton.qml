import QtQuick
import qs.config
import qs.components
import qs.services

// the sun, where the screen's brightness can be set: the wheel steps it
BarIcon {
    visible: Settings.barShows("br") && Brightness.available
    icon: "sun"
    tip: `${Brightness.pct}%`
    onScrolled: steps => Brightness.step(steps * 0.05)
}
