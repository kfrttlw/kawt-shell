import qs.components
import qs.services
import qs.config

BracketButton {
    visible: Settings.barShows("br") && (Brightness.available)
    tag: "br"
    label: String(Brightness.pct)
    meter: Brightness.pct / 100
    onScrolled: steps => Brightness.step(steps * 0.05)
}
