pragma Singleton
import QtQuick
import Quickshell
import qs.config

// Local AI chat over ollama's HTTP API (localhost:11434 by default, nothing leaves the machine).
// Uses QML's built-in XMLHttpRequest, no external tools. The reply streams in as one JSON
// object per line, is collected in `partial`, and moved into `messages` when done.
Singleton {
    id: root

    readonly property int historyLimit: 20 // messages sent as context

    property var messages: [] // [{ role: "user" | "assistant" | "error", text }]
    property string partial: ""
    property bool online: false
    property bool busy: false
    property list<string> models: []

    property var req: null // the in-flight chat request
    property int offset: 0 // how much of responseText is already parsed
    property bool gotError: false
    property bool checking: false

    function send(text: string): void {
        text = text.trim();
        if (!text)
            return;
        if (text.startsWith("/")) {
            command(text);
            return;
        }
        if (busy)
            return;

        messages = [...messages, { role: "user", text }];
        const history = messages.filter(m => m.role !== "error").slice(-historyLimit).map(m => ({ role: m.role, content: m.text }));

        const xhr = new XMLHttpRequest();
        req = xhr;
        offset = 0;
        partial = "";
        gotError = false;
        busy = true;

        xhr.onreadystatechange = () => {
            if (xhr !== root.req)
                return; // stopped
            // 3 = LOADING (a chunk arrived), 4 = DONE
            if (xhr.readyState >= 3) {
                watchdog.restart();
                root.pump(xhr.responseText, xhr.readyState === 4);
            }
            if (xhr.readyState === 4)
                root.done(xhr.status);
        };
        xhr.open("POST", `${Settings.ollamaUrl}/api/chat`);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify({
            model: Settings.ollamaModel,
            messages: history,
            stream: true
        }));
        watchdog.restart();
    }

    function stop(): void {
        if (!req)
            return;
        const xhr = req;
        req = null;
        watchdog.stop();
        xhr.abort();
        finish();
    }

    function command(text: string): void {
        const [cmd, ...args] = text.split(/\s+/);
        if (cmd === "/clear") {
            stop();
            messages = [];
        } else if (cmd === "/stop") {
            stop();
        } else if (cmd === "/model" && args[0]) {
            Settings.ollamaModel = args[0];
            note(`model -> ${args[0]}`);
        } else if (cmd === "/model" || cmd === "/models") {
            checkStatus();
            note(models.length ? `models: ${models.join(", ")}` : "no models (ollama pull llama3.2)");
        } else {
            note(`unknown command: ${cmd}`);
        }
    }

    function note(text: string): void {
        messages = [...messages, { role: "error", text }];
    }

    // parse every complete line received so far; on the last call also the unterminated tail
    function pump(text: string, final: bool): void {
        let nl;
        while ((nl = text.indexOf("\n", offset)) !== -1) {
            handleLine(text.slice(offset, nl));
            offset = nl + 1;
        }
        if (final && offset < text.length) {
            handleLine(text.slice(offset));
            offset = text.length;
        }
    }

    function handleLine(line: string): void {
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (msg.error) {
            gotError = true;
            note(`ollama: ${msg.error}`);
        } else if (msg.message?.content) {
            partial += msg.message.content;
        }
    }

    function done(status: int): void {
        req = null;
        watchdog.stop();
        finish();
        if (status === 0) {
            online = false;
            note("ollama is offline: sudo systemctl enable --now ollama");
        } else if (status >= 400 && !gotError) {
            note(`http ${status}, is the model pulled? ollama pull ${Settings.ollamaModel}`);
        }
    }

    function finish(): void {
        if (partial !== "")
            messages = [...messages, { role: "assistant", text: partial }];
        partial = "";
        busy = false;
    }

    function checkStatus(): void {
        if (checking)
            return;
        checking = true;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== 4)
                return;
            root.checking = false;
            try {
                root.models = JSON.parse(xhr.responseText).models.map(m => m.name);
                root.online = true;
            } catch (e) {
                root.models = [];
                root.online = false;
            }
        };
        xhr.open("GET", `${Settings.ollamaUrl}/api/tags`);
        xhr.send();
    }

    // a big model can take a while to load, but give up if nothing arrives for 2 minutes
    Timer {
        id: watchdog

        interval: 120000
        onTriggered: {
            root.stop();
            root.note("no response for 2 min, stopped");
        }
    }

    Timer {
        running: Panels.sidebarOpen
        repeat: true
        interval: 15000
        triggeredOnStart: true
        onTriggered: root.checkStatus()
    }
}
