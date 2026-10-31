import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.utils

// The wifi panel's [who's out] page: who talks to the internet right now (services/NetWho.qml).
// It exists only while it's shown, and only then is anything looked at.
//
//   goes out now                                        [lan]
//   firefox          12  140.82.112.3:443 +11   ↓ 1.2M ↑  34K  [!]
//     [kill] [offline]    closes it · no internet from its next start
//   telegram          2  149.154.167.51:443     ↓   3K ↑   1K  [!]
//   ?                 3  system services, other users: sudo tools/net.sh
//   ───────────────────────────────────────────────────────────
//   no net: [firefox x] [steam x]
//   kawt itself: one git fetch a week (the update check)
//
// A new connection turns its program red until the next look. [kill] asks once more, then the
// program is asked to quit; [offline]: started from the launcher or the dock it gets no internet
// from then on (ctrl+o in the launcher does the same)
ColumnLayout {
    id: root

    property string opened: "" // the program whose [!] is open
    property bool armed: false // [kill] pressed once: once more and it's asked to quit
    property string status: ""
    readonly property real charW: Metrics.fontSize * 0.6

    spacing: 2

    Component.onCompleted: NetWho.watching = true
    Component.onDestruction: NetWho.watching = false

    function toggle(name: string): void {
        opened = opened === name ? "" : name;
        armed = false;
        status = "";
    }

    function offline(a: var): void {
        status = "looking for its launcher entry...";
        NetWho.findEntry(a, Apps.apps, id => {
            if (!id) {
                root.status = `can't tell which app starts ${a.name}: mark it in the launcher (ctrl+o)`;
                return;
            }
            const on = !Apps.offline.includes(id);
            Apps.setOffline(id, on);
            root.status = on ? `${Apps.nameOf(id).toLowerCase()}: no internet from its next start (close it first)` : `${Apps.nameOf(id).toLowerCase()}: internet again from its next start`;
        });
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing

        Label {
            Layout.fillWidth: true
            text: NetWho.missing ? "ss is missing (it comes with iproute2)" : "goes out now"
            color: NetWho.missing ? Colors.warn : Colors.dim
        }

        BracketButton {
            label: "lan"
            textColor: NetWho.lan ? Colors.accent : Colors.dim
            onClicked: NetWho.lan = !NetWho.lan
        }
    }

    Label {
        visible: NetWho.ready && NetWho.apps.length === 0 && NetWho.others === 0
        text: "nothing goes out right now"
        color: Colors.dim
    }

    // by name: a new look moves the rows instead of making them again (an open [!] stays open)
    Repeater {
        model: ScriptModel {
            values: NetWho.apps.map(a => a.name)
        }

        ColumnLayout {
            id: row

            required property string modelData
            readonly property var app: NetWho.byName[modelData] ?? null
            readonly property bool isOpen: root.opened === modelData

            Layout.fillWidth: true
            visible: app !== null
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacing

                Label {
                    Layout.preferredWidth: root.charW * 15
                    elide: Text.ElideRight
                    text: row.modelData
                    color: row.app?.fresh || row.isOpen ? Colors.accent : Colors.fg
                }

                Label {
                    Layout.preferredWidth: root.charW * 3
                    horizontalAlignment: Text.AlignRight
                    text: row.app?.conns ?? ""
                    color: Colors.dim
                }

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    text: row.app ? row.app.peer + (row.app.more > 0 ? ` +${row.app.more}` : "") + (row.app.local ? " lan" : "") : ""
                    color: Colors.dim
                }

                // fast ones in ink, the rest grey
                Label {
                    text: !row.app || row.app.down < 0 || row.app.down + row.app.up === 0 ? "" : `↓${Fmt.rate(row.app.down)} ↑${Fmt.rate(row.app.up)}`
                    color: row.app && row.app.down + row.app.up > 100 * 1024 ? Colors.fg : Colors.dim
                }

                BracketButton {
                    visible: !row.app?.self
                    label: "!"
                    active: row.isOpen
                    onClicked: root.toggle(row.modelData)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(root.charW * 2)
                visible: row.isOpen
                spacing: Metrics.spacing

                BracketButton {
                    label: root.armed ? "sure? kill" : "kill"
                    textColor: root.armed ? Colors.warn : Colors.fg
                    onClicked: {
                        if (!root.armed) {
                            root.armed = true;
                            root.status = "anything unsaved in it is lost";
                            return;
                        }
                        NetWho.kill(row.app);
                        root.status = `${row.modelData} asked to quit`;
                        root.opened = "";
                        root.armed = false;
                    }
                }

                BracketButton {
                    readonly property string entry: NetWho.entries[row.modelData] ?? ""

                    label: "offline"
                    textColor: entry && Apps.offline.includes(entry) ? Colors.accent : Colors.fg
                    onClicked: root.offline(row.app)
                }

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: "close it · no internet from its next start"
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
                }
            }
        }
    }

    // programs of other users and system services (networkmanager, updates, time) can't be told
    // apart without root
    RowLayout {
        Layout.fillWidth: true
        visible: NetWho.others > 0
        spacing: Metrics.spacing

        Label {
            Layout.preferredWidth: root.charW * 15
            text: "?"
            color: Colors.dim
        }

        Label {
            Layout.preferredWidth: root.charW * 3
            horizontalAlignment: Text.AlignRight
            text: NetWho.others
            color: Colors.dim
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: "system services (sudo tools/net.sh)"
            color: Colors.dim
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.status !== ""
        wrapMode: Text.Wrap
        text: root.status
        color: root.armed ? Colors.warn : Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        implicitHeight: Metrics.borderWidth
        color: Colors.border
    }

    // the apps started without internet; a click gives it back
    Flow {
        Layout.fillWidth: true
        spacing: Metrics.spacing

        Label {
            height: Metrics.barHeight - Metrics.spacing // as tall as the buttons beside it
            verticalAlignment: Text.AlignVCenter
            text: Apps.offline.length ? "no net:" : "no net: none yet (launcher: ctrl+o)"
            color: Colors.dim
        }

        Repeater {
            model: Apps.offline

            BracketButton {
                required property string modelData

                label: `${Apps.nameOf(modelData).toLowerCase()} x`
                onClicked: Apps.setOffline(modelData, false)
            }
        }
    }

    // what kawt itself sends
    Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: {
            const out = [Settings.updateAuto ? "one git fetch a week (update check)" : "", Settings.aiProvider === "api" ? "the ai panel, to your api" : ""].filter(s => s);
            return `kawt itself: ${out.join(", ") || "nothing"}`;
        }
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }
}
