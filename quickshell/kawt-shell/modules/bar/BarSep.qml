import QtQuick
import qs.config

// │ a thin line between the bar's groups
Rectangle {
    implicitWidth: Metrics.borderWidth
    implicitHeight: Math.round(Metrics.fontSize * 1.1)
    color: Colors.border
}
