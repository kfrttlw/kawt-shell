import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// super + /: every kawt bind, read straight from hypr/kawt.lua (each hl.bind line ends with a
// "-- what it does" comment), so the list can't drift away from the real binds.
// Plus the keys that work inside kawt's own windows.
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property bool open: Panels.isOpen("keys", forScreen)
    property var binds: [] // [{ keys, what }]

    readonly property var inside: [
        ["launcher", "↑↓ pick · enter run · ctrl+tab mode · ctrl+s pin · prefixes ! > = ? : ;"],
        ["style (super+w)", "arrows pick a wallpaper · enter set · [ ] theme · t dark/light"],
        ["power (super+esc)", "↑↓ pick · enter run · enter again: now · esc cancel"],
        ["todo", "14:30 / 9am / +30m / 05.10 10:00 · #folder · ! !! !!!"],
        ["everywhere", "esc closes · click outside closes"]
    ]

    screen: forScreen
    visible: open
    color: "transparent"

    WlrLayershell.namespace: "kawt-keys"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    OpenWatch {
        open: root.open
        onOpened: {
            file.reload();
            box.forceActiveFocus();
        }
    }

    // "SUPER + SHIFT + S" -> "super+shift+s"
    function pretty(keys: string): string {
        return keys.toLowerCase().replace(/\s*\+\s*/g, "+").replace("slash", "/").replace("escape", "esc");
    }

    FileView {
        id: file

        path: `${Quickshell.shellDir}/hypr/kawt.lua`
        onLoaded: {
            const out = [];
            for (const line of text().split("\n")) {
                // hl.bind(mod .. " + R", ...) -- what   /   hl.bind("Print", ...) -- what
                const m = line.match(/^\s*hl\.bind\((mod\s*\.\.\s*)?"([^"]+)".*?--\s*(.+)$/);
                if (m)
                    out.push({ keys: root.pretty((m[1] ? "SUPER" : "") + m[2]), what: m[3].trim() });
            }
            root.binds = out;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: Panels.close()
        }
    }

    TitledBox {
        id: box

        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: Math.min(760, root.width - Metrics.padding * 4)
        height: body.implicitHeight + Metrics.padding * 2 + titleOverhang
        title: "keys"
        hint: "esc"

        Keys.onEscapePressed: Panels.close()

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Metrics.padding * 1.5
            anchors.topMargin: Metrics.padding * 1.5 + box.titleOverhang
            spacing: 2

            Label {
                visible: root.binds.length === 0
                text: "-- couldn't read hypr/kawt.lua --"
                color: Colors.warn
            }

            // two columns of  keys  what
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: Metrics.padding
                rowSpacing: 2

                // flat: keys, what, keys, what... (a nested Repeater would take a grid cell itself)
                Repeater {
                    model: root.binds.reduce((all, b) => all.concat([b.keys, b.what]), [])

                    Label {
                        required property string modelData
                        required property int index
                        readonly property bool isKeys: index % 2 === 0

                        Layout.fillWidth: !isKeys
                        Layout.preferredWidth: isKeys ? -1 : 1
                        elide: Text.ElideRight
                        text: modelData
                        color: isKeys ? Colors.accent : Colors.fg
                    }
                }
            }

            Label {
                Layout.topMargin: Metrics.padding
                text: "-- inside kawt --"
                color: Colors.dim
            }

            Repeater {
                model: root.inside

                RowLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Metrics.padding

                    Label {
                        Layout.preferredWidth: Metrics.fontSize * 0.6 * 18
                        text: modelData[0]
                        color: Colors.accent
                    }

                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: modelData[1]
                        color: Colors.dim
                    }
                }
            }
        }
    }
}
