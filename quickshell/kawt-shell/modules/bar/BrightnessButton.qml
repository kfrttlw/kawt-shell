import qs.components
import qs.services

BracketButton {
    visible: Brightness.available
    tag: "br"
    label: `${Brightness.pct}%`
    onScrolled: steps => Brightness.step(steps * 0.05)
}
