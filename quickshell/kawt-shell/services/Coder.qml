pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.utils

// The coder agent: the same model as the ai panel, working inside one project folder
// (Settings.aiFolder) through its tools, in a loop:
//   model thinks -> asks for a tool -> kawt runs it -> the result goes back -> ... -> summary
//
//   list    files of a folder                    runs at once
//   search  lines containing a text              runs at once
//   read    numbered lines of a file             runs at once
//   edit    replace a piece of a file / new file waits for Apply or Skip, shown as a diff
//   run     a shell command (tests, a build)     waits for Run or Skip; then runs in a
//                                                sandbox (scripts/sandbox.sh: no network, only
//                                                the folder writable, a time limit). Only
//                                                there's a sandbox and Settings.aiRun is on
//
// Every path goes through scripts/coder-tool.sh, which refuses anything outside the folder.
// What a command changed is found from two pictures of the project, from before and after it
// (coder-tool.sh snap / changes: git trees in kawt's own folder in ~/.cache, never the project's
// .git), and shown in its step file by file. Changes shows every file the agent changed this
// session as one diff each; Undo puts all of them back, by edit or by command (not what
// .gitignore hides, build output: a command's changes there aren't seen).
Singleton {
    id: root

    readonly property string tool: `${Quickshell.shellDir}/scripts/coder-tool.sh`
    readonly property string sandboxTool: `${Quickshell.shellDir}/scripts/sandbox.sh`
    property string sandbox: "" // what scripts/sandbox.sh check found: "bwrap", "podman <image>", ""
    readonly property bool canRun: Settings.aiRun && sandbox !== ""
    readonly property var sandboxEnv: [`KAWT_SANDBOX=${Settings.aiSandbox}`, `KAWT_IMAGE=${Settings.aiSandboxImage}`]
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
    property var pending: null // the edit waiting for Apply: { stepId, path, content, original, folder }
    // what Undo takes back, oldest first: { folder, path, original } an edit (original null:
    // it made the file), { folder, before, after, paths, count } a command (two pictures, the
    // files it changed; fewer paths than count: some were put back one by one since)
    property var history: []
    // each file the agent changed, as it was before its first change to it, for Changes and
    // the count on Undo: "<folder>\n<path>" -> { folder, path, original } (from an edit) or
    // { folder, path, picture } (from a command)
    property var changedFiles: ({})
    // a command is on (its picture from before, itself, then what it changed): no Undo and
    // no new task until it's all known
    readonly property bool settling: runner.run !== null
    property int session: 0 // one more with each [+]: what the old one still reports is dropped
    property var req: null
    property var jobs: [] // shell jobs, one at a time: [{ args, done(code, out) }]

    readonly property int changedCount: Object.keys(changedFiles).length

    // these files ("<folder>\n<path>", as in changedFiles) were just changed again: Changes
    // reads their diffs anew
    signal filesTouched(var keys)
    readonly property bool canUndo: changedCount > 0 && !running && !settling

    readonly property var runSpec: ({
        name: "run",
        description: "Run a shell command in the project folder (tests, a build, a linter, a script). It runs in a sandbox: no network, only the project folder is writable, a time limit. The user approves every command first. Returns the exit code and the output (cut when long). Keep commands short and non-interactive.",
        parameters: { type: "object", properties: { command: { type: "string", description: "one sh command line, run from the project's root" } }, required: ["command"] }
    })
    readonly property var toolSpecs: canRun ? baseSpecs.concat([runSpec]) : baseSpecs
    readonly property var baseSpecs: [
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
Use the tools: list to see the structure, search to find where something is, read a file before changing it, edit to change it.${canRun ? " run executes a shell command in the project (tests, builds, checks), in a sandbox without network; use it to check your changes, not to edit files." : ""}
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
        if (!task || running || settling)
            return;
        if (!Settings.aiFolder) {
            addStep({ kind: "error", text: Strings.t("coderNoFolder") });
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
        // the first task right as the panel opens: the sandbox check decides which tools there are
        if (sandboxCheck.running && sandboxWait.tries < 20) {
            sandboxWait.tries++;
            sandboxWait.restart();
            return;
        }
        sandboxWait.tries = 0;
        if (maxSteps > 0 && stepCount >= maxSteps) {
            addStep({ kind: "info", text: Strings.t("coderMaxSteps").arg(maxSteps) });
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
                root.fail(Ai.useApi ? Strings.t("aiNoteNoReach").arg(Settings.apiUrl) : Strings.t("aiNoteOllamaOff"));
            } else if (xhr.status >= 400 || !data) {
                const err = data && data.error;
                const msg = (err && err.message) || err || `http ${xhr.status}`;
                root.fail(String(msg).includes("does not support tools") ? Strings.t("coderNoTools").arg(Ai.modelName) : Strings.t("aiNoteModelError").arg(msg));
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
            fail(Strings.t("coderEmpty"));
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
            addStep({ kind: "answer", text: text || Strings.t("coderNoAnswer") });
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
        const label = { list: a.path || ".", search: `"${a.text ?? ""}"`, read: a.path ?? "", edit: a.path ?? "", run: a.command ?? "" }[call.name] ?? "";
        const id = addStep({ kind: "tool", name: call.name, arg: label, status: "running" });
        action = `${call.name} ${label}`;

        if (call.name === "list") {
            shell(["list", a.path || "."], (code, out) => done(call, id, code, out, out ? `${out.split("\n").length} entries` : "empty"));
        } else if (call.name === "search") {
            shell(["search", a.text ?? "", a.path || "."], (code, out) => done(call, id, code, out || "no matches", out ? `${out.split("\n").length} lines` : "no matches"));
        } else if (call.name === "read") {
            const args = ["read", a.path ?? ""];
            // whole numbers only (the script checks again): the model's arguments are untrusted
            const from = Math.max(1, parseInt(a.from) || 0);
            if (a.from)
                args.push(String(from), String(Math.max(from, parseInt(a.to) || from + 299)));
            shell(args, (code, out) => done(call, id, code, out, `${out.split("\n").filter(l => /^\s*\d+\|/.test(l)).length} lines`));
        } else if (call.name === "edit") {
            prepareEdit(call, id);
        } else if (call.name === "run" && canRun) {
            prepareRun(call, id);
        } else {
            setStep(id, { status: "error", text: "unknown tool" });
            reply(call, `error: there is no tool named ${call.name}. use ${toolSpecs.map(t => t.name).join(", ")}.`);
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
            // two lines around the change, as they are in the file now
            const all = original === null ? [] : original.split("\n");
            const end = at - 1 + oldText.split("\n").length;
            if (result.length > 120000) {
                setStep(id, { status: "error", text: "file too big" });
                reply(call, "error: the result is too big for kawt to write (120k characters).");
                return;
            }
            const diff = {
                at,
                above: all.slice(Math.max(0, at - 3), Math.max(0, at - 1)),
                minus: original === null ? [] : oldText.split("\n"),
                plus: newText.split("\n"),
                below: all.slice(end, end + 2)
            };
            setStep(id, { status: "waiting", text: original === null ? "new file" : `+${diff.plus.length} −${diff.minus.length}`, diff });
            pending = { stepId: id, call, path, content: result, original, folder };
            action = `edit ${path} (waiting for you)`;
        });
    }

    // Apply: write it, remember the original for Undo, go on.
    // The new content was made from the file as it was when the diff was shown; if it changed
    // since (you edited it while the diff waited), writing would throw your change away. So it's
    // read again first, and the model is told to redo the edit instead.
    function apply(): void {
        const p = pending;
        if (!p)
            return;
        pending = null;
        if (p.kind === "run") {
            execRun(p);
            return;
        }
        shell(["cat", p.path], (code, now) => {
            const current = code === 5 ? null : code === 0 ? now : undefined;
            if (current !== p.original) {
                const why = current === undefined ? problem(code) : "the file changed since the diff";
                setStep(p.stepId, { status: "error", text: why });
                reply(p.call, current === undefined ? `error: ${why}` : "error: the file was changed on disk after you proposed this edit. read it again and redo the edit on the new content.");
                return;
            }
            shell(["write", p.path], (code, written) => {
                if (code !== 0) {
                    setStep(p.stepId, { status: "error", text: problem(code) });
                    reply(p.call, `error: writing failed: ${problem(code)}`);
                    return;
                }
                // the path as the script wrote it (from the folder, ./ and links gone): a
                // command's changes name the file the same way
                remember({ folder: p.folder, path: written || p.path, original: p.original });
                setStep(p.stepId, { status: "applied" });
                reply(p.call, "the edit was applied.");
            }, p.content, p.folder);
        }, undefined, p.folder);
    }

    // Skip: tell the model, it decides what's next
    function skip(): void {
        const p = pending;
        if (!p)
            return;
        pending = null;
        setStep(p.stepId, { status: "skipped" });
        reply(p.call, p.kind === "run" ? "the user didn't run this command. don't repeat it; ask or try something else." : "the user rejected this edit. don't repeat it; ask or try something else.");
    }

    // ------------------------------------------------------------------ commands

    // shown whole, waiting for Run: nothing runs before that
    function prepareRun(call: var, id: real): void {
        const command = String(call.args.command ?? "").trim();
        if (!command) {
            setStep(id, { status: "error", text: "no command" });
            reply(call, "error: give the command to run as `command`.");
            return;
        }
        setStep(id, { status: "waiting", text: "run it?", cmd: command });
        pending = { stepId: id, call, kind: "run", command };
        action = "run (waiting for you)";
    }

    // Run: a picture of the project first, then the command in the sandbox, with a time
    // limit, then another picture. The exit code, the output and the files it changed go to
    // the model; the files to its step, Changes and Undo
    function execRun(p: var): void {
        setStep(p.stepId, { status: "running", text: "" });
        action = `run ${p.command}`;
        const r = { call: p.call, stepId: p.stepId, command: p.command, folder, session, before: "", unwatched: "", since: 0, stopped: false };
        runner.run = r;
        // nothing to take back yet: the old pictures can go
        shell(["snap", history.length > 0 ? "" : "fresh"], (code, out) => {
            if (runner.run !== r)
                return; // stopped meanwhile
            r.before = code === 0 ? out.trim() : "";
            r.unwatched = code === 0 ? "" : code === 8 ? "the project is too big to keep a copy of (20000 files, 200 MB)" : code === 7 ? "it needs git" : `no copy of the project (${problem(code)})`;
            r.since = Date.now();
            runner.command = ["env", ...sandboxEnv, "sh", sandboxTool, r.folder, String(Settings.aiRunSecs), r.command];
            runner.running = true;
        }, undefined, r.folder);
    }

    // a command ended (or was stopped): what it changed is kept, then the model hears of it
    // (unless you stopped it)
    function ranDone(r: var, code: int, out: string, found: var): void {
        runner.run = null;
        const files = found ? found.files : [];
        if (files.length > 0 && r.session === session)
            remember({ folder: r.folder, before: r.before, after: found.after, paths: files.map(f => f.path), count: files.length });
        const secs = Math.round((Date.now() - r.since) / 100) / 10;
        const lines = out ? out.replace(/\n$/, "").split("\n") : [];
        const why = r.stopped ? " (stopped)" : code === 124 ? ` (stopped: over ${Settings.aiRunSecs}s)` : code === 125 ? " (no sandbox)" : "";
        const unwatched = r.unwatched || (r.before && !found ? "git couldn't read them (twice)" : "");
        setStep(r.stepId, {
            status: code === 0 && !r.stopped ? "done" : "error",
            text: `exit ${code}${why} · ${lines.length} lines · ${secs}s${files.length ? ` · ${files.length} file${files.length === 1 ? "" : "s"} changed` : ""}`,
            out: lines.slice(-40).join("\n"),
            files,
            unwatched
        });
        if (!running || r.stopped || r.session !== session)
            return;
        const what = files.slice(0, 40).map(f => `${f.path} (${({ A: "new", D: "deleted" })[f.how] ?? "changed"})`).join(", ");
        reply(r.call, `exit code ${code}${why}${out.length >= 65536 ? " (the output was cut at 64 KB)" : ""}\n${cutOutput(out) || "(no output)"}${files.length ? `\nfiles it changed: ${what}${files.length > 40 ? ", ..." : ""}` : ""}`);
    }

    // what coder-tool.sh changes printed: the new picture, a file a line, "--", the diff. Each
    // file gets its own part of the diff (the same order), from its first @@ on; a file that
    // became a link or the other way round (T) has two parts, the old one gone, the new one made
    function parseChanges(text: string): var {
        const lines = text.split("\n");
        const files = [];
        let i = 1;
        for (; i < lines.length && lines[i] !== "--"; i++) {
            const m = lines[i].match(/^([ADMT]) (\S+) (\S+) (\d+) (\d+)\t(.*)$/);
            if (m)
                files.push({ how: m[1], plus: m[2], minus: m[3], modes: [m[4], m[5]], path: unquote(m[6]), diff: [] });
        }
        let at = -1, more = 0, head = true;
        for (i++; i < lines.length; i++) {
            const l = lines[i];
            if (l.startsWith("diff --git ")) {
                if (more > 0) {
                    more--;
                } else {
                    at++;
                    more = files[at]?.how === "T" ? 1 : 0;
                }
                head = true; // "index ...", "--- a/x", "+++ b/x": not shown
                continue;
            }
            if (l.startsWith("@@") || l.startsWith("Binary files"))
                head = false;
            const f = files[at];
            if (f && !head && !(l === "" && i === lines.length - 1))
                f.diff.push(l.startsWith("Binary files") ? "(binary)" : l);
        }
        return { after: lines[0].trim(), files };
    }

    // a path as git prints it: in "..." with \t, \" and the like when it has odd characters
    function unquote(p: string): string {
        if (p.length < 2 || !p.startsWith('"') || !p.endsWith('"'))
            return p;
        return p.slice(1, -1).replace(/\\([0-7]{3}|.)/g, (m, c) => c.length === 3 ? String.fromCharCode(parseInt(c, 8)) : ({ a: "\x07", b: "\b", t: "\t", n: "\n", v: "\v", f: "\f", r: "\r" })[c] ?? c);
    }

    // what the model gets back from a command: the end matters most (errors, the summary)
    function cutOutput(out: string): string {
        return out.length <= 12000 ? out : `${out.slice(0, 3000)}\n... (${out.length - 11000} characters left out) ...\n${out.slice(-8000)}`;
    }

    Job {
        id: runner

        // the command of now: { call, stepId, command, folder, session, before (the picture
        // from before it; "": none, unwatched says why), since, stopped }
        property var run: null

        onDone: (code, out) => {
            const r = run;
            if (!r)
                return;
            if (!r.before) {
                root.ranDone(r, code, out, null);
                return;
            }
            // twice: without it, what the command did can't be taken back
            const read = again => root.shell(["changes", r.before], (c, list) => {
                if (c !== 0 && again)
                    read(false);
                else
                    root.ranDone(r, code, out, c === 0 ? root.parseChanges(list) : null);
            }, undefined, r.folder);
            read(true);
        }
    }

    // which sandbox works here; again when the setting changes
    Process {
        id: sandboxCheck

        running: true
        command: ["env", ...root.sandboxEnv, "sh", root.sandboxTool, "check"]
        stdout: StdioCollector {
            onStreamFinished: root.sandbox = text.trim()
        }
    }

    Timer {
        id: sandboxWait

        property int tries: 0

        interval: 150
        onTriggered: root.callModel()
    }

    onSandboxEnvChanged: {
        sandboxCheck.running = false;
        sandboxCheck.running = true;
    }

    // one more change for Undo and Changes (see history and changedFiles above)
    function remember(c: var): void {
        history = [...history, c];
        const ch = Object.assign({}, changedFiles);
        const keys = [];
        for (const path of c.paths ?? [c.path]) {
            const key = `${c.folder}\n${path}`;
            keys.push(key);
            if (!(key in ch))
                ch[key] = c.after ? { folder: c.folder, path, picture: c.before } : { folder: c.folder, path, original: c.original };
        }
        changedFiles = ch;
        filesTouched(keys);
    }

    // one file back as it was: from a command's picture ({ picture }), or an edit's text
    // ({ original }; null: the edit made it, so it goes). remove finding no file (5) is fine
    function restoreFile(folder: string, path: string, was: var, cb: var): void {
        const done = code => cb(code === 5 && was.original === null ? 0 : code);
        if (was.picture)
            shell(["put", path, was.picture], done, undefined, folder);
        else if (was.original === null)
            shell(["remove", path], done, undefined, folder);
        else
            shell(["write", path], done, was.original, folder);
    }

    // one change taken back: a command's files as in its picture from before (one by one once
    // some were put back alone), an edit's file as it was
    function takeBack(c: var, cb: var): void {
        if (c.after && c.paths.length === c.count)
            shell(["restore", c.before, c.after], cb, undefined, c.folder);
        else if (c.after)
            for (const path of c.paths)
                restoreFile(c.folder, path, { picture: c.before }, cb);
        else
            restoreFile(c.folder, c.path, c, cb);
    }

    // Undo: every file the agent changed back as it was, newest change first: so each ends as
    // it was before the agent's first change to it, whatever came between
    function undo(): void {
        if (!canUndo)
            return;
        const todo = history.slice().reverse();
        const n = changedCount;
        history = [];
        changedFiles = ({});
        let left = todo.reduce((k, c) => k + (c.after && c.paths.length !== c.count ? c.paths.length : 1), 0);
        let failed = 0;
        const end = code => {
            if (code !== 0)
                failed++;
            if (--left === 0)
                addStep({ kind: "info", text: Strings.t("coderUndone").arg(Strings.count(n, "file")) + (failed ? Strings.t("coderUndoFailed").arg(failed) : "") });
        };
        for (const c of todo)
            takeBack(c, end);
        if (left === 0)
            addStep({ kind: "info", text: Strings.t("coderUndoNothing") });
    }

    // one file of Changes back as it was before the agent's first change to it. The changes
    // before that are told to leave it alone, so Undo later doesn't take it back again
    // (it may be yours by then)
    function putBack(key: string): void {
        const c = changedFiles[key];
        if (!c || running || settling)
            return;
        restoreFile(c.folder, c.path, c, code => {
            if (code !== 0) {
                addStep({ kind: "error", text: Strings.t("coderCantPutBack").arg(c.path).arg(problem(code)) });
                return;
            }
            const ch = Object.assign({}, changedFiles);
            delete ch[key];
            changedFiles = ch;
            history = history.filter(h => h.after || h.folder !== c.folder || h.path !== c.path).map(h => h.after && h.folder === c.folder && h.paths.includes(c.path) ? Object.assign({}, h, { paths: h.paths.filter(x => x !== c.path) }) : h).filter(h => !h.after || h.paths.length > 0);
            addStep({ kind: "info", text: Strings.t("coderUndone").arg(c.path) });
        });
    }

    // the diff of one file of Changes, from before the agent's first change to it to now:
    // cb({ how: new|gone|changed|same, lines, plus, minus }) or cb(null)
    function diffOf(key: string, cb: var): void {
        const c = changedFiles[key];
        if (!c) {
            cb(null);
            return;
        }
        shell(["diff", c.path, c.picture || (c.original === null ? "new" : "-")], (code, out) => {
            if (code !== 0) {
                cb(null);
                return;
            }
            const all = out.replace(/\n$/, "").split("\n");
            const at = all.findIndex(l => l.startsWith("@@") || l.startsWith("Binary files"));
            const lines = at < 0 ? [] : all.slice(at).map(l => l.startsWith("Binary files") ? "(binary)" : l);
            cb({ how: all[0], lines, plus: lines.filter(l => l.startsWith("+")).length, minus: lines.filter(l => l.startsWith("-")).length });
        }, c.picture ? undefined : (c.original ?? undefined), c.folder);
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
        const r = runner.run;
        if (r && !r.stopped) {
            r.stopped = true;
            if (r.since === 0) {
                // still taking the picture: nothing ran
                runner.run = null;
                setStep(r.stepId, { status: "error", text: Strings.t("coderStopped") });
            } else if (runner.running) {
                // sandbox.sh takes the TERM: it stops the command and still looks after it; then
                // what it changed is read as always (ranDone)
                setStep(r.stepId, { status: "running", text: Strings.t("coderStopping") });
                runner.running = false;
            }
            // ended already: what it changed is being read, and kept; the model isn't told
        }
        if (was)
            addStep({ kind: "info", text: Strings.t("coderStopped") });
        finish();
    }

    // forget this session: a fresh agent (changed files stay changed; undo first if needed)
    function reset(): void {
        stop();
        session++;
        convo = [];
        steps = [];
        history = [];
        changedFiles = ({});
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

    // input: text for the command's stdin (the content of a write), or undefined. dir: the
    // project folder, when it's not the one of now (an undo after the folder was changed)
    function shell(args: list<string>, cb: var, input: var, dir: var): void {
        jobs = [...jobs, { args, cb, input, dir: dir || folder }];
        nextJob();
    }

    // one at a time: a callback that queues the next job starts it right away, and the
    // nextJob() after that callback then finds the process busy
    function nextJob(): void {
        if (jobs.length === 0 || proc.running || !proc.reported)
            return;
        const j = jobs[0];
        jobs = jobs.slice(1);
        proc.cb = j.cb;
        proc.input = typeof j.input === "string" ? j.input : null;
        proc.stdinEnabled = proc.input !== null;
        proc.command = ["sh", tool, j.dir, ...j.args];
        proc.reported = false; // busy from now on, even before the process is up
        proc.running = true;
    }

    // utils/Job.qml: reports only once the output is read to the end (a read of a long
    // file could otherwise come back cut short)
    Job {
        id: proc

        property var cb: null
        property var input: null // written once the process is up, then stdin is closed (EOF)

        onStarted: {
            if (input === null)
                return;
            write(input);
            input = null;
            stdinEnabled = false;
        }
        onDone: (code, out) => {
            const cb = proc.cb;
            proc.cb = null;
            if (cb)
                cb(code, out);
            root.nextJob();
        }
    }
}
