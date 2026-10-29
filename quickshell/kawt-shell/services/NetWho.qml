pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Who talks to the internet right now (tools/net.sh in the wifi panel, its [who's out] page):
// every connection that leaves this machine, by program, and how fast. Looked at only while that
// page is open (`watching`): every 3 s, every 6 s on an old machine; nothing runs otherwise.
// Addresses stay numbers: looking their names up would itself send a question to a dns server.
// The speed is tcp's alone: ss counts no bytes for udp, so quic (video in a browser, calls) shows
// as connections without one. Programs of other users and system services can't be seen without
// root: they're counted together (`others`).
//
// What can be done about a program (scripts/netapp.sh): kill() asks it to quit, findEntry() says
// which launcher entry starts it, for Apps.setOffline() (started without internet from then on)
Singleton {
    id: root

    property bool watching: false
    property bool lan: false // the local network too (router, printer, phone), marked as such
    // [{ name, pids, conns, peer (the busiest address), more (other addresses), down, up (bytes/s,
    //   -1 until the second look), fresh (a new connection since the last look), local, self }]
    property var apps: []
    property var byName: ({}) // the same, by name
    property int others: 0
    property bool ready: false // the first look is done
    property bool missing: false // no ss (it comes with iproute2)

    property var last: ({}) // socket -> [received, sent] at the last look
    property real lastAt: 0

    onWatchingChanged: if (!watching) {
        last = {};
        lastAt = 0;
        ready = false;
    }

    Timer {
        running: root.watching
        interval: Settings.lite ? 6000 : 3000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!ss.running)
            ss.running = true
    }

    Process {
        id: ss

        command: ["ss", "-Htunpi", "state", "established"]
        stdout: StdioCollector {
            onStreamFinished: if (root.watching)
                root.look(text)
        }
        onExited: code => root.missing = code === 127
    }

    // [2a00::1]:443 -> 2a00::1, 1.2.3.4:443 -> 1.2.3.4, ::ffff:1.2.3.4 -> 1.2.3.4, fe80::1%wlan0 -> fe80::1
    function hostOf(peer: string): string {
        let h = peer.startsWith("[") ? peer.slice(1, peer.indexOf("]")) : peer.replace(/:[^:]*$/, "");
        return h.replace(/^::ffff:/, "").replace(/%.*$/, "");
    }

    function isLan(h: string): bool {
        return /^(10\.|192\.168\.|169\.254\.|172\.(1[6-9]|2[0-9]|3[01])\.|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.)/.test(h) || /^(fe80|fc|fd)/i.test(h);
    }

    // ss -tunpi: a line per socket, tcp's followed by an indented line of numbers
    //   tcp 0 0 192.168.1.30:52344 140.82.112.3:443 users:(("firefox",pid=1234,fd=88),...)
    //   \t cubic ... bytes_sent:381769 bytes_acked:381770 bytes_received:87281 ...
    function look(text: string): void {
        const now = Date.now();
        const dt = lastAt > 0 ? (now - lastAt) / 1000 : 0;
        const socks = {};
        let cur = null;
        for (const line of text.split("\n")) {
            if (/^\s/.test(line)) {
                if (cur) {
                    const r = /bytes_received:(\d+)/.exec(line), t = /bytes_sent:(\d+)/.exec(line);
                    cur.rx = r ? Number(r[1]) : 0;
                    cur.tx = t ? Number(t[1]) : 0;
                }
                continue;
            }
            cur = null;
            const f = line.trim().split(/\s+/);
            if (f.length < 5)
                continue;
            const host = hostOf(f[4]);
            if (/^127\./.test(host) || host === "::1")
                continue; // this machine itself: ollama, kawt...
            const local = isLan(host);
            if (local && !lan)
                continue;
            const u = /users:\(\("([^"]+)"/.exec(line);
            const name = u ? u[1] : "";
            const pids = [];
            const re = /pid=(\d+)/g;
            for (let m = re.exec(line); m; m = re.exec(line))
                pids.push(Number(m[1]));
            cur = { name, pids, peer: f[4], local, rx: 0, tx: 0 };
            socks[`${f[0]} ${f[3]} ${f[4]}`] = cur;
        }

        const by = {};
        let others = 0;
        const seen = {};
        for (const key in socks) {
            const s = socks[key];
            const before = last[key];
            seen[key] = [s.rx, s.tx];
            if (!s.name) {
                others++;
                continue;
            }
            // a connection that wasn't there at the last look: all of it is new
            const drx = before ? Math.max(0, s.rx - before[0]) : s.rx;
            const dtx = before ? Math.max(0, s.tx - before[1]) : s.tx;
            const a = by[s.name] ?? (by[s.name] = { name: s.name, pids: [], conns: 0, peers: {}, down: 0, up: 0, fresh: false, local: true });
            a.conns++;
            for (const p of s.pids)
                if (!a.pids.includes(p))
                    a.pids.push(p);
            a.peers[s.peer] = (a.peers[s.peer] ?? 0) + drx + dtx + 1;
            a.down += drx;
            a.up += dtx;
            a.fresh = a.fresh || (!before && lastAt > 0);
            a.local = a.local && s.local;
        }

        const list = Object.values(by).map(a => {
            const peers = Object.keys(a.peers).sort((x, y) => a.peers[y] - a.peers[x]);
            return {
                name: a.name,
                pids: a.pids,
                conns: a.conns,
                peer: peers[0],
                more: peers.length - 1,
                down: dt > 0 ? a.down / dt : -1,
                up: dt > 0 ? a.up / dt : -1,
                fresh: a.fresh,
                local: a.local,
                self: a.name === "qs" || a.name === "quickshell"
            };
        }).sort((x, y) => (y.down + y.up) - (x.down + x.up) || y.conns - x.conns || x.name.localeCompare(y.name));
        const named = {};
        for (const a of list)
            named[a.name] = a;
        byName = named;
        apps = list;
        root.others = others;
        last = seen;
        lastAt = now;
        ready = true;
    }

    // ---- what can be done about one

    readonly property string script: `${Quickshell.shellDir}/scripts/netapp.sh`

    // asks it to quit (SIGTERM: it can still save), the whole program, not only the process that
    // held the connection (a browser's network process would just be started again)
    function kill(app: var): void {
        if (app?.pids?.length && !app.self)
            Quickshell.execDetached(["sh", script, "kill", ...app.pids.map(String)]);
    }

    // which launcher entry starts it: cb(id), "" when it can't be told. Remembered per name
    property var entries: ({}) // program name -> entry id
    property var findCb: null
    property string finding: ""

    function findEntry(app: var, list: var, cb: var): void {
        if (entries[app.name] !== undefined) {
            cb(entries[app.name]);
            return;
        }
        // another one is being looked up this very moment (or no process to look at): can't
        // tell now, rather than no answer at all
        if (finder.running || !app.pids.length) {
            cb("");
            return;
        }
        finding = app.name;
        findCb = cb;
        const args = ["sh", script, "find", String(app.pids[0])];
        for (const e of list)
            if (e.command?.length)
                args.push(e.id, e.command[0]);
        finder.command = args;
        finder.running = true;
    }

    Process {
        id: finder

        stdout: StdioCollector {
            onStreamFinished: {
                const id = text.trim();
                root.entries = Object.assign({}, root.entries, { [root.finding]: id });
                const cb = root.findCb;
                root.findCb = null;
                if (cb)
                    cb(id);
            }
        }
    }
}
