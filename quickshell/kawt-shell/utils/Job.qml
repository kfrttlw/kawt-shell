import QtQuick
import Quickshell.Io

// A Process that reports once, with its exit code and its whole output:
//   Job { id: job; onDone: (code, out) => ... }   job.command = [...]; job.running = true
// `exited` alone can come before the last of stdout is read, and then the output is cut short
// (services/Wallpapers.qml ran into that). This waits for both. If the output's end never
// shows up, it reports 300 ms after the exit with what it has.
// (onRunningChanged / onExited are taken here; users get onStarted and onDone)
Process {
    id: root

    property int code: -1
    property bool outDone: false
    property bool reported: true
    readonly property string out: collector.text

    signal done(int code, string out)

    function report(): void {
        if (reported || code < 0 || !outDone)
            return;
        reported = true;
        drain.stop();
        done(code, collector.text);
    }

    // a fresh start: forget the last run
    onRunningChanged: if (running) {
        drain.stop();
        code = -1;
        outDone = false;
        reported = false;
    }

    onExited: c => {
        code = c;
        drain.restart();
        report();
    }

    stdout: StdioCollector {
        id: collector

        onStreamFinished: {
            root.outDone = true;
            root.report();
        }
    }

    property Timer drain: Timer {
        interval: 300
        onTriggered: {
            root.outDone = true;
            root.report();
        }
    }
}
