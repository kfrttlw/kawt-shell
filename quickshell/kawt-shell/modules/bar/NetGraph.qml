import QtQuick
import qs.config
import qs.components
import qs.services
import qs.utils

// [↓ 1.2M ▁▂▃▅▇▆▃▂ ↑  34K]
BarBox {
    id: root

    readonly property int samples: 12

    Label {
        text: `[↓${Fmt.rate(NetStats.rx)} `
    }

    Label {
        text: Fmt.spark(NetStats.rxHistory.slice(-root.samples))
        color: Colors.accent
    }

    Label {
        text: ` ↑${Fmt.rate(NetStats.tx)}`
        color: Colors.dim
    }

    Label {
        text: "]"
    }
}
