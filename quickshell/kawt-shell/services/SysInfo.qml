pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// System stats for the profile panel. Only polls while the panel is open,
// and the process list only while its tab is shown (`topActive`, set by the panel).
Singleton {
    id: root

    // polls only while something shows it: the profile, the dashboard, the lock screen
    readonly property bool active: Panels.current === "profile" || Panels.current === "dashboard" || Panels.current === "power" || Panels.locked

    readonly property string user: Quickshell.env("USER") ?? "user"
    property string host: ""
    property string kernel: ""
    property string os: ""
    property string model: ""
    property int chassis: 0 // SMBIOS chassis type

    // 8-10, 14, 30-32: portable / laptop / notebook / sub-notebook / tablet / convertible / detachable
    readonly property bool detectedLaptop: [8, 9, 10, 14, 30, 31, 32].includes(chassis)
    readonly property bool laptop: Settings.device === "auto" ? detectedLaptop : Settings.device === "laptop"

    readonly property string shell: (Quickshell.env("SHELL") ?? "").split("/").pop() || "sh"
    property string cpuModel: ""
    property int cores: 0
    property list<string> gpus: []
    property string wm: ""
    property int pkgs: 0
    property string res: ""
    property real batHealth: -1 // 0..1, full / design capacity
    property int batCycles: -1
    property int batLimit: -1 // charge stop threshold, %

    readonly property int historyLength: 40
    property list<real> cpuHistory: new Array(historyLength).fill(0)
    property list<real> memHistory: new Array(historyLength).fill(0)
    property string load: ""

    property bool topActive: false
    property var procs: [] // [{ pid, comm, state, cpu, mem }] busiest first
    property int taskCount: 0
    property var lastProcTicks: ({})
    property real lastProcTime: 0

    property real uptime: 0
    property real cpu: 0 // 0..1
    property real mem: 0 // 0..1
    property real memUsedGb: 0
    property real memTotalGb: 0
    property real swap: 0 // 0..1
    property real swapTotalGb: 0
    property real disk: 0 // 0..1, root fs
    property real cpuTemp: -1 // °C
    property int fan: -1 // rpm

    property string tempPath: ""
    property string fanPath: ""
    property var lastCpu: null

    FileView {
        path: "/proc/sys/kernel/hostname"
        onLoaded: root.host = text().trim()
    }

    FileView {
        path: "/proc/sys/kernel/osrelease"
        onLoaded: root.kernel = text().trim()
    }

    // Lenovo keeps the marketing name in product_version ("ThinkPad T480"), most others in
    // product_name; desktop boards often only have placeholders there, so fall back to board_name.
    Process {
        running: true
        command: ["sh", "-c", "cd /sys/class/dmi/id && for f in chassis_type product_version product_name board_name; do echo \"$f=$(cat $f 2>/dev/null)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const dmi = {};
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf("=");
                    dmi[line.slice(0, i)] = line.slice(i + 1).trim();
                }
                const junk = /o\.?e\.?m|default string|system product name|system version|to be filled|not applicable|not specified|^none$|^[\d.]*$/i;
                root.chassis = parseInt(dmi.chassis_type) || 0;
                root.model = [dmi.product_version, dmi.product_name, dmi.board_name].find(s => s && !junk.test(s)) ?? "";
            }
        }
    }

    FileView {
        path: "/etc/os-release"
        onLoaded: root.os = (text().match(/^PRETTY_NAME="?([^"\n]*)/m) ?? [])[1] ?? "linux"
    }

    // hwmon indices change between boots, so resolve sensors by name.
    // Prefer the CPU die sensor (k10temp/coretemp), fall back to thinkpad_acpi.
    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do echo \"$(cat $h/name) $h\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.trim().split("\n")) {
                    const [name, path] = line.split(" ");
                    map[name] = path;
                }
                const cpu = map.k10temp ?? map.coretemp ?? map.zenpower ?? map.thinkpad;
                if (cpu)
                    root.tempPath = `${cpu}/temp1_input`;
                if (map.thinkpad)
                    root.fanPath = `${map.thinkpad}/fan1_input`;
            }
        }
    }

    FileView {
        id: stat

        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number); // guest time is already in user
            const idle = f[3] + (f[4] ?? 0);
            const total = f.reduce((a, b) => a + b, 0);
            if (root.lastCpu) {
                const dt = total - root.lastCpu.total;
                if (dt > 0) {
                    root.cpu = 1 - (idle - root.lastCpu.idle) / dt;
                    root.cpuHistory = [...root.cpuHistory.slice(1), root.cpu];
                }
            }
            root.lastCpu = { idle, total };
        }
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const kb = k => Number((t.match(new RegExp(`^${k}:\\s+(\\d+)`, "m")) ?? [])[1] ?? 0);
            const total = kb("MemTotal"), avail = kb("MemAvailable");
            if (total > 0) {
                root.mem = 1 - avail / total;
                root.memTotalGb = total / 1048576;
                root.memUsedGb = (total - avail) / 1048576;
                root.memHistory = [...root.memHistory.slice(1), root.mem];
            }
            const swapTotal = kb("SwapTotal");
            root.swapTotalGb = swapTotal / 1048576;
            root.swap = swapTotal > 0 ? 1 - kb("SwapFree") / swapTotal : 0;
        }
    }

    FileView {
        path: "/proc/cpuinfo"
        onLoaded: {
            const t = text();
            root.cores = (t.match(/^processor\s*:/gm) ?? []).length;
            root.cpuModel = ((t.match(/^model name\s*:\s*(.*)$/m) ?? [])[1] ?? "")
                .replace(/\((R|TM)\)/gi, "")
                .replace(/ CPU| Processor|\d+-Core|with Radeon.*$|@.*$/gi, "")
                .replace(/Core /, "")
                .replace(/\s+/g, " ").trim();
        }
    }

    // slow-changing facts: package count, gpu, hyprland version, monitors, battery wear
    Process {
        running: true
        command: ["sh", `${Quickshell.shellDir}/scripts/sysinfo.sh`]
        stdout: StdioCollector {
            onStreamFinished: {
                const gpus = [];
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    const key = line.slice(0, i), val = line.slice(i + 1).trim();
                    if (key === "pkgs") {
                        root.pkgs = parseInt(val) || 0;
                    } else if (key === "gpu") {
                        gpus.push(root.shortGpu(val));
                    } else if (key === "wm") {
                        root.wm = val ? `hyprland ${val.replace(/^v/, "")}` : "";
                    } else if (key === "monitors") {
                        try {
                            root.res = JSON.parse(val).map(m => `${m.width}x${m.height}@${Math.round(m.refreshRate)}`).join(", ");
                        } catch (e) {}
                    } else if (key === "bathealth") {
                        const [full, design] = val.split(" ").map(Number);
                        root.batHealth = full > 0 && design > 0 ? full / design : -1;
                    } else if (key === "batcycles") {
                        root.batCycles = val === "" ? -1 : parseInt(val);
                    } else if (key === "batlimit") {
                        root.batLimit = val === "" ? -1 : parseInt(val);
                    }
                }
                root.gpus = gpus;
            }
        }
    }

    // "Intel Corporation UHD Graphics 620 (rev 07)" -> "Intel UHD Graphics 620",
    // "... [AMD/ATI] Navi 23 [Radeon RX 6600]" -> "Radeon RX 6600"
    function shortGpu(s: string): string {
        s = s.replace(/\s*\(rev [^)]*\)/, "");
        // no String.matchAll in Qt's JS engine
        const brackets = (s.match(/\[[^\]]+\]/g) ?? []).map(m => m.slice(1, -1)).filter(b => b !== "AMD/ATI");
        if (brackets.length > 0)
            return brackets[brackets.length - 1].split(" / ")[0]; // "Radeon Vega Series / Radeon Vega Mobile Series"
        return s.replace(/ Corporation|, Inc\.| Integrated Graphics Controller/g, "").replace(/\s+/g, " ").trim();
    }

    function kill(pid: int): void {
        Quickshell.execDetached(["kill", String(pid)]);
    }

    FileView {
        id: loadFile

        path: "/proc/loadavg"
        onLoaded: root.load = text().split(" ").slice(0, 3).join(" ")
    }

    // per-process cpu from utime+stime deltas between samples, like top
    Process {
        id: procProc

        command: ["sh", "-c", "cat /proc/[0-9]*/stat 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const now = Date.now();
                const dt = root.lastProcTime > 0 ? (now - root.lastProcTime) / 1000 : 0;
                const prev = root.lastProcTicks;
                const memBytes = root.memTotalGb * 1073741824;
                const ticks = {};
                const out = [];
                for (const line of text.split("\n")) {
                    // "1234 (comm with spaces) S ppid ..."; fields after ")" start at #3 (state)
                    const open = line.indexOf("("), close = line.lastIndexOf(")");
                    if (open < 0 || close < 0)
                        continue;
                    const pid = parseInt(line.slice(0, open));
                    const f = line.slice(close + 2).split(" ");
                    const t = Number(f[11]) + Number(f[12]); // utime + stime, in 1/100 s
                    ticks[pid] = t;
                    out.push({
                        pid,
                        comm: line.slice(open + 1, close),
                        state: f[0],
                        cpu: dt > 0 && prev[pid] !== undefined ? Math.max(0, t - prev[pid]) / dt : 0, // % of one core
                        mem: memBytes > 0 ? Number(f[21]) * 4096 / memBytes * 100 : 0
                    });
                }
                root.lastProcTicks = ticks;
                root.lastProcTime = now;
                root.taskCount = out.length;
                root.procs = out.sort((a, b) => b.cpu - a.cpu || b.mem - a.mem).slice(0, 14);
            }
        }
    }

    Timer {
        running: root.active && root.topActive
        repeat: true
        interval: 1500
        triggeredOnStart: true
        onTriggered: procProc.running = true
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        onLoaded: root.uptime = parseFloat(text())
    }

    FileView {
        id: tempFile

        path: root.tempPath
        printErrors: false
        onLoaded: root.cpuTemp = parseInt(text()) / 1000
    }

    FileView {
        id: fanFile

        path: root.fanPath
        printErrors: false
        onLoaded: root.fan = parseInt(text())
    }

    Process {
        id: df

        command: ["df", "--output=pcent", "/"]
        stdout: StdioCollector {
            onStreamFinished: root.disk = parseInt(text.split("\n")[1]) / 100 || 0
        }
    }

    Timer {
        running: root.active
        repeat: true
        interval: 2000
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            uptimeFile.reload();
            loadFile.reload();
            if (root.tempPath)
                tempFile.reload();
            if (root.fanPath)
                fanFile.reload();
        }
    }

    Timer {
        running: root.active
        repeat: true
        interval: 30000
        triggeredOnStart: true
        onTriggered: df.running = true
    }
}
