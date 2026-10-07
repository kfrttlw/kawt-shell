pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The coder agent: the same model as the ai panel, working inside one project folder
// (Settings.aiFolder) through four tools, in a loop:
//   model thinks -> asks for a tool -> kawt runs it -> the result goes back -> ... -> summary
//
//   list    files of a folder                    runs at once
//   search  lines containing a text              runs at once
//   read    numbered lines of a file             runs at once
//   edit    replace a piece of a file / new file waits for [apply] or [skip], shown as a diff
//
// Every path goes through scripts/coder-tool.sh, which refuses anything outside the folder.
// [undo] puts back every file the agent changed during the session.
Singleton {
    id: root

    readonly property string tool: `${Quickshell.shellDir}/scripts/coder-tool.sh`
    readonly property string folder: Settings.expand(Settings.aiFolder)
    readonly property int maxSteps: Settings.aiCoderSteps // 0 = no limit

    property bool running: false
    property bool thinking: false // waiting for the model
    property string action: "" // what's happening now, for the ascii art: "read src/app.qml"
    // what the panel shows: [{ id, kind: task|think|tool|answer|error|info, name, arg, text, status, diff, time }]
    property var steps: []
    property var convo: [] // the conversation in the provider's own format
    property var queue: [] // tool calls of the current reply still to run
    property int stepCount: 0
    property var pending: null // the edit waiting for [apply]: { stepId, path, content, original }
    property var touched: ({}) // path -> original content (null: the agent created it), for [undo]
    property var req: null
    property var jobs: [] // shell jobs, one at a time: [{ args, done(code, out) }]

    readonly property bool canUndo: Object.keys(touched).length > 0 && !running

    readonly property var toolSpecs: [
        {
            name: "list",
            description: "List files and folders (2 levels deep) under a path of the project. Folders end with /.",
            parameters: { type: "object", properties: { path: { type: "string", description: "folder, relative to the project; . for the root" } }, required: ["path"] }
        },
        {
            name: "search",
            description: "Find lines that contain a text (plain text, not a regex) in the project's files. Returns file:line:content.",
            parameters: { type: "object", properties: { text: { type: "string" }, path: { type: "string", description: "folder or file to search in; . for everything" } }, required: ["text"] }
        },
        {
            name: "read",
            description: "Read a text file with line numbers ('  12| code'). Use from/to for long files.",
            parameters: { type: "object", properties: { path: { type: "string" }, from: { type: "integer" }, to: { type: "integer" } }, required: ["path"] }
        },
        {
            name: "edit",
            description: "Change a file: replace the exact text `old` with `new`. Copy `old` from the file without the line numbers and the '| ', a few lines, unique in the file. To create a new file, give an empty `old` and the whole file as `new`. The user sees a diff and approves or rejects it.",
            parameters: { type: "object", properties: { path: { type: "string" }, old: { type: "string" }, new: { type: "string" } }, required: ["path", "old", "new"] }
        }
    ]

    function system(): string {
        return `You are a careful coding agent. You work inside one project folder (${folder.split("/").pop()}), chosen by the user; nothing outside it exists for you.
Use the tools: list to see the structure, search to find where something is, read a file before changing it, edit to change it.
Rules:
- Never guess what a file contains: read it first.
- In edit, copy \`old\` exactly from the file, without the line numbers and the "| " that read adds. Keep it to a few lines that appear only once.
- Make small, focused edits, one at a time. The user approves every edit; if one is rejected, don't repeat it.
- When the task is done, or can't be done, stop calling tools and answer with a short summary of what you changed (file and what).
Answer in the language of the user's task.`;
    }

    // ------------------------------------------------------------------ the loop

    function start(task: string): void {
        task = task.trim();
        if (!task || running)
            return;
        if (!Settings.aiFolder) {
            addStep({ kind: "error", text: "pick a project folder first: open the panel wide [<>] and set dir>" });
            return;
        }
        if (convo.length === 0)
            convo = [{ role: "system", content: system() }];
        convo = [...convo, { role: "user", content: task }];
        addStep({ kind: "task", text: task });
        stepCount = 0;
        running = true;
        callModel();
    }

    function callModel(): void {
        if (!running)
            return;
        if (maxSteps > 0 && stepCount >= maxSteps) {
            addStep({ kind: "info", text: `stopped after ${maxSteps} steps. say "go on" to continue` });
            finish();
            return;
        }
        stepCount++;
        thinking = true;
        action = "thinking";

        // the context has to hold the whole conversation (files read so far included)
        const need = Math.ceil(convo.reduce((n, m) => n + (m.content || "").length + JSON.stringify(m.tool_calls || "").length, 0) / 3.5) + 2048;
        let ctx = Math.max(Settings.aiCtx, 8192);
        while (ctx < need && ctx < 32768)
            ctx *= 2;

        const xhr = new XMLHttpRequest();
        req = xhr;
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== 4 || xhr !== root.req)
                return;
            root.req = null;
            root.thinking = false;
            let data = null;
            try {
                data = JSON.parse(xhr.responseText);
            } catch (e) {}
            if (xhr.status === 0) {
                root.fail(Ai.useApi ? `can't reach ${Settings.apiUrl}` : "ollama is offline: sudo systemctl enable --now ollama");
            } else if (xhr.status >= 400 || !data) {
                const err = data && data.error;
                const msg = (err && err.message) || err || `http ${xhr.status}`;
                root.fail(String(msg).includes("does not support tools") ? `${Ai.modelName} can't use tools. pick qwen2.5 / qwen2.5-coder / llama3.1+ in [models]` : `model error: ${msg}`);
            } else {
                root.handleReply(Ai.useApi ? (data.choices && data.choices[0] && data.choices[0].message) : data.message);
            }
        };

        if (Ai.useApi) {
            xhr.open("POST", `${Settings.apiUrl.replace(/\/+$/, "")}/chat/completions`);
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.setRequestHeader("Authorization", `Bearer ${Ai.apiKey}`);
            xhr.send(JSON.stringify({
                model: Settings.apiModel,
                messages: convo,
                tools: toolSpecs.map(t => ({ type: "function", function: t })),
                temperature: 0.2
            }));
        } else {
            const options = { num_ctx: ctx, temperature: 0.2, num_predict: Math.max(Settings.aiMaxAnswer, 2048) };
            if (Settings.aiThreads > 0)
                options.num_thread = Settings.aiThreads;
            if (Settings.aiGpuLayers >= 0)
                options.num_gpu = Settings.aiGpuLayers;
            xhr.open("POST", `${Settings.ollamaUrl}/api/chat`);
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.send(JSON.stringify({
                model: Settings.ollamaModel,
                messages: convo,
                tools: toolSpecs.map(t => ({ type: "function", function: t })),
                stream: false,
                keep_alive: Ai.keepAliveValue(),
                options
            }));
        }
    }

    // Small local models often can't do real tool calling and write the call as text instead:
    //   {"name": "list", "arguments": {"path": "."}}   or inside ```json / <tool_call>
    // Pick those up, so the agent still acts instead of printing JSON. Only names of our own
    // tools count; any other JSON in an answer stays text.
    function textCalls(text: string, known: var): var {
        const calls = [];
        let rest = text;
        // every top-level {...} block in the text (strings with braces inside are respected)
        const blocks = [];
        let depth = 0, start = -1, inStr = false, esc = false;
        for (let i = 0; i < text.length; i++) {
            const ch = text[i];
            if (inStr) {
                if (esc) esc = false;
                else if (ch === "\\") esc = true;
                else if (ch === '"') inStr = false;
                continue;
            }
            if (ch === '"') inStr = true;
            else if (ch === "{") {
                if (depth === 0) start = i;
                depth++;
            } else if (ch === "}" && depth > 0) {
                depth--;
                if (depth === 0) blocks.push([start, i + 1]);
            }
        }
        for (const [a, b] of blocks) {
            let obj;
            try {
                obj = JSON.parse(text.slice(a, b));
            } catch (e) {
                continue;
            }
            const list = Array.isArray(obj) ? obj : [obj];
            let took = false;
            for (const o of list) {
                const f = o.function || o;
                const name = f.name || o.tool || o.tool_name;
                let args = f.arguments ?? f.parameters ?? f.args ?? f.input ?? {};
                if (typeof args === "string") {
                    try { args = JSON.parse(args); } catch (e) { args = {}; }
                }
                if (name && known.includes(name)) {
                    calls.push({ id: "", name, args });
                    took = true;
                }
            }
            if (took) rest = rest.replace(text.slice(a, b), "");
        }
        rest = rest.replace(/```(?:json)?/g, "").replace(/<\/?tool_call>/g, "").trim();
        return { calls, rest };
    }

    // the model answered: its thoughts, maybe some tool calls
    function handleReply(msg: var): void {
        if (!msg) {
            fail("empty answer from the model");
            return;
        }
        let text = (msg.content || "").trim();
        let calls = (msg.tool_calls || []).map(c => {
            let args = (c.function && c.function.arguments) || {};
            if (typeof args === "string") {
                try {
                    args = JSON.parse(args);
                } catch (e) {
                    args = {};
                }
            }
            return { id: c.id || "", name: (c.function && c.function.name) || "?", args };
        });
        let rawCalls = msg.tool_calls;
        if (calls.length === 0 && text) {
            const found = textCalls(text, toolSpecs.map(t => t.name));
            if (found.calls.length > 0) {
                calls = found.calls.map((c, i) => Object.assign({}, c, { id: `kawt_${Date.now()}_${i}` }));
                text = found.rest;
                // tell the provider about them the proper way, so the tool results line up
                rawCalls = calls.map(c => Ai.useApi
                    ? { id: c.id, type: "function", function: { name: c.name, arguments: JSON.stringify(c.args) } }
                    : { function: { name: c.name, arguments: c.args } });
            }
        }
        // the assistant turn goes back with its tool calls
        const turn = { role: "assistant", content: calls.length > 0 ? text : (msg.content || "") };
        if (calls.length > 0)
            turn.tool_calls = rawCalls;
        convo = [...convo, turn];
        if (calls.length === 0) {
            addStep({ kind: "answer", text: text || "(no answer)" });
            finish();
            return;
        }
        if (text)
            addStep({ kind: "think", text });
        queue = calls;
        nextCall();
    }

    function nextCall(): void {
        if (!running)
            return;
        if (queue.length === 0) {
            callModel();
            return;
        }
        const call = queue[0];
        queue = queue.slice(1);
        runTool(call);
    }

    // a tool's result goes back to the model
    function reply(call: var, result: string): void {
        // keep huge outputs from eating the whole context
        const r = result.length > 24000 ? result.slice(0, 24000) + "\n... (cut)" : result;
        convo = [...convo, Ai.useApi ? { role: "tool", tool_call_id: call.id, content: r } : { role: "tool", tool_name: call.name, content: r }];
        nextCall();
    }

    function runTool(call: var): void {
        const a = call.args;
        const label = { list: a.path || ".", search: `"${a.text ?? ""}"`, read: a.path ?? "", edit: a.path ?? "" }[call.name] ?? "";
        const id = addStep({ kind: "tool", name: call.name, arg: label, status: "running" });
        action = `${call.name} ${label}`;

        if (call.name === "list") {
            shell(["list", a.path || "."], (code, out) => done(call, id, code, out, out ? `${out.split("\n").length} entries` : "empty"));
        } else if (call.name === "search") {
            shell(["search", a.text ?? "", a.path || "."], (code, out) => done(call, id, code, out || "no matches", out ? `${out.split("\n").length} lines` : "no matches"));
        } else if (call.name === "read") {
            const args = ["read", a.path ?? ""];
            if (a.from)
                args.push(String(a.from), String(a.to || a.from + 299));
            shell(args, (code, out) => done(call, id, code, out, `${out.split("\n").filter(l => /^\s*\d+\|/.test(l)).length} lines`));
        } else if (call.name === "edit") {
            prepareEdit(call, id);
        } else {
            setStep(id, { status: "error", text: "unknown tool" });
            reply(call, `error: there is no tool named ${call.name}. use list, search, read or edit.`);
        }
    }

    // shell exit codes -> what the model and the user are told
    function problem(code: int): string {
        return ({ 3: "outside the project folder, not allowed", 4: "the project folder doesn't exist", 5: "no such file or folder", 6: "not a text file", 2: "bad arguments" })[code] ?? `failed (exit ${code})`;
    }

    function done(call: var, id: real, code: int, out: string, summary: string): void {
        if (code === 0) {
            setStep(id, { status: "done", text: summary });
            reply(call, out);
        } else {
            setStep(id, { status: "error", text: problem(code) });
            reply(call, `error: ${problem(code)}`);
        }
    }

    // ------------------------------------------------------------------ edits

    function prepareEdit(call: var, id: real): void {
        const path = call.args.path ?? "";
        const oldText = call.args.old ?? "";
        const newText = call.args.new ?? "";
        shell(["cat", path], (code, content) => {
            let result = null, original = null, at = 0;
            if (code === 5 && oldText === "") {
                result = newText; // a new file
            } else if (code !== 0) {
                setStep(id, { status: "error", text: problem(code) });
                reply(call, `error: ${problem(code)}`);
                return;
            } else if (oldText === "") {
                setStep(id, { status: "error", text: "file exists, `old` was empty" });
                reply(call, "error: the file already exists. to change it, read it and pass the exact text to replace as `old`.");
                return;
            } else {
                const first = content.indexOf(oldText);
                const count = first < 0 ? 0 : content.split(oldText).length - 1;
                if (count !== 1) {
                    const why = count === 0 ? "`old` was not found in the file" : `\`old\` appears ${count} times`;
                    setStep(id, { status: "error", text: why });
                    reply(call, `error: ${why}. read the file again and copy ${count === 0 ? "the text exactly (without line numbers)" : "more surrounding lines so it's unique"}.`);
                    return;
                }
                original = content;
                at = content.slice(0, first).split("\n").length;
                result = content.slice(0, first) + newText + content.slice(first + oldText.length);
            }
            if (result.length > 120000) {
                setStep(id, { status: "error", text: "file too big" });
                reply(call, "error: the result is too big for kawt to write (120k characters).");
                return;
            }
            const diff = {
                at,
                minus: original === null ? [] : oldText.split("\n"),
                plus: newText.split("\n")
            };
            setStep(id, { status: "waiting", text: original === null ? "new file" : `+${diff.plus.length} −${diff.minus.length}`, diff });
            pending = { stepId: id, call, path, content: result, original };
            action = `edit ${path} (waiting for you)`;
        });
    }

    // [apply]: write it, remember the original for [undo], go on
    function apply(): void {
        const p = pending;
        if (!p)
            return;
        pending = null;
        shell(["write", p.path, p.content], code => {
            if (code !== 0) {
                setStep(p.stepId, { status: "error", text: problem(code) });
                reply(p.call, `error: writing failed: ${problem(code)}`);
                return;
            }
            if (!(p.path in touched)) {
                const t = Object.assign({}, touched);
                t[p.path] = p.original;
                touched = t;
            }
            setStep(p.stepId, { status: "applied" });
            reply(p.call, "the edit was applied.");
        });
    }

    // [skip]: tell the model, it decides what's next
    function skip(): void {
        const p = pending;
        if (!p)
            return;
        pending = null;
        setStep(p.stepId, { status: "skipped" });
        reply(p.call, "the user rejected this edit. don't repeat it; ask or try something else.");
    }

    // put back every file the agent changed, delete the ones it created
    function undo(): void {
        if (running)
            return;
        const entries = Object.entries(touched);
        touched = ({});
        for (const [path, original] of entries)
            shell(original === null ? ["remove", path] : ["write", path, original], () => {});
        addStep({ kind: "info", text: `undo: ${entries.length} file${entries.length === 1 ? "" : "s"} put back` });
    }

    // ------------------------------------------------------------------ control

    // stop everything first, so nothing below starts the next step
    function stop(): void {
        const was = running;
        running = false;
        queue = [];
        if (req) {
            const x = req;
            req = null;
            x.abort();
        }
        if (pending) {
            setStep(pending.stepId, { status: "skipped" });
            pending = null;
        }
        if (was)
            addStep({ kind: "info", text: "stopped" });
        finish();
    }

    // forget this session: a fresh agent (changed files stay changed; undo first if needed)
    function reset(): void {
        stop();
        convo = [];
        steps = [];
        touched = ({});
    }

    function fail(text: string): void {
        addStep({ kind: "error", text });
        finish();
    }

    function finish(): void {
        running = false;
        thinking = false;
        action = "";
        queue = [];
    }

    function addStep(s: var): real {
        const id = Date.now() * 100 + steps.length % 100; // unique, and too big for an int: real
        steps = [...steps, Object.assign({ id, time: Date.now(), status: "", text: "", name: "", arg: "" }, s)];
        return id;
    }

    function setStep(id: real, fields: var): void {
        steps = steps.map(s => s.id === id ? Object.assign({}, s, fields) : s);
    }

    // ------------------------------------------------------------------ shell jobs

    function shell(args: list<string>, cb: var): void {
        jobs = [...jobs, { args, cb }];
        if (!proc.running)
            nextJob();
    }

    function nextJob(): void {
        if (jobs.length === 0)
            return;
        const j = jobs[0];
        jobs = jobs.slice(1);
        proc.cb = j.cb;
        proc.command = ["sh", tool, folder, ...j.args];
        proc.running = true;
    }

    Process {
        id: proc

        property var cb: null

        stdout: StdioCollector {
            id: procOut
        }
        onExited: code => {
            const cb = proc.cb;
            proc.cb = null;
            if (cb)
                cb(code, procOut.text);
            root.nextJob();
        }
    }
}
