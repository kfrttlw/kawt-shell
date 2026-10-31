pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.utils

// The ai panel's brain. Two providers:
//   ollama  a local model (localhost:11434 by default; nothing leaves the machine)
//   api     any OpenAI-compatible service (OpenAI, OpenRouter, Groq, LM Studio, ...)
// Both stream the answer into `partial`, which moves into the chat when done.
//
// How much ollama eats is set per request (Settings.ai*):
//   model size        the biggest lever: 1-3B models need ~1-2 GB, 7-8B ~5 GB
//   aiCtx (num_ctx)   context window; memory grows with it
//   aiThreads         cpu threads it may use (0 = ollama decides); fewer = the system stays smooth
//   aiGpuLayers       layers on the gpu (-1 = ollama decides, 0 = cpu only)
//   aiKeepAlive       how long the model stays loaded after an answer ("0" frees ram at once)
//
// Files: only from Settings.aiFolder, and only the ones you attach. The model never opens
// anything itself; kawt reads the file (text only, capped) and puts it into your message.
// The folder check is done with realpath, so ../ or a symlink can't reach outside it.
//
// Chats are kept in ~/.local/state/kawt/chats.json, the api key alone in
// ~/.local/state/kawt/secrets.json (readable only by you).
Singleton {
    id: root

    // ---- chat state
    readonly property var chats: chatStore.chats
    readonly property var chat: chats.find(c => c.id === chatStore.current) ?? null
    // [{ role: "user" | "assistant" | "error", text, time (ms), took (ms, answers), tps (answers, ollama) }]
    readonly property var messages: chat?.messages ?? []
    property string partial: ""
    // what the panel shows of `partial`: at most ten updates a second. Each update lays the
    // whole answer out again, so following every token (20-50 a second) was mostly wasted work
    property string partialShown: ""
    property string draft: "" // unsent text of the panel's input, kept while the panel is closed
    property bool busy: false
    property real sentAt: 0 // when the question went out, for "3.2s"
    property string askedModel: "" // the model of the answer being streamed
    property bool comparing: false // the second answer (Settings.aiCompare) is being streamed
    property bool looped: false
    property int checkedAt: 0 // partial length at the last loop check

    // personas: [key, label, system prompt]; "custom" uses Settings.aiSystem
    readonly property var personas: [
        ["short", "short", "Answer briefly and informatively. Get straight to the point, skip filler and repetition. Use a list or a code block only when it really helps. Answer in the language of the question."],
        ["teacher", "teacher", "You are a patient teacher. Explain step by step with simple words and a small example, then check understanding with one short question. Answer in the language of the question."],
        ["review", "code review", "You are a senior engineer reviewing code. Point out bugs first, then risky parts, then style, each with the line and a concrete fix. Be direct and short. Answer in the language of the question."],
        ["translate", "translator", "Translate the user's text. Russian goes to English, any other language goes to Russian. Output only the translation, keep the formatting."],
        ["custom", "custom", ""]
    ]
    property real tps: 0 // tokens per second of the last ollama answer

    // ---- ollama state
    property bool online: false
    property var models: [] // [{ name, size (bytes), params, quant }]
    property var loaded: [] // [{ name, ram (bytes), vram (bytes), until (ms) }]  from /api/ps
    property string pullStatus: ""
    property bool pulling: false

    readonly property bool useApi: Settings.aiProvider === "api"
    readonly property string modelName: useApi ? Settings.apiModel : Settings.ollamaModel
    readonly property string apiKey: secretStore.apiKey

    // ---- files
    readonly property int fileLimit: 20000 // characters per attached file
    property var files: [] // paths inside Settings.aiFolder, relative
    property var attachments: [] // [{ path (relative), text }] going with the next message
    // a picture going with the next message (a screenshot's [ask]): a copy in ~/.cache/kawt/ai,
    // sent to Settings.aiVisionModel (or the chat's model) as base64, read only when it goes.
    // The chats file keeps the path, not the picture
    property string image: ""
    property var imageData: ({}) // path -> base64 of pictures already read
    readonly property string imageDir: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/kawt/ai`
    readonly property string visionModel: useApi ? Settings.apiModel : Settings.aiVisionModel || Settings.ollamaModel
    property var attachQueue: []
    property string fileStatus: ""

    property var req: null // the in-flight chat request
    property int offset: 0 // how much of responseText is already parsed
    property bool gotError: false
    property bool checking: false

    // ------------------------------------------------------------------ chats

    function newChat(): void {
        stop();
        const id = Date.now();
        chatStore.chats = [{ id, title: "", updated: id, messages: [] }, ...chatStore.chats].slice(0, 100);
        chatStore.current = id;
    }

    function openChat(id: real): void {
        stop();
        chatStore.current = id;
    }

    function deleteChat(id: real): void {
        if (id === chatStore.current)
            stop();
        chatStore.chats = chatStore.chats.filter(c => c.id !== id);
        if (id === chatStore.current)
            chatStore.current = chatStore.chats[0]?.id ?? 0;
    }

    function clearChats(): void {
        stop();
        chatStore.chats = [];
        chatStore.current = 0;
    }

    function setMessages(list: var): void {
        if (!chat)
            newChat();
        // `content` (the attached files, the clipboard text of a quick action) can be big, and
        // it only matters while the message can still go back to the model: the last
        // Settings.aiHistory messages. Older ones keep just what the chat shows, so chats.json
        // doesn't grow by whole files and isn't rewritten with them on every message
        const keep = list.length - Settings.aiHistory;
        list = list.map((m, i) => {
            if (i >= keep || m.content === undefined)
                return m;
            const short = Object.assign({}, m);
            delete short.content;
            return short;
        });
        const title = chat.title || (list.find(m => m.role === "user")?.text ?? "").slice(0, 60);
        chatStore.chats = chatStore.chats.map(c => c.id === chatStore.current ? Object.assign({}, c, { messages: list, title, updated: Date.now() }) : c);
    }

    function note(text: string): void {
        setMessages([...messages, { role: "error", text, time: Date.now() }]);
    }

    // ------------------------------------------------------------------ sending

    function send(text: string): void {
        text = text.trim();
        // a picture and nothing typed: the plain question
        if (!text && image)
            text = "What's on this picture? Briefly.";
        if (!text)
            return;
        if (text.startsWith("/")) {
            command(text);
            return;
        }
        if (busy)
            return;
        if (useApi && (!Settings.apiUrl || !apiKey)) {
            setMessages([...messages, { role: "user", text, time: Date.now() }]);
            note("api: set the url, model and key in [models] first");
            return;
        }
        // attached files go in front of the question; the chat shows just their names
        const att = attachments;
        const content = att.length === 0 ? text : att.map(a => `File: ${a.path}\n\`\`\`\n${a.text}\n\`\`\``).join("\n\n") + `\n\n${text}`;
        attachments = [];
        const pic = image;
        image = "";
        const msg = { role: "user", text, time: Date.now(), files: att.map(a => a.path), content };
        if (pic) {
            msg.image = pic;
            msg.files = [...msg.files, pic.split("/").pop()];
        }
        setMessages([...messages, msg]);
        comparing = false;
        go();
    }

    // to the model: the one that sees while a picture is in what it gets, else the chat's
    function go(): void {
        const pic = recentImage();
        if (pic)
            readImage(pic);
        else
            ask(modelName);
    }

    // the messages the model gets (the newest Settings.aiHistory of them)
    function history_(): var {
        return messages.filter(m => m.role === "user" || (m.role === "assistant" && !m.alt)).slice(-Settings.aiHistory);
    }

    // the newest picture among them, or ""
    function recentImage(): string {
        const h = history_();
        for (let i = h.length - 1; i >= 0; i--)
            if (h[i].image)
                return h[i].image;
        return "";
    }

    // ---- pictures

    // a screenshot's [ask]: copied out of the shots' folder (those go after an hour), then the
    // panel opens with it waiting for your question
    function askAbout(path: string): void {
        if (!path)
            return;
        imageCopy.command = ["sh", "-c", 'mkdir -p "$2" && f="$2/$(date +%Y%m%d-%H%M%S)-${1##*/}" && cp -- "$1" "$f" && find "$2" -name "*.png" -mtime +7 -delete; printf %s "$f"', "sh", path, imageDir];
        imageCopy.running = true;
    }

    Job {
        id: imageCopy

        onDone: (code, out) => {
            if (code !== 0 || !out)
                return;
            root.image = out;
            Settings.aiMode = "chat";
            Panels.aiTab = 0;
            Panels.sidebarScreen = Panels.focusedScreen;
            Panels.sidebarOpen = true;
        }
    }

    // the picture as base64, then the question goes (to the model that sees)
    function readImage(path: string): void {
        if (imageData[path]) {
            ask(visionModel);
            return;
        }
        imageReader.path = path;
        imageReader.command = ["base64", "-w0", path];
        imageReader.running = true;
    }

    Job {
        id: imageReader

        property string path: ""

        onDone: (code, out) => {
            if (code !== 0 || !out) {
                root.note("the picture is gone (it was in ~/.cache/kawt/ai): asked without it");
                root.ask(root.modelName);
                return;
            } else {
                // only the newest few stay in memory
                const d = {};
                d[path] = out.trim();
                for (const k of Object.keys(root.imageData).slice(-2))
                    d[k] = root.imageData[k];
                root.imageData = d;
            }
            root.ask(root.visionModel);
        }
    }

    // ask again: drop the answers after the last question and send it once more
    function retry(): void {
        if (busy)
            return;
        const last = messages.map(m => m.role).lastIndexOf("user");
        if (last < 0)
            return;
        setMessages(messages.slice(0, last + 1));
        comparing = false;
        go();
    }

    // take the last question back into the input: returns its text, drops it and what followed
    function editLast(): string {
        if (busy)
            return "";
        const last = messages.map(m => m.role).lastIndexOf("user");
        if (last < 0)
            return "";
        const text = messages[last].text;
        setMessages(messages.slice(0, last));
        return text;
    }

    // the system prompt of the chosen persona ("custom" = your own text)
    function systemPrompt(): string {
        const p = personas.find(p => p[0] === Settings.aiPersona);
        return (p && p[0] !== "custom" ? p[2] : Settings.aiSystem).trim();
    }

    // send the conversation to `model` and stream its answer
    function ask(model: string): void {
        sentAt = Date.now();
        tps = 0;
        askedModel = model;
        const picked = history_();
        // the newest picture goes along (older ones only as their text: requests stay small)
        const withPic = picked.map(m => !!(m.image && imageData[m.image])).lastIndexOf(true);
        const history = picked.map((m, i) => {
            const h = { role: m.role, content: m.content ?? m.text };
            if (i === withPic) {
                const b64 = imageData[m.image];
                if (useApi)
                    h.content = [{ type: "text", text: h.content }, { type: "image_url", image_url: { url: `data:image/png;base64,${b64}` } }];
                else
                    h.images = [b64];
            }
            return h;
        });
        const system = systemPrompt() + (Settings.aiTodo ? todoContext() : "");
        if (system)
            history.unshift({ role: "system", content: system.trim() });

        // the context must hold the whole conversation, or ollama silently cuts its start and
        // small models lose the thread and start repeating. ~3.5 characters per token.
        const need = Math.ceil(history.reduce((n, m) => n + (typeof m.content === "string" ? m.content.length : 2000), 0) / 3.5) + 1024 + (withPic >= 0 ? 2048 : 0);
        let ctx = Settings.aiCtx;
        while (ctx < need && ctx < 16384)
            ctx *= 2;
        if (ctx > Settings.aiCtx && !useApi)
            note(`context raised to ${ctx / 1024}k for this message (it's long)`);

        const xhr = new XMLHttpRequest();
        req = xhr;
        offset = 0;
        partial = "";
        partialShown = "";
        gotError = false;
        looped = false;
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

        if (useApi) {
            xhr.open("POST", `${Settings.apiUrl.replace(/\/+$/, "")}/chat/completions`);
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.setRequestHeader("Authorization", `Bearer ${apiKey}`);
            xhr.send(JSON.stringify({
                model,
                messages: history,
                stream: true,
                temperature: Settings.aiTemperature
            }));
        } else {
            const options = {
                num_ctx: ctx,
                temperature: Settings.aiTemperature,
                num_predict: Settings.aiMaxAnswer, // never answer forever
                repeat_penalty: 1.15 // a push away from saying the same thing again
            };
            if (Settings.aiThreads > 0)
                options.num_thread = Settings.aiThreads;
            if (Settings.aiGpuLayers >= 0)
                options.num_gpu = Settings.aiGpuLayers;
            xhr.open("POST", `${Settings.ollamaUrl}/api/chat`);
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.send(JSON.stringify({
                model,
                messages: history,
                stream: true,
                keep_alive: keepAliveValue(),
                options
            }));
        }
        watchdog.restart();
    }

    // true if the answer ends with the same piece of text three times in a row:
    // a small model stuck in a loop
    function isLooping(t: string): bool {
        if (t.length < 120)
            return false;
        for (let p = 12; p <= 200 && p * 3 <= t.length; p++) {
            const a = t.slice(-p);
            // a line of ===== or spaces repeats too, but that's drawing, not a loop
            if (/^(.)\1*$/.test(a.replace(/\s/g, "")) || !a.trim())
                continue;
            if (t.slice(-2 * p, -p) === a && t.slice(-3 * p, -2 * p) === a)
                return true;
        }
        return false;
    }

    // "-1" stays forever, "0" unloads right after the answer; ollama wants numbers for those
    function keepAliveValue(): var {
        const k = Settings.aiKeepAlive;
        return /^-?\d+$/.test(k) ? parseInt(k) : k;
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
        if (cmd === "/clear" || cmd === "/new") {
            newChat();
        } else if (cmd === "/stop") {
            stop();
        } else if (cmd === "/model" && args[0]) {
            if (useApi)
                Settings.apiModel = args[0];
            else
                Settings.ollamaModel = args[0];
            note(`model -> ${args[0]}`);
        } else if (cmd === "/model" || cmd === "/models") {
            refresh();
            note(models.length ? `models: ${models.map(m => m.name).join(", ")}` : "no models (ollama pull llama3.2)");
        } else {
            note(`unknown command: ${cmd}`);
        }
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

    // ollama: one JSON object per line · api: server-sent events, "data: {...}" / "data: [DONE]"
    function handleLine(line: string): void {
        line = line.trim();
        if (!line)
            return;
        if (useApi) {
            if (!line.startsWith("data:")) {
                // a plain JSON error body (bad key, unknown model...)
                try {
                    const e = JSON.parse(line);
                    if (e.error) {
                        gotError = true;
                        note(`api: ${e.error.message ?? JSON.stringify(e.error)}`);
                    }
                } catch (err) {}
                return;
            }
            const data = line.slice(5).trim();
            if (data === "[DONE]")
                return;
            try {
                const msg = JSON.parse(data);
                if (msg.error) {
                    gotError = true;
                    note(`api: ${msg.error.message ?? JSON.stringify(msg.error)}`);
                } else {
                    const choice = msg.choices && msg.choices[0];
                    partial += (choice && choice.delta && choice.delta.content) || "";
                    guardLoop();
                }
            } catch (err) {}
            return;
        }
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (msg.error) {
            gotError = true;
            note(`ollama: ${msg.error}`);
        } else {
            if (msg.message?.content) {
                partial += msg.message.content;
                guardLoop();
            }
            // the last line carries the timing: eval_count tokens in eval_duration ns
            if (msg.done && msg.eval_count && msg.eval_duration)
                tps = msg.eval_count / (msg.eval_duration / 1e9);
        }
    }

    function done(status: int): void {
        req = null;
        watchdog.stop();
        const wasMain = !comparing;
        const wasLooping = looped;
        finish();
        if (status >= 200 && status < 300 && !gotError && !wasLooping)
            maybeCompare(wasMain);
        if (status === 0) {
            if (useApi) {
                note(`can't reach ${Settings.apiUrl}`);
            } else {
                online = false;
                note("ollama is offline: sudo systemctl enable --now ollama");
            }
        } else if (status >= 400 && !gotError) {
            note(useApi ? `api: http ${status} (check the key and the model name)` : `http ${status}, is the model pulled? ollama pull ${Settings.ollamaModel}`);
        }
        if (!useApi)
            psTimer.restart(); // the model just (re)loaded: show its memory soon
    }

    // checked every ~100 new characters: stop a model that keeps repeating itself
    function guardLoop(): void {
        if (partial.length - checkedAt < 100)
            return;
        checkedAt = partial.length;
        if (isLooping(partial)) {
            looped = true;
            stop();
        }
    }

    function finish(): void {
        const second = comparing;
        if (partial !== "")
            setMessages([...messages, { role: "assistant", text: partial, time: Date.now(), took: Date.now() - sentAt, tps: Math.round(tps), model: askedModel, alt: second }]);
        partial = "";
        partialShown = "";
        checkedAt = 0;
        busy = false;
        if (looped) {
            looped = false;
            note("stopped: the model started repeating itself. try [retry], a bigger context, or a bigger model");
            return;
        }
        comparing = false;
    }

    // compare mode: once the first model answered fine, the same question goes to the second
    function maybeCompare(firstWasMain: bool): void {
        if (firstWasMain && Settings.aiCompare && !useApi && Settings.aiCompareModel && Settings.aiCompareModel !== Settings.ollamaModel) {
            comparing = true;
            ask(Settings.aiCompareModel);
        }
    }

    // ------------------------------------------------------------------ quick actions

    // one click on what's in the clipboard: [explain] [translate] [fix] [summary]
    readonly property var actions: [
        ["explain", "Explain this clearly and briefly:"],
        ["translate", "Translate this (Russian to English, anything else to Russian). Output only the translation:"],
        ["fix", "Fix the mistakes in this (spelling, grammar, or bugs if it's code). Show the corrected version, then list what changed:"],
        ["summary", "Summarize this in a few short points:"]
    ]

    function quick(name: string): void {
        if (busy || clipReader.running)
            return;
        clipAction = name;
        clipReader.running = true;
    }

    property string clipAction: ""

    // Job: waits until the clipboard is read to the end (a plain onExited could see half of it)
    Job {
        id: clipReader

        command: ["wl-paste", "--no-newline", "--type", "text"]
        onDone: (code, out) => {
            const t = out.trim();
            const a = root.actions.find(a => a[0] === root.clipAction);
            if (code !== 0 || !t) {
                root.note("the clipboard is empty (copy some text first)");
                return;
            }
            // shown short in the chat, sent in full
            root.setMessages([...root.messages, { role: "user", text: `[${a[0]}] ${t.length > 200 ? t.slice(0, 200) + "…" : t}`, time: Date.now(), content: `${a[1]}\n\n${t}` }]);
            root.comparing = false;
            root.ask(root.modelName);
        }
    }

    // ------------------------------------------------------------------ your tasks

    // [x] tasks in the chat (Settings.aiTodo): the todo list goes along with every question, so
    // "what's on tomorrow?" can be answered. Only the open ones, only to the model you use (a
    // local one stays on the machine). Tasks it proposes come back as "+ task: ..." lines, and
    // the answer gets an [add] for them (modules/sidebar/ChatLine.qml)
    function todoContext(): string {
        const now = new Date(Time.ms());
        const open = Todo.sorted.filter(t => !t.done).slice(0, 80);
        const lines = open.map(t => `- ${t.text}${t.due ? ` (due ${Qt.formatDateTime(new Date(t.due), "ddd dd.MM HH:mm")})` : ""}${t.folder && t.folder !== "inbox" ? ` [${t.folder}]` : ""}${t.prio ? " " + "!".repeat(t.prio) : ""}`);
        return `\n\nIt is now ${Qt.formatDateTime(now, "dddd dd.MM.yyyy HH:mm")}. The user's open tasks (their todo list):\n${lines.join("\n") || "(none)"}\nWhen the user wants tasks added, write each one on its own line exactly as: + task: DD.MM HH:MM text (the date and time only if it has one).`;
    }

    // "+ task: 05.10 14:00 buy milk" lines of an answer -> "05.10 14:00 buy milk"
    function tasksIn(text: string): var {
        return text.split("\n").map(l => l.match(/^\s*[-*]?\s*\+\s*task:\s*(.+)$/i)).filter(m => m).map(m => m[1].replace(/[*`]/g, "").trim()).filter(t => t);
    }

    // ------------------------------------------------------------------ one question, one answer

    // not into the chat: the launcher's $ (a command) and the selection's actions. The whole
    // answer at once; cb(text, error). Returns the request (abort() stops it)
    function oneShot(system: string, prompt: string, maxTokens: int, cb: var): var {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== 4)
                return;
            let data = null;
            try {
                data = JSON.parse(xhr.responseText);
            } catch (e) {}
            if (xhr.status === 0) {
                cb("", useApi ? `can't reach ${Settings.apiUrl}` : "ollama is offline: sudo systemctl enable --now ollama");
                return;
            }
            const err = data && data.error;
            if (xhr.status >= 400 || !data) {
                cb("", `model error: ${(err && err.message) || err || `http ${xhr.status}`}`);
                return;
            }
            const msg = useApi ? data.choices && data.choices[0] && data.choices[0].message : data.message;
            const text = ((msg && msg.content) || "").trim();
            cb(text, text ? "" : "the model said nothing");
        };
        const messages = [{ role: "system", content: system }, { role: "user", content: prompt }];
        if (useApi) {
            if (!Settings.apiUrl || !apiKey) {
                cb("", "api: set the url, model and key in the ai panel's [models] first");
                return xhr;
            }
            xhr.open("POST", `${Settings.apiUrl.replace(/\/+$/, "")}/chat/completions`);
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.setRequestHeader("Authorization", `Bearer ${apiKey}`);
            xhr.send(JSON.stringify({ model: Settings.apiModel, messages, temperature: 0.2, max_tokens: maxTokens }));
        } else {
            const options = { num_ctx: Math.max(Settings.aiCtx, Math.ceil(prompt.length / 3.5) + maxTokens + 512), temperature: 0.2, num_predict: maxTokens };
            if (Settings.aiThreads > 0)
                options.num_thread = Settings.aiThreads;
            if (Settings.aiGpuLayers >= 0)
                options.num_gpu = Settings.aiGpuLayers;
            xhr.open("POST", `${Settings.ollamaUrl}/api/chat`);
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.send(JSON.stringify({ model: Settings.ollamaModel, messages, stream: false, keep_alive: keepAliveValue(), options }));
        }
        return xhr;
    }

    // ---- the launcher's $: what you want -> one shell command, never run by itself
    property string cmdFor: "" // the request the answer below is for
    property string cmdText: ""
    property string cmdAbout: ""
    property string cmdError: ""
    property var cmdReq: null
    readonly property bool cmdBusy: cmdReq !== null

    function suggestCommand(what: string): void {
        what = what.trim();
        if (!what)
            return;
        if (cmdReq)
            cmdReq.abort();
        cmdFor = what;
        cmdText = "";
        cmdAbout = "";
        cmdError = "";
        const system = "You turn a request into ONE shell command for Arch Linux (bash or zsh, GNU tools, pacman, systemd, Hyprland). Reply with exactly two lines: the command on the first line (no $ in front, no backticks, no markdown), then one short line saying what it does, in the language of the request. Prefer safe, read-only commands; never add sudo unless the task really needs root.";
        const req = oneShot(system, what, 160, (text, error) => {
            if (root.cmdReq !== req)
                return;
            root.cmdReq = null;
            if (error) {
                root.cmdError = error;
                return;
            }
            const lines = text.replace(/```\w*/g, "").split("\n").map(l => l.trim()).filter(l => l);
            root.cmdText = (lines[0] ?? "").replace(/^\$\s+/, "").replace(/^`+|`+$/g, "");
            root.cmdAbout = lines.slice(1).join(" ").replace(/^[#>*-]+\s*/, "");
            if (!root.cmdText)
                root.cmdError = "no command came back";
        });
        cmdReq = req;
    }

    // what makes a command worth a second look
    function risks(c: string): var {
        const rules = [
            [/\brm\s/, "deletes files"],
            [/\b(sudo|doas|pkexec|su)\b/, "runs as root"],
            [/\b(dd|mkfs[\w.]*|wipefs|fdisk|parted|sgdisk|shred)\b/, "writes to disks"],
            [/>\s*\/dev\/(sd|nvme|mmcblk|vd|hd)/, "writes to a disk"],
            [/\b(chmod|chown)\s+(-\w+\s+)*-R|\b(chmod|chown)\s+-\w*R/, "changes many files"],
            [/\b(curl|wget)\b[^|]*\|\s*(sudo\s+)?(ba|z|da)?sh\b/, "runs a script from the internet"],
            [/:\(\)\s*\{/, "floods the machine with copies of itself"],
            [/\b(shutdown|reboot|poweroff|halt)\b|systemctl\s+(poweroff|reboot|halt)/, "turns the machine off"],
            [/\bkill(all)?\s+-(9|KILL)\b|\bpkill\b/, "kills processes"],
            [/\bgit\s+(push\s+.*(-f\b|--force)|reset\s+--hard|clean\s+-\w*f)/, "throws work away"],
            [/\bpacman\s+-R|\bpacman\s+-S\w*\s/, "changes packages"],
            [/(^|[^>&0-9])>\s*[~\/.\w]/, "overwrites a file"]
        ];
        return rules.filter(r => r[0].test(c)).map(r => r[1]);
    }

    // ---- the selection (super + alt + a): the text you marked, without copying it
    readonly property var selActions: [
        ["explain", "Explain this clearly and briefly:", false],
        ["translate", "Translate this (Russian to English, anything else to Russian). Output only the translation, nothing else:", true],
        ["fix", "Fix the mistakes in this (spelling, grammar, or bugs if it's code). Output only the corrected text, nothing else:", true],
        ["summary", "Summarize this in a few short points:", false]
    ]
    property string selText: ""
    property bool selFromClipboard: false // nothing was selected: the clipboard instead
    property string selAction: ""
    property string selAnswer: ""
    property string selError: ""
    property real selTook: 0
    property var selReq: null
    readonly property bool selBusy: selReq !== null || selReader.running
    property bool canType: false // wtype: [replace] types the answer over the selection

    // read what's selected: the "primary" selection, what middle click would paste
    function selRead(): void {
        selText = "";
        selAnswer = "";
        selError = "";
        selAction = "";
        selReader.command = ["sh", "-c", 'command -v wtype > /dev/null && echo wtype; echo ---; t=$(wl-paste --primary --no-newline 2> /dev/null); if [ -n "$t" ]; then printf "primary\n%s" "$t"; else printf "clipboard\n%s" "$(wl-paste --no-newline --type text 2> /dev/null)"; fi'];
        selReader.running = true;
    }

    Job {
        id: selReader

        onDone: (code, out) => {
            const cut = out.indexOf("---\n");
            root.canType = out.slice(0, Math.max(0, cut)).includes("wtype");
            const rest = cut >= 0 ? out.slice(cut + 4) : out;
            const nl = rest.indexOf("\n");
            root.selFromClipboard = rest.slice(0, nl) === "clipboard";
            root.selText = nl >= 0 ? rest.slice(nl + 1).slice(0, 20000) : "";
            if (!root.selText.trim())
                root.selError = "nothing selected (and the clipboard is empty): mark some text first";
        }
    }

    function selDo(name: string): void {
        const a = selActions.find(x => x[0] === name);
        if (!a || !selText.trim())
            return;
        if (selReq)
            selReq.abort();
        selAction = name;
        selAnswer = "";
        selError = "";
        const started = Date.now();
        const req = oneShot(systemPrompt() || "Answer briefly.", `${a[1]}\n\n${selText}`, Math.max(512, Settings.aiMaxAnswer), (text, error) => {
            if (root.selReq !== req)
                return;
            root.selReq = null;
            root.selTook = Date.now() - started;
            root.selAnswer = text;
            root.selError = error;
        });
        selReq = req;
    }

    function selStop(): void {
        if (selReq) {
            const r = selReq;
            selReq = null;
            r.abort();
        }
    }

    // over the selection, in the window it's in: the popup closes first, then wtype types it
    function selReplace(): void {
        if (!selAnswer || !canType)
            return;
        Panels.close();
        Quickshell.execDetached(["sh", "-c", 'sleep 0.25; wtype -- "$1"', "sh", selAnswer]);
    }

    // on into the chat, to go on about it there
    function selToChat(): void {
        const a = selActions.find(x => x[0] === selAction);
        if (!selText)
            return;
        const msgs = [...messages, { role: "user", text: `[${selAction || "selection"}] ${selText.length > 200 ? selText.slice(0, 200) + "…" : selText}`, time: Date.now(), content: a ? `${a[1]}\n\n${selText}` : selText }];
        if (selAnswer)
            msgs.push({ role: "assistant", text: selAnswer, time: Date.now(), took: selTook, model: modelName });
        setMessages(msgs);
        Panels.close();
        Settings.aiMode = "chat";
        Panels.aiTab = 0;
        Panels.sidebarScreen = Panels.focusedScreen;
        Panels.sidebarOpen = true;
    }

    // an answer into the notes tab, folder "ai"
    function saveNote(text: string): void {
        Notes.addFolder("ai");
        const id = Notes.create("ai");
        Notes.update(id, { body: text });
    }

    // ------------------------------------------------------------------ files

    // the folder's files (3 levels deep, text-sized, no .git / node_modules)
    function refreshFiles(): void {
        if (!Settings.aiFolder) {
            files = [];
            return;
        }
        lister.command = ["sh", "-c", 'cd -- "$1" 2>/dev/null || exit 4; find . -maxdepth 3 -type f -size -1024k -not -path "*/.git/*" -not -path "*/node_modules/*" 2>/dev/null | sed "s|^\\./||" | sort | head -n 400', "sh", Settings.expand(Settings.aiFolder)];
        lister.running = true;
    }

    function attached(path: string): bool {
        return attachments.some(a => a.path === path);
    }

    function attach(path: string): void {
        if (attached(path))
            return;
        attachQueue = [...attachQueue, path];
        nextAttach();
    }

    function detach(path: string): void {
        attachments = attachments.filter(a => a.path !== path);
    }

    function nextAttach(): void {
        if (reader.running || !reader.reported || attachQueue.length === 0)
            return;
        reader.path = attachQueue[0];
        attachQueue = attachQueue.slice(1);
        // exit 3: outside the folder · 5: not a file · 6: not text
        reader.command = ["sh", "-c", `dir=$(realpath -e -- "$2") || exit 4
real=$(realpath -e -- "$2/$1") || exit 5
case "$real" in "$dir"/*) ;; *) exit 3 ;; esac
[ -f "$real" ] || exit 5
[ -s "$real" ] && ! grep -Iq . -- "$real" && exit 6
head -c ${fileLimit} -- "$real"`, "sh", reader.path, Settings.expand(Settings.aiFolder)];
        reader.running = true;
    }

    Process {
        id: lister

        stdout: StdioCollector {
            onStreamFinished: root.files = text.split("\n").filter(l => l)
        }
        onExited: code => root.fileStatus = code === 4 ? "can't open that folder" : ""
    }

    Job {
        id: reader

        property string path: ""

        onDone: (code, out) => {
            if (code === 0) {
                root.attachments = [...root.attachments, { path: reader.path, text: out }];
                root.fileStatus = out.length >= root.fileLimit ? `${reader.path}: only the first ${root.fileLimit / 1000}k characters` : "";
            } else {
                root.fileStatus = `${reader.path}: ${({ 3: "outside the folder, not allowed", 6: "not a text file" })[code] ?? "can't read it"}`;
            }
            root.nextAttach();
        }
    }

    // ------------------------------------------------------------------ ollama models

    function refresh(): void {
        if (checking)
            return;
        checking = true;
        get("/api/tags", (ok, data) => {
            root.checking = false;
            root.online = ok;
            root.models = ok ? (data.models ?? []).map(m => ({
                name: m.name,
                size: m.size ?? 0,
                params: m.details?.parameter_size ?? "",
                quant: m.details?.quantization_level ?? ""
            })).sort((a, b) => a.size - b.size) : [];
        });
        refreshLoaded();
    }

    // which models sit in memory right now, and how much
    function refreshLoaded(): void {
        get("/api/ps", (ok, data) => {
            root.loaded = ok ? (data.models ?? []).map(m => ({
                name: m.name,
                ram: m.size ?? 0,
                vram: m.size_vram ?? 0,
                until: m.expires_at ? Date.parse(m.expires_at) : 0
            })) : [];
        });
    }

    // free the memory now instead of waiting for keep-alive
    function unload(name: string): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState === 4)
                root.refreshLoaded();
        };
        xhr.open("POST", `${Settings.ollamaUrl}/api/generate`);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify({ model: name, keep_alive: 0 }));
    }

    // download a model, with progress in pullStatus
    function pull(name: string): void {
        name = name.trim();
        if (!name || pulling)
            return;
        pulling = true;
        pullStatus = `${name}: starting...`;
        const xhr = new XMLHttpRequest();
        let seen = 0;
        xhr.onreadystatechange = () => {
            if (xhr.readyState < 3)
                return;
            const text = xhr.responseText;
            let nl;
            while ((nl = text.indexOf("\n", seen)) !== -1) {
                const line = text.slice(seen, nl);
                seen = nl + 1;
                try {
                    const m = JSON.parse(line);
                    if (m.error)
                        root.pullStatus = `${name}: ${m.error}`;
                    else if (m.total && m.completed)
                        root.pullStatus = `${name}: ${m.status} ${Math.round(m.completed / m.total * 100)}% of ${root.size(m.total)}`;
                    else if (m.status)
                        root.pullStatus = `${name}: ${m.status}`;
                } catch (e) {}
            }
            if (xhr.readyState === 4) {
                root.pulling = false;
                if (xhr.status === 0)
                    root.pullStatus = "ollama is offline";
                else if (root.pullStatus.endsWith("success"))
                    root.pullStatus = `${name}: done`;
                root.refresh();
            }
        };
        xhr.open("POST", `${Settings.ollamaUrl}/api/pull`);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify({ model: name, stream: true }));
    }

    // Qt's XMLHttpRequest can't send a body with DELETE, so this goes through the ollama cli
    function remove(name: string): void {
        removeProc.command = ["ollama", "rm", name];
        removeProc.running = true;
    }

    // "2.0G" / "640M"
    function size(bytes: real): string {
        return bytes >= 1e9 ? `${(bytes / 1073741824).toFixed(1)}G` : `${Math.round(bytes / 1048576)}M`;
    }

    function get(path: string, cb: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== 4)
                return;
            try {
                cb(xhr.status === 200, JSON.parse(xhr.responseText));
            } catch (e) {
                cb(false, null);
            }
        };
        xhr.open("GET", `${Settings.ollamaUrl}${path}`);
        xhr.send();
    }

    // kept for older callers
    function checkStatus(): void {
        refresh();
    }

    // ------------------------------------------------------------------ api key

    function setApiKey(key: string): void {
        key = key.trim();
        secretStore.apiKey = key; // used at once; the file follows
        saveKey.input = JSON.stringify({ apiKey: key }, null, 4);
        saveKey.stdinEnabled = true;
        saveKey.running = true;
    }

    // The only writer of secrets.json. Created private (umask 077) as a temp file and renamed
    // into place, so the key is never readable by others, not even for a moment (writing it
    // first and chmod-ing after left a gap). The key goes in on stdin: arguments of a process
    // can be read by anyone in /proc.
    Process {
        id: saveKey

        property string input: ""

        command: ["sh", "-c", 'umask 077 && mkdir -p "$1" && cat > "$1/secrets.json.tmp" && mv -f "$1/secrets.json.tmp" "$1/secrets.json"', "sh", Settings.dir]
        onStarted: {
            write(input);
            input = "";
            stdinEnabled = false;
        }
    }

    // a key file saved by an older kawt may still be readable by others
    Process {
        id: fixPerms

        command: ["chmod", "600", `${Settings.dir}/secrets.json`]
    }

    Process {
        id: removeProc

        onExited: root.refresh()
    }

    Timer {
        running: root.busy
        repeat: true
        interval: 100
        onTriggered: if (root.partialShown !== root.partial)
            root.partialShown = root.partial
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
        onTriggered: root.refresh()
    }

    Timer {
        id: psTimer

        interval: 1500
        onTriggered: root.refreshLoaded()
    }

    FileView {
        path: `${Settings.dir}/chats.json`
        printErrors: false // missing on first run
        blockWrites: true // at once: in the background a quick second change was undone (config/Settings.qml)
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: chatStore

            property var chats: [] // [{ id, title, updated, messages: [{ role, text }] }] newest first
            property real current: 0
        }
    }

    // read only: saving goes through saveKey above, never through the adapter
    FileView {
        path: `${Settings.dir}/secrets.json`
        printErrors: false // missing until a key is saved
        watchChanges: true
        onFileChanged: reload()
        onLoaded: fixPerms.running = true

        JsonAdapter {
            id: secretStore

            property string apiKey: ""
        }
    }
}
