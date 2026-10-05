import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// ┌─run─────────────────────────────────────esc┐
// │ [apps] run  term  calc  ai                  │
// │ $ fire█                                     │
// │ > ▣ Firefox *                   web browser │
// └─────────────────────────────────────────────┘
// rofi-style launcher. Modes are just prefixes: !cmd shell, >cmd terminal, =expr calc, ?text ai,
// so they can be typed directly or picked with ctrl+tab / a click on the tab.
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property bool open: Panels.isOpen("launcher", forScreen)
    readonly property int maxRows: 9
    readonly property int rowHeight: Metrics.fontSize + 16

    readonly property var modes: [
        { prefix: "", name: "apps" },
        { prefix: "!", name: "run" },
        { prefix: ">", name: "term" },
        { prefix: "=", name: "calc" },
        { prefix: "?", name: "ai" },
        { prefix: ":", name: "clip" }
    ]
    readonly property string query: input.text
    readonly property string mode: modes.some(m => m.prefix && query.startsWith(m.prefix)) ? query[0] : ""
    readonly property int modeIndex: modes.findIndex(m => m.prefix === mode)
    readonly property string arg: mode ? query.slice(1).trim() : query
    readonly property string calcResult: mode === "=" ? Apps.calc(arg) : ""
    readonly property var results: open && !mode ? Apps.search(query).slice(0, 60) : []
    readonly property var clips: open && mode === ":" ? Clipboard.search(arg) : []
    // how many rows the current mode lists (apps or clipboard entries)
    readonly property int rows: mode === ":" ? clips.length : results.length
    property int current: 0

    screen: forScreen
    visible: open
    color: "transparent"

    WlrLayershell.namespace: "kawt-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    onOpenChanged: if (open) {
        input.text = Panels.launcherPrefix;
        Panels.launcherPrefix = "";
        current = 0;
        input.input.forceActiveFocus();
        fadeIn.restart();
    }
    onQueryChanged: current = 0
    onCurrentChanged: (mode === ":" ? clipList : list).positionViewAtIndex(current, ListView.Contain)
    onModeChanged: if (mode === ":")
        Clipboard.refresh()

    function move(delta: int): void {
        if (rows > 0)
            current = (current + delta + rows) % rows;
    }

    function setMode(i: int): void {
        const m = modes[(i + modes.length) % modes.length];
        input.text = m.prefix + arg;
        input.input.cursorPosition = input.text.length;
        input.input.forceActiveFocus();
    }

    function accept(): void {
        if (mode === "!" && arg) {
            Apps.run(arg);
        } else if (mode === ">" && arg) {
            Apps.runInTerminal(arg);
        } else if (mode === "=" && calcResult) {
            try {
                Quickshell.clipboardText = calcResult;
            } catch (e) {
                Quickshell.execDetached(["wl-copy", calcResult]); // older quickshell
            }
        } else if (mode === ":" && clips[current]) {
            Clipboard.copy(clips[current]);
        } else if (mode === "?" && arg) {
            Panels.sidebarScreen = forScreen.name;
            Panels.sidebarOpen = true;
            Ai.send(arg);
        } else if (!mode && results[current]) {
            Apps.launch(results[current]);
        } else {
            return;
        }
        Panels.close();
    }

    // dim the screen like a terminal taking over
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)

        MouseArea {
            anchors.fill: parent
            onClicked: Panels.close()
        }
    }

    TitledBox {
        id: box

        x: Math.round((root.width - width) / 2)
        y: Math.round(root.height * 0.18)
        width: Math.min(640, root.width - Metrics.padding * 2)
        height: body.implicitHeight + Metrics.padding * 2 + titleOverhang
        title: "run"
        hint: "esc"

        NumberAnimation {
            id: fadeIn

            target: box
            property: "opacity"
            from: 0
            to: 1
            duration: 120
        }

        MouseArea {
            anchors.fill: parent // swallow clicks so they don't close the launcher
        }

        ColumnLayout {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Metrics.padding
            anchors.topMargin: Metrics.padding + box.titleOverhang
            spacing: Metrics.spacing

            // [apps] run term calc ai
            Row {
                spacing: Metrics.spacing

                Repeater {
                    model: root.modes

                    Item {
                        id: tab

                        required property var modelData
                        required property int index
                        readonly property bool selected: index === root.modeIndex

                        implicitWidth: tabText.implicitWidth + 6
                        implicitHeight: tabText.implicitHeight + 2

                        Rectangle {
                            anchors.fill: parent
                            visible: tab.selected || tabArea.containsMouse
                            color: Colors.hoverFill
                        }

                        Label {
                            id: tabText

                            anchors.centerIn: parent
                            text: tab.selected ? `[${tab.modelData.name}]` : ` ${tab.modelData.name} `
                            color: tab.selected ? Colors.fg : Colors.dim
                        }

                        MouseArea {
                            id: tabArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setMode(tab.index)
                        }
                    }
                }
            }

            TermInput {
                id: input

                Layout.fillWidth: true
                prompt: "$"
                placeholder: "search apps..."
                onAccepted: root.accept()

                // TextInput doesn't use these keys, so they bubble up to here
                Keys.onEscapePressed: Panels.close()
                Keys.onUpPressed: root.move(-1)
                Keys.onDownPressed: root.move(1)
                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    if (ctrl && event.key === Qt.Key_Tab)
                        root.setMode(root.modeIndex + 1);
                    else if (ctrl && event.key === Qt.Key_Backtab)
                        root.setMode(root.modeIndex - 1);
                    else if (event.key === Qt.Key_Tab)
                        root.move(1);
                    else if (event.key === Qt.Key_Backtab)
                        root.move(-1);
                    else if (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J))
                        root.move(1);
                    else if (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K))
                        root.move(-1);
                    else if (ctrl && event.key === Qt.Key_D && root.mode === ":" && root.clips[root.current])
                        Clipboard.remove(root.clips[root.current]);
                    else if (ctrl && event.key === Qt.Key_S && root.results[root.current])
                        Apps.togglePin(root.results[root.current]);
                    else
                        return;
                    event.accepted = true;
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Metrics.borderWidth
                color: Colors.border
            }

            // what a prefixed command will do
            Label {
                visible: root.mode !== ""
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                elide: Text.ElideRight
                text: {
                    if (root.mode === "!")
                        return root.arg ? `sh -c '${root.arg}'` : "run a shell command in the background";
                    if (root.mode === ">")
                        return root.arg ? `${Settings.terminal} ${root.arg}` : "run a command in a terminal";
                    if (root.mode === "=")
                        return root.calcResult ? `= ${root.calcResult}   (enter: copy)` : "calculator: 2*(3+4), 2^10, 15%4";
                    if (root.mode === ":")
                        return !Clipboard.available ? "clipboard history needs cliphist: sudo pacman -S cliphist"
                            : `${root.clips.length} copied · enter: copy again · ctrl+d: forget`;
                    return root.arg ? `ask ${Settings.ollamaModel}: ${root.arg}` : "ask the local ai";
                }
                color: root.mode === "=" && root.calcResult ? Colors.accent : root.arg ? Colors.fg : Colors.dim
            }

            Label {
                visible: (root.mode === "" && root.results.length === 0) || (root.mode === ":" && Clipboard.available && root.clips.length === 0)
                text: root.mode === ":" && !root.arg ? "-- nothing copied yet --" : "-- no match --"
                color: Colors.dim
            }

            // clipboard: [clear history] (second click: sure?)
            RowLayout {
                Layout.fillWidth: true
                visible: root.mode === ":" && root.clips.length > 0

                Item {
                    Layout.fillWidth: true
                }

                BracketButton {
                    id: wipeButton

                    property bool armed: false

                    label: armed ? "sure? click again" : "clear history"
                    textColor: Colors.warn
                    bordered: false
                    onClicked: {
                        if (armed) {
                            armed = false;
                            Clipboard.wipe();
                        } else {
                            armed = true;
                            wipeDisarm.restart();
                        }
                    }

                    Timer {
                        id: wipeDisarm

                        interval: 3000
                        onTriggered: wipeButton.armed = false
                    }
                }
            }

            // clipboard history: newest first
            ListView {
                id: clipList

                Layout.fillWidth: true
                implicitHeight: Math.min(count, root.maxRows) * root.rowHeight
                visible: root.mode === ":" && count > 0
                clip: true
                model: root.clips
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: clipRow

                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.current
                    readonly property bool image: modelData.text.startsWith("[[ binary data")

                    width: clipList.width
                    height: root.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        visible: clipRow.selected
                        color: Colors.hoverFill
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 2
                        anchors.rightMargin: 4
                        spacing: Metrics.spacing

                        Label {
                            text: clipRow.selected ? ">" : " "
                            color: Colors.accent
                        }

                        Label {
                            text: clipRow.image ? "img" : "txt"
                            color: Colors.dim
                            font.pixelSize: Metrics.fontSize - 2
                        }

                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            // one line: newlines and tabs shown as spaces
                            text: clipRow.modelData.text.replace(/\s+/g, " ")
                            color: clipRow.selected ? Colors.accent : Colors.fg
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: root.current = clipRow.index
                        onClicked: mouse => {
                            root.current = clipRow.index;
                            if (mouse.button === Qt.RightButton)
                                Clipboard.remove(clipRow.modelData);
                            else
                                root.accept();
                        }
                    }
                }
            }

            ListView {
                id: list

                Layout.fillWidth: true
                implicitHeight: Math.min(count, root.maxRows) * root.rowHeight
                visible: count > 0
                clip: true
                model: root.results
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: entry

                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.current
                    readonly property bool pinned: Apps.isPinned(modelData)

                    width: list.width
                    height: root.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        visible: entry.selected
                        color: Colors.hoverFill
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 2
                        anchors.rightMargin: 4
                        spacing: Metrics.spacing

                        Label {
                            text: entry.selected ? ">" : " "
                            color: Colors.accent
                        }

                        AppIcon {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            icon: entry.modelData.icon
                            name: entry.modelData.name
                            colored: entry.selected
                        }

                        Label {
                            text: entry.modelData.name
                            color: entry.selected ? Colors.accent : Colors.fg
                        }

                        Label {
                            visible: entry.pinned
                            text: "*"
                            color: Colors.accent
                        }

                        Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                            text: (entry.modelData.genericName || entry.modelData.comment || "").toLowerCase()
                            color: Colors.dim
                            font.pixelSize: Metrics.fontSize - 2
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        // not onEntered: that also fires when the list scrolls under a resting mouse
                        onPositionChanged: root.current = entry.index
                        onClicked: mouse => {
                            root.current = entry.index;
                            if (mouse.button === Qt.RightButton)
                                Apps.togglePin(entry.modelData);
                            else
                                root.accept();
                        }
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignRight
                text: root.mode === ":" ? "↑↓ select · enter copy · ctrl+d / rmb forget · ctrl+tab mode"
                    : "↑↓ select · enter run · ctrl+s / rmb pin (*) · ctrl+tab mode"
                color: Colors.dim
                font.pixelSize: Metrics.fontSize - 3
            }
        }
    }
}
