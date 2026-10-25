import qs.components
import qs.services
import qs.config

BracketButton {
    visible: Settings.barShows("br") && (Brightness.available)
    tag: "br"
    label: `${Brightness.pct}%`
    onScrolled: steps => Brightness.step(steps * 0.05)
}
