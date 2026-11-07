import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import "../companion"

// Right-side ai panel (super + a), a kawt window at the edge: □ makes it wide (most of the
// screen, with the files column), × closes it. Tabs:
//   chat      the conversation (or the coder's steps)
//   chats     saved conversations: open, delete
//   models    ollama: what's installed (size), what sits in memory (unload), pull new ones;
//             or the api: url, model, key
//   settings  how much the local model may take: context, cpu threads, gpu, keep-alive;
//             temperature, history length, system prompt
PanelWindow {
    id: root

    required property ShellScreen forScreen
    readonly property bool open: Panels.isSidebarOpen(forScreen)
    // 0 hidden .. 1 shown; starts at 0 so the panel slides in when it's created (Bar.qml makes
    // it on open, and keeps it a moment after closing for the slide out)
    property real progress: 0
    readonly property int tab: Panels.aiTab
    readonly property bool coder: Settings.aiMode === "coder"
    property var catalogOpen: null // null: decide by itself (open while no model is installed)
    property bool changesOpen: false // coder: [changes] instead of the steps
    readonly property bool catalogShown: catalogOpen === null ? Ai.online && Ai.models.length === 0 : catalogOpen
    // a short, curated list with the download size
    readonly property var catalog: [
        ["qwen2.5:0.5b", "0.4G", "tiny and fast, simple questions", "крошечная и быстрая, простые вопросы"],
        ["gemma3:1b", "0.8G", "small, good for its size", "маленькая, хороша для своего размера"],
        ["llama3.2:1b", "1.3G", "small all-rounder", "маленькая, на все случаи"],
        ["qwen2.5:3b", "1.9G", "balanced, good with code", "средняя, хороша с кодом"],
        ["llama3.2:3b", "2.0G", "balanced all-rounder", "средняя, на все случаи"],
        ["phi4-mini", "2.5G", "reasoning, math", "рассуждения, математика"],
        ["gemma3:4b", "3.3G", "smart, still light, sees pictures", "умная, всё ещё лёгкая, видит картинки"],
        ["qwen2.5vl:3b", "3.2G", "sees pictures: a screenshot's Ask", "видит картинки: «Спросить» у снимка"],
        ["qwen2.5-coder:7b", "4.7G", "code, needs ~8G ram", "код, нужно ~8G памяти"],
        ["llama3.1:8b", "4.9G", "smartest here, needs ~8G ram", "самая умная здесь, нужно ~8G памяти"]
    ]
    // more names for the by-name completion (from ollama.com/library)
    readonly property list<string> popular: ["llama3.2", "llama3.1", "llama3.3", "mistral", "mistral-nemo", "mixtral", "qwen2.5", "qwen2.5:1.5b", "qwen2.5:7b", "qwen2.5:14b", "qwen2.5-coder", "qwen2.5-coder:1.5b", "qwen2.5-coder:3b", "qwen3", "qwen3:0.6b", "qwen3:1.7b", "qwen3:4b", "qwen3:8b", "deepseek-r1", "deepseek-r1:1.5b", "deepseek-r1:7b", "deepseek-r1:8b", "gemma2", "gemma2:2b", "gemma3", "gemma3:12b", "phi3", "phi3:mini", "phi4", "codellama", "codegemma", "starcoder2", "llava", "llava:7b", "moondream", "qwen2.5vl", "qwen2.5vl:3b", "qwen2.5vl:7b", "tinyllama", "smollm2", "smollm2:360m", "granite3.1-dense", "nomic-embed-text"]
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

    // what you said (services/Voice.qml), after what's typed
    Connections {
        target: Voice

        function onHeard(text: string): void {
            input.text = `${input.text} ${text}`.trim();
            input.input.cursorPosition = input.text.length;
            input.input.forceActiveFocus();
        }
    }

    OpenWatch {
        open: root.open
        onOpened: {
            Ai.refresh();
            if (root.tab === 0)
                input.input.forceActiveFocus();
        }
    }

    Component.onCompleted: progress = Qt.binding(() => open ? 1 : 0)

    // "4m" until the model unloads
    function until(ms: real): string {
        const s = Math.max(0, Math.round((ms - Date.now()) / 1000));
        if (ms <= 0 || s > 86400 * 30)
            return Strings.t("aiStays");
        return Strings.t("aiUnloadsIn").arg(s >= 60 ? `${Math.round(s / 60)}m` : `${s}s`);
    }

    // what's running, and what it costs: the status bar's second cell
    readonly property string memoryLine: {
        if (Ai.useApi)
            return `api · ${Settings.apiUrl.replace(/^https?:\/\//, "")}`;
        if (!Ai.online)
            return Strings.t("aiOllamaOff");
        const m = Ai.loaded.find(l => l.name === Settings.ollamaModel || l.name === Settings.ollamaModel + ":latest");
        return m ? `${Strings.t("aiInMemory")}: ${Ai.size(m.ram)}${m.vram > 0 ? ` (gpu ${Ai.size(m.vram)})` : ""} · ${root.until(m.until)}` : Strings.t("aiNotLoaded");
    }

    KWindow {
        id: box

        // slides in from its own edge (the shadow's 5 px stay on the screen)
        x: root.onLeft ? -(1 - root.progress) * width : Metrics.padding - 5 + (1 - root.progress) * width
        // between the bar and the other edge, wherever the bar is
        y: Metrics.topGap > 0 ? Metrics.topGap + Metrics.spacing : Metrics.padding
        width: root.panelWidth - Metrics.padding
        height: parent.height - y - (Metrics.bottomGap > 0 ? Metrics.bottomGap + Metrics.spacing : Metrics.padding) - 5
        title: `${Strings.t("ai")} — ${Ai.modelName}`
        icon: "ai"
        maximizable: true
        maximized: Settings.aiWide
        status: [Ai.useApi ? "api" : Ai.online ? Strings.t("aiOnline") : Strings.t("aiOffline"), root.memoryLine]
        onCloseClicked: Panels.sidebarOpen = false
        // wide: most of the screen + the files column
        onMaximizeClicked: {
            Settings.aiWide = !Settings.aiWide;
            if (Settings.aiWide)
                Ai.refreshFiles();
        }
        onTitleDoubleClicked: maximizeClicked()

        Keys.onEscapePressed: Panels.sidebarOpen = false
        // ctrl + / ctrl - / ctrl 0: chat text size, like a terminal; ctrl + tab: the next tab
        Keys.onPressed: event => {
            if (!(event.modifiers & Qt.ControlModifier))
                return;
            if (event.key === Qt.Key_Tab)
                Panels.aiTab = (root.tab + 1) % 4;
            else if (event.key === Qt.Key_Backtab)
                Panels.aiTab = (root.tab + 3) % 4;
            else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal)
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
            spacing: Metrics.padding

        FilesPane {
            Layout.preferredWidth: 260
            Layout.maximumWidth: 260
            Layout.fillHeight: true
            visible: Settings.aiWide
        }

        Rule {
            vertical: true
            Layout.fillHeight: true
            visible: Settings.aiWide
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Metrics.spacing

            // [Chat] [Chats] [Models] [Settings]                    (•) chat ( ) coder [New]
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Tabs {
                    id: aiTabs

                    tabs: [Strings.t("aiChat"), Strings.t("aiChats"), Strings.t("aiModels"), Strings.t("settings")]
                    Component.onCompleted: current = root.tab
                    onCurrentChanged: Panels.aiTab = current

                    // opened at a tab from elsewhere (a chat picked, a screenshot's ask)
                    Connections {
                        target: Panels

                        function onAiTabChanged(): void {
                            aiTabs.current = Panels.aiTab;
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Repeater {
                    model: ["chat", "coder"]

                    Check {
                        required property string modelData

                        Layout.alignment: Qt.AlignVCenter
                        radio: true
                        text: Strings.t(modelData === "chat" ? "aiModeChat" : "aiModeCoder")
                        checked: Settings.aiMode === modelData
                        onToggled: {
                            Settings.aiMode = modelData;
                            Panels.aiTab = 0;
                            input.input.forceActiveFocus();
                        }
                    }
                }

                // a new chat / a new coder session
                PushButton {
                    small: true
                    text: Strings.t("aiNew")
                    onClicked: {
                        if (root.coder) {
                            Coder.reset();
                            root.changesOpen = false;
                        } else
                            Ai.newChat();
                        Panels.aiTab = 0;
                        input.input.forceActiveFocus();
                    }
                }
            }

            // ------------------------------------------------------------ chat
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: -Metrics.spacing
                visible: root.tab === 0 && !root.coder
                color: Colors.well

                Bevel {
                    style: "sunk"
                }

                ListView {
                    id: log

                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    spacing: Metrics.padding
                    // ScriptModel: a new message adds one line; with the plain array every message
                    // was laid out again (markdown and all) each time one came in
                    model: ScriptModel {
                        values: Ai.messages
                    }
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
                        text: Strings.t("aiChatHelp")
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
                        text: Ai.partialShown
                        model: Ai.askedModel
                        streaming: true
                    }
                }
            }

            // you scrolled up: one click back to the newest
            PushButton {
                small: true
                Layout.alignment: Qt.AlignRight
                visible: root.tab === 0 && !root.coder && !log.follow
                text: Strings.t("aiBottom")
                onClicked: log.toEnd()
            }

            // ------------------------------------------------------------ coder
            // stripes, keeping the coder company
            CoderBuddy {
                Layout.topMargin: Metrics.spacing
                visible: root.tab === 0 && root.coder && Companion.enabled
                forScreen: root.forScreen
                origin: Qt.point(root.onLeft ? 0 : root.forScreen.width - root.width, 0)
            }

            // kawt's red block and what's going on, wide only; narrow gets one line
            CoderLight {
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacing
                visible: root.tab === 0 && root.coder && Settings.aiWide
                // root.coder first everywhere Coder is named: in chat mode the coder service is
                // never even loaded (a singleton starts the first time something reads it)
                mode: !root.coder ? "idle" : Coder.pending ? "wait" : Coder.thinking ? "scan" : Coder.running || Coder.settling ? "run" : "idle"
                label: !root.coder ? "" : Coder.thinking ? Strings.t("aiThinkingStep").arg(`${Coder.stepCount}${Coder.maxSteps ? "/" + Coder.maxSteps : ""}`) : Coder.settling && !Coder.running ? Strings.t("aiLookingChanges") : Coder.action
                steps: root.coder ? Coder.steps : []
                changedCount: root.coder ? Coder.changedCount : 0
            }

            Label {
                Layout.fillWidth: true
                visible: root.tab === 0 && root.coder && !Settings.aiWide && Coder.running
                elide: Text.ElideRight
                text: !root.coder ? "" : `~ ${Coder.thinking ? Strings.t("aiThinkingStep").arg(`${Coder.stepCount}${Coder.maxSteps ? "/" + Coder.maxSteps : ""}`) : Coder.action}`
                color: Colors.accent
                font.pixelSize: Metrics.size(-1)
            }

            Label {
                Layout.fillWidth: true
                visible: root.tab === 0 && root.coder
                elide: Text.ElideMiddle
                text: Settings.aiFolder ? Strings.t("aiProject").arg(Settings.aiFolder) : Strings.t("aiNoProject")
                color: Settings.aiFolder ? Colors.dim : Colors.warn
                font.pixelSize: Metrics.size(-2)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.tab === 0 && root.coder && !root.changesOpen
                color: Colors.well

                Bevel {
                    style: "sunk"
                }

                ListView {
                    id: coderLog

                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    spacing: Metrics.spacing
                    model: ScriptModel {
                        values: root.coder ? Coder.steps : []
                    }
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
                        text: Strings.t("aiCoderHelp").arg(root.coder && Coder.canRun ? Strings.t("aiCoderRunHelp") : "")
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
            }

            // [changes]: every file it changed, as diffs (made only while open)
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: root.tab === 0 && root.coder && root.changesOpen
                visible: active

                sourceComponent: ChangesPane {}
            }

            // you scrolled up: one click back to the newest
            PushButton {
                small: true
                Layout.alignment: Qt.AlignRight
                visible: root.tab === 0 && root.coder && !coderLog.follow && !root.changesOpen
                text: Strings.t("aiBottom")
                onClicked: coderLog.toEnd()
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.tab === 0 && root.coder && (Coder.running || Coder.changedCount > 0 || root.changesOpen)
                spacing: Metrics.spacing

                Item {
                    Layout.fillWidth: true
                }

                PushButton {
                    small: true
                    visible: root.coder && (Coder.changedCount > 0 || root.changesOpen)
                    text: !root.coder ? "" : root.changesOpen ? Strings.t("aiSteps") : Strings.t("aiChanges").arg(Coder.changedCount)
                    active: root.changesOpen
                    onClicked: root.changesOpen = !root.changesOpen
                }

                PushButton {
                    small: true
                    visible: root.coder && Coder.running
                    text: Strings.t("aiStop")
                    onClicked: Coder.stop()
                }

                PushButton {
                    small: true
                    visible: root.coder && Coder.canUndo
                    text: root.coder ? Strings.t("aiUndo").arg(Coder.changedCount) : ""
                    onClicked: Coder.undo()
                }
            }

            // one click on what's copied: Copied: [Explain] [Translate] [Fix] [Summary]
            RowLayout {
                Layout.fillWidth: true
                visible: root.tab === 0 && !root.coder
                spacing: 4

                Label {
                    text: Strings.t("aiClip")
                    color: Colors.dim
                }

                Repeater {
                    model: Ai.actions

                    PushButton {
                        required property var modelData

                        small: true
                        text: Strings.t(`aiAct_${modelData[0]}`)
                        enabled: !Ai.busy
                        onClicked: Ai.quick(modelData[0])
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // your open tasks go along: "what's on tomorrow?", "add: call mom at 6"
                Check {
                    text: Strings.t("aiTasks")
                    checked: Settings.aiTodo
                    onToggled: Settings.aiTodo = !Settings.aiTodo
                }
            }

            // files going with the next message: [@notes.md x]; a picture: [picture shot.png x]
            Flow {
                Layout.fillWidth: true
                visible: root.tab === 0 && !root.coder && (Ai.attachments.length > 0 || Ai.image !== "")
                spacing: Metrics.spacing

                PushButton {
                    small: true
                    visible: Ai.image !== ""
                    tag: Strings.t("aiPicture")
                    text: `${Ai.image.split("/").pop().replace(/^\d{8}-\d{6}-/, "")} ×`
                    onClicked: Ai.image = ""
                }

                Repeater {
                    model: Ai.attachments

                    PushButton {
                        required property var modelData

                        small: true
                        text: `@${modelData.path} ×`
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
                    // the panel is destroyed when closed: the unsent text waits in Ai.draft
                    Component.onCompleted: text = Ai.draft
                    Component.onDestruction: Ai.draft = text
                    prompt: Ai.busy && !root.coder ? "~" : ">"
                    placeholder: root.coder ? (Coder.running ? Strings.t("aiWorking") : Coder.settling ? Strings.t("aiSettling") : Strings.t("aiCoderAsk")) : Ai.busy ? Strings.t("aiThinkingDots") : Ai.image ? Strings.t("aiAboutPicture").arg(Ai.visionModel) : Strings.t("aiAsk")
                    onAccepted: t => {
                        if (root.coder) {
                            if (Coder.running || Coder.settling)
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

                PushButton {
                    small: true
                    visible: Ai.busy && !root.coder
                    text: Strings.t("aiStop")
                    onClicked: Ai.stop()
                }

                // speak instead of typing (super + alt + v): whisper.cpp, on this machine
                PushButton {
                    small: true
                    text: Panels.voice !== "" ? Panels.voice : Strings.t("aiMic")
                    active: Panels.voice !== ""
                    onClicked: Voice.toggle()
                }
            }

            // ----------------------------------------------------------- chats
            // chats, models and cfg are each in a Loader: only the open tab exists (a hundred
            // saved chats, the model lists and every setting were made on each open before)
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: root.tab === 1
                visible: active

                sourceComponent: Component {
                    ColumnLayout {
                      spacing: Metrics.spacing

                      Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: -Metrics.spacing
                        color: Colors.well

                        Bevel {
                            style: "sunk"
                        }

                        Label {
                            anchors.centerIn: parent
                            visible: Ai.chats.length === 0
                            text: `— ${Strings.t("aiNoChats")} —`
                            color: Colors.dim
                        }

                      Flickable {
                        id: chatsFlick

                        anchors.fill: parent
                        anchors.margins: 3
                        clip: true
                        contentHeight: chatsCol.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: chatsCol

                            width: chatsFlick.width
                            spacing: 0

                            Repeater {
                                model: ScriptModel {
                                    values: Ai.chats
                                }

                                Item {
                                    id: chatRow

                                    required property var modelData
                                    readonly property bool current: Ai.chat?.id === modelData.id

                                    readonly property bool lit: chatRow.current || chatArea.containsMouse

                                    Layout.fillWidth: true
                                    implicitHeight: chatLine.implicitHeight + 6

                                    Rectangle {
                                        anchors.fill: parent
                                        visible: chatRow.lit
                                        color: chatRow.current ? Colors.accent : Colors.hoverFill
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
                                            text: chatRow.modelData.title || Strings.t("aiEmpty")
                                            color: chatRow.current ? Colors.onAccent : Colors.fg
                                        }

                                        Label {
                                            text: `${chatRow.modelData.messages.length} · ${Qt.formatDateTime(new Date(chatRow.modelData.updated), "dd.MM hh:mm")}`
                                            color: chatRow.current ? Colors.onAccent : Colors.dim
                                        }

                                        Label {
                                            text: "×"
                                            opacity: chatArea.containsMouse ? 1 : 0
                                            color: chatRow.current ? Colors.onAccent : Colors.warn
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

                        }
                      }
                      }

                      PushButton {
                          id: wipeChats

                          property bool armed: false

                          small: true
                          Layout.alignment: Qt.AlignRight
                          visible: Ai.chats.length > 0
                          text: armed ? Strings.t("sureAgain") : Strings.t("aiDeleteAll")
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
            }

            // ---------------------------------------------------------- models
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: root.tab === 2
                visible: active

                sourceComponent: Component {
                    Flickable {
                        id: modelsFlick

                        clip: true
                        contentHeight: modelsCol.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: modelsCol

                            width: modelsFlick.width
                            spacing: Metrics.spacing

                            Choice {
                                title: Strings.t("aiProvider")
                                options: [["ollama", Strings.t("aiOllamaLocal")], ["api", "api"]]
                                value: Settings.aiProvider
                                onPicked: v => Settings.aiProvider = v
                            }

                            // ---- ollama: what's in memory, what's installed, more
                            Group {
                                visible: !Ai.useApi
                                title: Strings.t("aiInMemoryNow")

                                Label {
                                    visible: Ai.loaded.length === 0
                                    text: Strings.t("aiNothingLoaded")
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
                                            text: `${modelData.name}  ${Ai.size(modelData.ram)}${modelData.vram > 0 ? ` (gpu ${Ai.size(modelData.vram)})` : ""} · ${root.until(modelData.until)}`
                                        }

                                        PushButton {
                                            small: true
                                            text: Strings.t("aiUnload")
                                            onClicked: Ai.unload(modelData.name)
                                        }
                                    }
                                }
                            }

                            // installed: a click uses one, × deletes it (a second click: sure)
                            Label {
                                visible: !Ai.useApi
                                text: Strings.t("aiInstalled")
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: -4
                                visible: !Ai.useApi
                                implicitHeight: Math.max(2, Ai.models.length) * (Metrics.fontSize + 9) + 6
                                color: Colors.well

                                Bevel {
                                    style: "sunk"
                                }

                                Label {
                                    anchors.centerIn: parent
                                    visible: Ai.models.length === 0
                                    text: Ai.online ? Strings.t("aiNoneYet") : Strings.t("aiOllamaOff")
                                    color: Colors.dim
                                }

                                Column {
                                    x: 3
                                    y: 3
                                    width: parent.width - 6

                                    Repeater {
                                        model: Ai.models

                                        Rectangle {
                                            id: modelRow

                                            required property var modelData
                                            readonly property bool current: Settings.ollamaModel === modelData.name || Settings.ollamaModel + ":latest" === modelData.name
                                            readonly property color ink: current ? Colors.onAccent : Colors.fg
                                            property bool armed: false

                                            width: parent.width
                                            height: Metrics.fontSize + 9
                                            color: current ? Colors.accent : modelArea.containsMouse ? Colors.hoverFill : "transparent"

                                            Label {
                                                x: 5
                                                width: info.x - x - 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                elide: Text.ElideRight
                                                text: modelRow.modelData.name.replace(/:latest$/, "")
                                                color: modelRow.ink
                                            }

                                            Label {
                                                id: info

                                                anchors.right: gone.left
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: [modelRow.modelData.params, modelRow.modelData.quant.toLowerCase(), Ai.size(modelRow.modelData.size)].filter(s => s).join(" · ")
                                                color: modelRow.current ? Colors.onAccent : Colors.dim
                                            }

                                            Label {
                                                id: gone

                                                anchors.right: parent.right
                                                anchors.rightMargin: 5
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelRow.armed ? Strings.t("aiSure") : "×"
                                                opacity: modelArea.containsMouse || modelRow.armed ? 1 : 0
                                                color: modelRow.current ? Colors.onAccent : Colors.warn
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
                                }
                            }

                            // a short, curated catalog behind one button; open by itself when
                            // nothing is installed yet. Anything else by its name
                            PushButton {
                                visible: !Ai.useApi
                                Layout.topMargin: 2
                                small: true
                                text: Strings.t("aiGetModel")
                                active: root.catalogShown
                                onClicked: root.catalogOpen = !root.catalogShown
                            }

                            Label {
                                visible: !Ai.useApi && root.catalogShown
                                text: Strings.t("aiSizesNote")
                                color: Colors.dim
                            }

                            Repeater {
                                model: !Ai.useApi && root.catalogShown ? root.catalog : []

                                RowLayout {
                                    id: catalogRow

                                    required property var modelData
                                    readonly property bool installed: Ai.models.some(m => m.name === modelData[0] || m.name === modelData[0] + ":latest")

                                    Layout.fillWidth: true
                                    spacing: Metrics.spacing

                                    Label {
                                        Layout.preferredWidth: Metrics.fontSize * 0.6 * 17
                                        elide: Text.ElideRight
                                        text: catalogRow.modelData[0]
                                    }

                                    Label {
                                        Layout.preferredWidth: Metrics.fontSize * 0.6 * 5
                                        text: catalogRow.modelData[1]
                                        color: Colors.dim
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: Strings.ru ? catalogRow.modelData[3] : catalogRow.modelData[2]
                                        color: Colors.dim
                                    }

                                    PushButton {
                                        small: true
                                        text: catalogRow.installed ? Strings.t("aiHave") : Strings.t("aiGet")
                                        enabled: !catalogRow.installed && !Ai.pulling
                                        onClicked: Ai.pull(catalogRow.modelData[0])
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                visible: !Ai.useApi
                                spacing: 6

                                Label {
                                    text: Strings.t("aiByName")
                                }

                                TermInput {
                                    Layout.fillWidth: true
                                    prompt: ""
                                    // gray completion: models you have (accent), the catalog, popular ones
                                    completions: [...Ai.models.map(m => m.name.replace(/:latest$/, "")), ...root.catalog.map(c => c[0]), ...root.popular]
                                    highlight: Ai.models.map(m => m.name.replace(/:latest$/, ""))
                                    placeholder: Strings.t("aiPullHint")
                                    onAccepted: t => {
                                        Ai.pull(t);
                                        text = "";
                                    }
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                visible: !Ai.useApi
                                elide: Text.ElideRight
                                text: Ai.pullStatus || Strings.t("aiLibrary")
                                color: Ai.pulling ? Colors.accent : Colors.dim
                            }

                            // ---- api: any OpenAI-compatible service
                            Label {
                                Layout.fillWidth: true
                                visible: Ai.useApi
                                wrapMode: Text.Wrap
                                text: Strings.t("aiApiNote")
                                color: Colors.dim
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                visible: Ai.useApi
                                columns: 2
                                columnSpacing: 6
                                rowSpacing: Metrics.spacing

                                Label {
                                    text: Strings.t("aiUrl")
                                }

                                TermInput {
                                    Layout.fillWidth: true
                                    prompt: ""
                                    text: Settings.apiUrl
                                    onAccepted: t => Settings.apiUrl = t.trim() || Settings.apiUrl
                                }

                                Label {
                                    text: Strings.t("aiModelWord")
                                }

                                TermInput {
                                    Layout.fillWidth: true
                                    prompt: ""
                                    text: Settings.apiModel
                                    onAccepted: t => Settings.apiModel = t.trim() || Settings.apiModel
                                }

                                Label {
                                    text: Strings.t("aiKey")
                                }

                                TermInput {
                                    id: keyInput

                                    Layout.fillWidth: true
                                    prompt: ""
                                    echoMode: TextInput.Password
                                    placeholder: Ai.apiKey ? Strings.t("aiKeySaved") : Strings.t("aiKeyPaste")
                                    onAccepted: t => {
                                        Ai.setApiKey(t);
                                        keyInput.text = "";
                                    }
                                }
                            }

                            // the key goes along with every request: over plain http to another
                            // machine anyone on the way can read it
                            Label {
                                Layout.fillWidth: true
                                visible: Ai.useApi && /^http:\/\//i.test(Settings.apiUrl) && !/^http:\/\/(localhost|127\.|\[::1\])/i.test(Settings.apiUrl)
                                wrapMode: Text.Wrap
                                text: Strings.t("aiHttpWarn")
                                color: Colors.warn
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: Ai.useApi
                                spacing: 6

                                Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    text: Ai.apiKey ? Strings.t("aiKeyWhere").arg(Ai.apiKey.slice(-4)) : Strings.t("aiNoKey")
                                    color: Colors.dim
                                }

                                PushButton {
                                    visible: Ai.apiKey !== ""
                                    small: true
                                    text: Strings.t("aiForgetKey")
                                    onClicked: Ai.setApiKey("")
                                }
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------------------- settings
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: root.tab === 3
                visible: active

                sourceComponent: Component {
                    Flickable {
                        id: cfgFlick

                        clip: true
                        contentHeight: cfgCol.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: cfgCol

                            width: cfgFlick.width - 2
                            spacing: Metrics.spacing

                            Group {
                                Layout.topMargin: 2
                                visible: !Ai.useApi
                                title: Strings.t("aiHowMuch")

                                Choice {
                                    title: Strings.t("aiContext")
                                    hintText: Strings.t("aiContextNote")
                                    options: [[2048, "2k"], [4096, "4k"], [8192, "8k"], [16384, "16k"]]
                                    value: Settings.aiCtx
                                    onPicked: v => Settings.aiCtx = v
                                }

                                Choice {
                                    title: Strings.t("aiKeep")
                                    hintText: Strings.t("aiKeepNote")
                                    options: [["0", "0"], ["1m", "1m"], ["5m", "5m"], ["30m", "30m"], ["-1", Strings.t("aiAlways")]]
                                    value: Settings.aiKeepAlive
                                    onPicked: v => Settings.aiKeepAlive = v
                                }

                                Choice {
                                    title: Strings.t("aiThreads")
                                    hintText: Strings.t("aiThreadsNote").arg(SysInfo.cores || "?")
                                    options: [[0, Strings.t("aiAuto")], [2, "2"], [4, "4"], [6, "6"], [8, "8"]].filter(o => o[0] === 0 || !SysInfo.cores || o[0] <= SysInfo.cores)
                                    value: Settings.aiThreads
                                    onPicked: v => Settings.aiThreads = v
                                }

                                Choice {
                                    title: "gpu"
                                    hintText: Strings.t("aiGpuNote")
                                    options: [[-1, Strings.t("aiAuto")], [0, Strings.t("aiCpuOnly")]]
                                    value: Settings.aiGpuLayers
                                    onPicked: v => Settings.aiGpuLayers = v
                                }

                                Choice {
                                    title: Strings.t("aiMaxAnswer")
                                    hintText: Strings.t("aiMaxAnswerNote")
                                    options: [[512, "512"], [1024, "1k"], [2048, "2k"], [4096, "4k"]]
                                    value: Settings.aiMaxAnswer
                                    onPicked: v => Settings.aiMaxAnswer = v
                                }
                            }

                            Group {
                                title: Strings.t("aiAnswers")

                                Choice {
                                    title: Strings.t("aiPersona")
                                    hintText: ((Ai.personas.find(p => p[0] === Settings.aiPersona) || [])[2] || Strings.t("aiOwnPrompt")).slice(0, 90)
                                    options: Ai.personas.map(p => [p[0], Strings.t(`aiPersona_${p[0]}`)])
                                    value: Settings.aiPersona
                                    onPicked: v => Settings.aiPersona = v
                                }

                                Choice {
                                    title: Strings.t("aiTemperature")
                                    hintText: Strings.t("aiTemperatureNote")
                                    options: [[0.2, "0.2"], [0.7, "0.7"], [1.0, "1.0"]]
                                    value: Settings.aiTemperature
                                    onPicked: v => Settings.aiTemperature = v
                                }

                                Choice {
                                    title: Strings.t("aiHistory")
                                    hintText: Strings.t("aiHistoryNote")
                                    options: [[6, "6"], [20, "20"], [50, "50"]]
                                    value: Settings.aiHistory
                                    onPicked: v => Settings.aiHistory = v
                                }

                                // the model that gets pictures (a screenshot's Ask): one that sees
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: !Ai.useApi
                                    spacing: 6

                                    Label {
                                        Layout.preferredWidth: Metrics.fontSize * 0.6 * 14
                                        text: Strings.t("aiPictures")
                                    }

                                    TermInput {
                                        Layout.fillWidth: true
                                        prompt: ""
                                        placeholder: Strings.t("aiChatsModel").arg(Settings.ollamaModel)
                                        completions: Ai.models.map(m => m.name)
                                        highlight: Ai.models.map(m => m.name)
                                        Component.onCompleted: text = Settings.aiVisionModel
                                        onAccepted: t => Settings.aiVisionModel = t.trim()
                                    }
                                }

                                Label {
                                    Layout.fillWidth: true
                                    visible: !Ai.useApi
                                    wrapMode: Text.Wrap
                                    text: Strings.t("aiPicturesNote")
                                    color: Colors.dim
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: Metrics.spacing
                                    visible: Settings.aiPersona === "custom"

                                    Label {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: Strings.t("aiYourPrompt")
                                        color: Colors.dim
                                    }

                                    PushButton {
                                        visible: Settings.aiSystem !== root.defaultSystem
                                        small: true
                                        text: Strings.t("aiDefault")
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
                                    color: Colors.well

                                    Bevel {
                                        style: "sunk"
                                    }

                                    TextEdit {
                                        id: systemEdit

                                        textFormat: TextEdit.PlainText // text, never html
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        text: Settings.aiSystem
                                        color: Colors.fg
                                        font.family: Metrics.longFamily
                                        font.pixelSize: Metrics.longSize - 1
                                        wrapMode: TextEdit.Wrap
                                        selectByMouse: true
                                        selectionColor: Colors.accent
                                        selectedTextColor: Colors.onAccent
                                        onActiveFocusChanged: if (!activeFocus && text !== Settings.aiSystem)
                                            Settings.aiSystem = text

                                        Label {
                                            visible: !systemEdit.text && !systemEdit.activeFocus
                                            text: Strings.t("aiPromptHint")
                                            color: Colors.dim
                                        }
                                    }
                                }
                            }

                            Group {
                                visible: !Ai.useApi
                                title: Strings.t("aiCompare")

                                Choice {
                                    title: Strings.t("aiSecond")
                                    hintText: Strings.t("aiSecondNote")
                                    options: [["", Strings.t("aiOff")], ...Ai.models.filter(m => m.name !== Settings.ollamaModel && m.name !== Settings.ollamaModel + ":latest").map(m => [m.name, m.name.replace(/:latest$/, "")])]
                                    value: Settings.aiCompare ? Settings.aiCompareModel : ""
                                    onPicked: v => {
                                        Settings.aiCompareModel = v;
                                        Settings.aiCompare = v !== "";
                                    }
                                }
                            }

                            Group {
                                title: Strings.t("aiCoderGroup")

                                Choice {
                                    title: Strings.t("aiCoderSteps")
                                    hintText: Strings.t("aiCoderStepsNote")
                                    options: [[15, "15"], [30, "30"], [50, "50"], [0, "∞"]]
                                    value: Settings.aiCoderSteps
                                    onPicked: v => Settings.aiCoderSteps = v
                                }

                                // the coder's `run`: every command waits for Run, then goes into the sandbox
                                Choice {
                                    visible: root.coder
                                    title: Strings.t("aiCoderRuns")
                                    hintText: !root.coder ? "" : !Settings.aiRun ? Strings.t("aiRunsOff") : Coder.sandbox ? Strings.t("aiRunsIn").arg(Coder.sandbox) : Settings.aiSandbox === "podman" ? Strings.t("aiRunsPodman") : Strings.t("aiRunsNoSandbox")
                                    options: [[true, Strings.t("aiOn")], [false, Strings.t("aiOff")]]
                                    value: Settings.aiRun
                                    onPicked: v => Settings.aiRun = v
                                }

                                Choice {
                                    visible: root.coder && Settings.aiRun
                                    title: Strings.t("aiSandbox")
                                    hintText: Strings.t("aiSandboxNote")
                                    options: [["bwrap", "bwrap"], ["podman", "podman"]]
                                    value: Settings.aiSandbox
                                    onPicked: v => Settings.aiSandbox = v
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: root.coder && Settings.aiRun && Settings.aiSandbox === "podman"
                                    spacing: 6

                                    Label {
                                        Layout.preferredWidth: Metrics.fontSize * 0.6 * 14
                                        text: Strings.t("aiImage")
                                    }

                                    TermInput {
                                        Layout.fillWidth: true
                                        prompt: ""
                                        placeholder: Strings.t("aiImageHint")
                                        Component.onCompleted: text = Settings.aiSandboxImage
                                        onAccepted: t => Settings.aiSandboxImage = t.trim()
                                    }
                                }

                                Choice {
                                    visible: root.coder && Settings.aiRun
                                    title: Strings.t("aiRunTime")
                                    hintText: Strings.t("aiRunTimeNote")
                                    options: [[30, "30s"], [120, "2m"], [600, "10m"]]
                                    value: Settings.aiRunSecs
                                    onPicked: v => Settings.aiRunSecs = v
                                }
                            }

                            // speaking to it (services/Voice.qml): whisper.cpp and a model of it, fetched once
                            Group {
                                title: Strings.t("aiVoice")

                                Choice {
                                    title: Strings.t("aiVoiceModel")
                                    hintText: !Voice.bin ? Strings.t("aiVoiceNeeds") : Voice.status || (Voice.ready ? Strings.t("aiVoiceReady") : Strings.t("aiVoiceGet").arg(Voice.size))
                                    options: Voice.sizes.map(s => [s[0], `${s[0]} ${s[1]}${Voice.have.includes(s[0]) ? " ✓" : ""}`])
                                    value: Voice.size
                                    onPicked: v => Settings.aiVoiceModel = v
                                }

                                PushButton {
                                    visible: Voice.bin !== "" && !Voice.have.includes(Voice.size)
                                    small: true
                                    text: Voice.fetching ? Strings.t("aiGetting") : Strings.t("aiGetVoice").arg(Voice.size)
                                    enabled: !Voice.fetching
                                    onClicked: Voice.get(Voice.size)
                                }

                                Choice {
                                    title: Strings.t("aiVoiceGoes")
                                    hintText: Strings.t("aiVoiceGoesNote")
                                    options: [[false, Strings.t("aiToInput")], [true, Strings.t("aiSent")]]
                                    value: Settings.aiVoiceSend
                                    onPicked: v => Settings.aiVoiceSend = v
                                }
                            }

                            Group {
                                title: Strings.t("aiPanel")

                                Choice {
                                    title: Strings.t("aiSide")
                                    options: [["right", Strings.t("aiRight")], ["left", Strings.t("aiLeft")]]
                                    value: Settings.aiSide
                                    onPicked: v => Settings.aiSide = v
                                }

                                Choice {
                                    title: Strings.t("aiTextSize")
                                    hintText: Strings.t("aiTextSizeNote")
                                    options: [[-2, Strings.t("aiSmall")], [0, Strings.t("aiNormal")], [2, Strings.t("aiBig")], [4, Strings.t("aiBigger")]]
                                    value: Settings.aiZoom
                                    onPicked: v => Settings.aiZoom = v
                                }

                                // how the two of you are named in the chat
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 4
                                    columnSpacing: 6

                                    Label {
                                        text: Strings.t("aiYouLabel")
                                    }

                                    TermInput {
                                        Layout.fillWidth: true
                                        prompt: ""
                                        text: Settings.aiUserLabel
                                        onAccepted: t => Settings.aiUserLabel = t.trim() || "you"
                                    }

                                    Label {
                                        text: Strings.t("aiBotLabel")
                                    }

                                    TermInput {
                                        Layout.fillWidth: true
                                        prompt: ""
                                        text: Settings.aiBotLabel
                                        onAccepted: t => Settings.aiBotLabel = t.trim() || "ai"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        }
    }

    // a setting with a few choices: its name, radio buttons in a row, a dim line under them
    component Choice: ColumnLayout {
        id: choice

        property string title
        property string hintText
        property var options: [] // [[value, label], ...]
        property var value

        signal picked(var v)

        Layout.fillWidth: true
        spacing: 1

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Label {
                Layout.preferredWidth: Metrics.fontSize * 0.6 * 14
                Layout.alignment: Qt.AlignTop
                text: choice.title
            }

            Flow {
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: choice.options

                    Check {
                        required property var modelData

                        radio: true
                        text: modelData[1]
                        checked: String(choice.value) === String(modelData[0])
                        onToggled: choice.picked(modelData[0])
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            Layout.leftMargin: Metrics.fontSize * 0.6 * 14 + 6
            visible: choice.hintText !== ""
            wrapMode: Text.Wrap
            text: choice.hintText
            color: Colors.dim
        }
    }
}
