import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.utils

// The start menu's bottom line: who you are and how long the machine has been up, then the power
// buttons. Lock and sleep at once; log out, reboot and off ask once more (a second click within
// 3 s), as the profile's sys tab does.
RowLayout {
    id: root

    property string armed: ""
    // [what, the word on it]
    readonly property var actions: [["lock", "lock"], ["sleep", "sleep"], ["logout", "log out"], ["reboot", "reboot"], ["off", "turn off"]]

    function power(action: string): void {
        if (action === "lock" || action === "sleep" || armed === action) {
            armed = "";
            Panels.close();
            if (action === "lock")
                Panels.lock(false);
            else if (action === "sleep")
                Panels.suspend(); // locks first: never wake up to an open desktop
            else if (action === "logout")
                Hypr.exit();
            else
                Quickshell.execDetached(["systemctl", action === "off" ? "poweroff" : "reboot"]);
        } else {
            armed = action;
            disarm.restart();
        }
    }

    spacing: Metrics.spacing

    Timer {
        id: disarm

        interval: 3000
        onTriggered: root.armed = ""
    }

    Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: `${SysInfo.user}@${SysInfo.host || "kawt"} · up ${Fmt.uptime(SysInfo.uptime)}`
        color: Colors.dim
    }

    Repeater {
        model: root.actions

        BracketButton {
            required property var modelData
            readonly property bool asking: root.armed === modelData[0]

            label: asking ? "sure?" : modelData[1]
            textColor: asking ? Colors.warn : Colors.fg
            onClicked: root.power(modelData[0])
        }
    }
}
