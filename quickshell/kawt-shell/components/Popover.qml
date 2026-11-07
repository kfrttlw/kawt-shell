import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services

// A panel under the bar, the old way: a raised window without a title bar. On top its icon and
// name (and its main switch on the right: Wi-Fi, do not disturb...), at the bottom a dim word
// and "Settings…", to the page of the settings it belongs to. Its window is just as big as
// the card and its shadow. Click outside or press Esc to close. Children go into a ColumnLayout.
//   Popover { name: "volume"; title: Strings.t("sound"); icon: "vol2"; settingsPage: "media" … }
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
    property string icon: "" // the pixel icon before the name (utils/pixicons.js)
    property bool head: true // false: no icon and name on top (the calendar's own: the time)
    property string settingsPage: "" // "Settings…" at the bottom opens this page of the settings
    property string note: "" // dim words at the bottom left ("wheel on the icon: ±5%")
    // the main switch, on the right of the head ("" = none)
    property string switchText: ""
    property bool switchOn: false
    readonly property int shadowRoom: 5
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
    signal switchToggled

    screen: forScreen
    visible: open
    color: "transparent"
    implicitWidth: cardW + shadowRoom
    implicitHeight: card.height + shadowRoom

    WlrLayershell.namespace: "kawt-popover"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // under the bar (over it, with the bar at the bottom), centered on its button, kept on the screen
    anchors.top: !Metrics.barBottom
    anchors.bottom: Metrics.barBottom
    anchors.left: true
    // right at the edge while the bar is tucked away (opened by a key then)
    readonly property int barGap: barWindow?.tucked ? 0 : Metrics.barHeight
    margins.top: barGap + Metrics.spacing
    margins.bottom: barGap + Metrics.spacing
    margins.left: Math.round(Math.max(Metrics.padding, Math.min(forScreen.width - cardW - shadowRoom - Metrics.padding, anchorX - cardW / 2)))

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

    Item {
        id: card

        width: root.cardW
        height: column.implicitHeight + Metrics.padding * 2

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

        // the hard shadow
        Rectangle {
            x: root.shadowRoom
            y: root.shadowRoom
            width: parent.width
            height: parent.height
            color: Qt.rgba(0, 0, 0, 0.5)
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.face

            Bevel {
                style: "raised"
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: card.forceActiveFocus()
        }

        ColumnLayout {
            id: column

            x: Metrics.padding
            y: Metrics.padding
            width: parent.width - Metrics.padding * 2
            spacing: Metrics.spacing

            // the head: icon, name, the main switch
            RowLayout {
                Layout.fillWidth: true
                visible: root.head
                spacing: 6

                PixIcon {
                    visible: root.icon !== ""
                    name: root.icon
                }

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.title
                }

                Check {
                    visible: root.switchText !== ""
                    text: root.switchText
                    checked: root.switchOn
                    onToggled: root.switchToggled()
                }
            }

            ColumnLayout {
                id: body

                Layout.fillWidth: true
                spacing: Metrics.spacing
            }

            // the foot: a word, and the way to the settings
            Rule {
                Layout.fillWidth: true
                visible: foot.visible
            }

            RowLayout {
                id: foot

                Layout.fillWidth: true
                visible: root.settingsPage !== "" || root.note !== ""
                spacing: Metrics.spacing

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.note
                    color: Colors.dim
                }

                PushButton {
                    visible: root.settingsPage !== ""
                    minWidth: 0
                    text: Strings.t("settingsDots")
                    onClicked: Panels.openWindow("settings", root.settingsPage)
                }
            }
        }
    }
}
