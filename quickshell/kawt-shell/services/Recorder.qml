pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Screen recording (scripts/record.sh, wf-recorder). One at a time: start() while recording
// stops it instead. The bar shows [● rec 0:42] meanwhile.
//   qs -c kawt-shell ipc call kawt record region|screen
Singleton {
    id: root

    readonly property bool recording: proc.running
    property string file: ""
    property real started: 0
    property int elapsed: 0 // seconds
    property string pending: ""

    function toggle(mode: string): void {
        if (recording) {
            stop();
            return;
        }
        Panels.close(); // keep kawt's panels out of the video
        pending = mode || "region";
        delay.restart();
    }

    function stop(): void {
        if (recording)
            proc.signal(2); // SIGINT: wf-recorder finishes the file and exits
    }

    Timer {
        id: delay

        interval: 200
        onTriggered: {
            root.file = `${Settings.expand(Settings.recordDir)}/${Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss")}.mp4`;
            proc.command = ["sh", `${Quickshell.shellDir}/scripts/record.sh`, root.pending, root.file, Colors.palette.accent + "ff", Colors.palette.bg + "88", Settings.recordAudio ? "1" : "0"];
            root.elapsed = 0;
            root.started = Date.now();
            proc.running = true;
        }
    }

    Timer {
        running: root.recording
        repeat: true
        interval: 1000
        onTriggered: root.elapsed = Math.round((Date.now() - root.started) / 1000)
    }

    Process {
        id: proc

        onExited: code => {
            // 3 = the area selection was cancelled: nothing was recorded
            if (code !== 3)
                Quickshell.execDetached(["sh", "-c", 'if [ -s "$1" ]; then notify-send -a recording "recording saved" "${1#"$HOME"/}"; else notify-send -a recording -u critical "recording failed" "is wf-recorder installed?"; fi', "sh", root.file]);
        }
    }
}
