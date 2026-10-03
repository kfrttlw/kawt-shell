import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Fullscreen transparent overlay with a titled card under the bar.
// Click outside or press Esc to close. Children go into a ColumnLayout.
PanelWindow {
    id: root

    required property ShellScreen forScreen
    property string name: ""
    property string title: name
    property Item anchorItem: null // bar widget to center the card under
    property int cardWidth: 260
    readonly property bool open: Panels.isOpen(name, forScreen)
    // the bar spans the whole screen width, so its scene x == screen x; re-evaluated on open
    readonly property real anchorX: open && anchorItem ? anchorItem.mapToItem(null, anchorItem.width / 2, 0).x : 0

    default property alias content: body.data

    screen: forScreen
    visible: open
    color: "transparent"

    WlrLayershell.namespace: "kawt-popover"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    onOpenChanged: if (open) {
        card.forceActiveFocus();
        fadeIn.restart();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Panels.close()
    }

    TitledBox {
        id: card

        title: root.title
        hint: "esc"
        x: Math.round(Math.max(Metrics.padding, Math.min(root.width - width - Metrics.padding, root.anchorX - width / 2)))
        y: Metrics.barHeight + Metrics.spacing + titleOverhang
        width: root.cardWidth
        height: body.implicitHeight + Metrics.padding * 2 + titleOverhang

        Keys.onEscapePressed: Panels.close()

        NumberAnimation {
            id: fadeIn

            target: card
            property: "opacity"
            from: 0
            to: 1
            duration: 120
        }

        MouseArea {
            anchors.fill: parent
            onClicked: card.forceActiveFocus()
        }

        ColumnLayout {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Metrics.padding
            anchors.topMargin: Metrics.padding + card.titleOverhang
            spacing: Metrics.spacing
        }
    }
}
