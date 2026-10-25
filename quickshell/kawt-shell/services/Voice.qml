pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.utils

// Speaking to the ai panel, all on this machine: super + alt + v (kawt voice) or [mic] in the
// panel starts listening (pw-record, the default mic), the same again stops; whisper.cpp
// writes down what you said and it lands in the panel's input (Settings.aiVoiceSend: sent at
// once). The recording is in $XDG_RUNTIME_DIR (memory) and goes right after; nothing leaves.
// It needs whisper-cpp (pacman) and one of its models, fetched once with [get] in the ai
// panel's cfg (the only time this goes online): ~/.local/share/kawt/whisper/ggml-<size>.bin
//   tiny 75 MB · base 142 MB · small 466 MB (better, slower)
Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share"}/kawt/whisper`
    readonly property string size: Settings.aiVoiceModel || "base"
    readonly property string model: `${dir}/ggml-${size}.bin`
    readonly property string wav: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/kawt-voice.wav`
    readonly property var sizes: [["tiny", "75 MB"], ["base", "142 MB"], ["small", "466 MB"]]
    readonly property int maxSecs: 90

    property string bin: "" // whisper-cli (or the older names)
    property var have: [] // the sizes downloaded
    readonly property bool ready: bin !== "" && have.includes(size)
    readonly property bool recording: rec.running
    readonly property bool writing: whisper.running
    property int elapsed: 0
    property string status: ""
    property bool fetching: fetch.running
    property bool startWhenFound: false
    property bool looked: false // the first look for whisper and its models is done

    // what was said, for the open panel's input (modules/sidebar/AiSidebar.qml)
    signal heard(string text)

    // the bar's [● voice 0:05] reads this from Panels: the bar doesn't start this service
    readonly property string barText: recording ? `● voice ${Fmt.mmss(elapsed)}` : writing ? "~ writing" : ""
    onBarTextChanged: Panels.voice = barText

    // into the ai panel: its input (open it if it's closed), or sent at once (Settings.aiVoiceSend)
    function deliver(text: string): void {
        if (Settings.aiVoiceSend) {
            Ai.send(text);
        } else if (Panels.sidebarOpen) {
            heard(text);
            return;
        } else {
            Ai.draft = `${Ai.draft} ${text}`.trim();
        }
        Panels.aiTab = 0;
        Panels.sidebarScreen = Panels.focusedScreen;
        Panels.sidebarOpen = true;
    }

    function toggle(): void {
        if (recording) {
            rec.signal(2); // SIGINT: pw-record closes the file properly
            return;
        }
        if (writing)
            return;
        // the very first press (the key started this service): whisper isn't looked for yet
        if (!looked) {
            startWhenFound = true;
            return;
        }
        if (!ready) {
            status = !bin ? "voice needs whisper-cpp: sudo pacman -S whisper-cpp" : `no voice model yet: ai -> cfg -> voice -> [get ${size}]`;
            Quickshell.execDetached(["notify-send", "-a", "kawt", "-e", "voice", status]);
            return;
        }
        status = "listening...";
        elapsed = 0;
        rec.running = true;
    }

    // the model, once, from whisper.cpp's own place on huggingface
    function get(name: string): void {
        if (fetch.running)
            return;
        status = `getting the ${name} model...`;
        fetch.name = name;
        fetch.command = ["sh", "-c", 'mkdir -p "$1" && curl -fL --retry 2 -o "$1/ggml-$2.bin.part" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$2.bin" && mv "$1/ggml-$2.bin.part" "$1/ggml-$2.bin"', "sh", dir, name];
        fetch.running = true;
    }

    function look(): void {
        finder.running = false;
        finder.running = true;
    }

    // whisper.cpp's program and the models there are
    Process {
        id: finder

        running: true
        command: ["sh", "-c", 'for b in whisper-cli whisper-cpp whisper.cpp; do command -v "$b" && break; done; echo ---; ls "$1" 2> /dev/null', "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const [a, b] = text.split("---");
                root.bin = (a ?? "").trim().split("\n")[0] ?? "";
                root.have = (b ?? "").split("\n").map(f => (f.match(/^ggml-(\w+)\.bin$/) ?? [])[1]).filter(x => x);
                root.looked = true;
                if (root.startWhenFound) {
                    root.startWhenFound = false;
                    root.toggle();
                }
            }
        }
    }

    // 16 kHz mono: what whisper wants
    Process {
        id: rec

        command: ["pw-record", "--rate", "16000", "--channels", "1", "--format", "s16", root.wav]
        onExited: code => {
            root.status = "writing it down...";
            whisper.running = true;
        }
    }

    Timer {
        running: root.recording
        repeat: true
        interval: 1000
        onTriggered: {
            root.elapsed++;
            if (root.elapsed >= root.maxSecs)
                root.toggle();
        }
    }

    // the language is found by itself; the recording goes once it's read
    Job {
        id: whisper

        command: ["sh", "-c", '"$1" -m "$2" -f "$3" -l auto -nt -np -t "$(nproc)" 2> /dev/null; c=$?; rm -f "$3"; exit $c', "sh", root.bin, root.model, root.wav]
        onDone: (code, out) => {
            // [BLANK_AUDIO], (music), [Music]: not words
            const text = out.replace(/\[[^\]]*\]|\([^)]*\)/g, " ").replace(/\s+/g, " ").trim();
            if (code !== 0) {
                root.status = "whisper failed (is the model whole? get it again)";
                return;
            }
            if (!text) {
                root.status = "heard nothing";
                return;
            }
            root.status = "";
            root.deliver(text);
        }
    }

    Process {
        id: fetch

        property string name: ""

        onExited: code => {
            root.status = code === 0 ? `the ${fetch.name} model is here` : "couldn't get the model (no internet?)";
            root.look();
        }
    }
}
