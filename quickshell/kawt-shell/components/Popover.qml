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
    property int cardWidth: 260 // at the standard font size; it grows with a bigger one
    readonly property int cardW: Math.round(cardWidth * Metrics.scale)
    readonly property bool open: Panels.isOpen(name, forScreen)
    // the bar spans the whole screen width, so its scene x == screen x; re-evaluated on open.
    // A button switched off in the bar (or opened by its key): the middle of the screen
    readonly property real anchorX: open && anchorItem?.visible ? anchorItem.mapToItem(null, anchorItem.width / 2, 0).x : forScreen.width / 2

    default property alias content: body.data

    // use these instead of onOpenChanged: the popover is created already open (Bar.qml).
    // (not opened / closed: the window already has a `closed` signal of its own)
    signal panelOpened
    signal panelClosed
    // a key on the card (the player's space, arrows...); Esc is taken already: it closes
    signal cardKey(var event)

    screen: forScreen
    visible: open
    color: "transparent"
    implicitWidth: cardW
    implicitHeight: card.height + card.titleOverhang

    WlrLayershell.namespace: "kawt-popover"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // under the bar (over it, with the bar at the bottom), centered on its button, kept on the screen
    anchors.top: !Metrics.barBottom
    anchors.bottom: Metrics.barBottom
    anchors.left: true
    margins.top: Metrics.barHeight + Metrics.spacing
    margins.bottom: Metrics.barHeight + Metrics.spacing
    margins.left: Math.round(Math.max(Metrics.padding, Math.min(forScreen.width - cardW - Metrics.padding, anchorX - cardW / 2)))

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
        width: root.cardW
        height: body.implicitHeight + Metrics.padding * 2 + titleOverhang

        Keys.onEscapePressed: Panels.close()
        Keys.onPressed: event => root.cardKey(event)

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
