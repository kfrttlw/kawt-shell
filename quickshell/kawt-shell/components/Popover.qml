import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services

// A titled card under the bar, in a window just as big as the card.
// Click outside or press Esc to close. Children go into a ColumnLayout.
// (It used to be a transparent window over the whole screen, only to catch the click outside:
// that's a screen-sized buffer, 8 MB at 1080p and 33 MB at 4K, twice or three times over.
// Hyprland's focus grab does the same for free, and leaves the bar clickable: a click on
// another bar button opens that one right away instead of only closing this.)
PanelWindow {
    id: root

    required property ShellScreen forScreen
    property string name: ""
    property string title: name
    property Item anchorItem: null // bar widget to center the card under
    property var barWindow: null // the bar it hangs from: clicks there don't close it (Bar.qml)
    property int cardWidth: 260
    readonly property bool open: Panels.isOpen(name, forScreen)
    // the bar spans the whole screen width, so its scene x == screen x; re-evaluated on open
    readonly property real anchorX: open && anchorItem ? anchorItem.mapToItem(null, anchorItem.width / 2, 0).x : 0

    default property alias content: body.data

    // use these instead of onOpenChanged: the popover is created already open (Bar.qml).
    // (not opened / closed: the window already has a `closed` signal of its own)
    signal panelOpened
    signal panelClosed

    screen: forScreen
    visible: open
    color: "transparent"
    implicitWidth: cardWidth
    implicitHeight: card.height + card.titleOverhang

    WlrLayershell.namespace: "kawt-popover"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // under the bar, centered on its button, kept on the screen
    anchors.top: true
    anchors.left: true
    margins.top: Metrics.barHeight + Metrics.spacing
    margins.left: Math.round(Math.max(Metrics.padding, Math.min(forScreen.width - cardWidth - Metrics.padding, anchorX - cardWidth / 2)))

    // a click outside this window and the bar closes it
    HyprlandFocusGrab {
        active: root.open
        windows: [root, root.barWindow].filter(w => w)
        onCleared: Panels.close()
    }

    OpenWatch {
        open: root.open
        onOpened: {
            card.forceActiveFocus();
            fadeIn.restart();
            root.panelOpened();
        }
        onClosed: root.panelClosed()
    }

    TitledBox {
        id: card

        title: root.title
        hint: "esc"
        y: titleOverhang
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
