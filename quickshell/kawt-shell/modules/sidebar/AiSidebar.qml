import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Right-side ai panel (super + a). Tabs:
//   chat    the conversation
//   chats   saved conversations: open, delete, new
//   models  ollama: what's installed (size), what sits in memory (unload), pull new ones;
//           or the api: url, model, key
//   cfg     how much the local model may take: context, cpu threads, gpu, keep-alive;
//           temperature, history length, system prompt
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property bool open: Panels.isSidebarOpen(forScreen)
    property real progress: open ? 1 : 0
    readonly property int tab: Panels.aiTab
    readonly property bool coder: Settings.aiMode === "coder"
    property var catalogOpen: null // null: decide by itself (open while no model is installed)
    readonly property bool catalogShown: catalogOpen === null ? Ai.online && Ai.models.length === 0 : catalogOpen
    // a short, curated list with the download size
    readonly property var catalog: [
        ["qwen2.5:0.5b", "0.4G", "tiny and fast, simple questions"],
        ["gemma3:1b", "0.8G", "small, good for its size"],
        ["llama3.2:1b", "1.3G", "small all-rounder"],
        ["qwen2.5:3b", "1.9G", "balanced, good with code"],
        ["llama3.2:3b", "2.0G", "balanced all-rounder"],
        ["phi4-mini", "2.5G", "reasoning, math"],
        ["gemma3:4b", "3.3G", "smart, still light"],
        ["qwen2.5-coder:7b", "4.7G", "code, needs ~8G ram"],
        ["llama3.1:8b", "4.9G", "smartest here, needs ~8G ram"]
    ]
    // more names for the pull> completion (from ollama.com/library)
    readonly property list<string> popular: ["llama3.2", "llama3.1", "llama3.3", "mistral", "mistral-nemo", "mixtral", "qwen2.5", "qwen2.5:1.5b", "qwen2.5:7b", "qwen2.5:14b", "qwen2.5-coder", "qwen2.5-coder:1.5b", "qwen2.5-coder:3b", "qwen3", "qwen3:0.6b", "qwen3:1.7b", "qwen3:4b", "qwen3:8b", "deepseek-r1", "deepseek-r1:1.5b", "deepseek-r1:7b", "deepseek-r1:8b", "gemma2", "gemma2:2b", "gemma3", "gemma3:12b", "phi3", "phi3:mini", "phi4", "codellama", "codegemma", "starcoder2", "llava", "moondream", "tinyllama", "smollm2", "smollm2:360m", "granite3.1-dense", "nomic-embed-text"]
    readonly property string defaultSystem: "Answer briefly and informatively. Get straight to the point, skip filler and repetition. Use a list or a code block only when it really helps. Answer in the language of the question."

    screen: forScreen
    visible: open || progress > 0
    color: "transparent"
    // wide: most of the screen, with the files column
    readonly property int panelWidth: Settings.aiWide ? Math.round(forScreen.width * 0.62) : Metrics.sidebarWidth
    implicitWidth: panelWidth + Metrics.padding

    WlrLayershell.namespace: "kawt-sidebar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // right or left edge (Settings.aiSide)
    readonly property bool onLeft: Settings.aiSide === "left"
    anchors.top: true
    anchors.right: !onLeft
    anchors.left: onLeft
    anchors.bottom: true

    Behavior on progress {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    onOpenChanged: if (open) {
        Ai.refresh();
        if (tab === 0)
            input.input.forceActiveFocus();
    }

    // "4m" until the model unloads
    function until(ms: real): string {
        const s = Math.max(0, Math.round((ms - Date.now()) / 1000));
        if (ms <= 0 || s > 86400 * 30)
            return "stays loaded";
        return s >= 60 ? `unloads in ${Math.round(s / 60)}m` : `unloads in ${s}s`;
    }

    TitledBox {
        id: box

        // slides in from its own edge
        x: root.onLeft ? -(1 - root.progress) * width : Metrics.padding + (1 - root.progress) * width
        y: Metrics.barHeight + Metrics.spacing + titleOverhang
        width: root.panelWidth - Metrics.padding
        height: parent.height - y - Metrics.padding
        title: `ai: ${Ai.modelName}`
        hint: Ai.useApi ? "api" : Ai.online ? "online" : "offline"

        Keys.onEscapePressed: Panels.sidebarOpen = false
        // ctrl + / ctrl - / ctrl 0: chat text size, like a terminal
        Keys.onPressed: event => {
            if (!(event.modifiers & Qt.ControlModifier))
                return;
            if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal)
                Settings.aiZoom = Math.min(12, Settings.aiZoom + 1);
            else if (event.key === Qt.Key_Minus)
                Settings.aiZoom = Math.max(-4, Settings.aiZoom - 1);
            else if (event.key === Qt.Key_0)
                Settings.aiZoom = 0;
            else
                return;
            event.accepted = true;
        }

        // files (wide only) | the panel
        RowLayout {
            anchors.fill: parent
            anchors.margins: Metrics.padding
            anchors.topMargin: Metrics.padding + box.titleOverhang
            spacing: Metrics.padding

        FilesPane {
            Layout.preferredWidth: 260
            Layout.maximumWidth: 260
            Layout.fillHeight: true
            visible: Settings.aiWide
        }

        Rectangle {
            Layout.fillHeight: true
            implicitWidth: Metrics.borderWidth
            visible: Settings.aiWide
            color: Colors.border
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Metrics.spacing

            // [chat] chats models cfg                     [new] [x]
            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacing

                Repeater {
                    model: ["chat", "chats", "models", "cfg"]

                    Label {
                        required property string modelData
                        required property int index

                        text: index === root.tab ? `[${modelData}]` : ` ${modelData} `
                        color: index === root.tab ? Colors.fg : tabArea.containsMouse ? Colors.fg : Colors.dim

                        MouseArea {
                            id: tabArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Panels.aiTab = parent.index
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // wide: most of the screen + the files column
                BracketButton {
                    label: Settings.aiWide ? "><" : "<>"
                    bordered: false
                    onClicked: {
                        Settings.aiWide = !Settings.aiWide;
                        if (Settings.aiWide)
                            Ai.refreshFiles();
                    }
                }

                BracketButton {
                    label: "+" // new chat / new coder session
                    bordered: false
                    onClicked: {
                        if (root.coder)
                            Coder.reset();
                        else
                            Ai.newChat();
                        Panels.aiTab = 0;
                        input.input.forceActiveFocus();
                    }
                }

                BracketButton {
                    label: "x"
                    bordered: false
                    onClicked: Panels.sidebarOpen = false
                }
            }

            // [chat] coder   ·   what's running, and what it costs
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: [["chat", "chat"], ["coder", "coder"]]

                    BracketButton {
                        required property var modelData

                        label: modelData[1]
                        active: Settings.aiMode === modelData[0]
                        textColor: Settings.aiMode === modelData[0] ? Colors.accent : Colors.dim
                        bordered: false
                        onClicked: {
                            Settings.aiMode = modelData[0];
                            Panels.aiTab = 0;
                            input.input.forceActiveFocus();
                        }
                    }
                }

            Label {
                Layout.fillWidth: true
                Layout.leftMargin: Metrics.spacing
                elide: Text.ElideRight
                text: {
                    if (Ai.useApi)
                        return `api · ${Settings.apiUrl.replace(/^https?:\/\//, "")}`;
                    if (!Ai.online)
                        return "ollama not reachable";
                    const m = Ai.loaded.find(l => l.name === Settings.ollamaModel || l.name === Settings.ollamaModel + ":latest");
                    return m ? `in memory: ${Ai.size(m.ram)}${m.vram > 0 ? ` (gpu ${Ai.size(m.vram)})` : ""} · ${root.until(m.until)}` : "model not loaded (loads on the first message)";
                }
                color: !Ai.useApi && !Ai.online ? Colors.warn : Colors.dim
                font.pixelSize: Metrics.fontSize - 2
            }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Metrics.borderWidth
                color: Colors.border
            }

            // ------------------------------------------------------------ chat
            ListView {
                id: log

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.tab === 0 && !root.coder
                clip: true
                spacing: Metrics.padding
                model: Ai.messages
                boundsBehavior: Flickable.StopAtBounds
                // follows new content only while you're at the bottom; scroll up and it stays put
                property bool follow: true
                property bool autoScroll: false

                function toEnd(): void {
                    autoScroll = true;
                    positionViewAtEnd();
                    autoScroll = false;
                    follow = true;
                }

                onContentYChanged: if (!autoScroll)
                    follow = atYEnd
                onCountChanged: if (follow)
                    Qt.callLater(toEnd)
                onContentHeightChanged: if (follow)
                    Qt.callLater(toEnd)

                header: Label {
                    width: log.width
                    visible: log.count === 0
                    height: visible ? implicitHeight : 0
                    text: "  enter         send\n  /model name   switch model\n  /new          new chat\n  /stop         stop the reply\n  esc           close\n\n  models and memory: [models] / [cfg]"
                    color: Colors.dim
                }

                delegate: ChatLine {
                    required property var modelData
                    required property int index

                    width: log.width
                    kind: modelData.role
                    text: modelData.text
                    time: modelData.time ?? 0
                    took: modelData.took ?? 0
                    tps: modelData.tps ?? 0
                    files: modelData.files ?? []
                    model: modelData.model ?? ""
                    // retry on the last answer, edit on the last question
                    showRetry: !Ai.busy && modelData.role === "assistant" && index === log.count - 1
                    showEdit: !Ai.busy && modelData.role === "user" && index === Ai.messages.map(m => m.role).lastIndexOf("user")
                    onRetry: Ai.retry()
                    onToNote: Ai.saveNote(text)
                    onEdit: {
                        input.text = Ai.editLast();
                        input.input.forceActiveFocus();
                    }
                }

                // the reply that is still streaming in
                footer: ChatLine {
                    width: log.width
                    visible: Ai.busy
                    height: visible ? implicitHeight : 0
                    topPadding: log.count > 0 ? log.spacing : 0
                    kind: "assistant"
                    text: Ai.partial
                    model: Ai.askedModel
                    streaming: true
                }
            }

            // you scrolled up: one click back to the newest
            BracketButton {
                Layout.alignment: Qt.AlignRight
                visible: root.tab === 0 && !root.coder && !log.follow
                label: "↓ bottom"
                textColor: Colors.accent
                bordered: false
                onClicked: log.toEnd()
            }

            // ------------------------------------------------------------ coder
            // the network, wide only; narrow gets one line
            NeuralArt {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Metrics.spacing
                visible: root.tab === 0 && root.coder && Settings.aiWide
                active: Coder.running
                label: Coder.thinking ? `thinking · step ${Coder.stepCount}${Coder.maxSteps ? "/" + Coder.maxSteps : ""}` : Coder.action
            }

            Label {
                Layout.fillWidth: true
                visible: root.tab === 0 && root.coder && !Settings.aiWide && Coder.running
                elide: Text.ElideRight
                text: `~ ${Coder.thinking ? `thinking · step ${Coder.stepCount}${Coder.maxSteps ? "/" + Coder.maxSteps : ""}` : Coder.action}`
                color: Colors.accent
                font.pixelSize: Metrics.fontSize - 1
            }

            Label {
                Layout.fillWidth: true
                visible: root.tab === 0 && root.coder
                elide: Text.ElideMiddle
                text: Settings.aiFolder ? `project: ${Settings.aiFolder}` : "no project folder: open wide [<>] and set dir>"
                color: Settings.aiFolder ? Colors.dim : Colors.warn
                font.pixelSize: Metrics.fontSize - 2
            }

            ListView {
                id: coderLog

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.tab === 0 && root.coder
                clip: true
                spacing: Metrics.spacing
                model: Coder.steps
                boundsBehavior: Flickable.StopAtBounds
                // follows new content only while you're at the bottom; scroll up and it stays put
                property bool follow: true
                property bool autoScroll: false

                function toEnd(): void {
                    autoScroll = true;
                    positionViewAtEnd();
                    autoScroll = false;
                    follow = true;
                }

                onContentYChanged: if (!autoScroll)
                    follow = atYEnd
                onCountChanged: if (follow)
                    Qt.callLater(toEnd)
                onContentHeightChanged: if (follow)
                    Qt.callLater(toEnd)

                header: Label {
                    width: coderLog.width
                    visible: coderLog.count === 0
                    height: visible ? implicitHeight : 0
                    text: "  coder: tell it what to do in the project.\n\n  it can list, search and read files on its own;\n  every change is shown as a diff: [apply] or [skip].\n  [undo] puts back everything it changed.\n\n  works best with qwen2.5 / qwen2.5-coder / llama3.1+"
                    color: Colors.dim
                }

                // the task and the final answer look like chat; the rest are steps
                delegate: Loader {
                    required property var modelData

                    width: coderLog.width
                    sourceComponent: modelData.kind === "task" || modelData.kind === "answer" ? chatStep : toolStep

                    Component {
                        id: chatStep

                        ChatLine {
                            kind: parent?.modelData?.kind === "task" ? "user" : "assistant"
                            text: parent?.modelData?.text ?? ""
                            time: parent?.modelData?.time ?? 0
                        }
                    }

                    Component {
                        id: toolStep

                        StepLine {
                            step: parent?.modelData ?? ({})
                        }
                    }
                }
            }

            // you scrolled up: one click back to the newest
            BracketButton {
                Layout.alignment: Qt.AlignRight
                visible: root.tab === 0 && root.coder && !coderLog.follow
                label: "↓ bottom"
                textColor: Colors.accent
                bordered: false
                onClicked: coderLog.toEnd()
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.tab === 0 && root.coder && (Coder.running || Coder.canUndo)
                spacing: Metrics.spacing

                Item {
                    Layout.fillWidth: true
                }

                BracketButton {
                    visible: Coder.running
                    label: "stop"
                    bordered: false
                    onClicked: Coder.stop()
                }

                BracketButton {
                    visible: Coder.canUndo
                    label: `undo (${Object.keys(Coder.touched).length})`
                    textColor: Colors.warn
                    bordered: false
                    onClicked: Coder.undo()
                }
            }

            // one click on the clipboard: clip: [explain] [translate] [fix] [summary]
            RowLayout {
                Layout.fillWidth: true
                visible: root.tab === 0 && !root.coder
                spacing: 0

                Label {
                    text: "clip:"
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
                }

                Repeater {
                    model: Ai.actions

                    BracketButton {
                        required property var modelData

                        label: modelData[0]
                        enabled: !Ai.busy
                        bordered: false
                        onClicked: Ai.quick(modelData[0])
                    }
                }
            }

            // files going with the next message: [@notes.md x]
            Flow {
                Layout.fillWidth: true
                visible: root.tab === 0 && !root.coder && Ai.attachments.length > 0
                spacing: Metrics.spacing

                Repeater {
                    model: Ai.attachments

                    BracketButton {
                        required property var modelData

                        label: `@${modelData.path} x`
                        textColor: Colors.accent
                        bordered: false
                        onClicked: Ai.detach(modelData.path)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.tab === 0
                spacing: Metrics.spacing

                TermInput {
                    id: input

                    Layout.fillWidth: true
                    prompt: root.coder ? "task>" : Ai.busy ? "~" : ">"
                    placeholder: root.coder ? (Coder.running ? "working..." : "what should it do in the project?") : Ai.busy ? "thinking..." : "ask something..."
                    onAccepted: t => {
                        if (root.coder) {
                            if (Coder.running)
                                return;
                            Coder.start(t);
                            input.text = "";
                            return;
                        }
                        // keep the draft while a reply is streaming; commands always go through
                        if (Ai.busy && !t.trim().startsWith("/"))
                            return;
                        Ai.send(t);
                        input.text = "";
                    }
                }

                BracketButton {
                    visible: Ai.busy && !root.coder
                    label: "stop"
                    bordered: false
                    onClicked: Ai.stop()
                }
            }

            // ----------------------------------------------------------- chats
            Flickable {
                id: chatsFlick

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.tab === 1
                clip: true
                contentHeight: chatsCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: chatsCol

                    width: chatsFlick.width
                    spacing: 1

                    Label {
                        visible: Ai.chats.length === 0
                        text: "-- no saved chats --"
                        color: Colors.dim
                    }

                    Repeater {
                        model: Ai.chats

                        Item {
                            id: chatRow

                            required property var modelData
                            readonly property bool current: Ai.chat?.id === modelData.id

                            Layout.fillWidth: true
                            implicitHeight: chatLine.implicitHeight + 6

                            Rectangle {
                                anchors.fill: parent
                                visible: chatRow.current || chatArea.containsMouse
                                color: Colors.hoverFill
                            }

                            RowLayout {
                                id: chatLine

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 2
                                anchors.rightMargin: 4
                                spacing: Metrics.spacing

                                Label {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: (chatRow.current ? "> " : "  ") + (chatRow.modelData.title || "(empty)")
                                    color: chatRow.current ? Colors.accent : Colors.fg
                                }

                                Label {
                                    text: `${chatRow.modelData.messages.length} · ${Qt.formatDateTime(new Date(chatRow.modelData.updated), "dd.MM hh:mm")}`
                                    color: Colors.dim
                                    font.pixelSize: Metrics.fontSize - 2
                                }

                                Label {
                                    text: "x"
                                    opacity: chatArea.containsMouse ? 1 : 0
                                    color: Colors.warn
                                }
                            }

                            MouseArea {
                                id: chatArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.x > width - 20) {
                                        Ai.deleteChat(chatRow.modelData.id);
                                    } else {
                                        Ai.openChat(chatRow.modelData.id);
                                        Panels.aiTab = 0;
                                    }
                                }
                            }
                        }
                    }

                    BracketButton {
                        id: wipeChats

                        property bool armed: false

                        Layout.topMargin: Metrics.spacing
                        visible: Ai.chats.length > 0
                        label: armed ? "sure? click again" : "delete all chats"
                        textColor: Colors.warn
                        bordered: false
                        onClicked: {
                            if (armed) {
                                armed = false;
                                Ai.clearChats();
                            } else {
                                armed = true;
                                wipeChatsTimer.restart();
                            }
                        }

                        Timer {
                            id: wipeChatsTimer

                            interval: 3000
                            onTriggered: wipeChats.armed = false
                        }
                    }
                }
            }

            // ---------------------------------------------------------- models
            Flickable {
                id: modelsFlick

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.tab === 2
                clip: true
                contentHeight: modelsCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: modelsCol

                    width: modelsFlick.width
                    spacing: Metrics.spacing

                    Choice {
                        title: "provider"
                        options: [["ollama", "ollama (local)"], ["api", "api"]]
                        value: Settings.aiProvider
                        onPicked: v => Settings.aiProvider = v
                    }

                    // ---- ollama
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: !Ai.useApi
                        spacing: 2

                        Label {
                            Layout.topMargin: Metrics.spacing
                            text: "-- in memory now --"
                            color: Colors.dim
                            font.pixelSize: Metrics.fontSize - 2
                        }

                        Label {
                            visible: Ai.loaded.length === 0
                            text: "  nothing loaded: 0 MB"
                            color: Colors.dim
                        }

                        Repeater {
                            model: Ai.loaded

                            RowLayout {
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: Metrics.spacing

                                Label {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: `  ${modelData.name}  ${Ai.size(modelData.ram)}${modelData.vram > 0 ? ` (gpu ${Ai.size(modelData.vram)})` : ""} · ${root.until(modelData.until)}`
                                    color: Colors.fg
                                }

                                BracketButton {
                                    label: "unload"
                                    bordered: false
                                    onClicked: Ai.unload(modelData.name)
                                }
                            }
                        }

                        Label {
                            Layout.topMargin: Metrics.spacing
                            text: "-- installed (click: use, x: delete) --"
                            color: Colors.dim
                            font.pixelSize: Metrics.fontSize - 2
                        }

                        Label {
                            visible: Ai.online && Ai.models.length === 0
                            text: "  none yet: pull one below"
                            color: Colors.dim
                        }

                        Repeater {
                            model: Ai.models

                            Item {
                                id: modelRow

                                required property var modelData
                                readonly property bool current: Settings.ollamaModel === modelData.name || Settings.ollamaModel + ":latest" === modelData.name
                                property bool armed: false

                                Layout.fillWidth: true
                                implicitHeight: modelLine.implicitHeight + 4

                                Rectangle {
                                    anchors.fill: parent
                                    visible: modelRow.current || modelArea.containsMouse
                                    color: Colors.hoverFill
                                }

                                RowLayout {
                                    id: modelLine

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.rightMargin: 4
                                    spacing: Metrics.spacing

                                    Label {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: (modelRow.current ? "> " : "  ") + modelRow.modelData.name.replace(/:latest$/, "")
                                        color: modelRow.current ? Colors.accent : Colors.fg
                                    }

                                    Label {
                                        text: [modelRow.modelData.params, modelRow.modelData.quant.toLowerCase(), Ai.size(modelRow.modelData.size)].filter(s => s).join(" · ")
                                        color: Colors.dim
                                        font.pixelSize: Metrics.fontSize - 2
                                    }

                                    Label {
                                        text: modelRow.armed ? "sure?" : "x"
                                        opacity: modelArea.containsMouse || modelRow.armed ? 1 : 0
                                        color: Colors.warn
                                    }
                                }

                                Timer {
                                    id: disarmModel

                                    interval: 3000
                                    onTriggered: modelRow.armed = false
                                }

                                MouseArea {
                                    id: modelArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (mouse.x > width - 50) {
                                            if (modelRow.armed) {
                                                modelRow.armed = false;
                                                Ai.remove(modelRow.modelData.name);
                                            } else {
                                                modelRow.armed = true;
                                                disarmModel.restart();
                                            }
                                        } else {
                                            Settings.ollamaModel = modelRow.modelData.name;
                                        }
                                    }
                                }
                            }
                        }

                        // a short, curated catalog behind one button; open by itself when
                        // nothing is installed yet. anything else goes through pull> by name
                        BracketButton {
                            Layout.topMargin: Metrics.spacing
                            label: root.catalogShown ? "get a model ▾" : "get a model ▸"
                            textColor: Colors.accent
                            bordered: false
                            onClicked: root.catalogOpen = !root.catalogShown
                        }

                        Label {
                            visible: root.catalogShown
                            text: "  sizes are the download · small first"
                            color: Colors.dim
                            font.pixelSize: Metrics.fontSize - 3
                        }

                        Repeater {
                            model: root.catalogShown ? root.catalog : []

                            RowLayout {
                                id: catalogRow

                                required property var modelData
                                readonly property bool installed: Ai.models.some(m => m.name === modelData[0] || m.name === modelData[0] + ":latest")

                                Layout.fillWidth: true
                                spacing: Metrics.spacing

                                Label {
                                    Layout.preferredWidth: Metrics.fontSize * 0.6 * 17
                                    elide: Text.ElideRight
                                    text: `  ${catalogRow.modelData[0]}`
                                    color: Colors.fg
                                }

                                Label {
                                    Layout.preferredWidth: Metrics.fontSize * 0.6 * 5
                                    text: catalogRow.modelData[1]
                                    color: Colors.dim
                                    font.pixelSize: Metrics.fontSize - 2
                                }

                                Label {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: catalogRow.modelData[2]
                                    color: Colors.dim
                                    font.pixelSize: Metrics.fontSize - 2
                                }

                                BracketButton {
                                    label: catalogRow.installed ? "have" : "get"
                                    enabled: !catalogRow.installed && !Ai.pulling
                                    textColor: catalogRow.installed ? Colors.dim : Colors.accent
                                    bordered: false
                                    onClicked: Ai.pull(catalogRow.modelData[0])
                                }
                            }
                        }

                        TermInput {
                            Layout.fillWidth: true
                            Layout.topMargin: Metrics.spacing
                            prompt: "pull>"
                            // gray completion: models you have (accent), the catalog, popular ones
                            completions: [...Ai.models.map(m => m.name.replace(/:latest$/, "")), ...root.catalog.map(c => c[0]), ...root.popular]
                            highlight: Ai.models.map(m => m.name.replace(/:latest$/, ""))
                            placeholder: "model name, e.g. llama3.2:1b"
                            onAccepted: t => {
                                Ai.pull(t);
                                text = "";
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Ai.pullStatus || "any other model by name: see ollama.com/library"
                            color: Ai.pulling ? Colors.accent : Colors.dim
                            font.pixelSize: Metrics.fontSize - 2
                        }
                    }

                    // ---- api
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: Ai.useApi
                        spacing: Metrics.spacing

                        Label {
                            Layout.fillWidth: true
                            Layout.topMargin: Metrics.spacing
                            elide: Text.ElideRight
                            text: "any OpenAI-compatible service: openai, openrouter, groq, lm studio..."
                            color: Colors.dim
                            font.pixelSize: Metrics.fontSize - 2
                        }

                        TermInput {
                            Layout.fillWidth: true
                            prompt: "url>"
                            text: Settings.apiUrl
                            onAccepted: t => Settings.apiUrl = t.trim() || Settings.apiUrl
                        }

                        TermInput {
                            Layout.fillWidth: true
                            prompt: "model>"
                            text: Settings.apiModel
                            onAccepted: t => Settings.apiModel = t.trim() || Settings.apiModel
                        }

                        TermInput {
                            id: keyInput

                            Layout.fillWidth: true
                            prompt: "key>"
                            echoMode: TextInput.Password
                            placeholder: Ai.apiKey ? "saved · enter a new one to replace" : "paste the api key, enter"
                            onAccepted: t => {
                                Ai.setApiKey(t);
                                keyInput.text = "";
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Ai.apiKey ? `key saved (…${Ai.apiKey.slice(-4)}) · ~/.local/state/kawt/secrets.json, only you can read it` : "no key yet"
                            color: Colors.dim
                            font.pixelSize: Metrics.fontSize - 2
                        }

                        BracketButton {
                            visible: Ai.apiKey !== ""
                            label: "forget the key"
                            textColor: Colors.warn
                            bordered: false
                            onClicked: Ai.setApiKey("")
                        }
                    }
                }
            }

            // ------------------------------------------------------------- cfg
            Flickable {
                id: cfgFlick

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.tab === 3
                clip: true
                contentHeight: cfgCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: cfgCol

                    width: cfgFlick.width
                    spacing: Metrics.spacing

                    Label {
                        Layout.fillWidth: true
                        visible: !Ai.useApi
                        elide: Text.ElideRight
                        text: "-- how much the local model may take --"
                        color: Colors.dim
                    }

                    Choice {
                        visible: !Ai.useApi
                        title: "context"
                        hintText: "more = remembers more, takes more ram"
                        options: [[2048, "2k"], [4096, "4k"], [8192, "8k"], [16384, "16k"]]
                        value: Settings.aiCtx
                        onPicked: v => Settings.aiCtx = v
                    }

                    Choice {
                        visible: !Ai.useApi
                        title: "keep in ram"
                        hintText: "after an answer; 0 = free the memory at once"
                        options: [["0", "0"], ["1m", "1m"], ["5m", "5m"], ["30m", "30m"], ["-1", "always"]]
                        value: Settings.aiKeepAlive
                        onPicked: v => Settings.aiKeepAlive = v
                    }

                    Choice {
                        visible: !Ai.useApi
                        title: "cpu threads"
                        hintText: `fewer = slower answers, the system stays smooth (${SysInfo.cores || "?"} total)`
                        options: [[0, "auto"], [2, "2"], [4, "4"], [6, "6"], [8, "8"]].filter(o => o[0] === 0 || !SysInfo.cores || o[0] <= SysInfo.cores)
                        value: Settings.aiThreads
                        onPicked: v => Settings.aiThreads = v
                    }

                    Choice {
                        visible: !Ai.useApi
                        title: "gpu"
                        hintText: "cpu only keeps the gpu free, but is slower"
                        options: [[-1, "auto"], [0, "cpu only"]]
                        value: Settings.aiGpuLayers
                        onPicked: v => Settings.aiGpuLayers = v
                    }

                    Label {
                        Layout.topMargin: Metrics.spacing
                        text: "-- answers --"
                        color: Colors.dim
                    }

                    Choice {
                        title: "persona"
                        hintText: ((Ai.personas.find(p => p[0] === Settings.aiPersona) || [])[2] || "your own prompt, below").slice(0, 90)
                        options: Ai.personas.map(p => [p[0], p[1]])
                        value: Settings.aiPersona
                        onPicked: v => Settings.aiPersona = v
                    }

                    Choice {
                        title: "coder steps"
                        hintText: "the agent stops after this many; ∞ = never (stop it yourself)"
                        options: [[15, "15"], [30, "30"], [50, "50"], [0, "∞"]]
                        value: Settings.aiCoderSteps
                        onPicked: v => Settings.aiCoderSteps = v
                    }

                    Choice {
                        visible: !Ai.useApi
                        title: "max answer"
                        hintText: "in tokens; stops runaway answers"
                        options: [[512, "512"], [1024, "1k"], [2048, "2k"], [4096, "4k"]]
                        value: Settings.aiMaxAnswer
                        onPicked: v => Settings.aiMaxAnswer = v
                    }

                    Choice {
                        title: "temperature"
                        hintText: "low = precise, high = creative"
                        options: [[0.2, "0.2"], [0.7, "0.7"], [1.0, "1.0"]]
                        value: Settings.aiTemperature
                        onPicked: v => Settings.aiTemperature = v
                    }

                    Choice {
                        title: "history"
                        hintText: "earlier messages sent along as context"
                        options: [[6, "6"], [20, "20"], [50, "50"]]
                        value: Settings.aiHistory
                        onPicked: v => Settings.aiHistory = v
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Metrics.spacing
                        visible: Settings.aiPersona === "custom"

                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: "your prompt  (saved when you click away)"
                            color: Colors.dim
                            font.pixelSize: Metrics.fontSize - 2
                        }

                        BracketButton {
                            visible: Settings.aiSystem !== root.defaultSystem
                            label: "default"
                            bordered: false
                            onClicked: {
                                Settings.aiSystem = root.defaultSystem;
                                systemEdit.text = root.defaultSystem;
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: Settings.aiPersona === "custom"
                        implicitHeight: Math.max(70, systemEdit.contentHeight + 12)
                        color: Colors.bg
                        border.color: systemEdit.activeFocus ? Colors.dim : Colors.border
                        border.width: Metrics.borderWidth

                        TextEdit {
                            id: systemEdit

                            anchors.fill: parent
                            anchors.margins: 6
                            text: Settings.aiSystem
                            color: Colors.fg
                            font.family: Metrics.fontFamily
                            font.pixelSize: Metrics.fontSize - 1
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            selectionColor: Colors.accent
                            selectedTextColor: Colors.bg
                            onActiveFocusChanged: if (!activeFocus && text !== Settings.aiSystem)
                                Settings.aiSystem = text

                            Label {
                                visible: !systemEdit.text && !systemEdit.activeFocus
                                text: "e.g. answer briefly, in russian"
                                color: Colors.dim
                                font.pixelSize: Metrics.fontSize - 1
                            }
                        }
                    }

                    Label {
                        Layout.topMargin: Metrics.spacing
                        visible: !Ai.useApi
                        text: "-- compare --"
                        color: Colors.dim
                    }

                    Choice {
                        visible: !Ai.useApi
                        title: "2nd model"
                        hintText: "the same question goes to it too, after the main one"
                        options: [["", "off"], ...Ai.models.filter(m => m.name !== Settings.ollamaModel && m.name !== Settings.ollamaModel + ":latest").map(m => [m.name, m.name.replace(/:latest$/, "")])]
                        value: Settings.aiCompare ? Settings.aiCompareModel : ""
                        onPicked: v => {
                            Settings.aiCompareModel = v;
                            Settings.aiCompare = v !== "";
                        }
                    }

                    Label {
                        Layout.topMargin: Metrics.spacing
                        text: "-- panel --"
                        color: Colors.dim
                    }

                    Choice {
                        title: "side"
                        options: [["right", "right"], ["left", "left"]]
                        value: Settings.aiSide
                        onPicked: v => Settings.aiSide = v
                    }

                    Choice {
                        title: "text size"
                        hintText: "or ctrl + / ctrl - / ctrl 0 in the panel"
                        options: [[-2, "small"], [0, "normal"], [2, "big"], [4, "bigger"]]
                        value: Settings.aiZoom
                        onPicked: v => Settings.aiZoom = v
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Metrics.spacing

                        TermInput {
                            Layout.fillWidth: true
                            prompt: "you>"
                            text: Settings.aiUserLabel
                            onAccepted: t => Settings.aiUserLabel = t.trim() || "you"
                        }

                        TermInput {
                            Layout.fillWidth: true
                            prompt: "ai>"
                            text: Settings.aiBotLabel
                            onAccepted: t => Settings.aiBotLabel = t.trim() || "ai"
                        }
                    }
                }
            }
        }
        }
    }

    // title  [a] b c   hint  — one setting with a few choices
    component Choice: ColumnLayout {
        id: choice

        property string title
        property string hintText
        property var options: [] // [[value, label], ...]
        property var value

        signal picked(var v)

        Layout.fillWidth: true
        spacing: 0

        RowLayout {
            spacing: Metrics.spacing

            Label {
                Layout.preferredWidth: Metrics.fontSize * 0.6 * 12
                text: choice.title
                color: Colors.fg
            }

            Repeater {
                model: choice.options

                BracketButton {
                    required property var modelData

                    label: modelData[1]
                    active: String(choice.value) === String(modelData[0])
                    textColor: String(choice.value) === String(modelData[0]) ? Colors.accent : Colors.dim
                    bordered: false
                    onClicked: choice.picked(modelData[0])
                }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: choice.hintText !== ""
            elide: Text.ElideRight
            text: choice.hintText
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 3
        }
    }
}
