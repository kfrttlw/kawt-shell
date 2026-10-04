import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import "../popovers"

//   ____________
//  | >_         |
//  ...                         12:34
//                       sat 03.10.2026
//  kawt-lock on tty · user@host
//  password: ********█
//  [!] access denied (1)
WlSessionLockSurface {
    id: root

    required property var lockScope

    color: Colors.bg

    // the wallpaper, barely there, like a picture burned into an old CRT
    Image {
        anchors.fill: parent
        source: Settings.wallpaper ? `file://${Settings.wallpaper}` : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 1280
        opacity: 0.12
    }

    // clicking anywhere gives the keyboard back to the password field
    MouseArea {
        anchors.fill: parent
        onClicked: password.input.forceActiveFocus()
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(460, root.width - 40)
        spacing: Metrics.spacing

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Metrics.padding * 2

            DeviceArt {
                laptop: SysInfo.laptop
                blink: true
            }

            Item {
                Layout.fillWidth: true
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignBottom
                spacing: 0

                Label {
                    Layout.alignment: Qt.AlignRight
                    text: Time.fmt(Time.now)
                    font.pixelSize: Metrics.fontSize * 4
                }

                Label {
                    Layout.alignment: Qt.AlignRight
                    text: Qt.formatDate(Time.now, "ddd dd.MM.yyyy").toLowerCase()
                    color: Colors.dim
                }
            }
        }

        Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: `kawt-lock · ${SysInfo.user}@${SysInfo.host}`
            color: Colors.accent
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Metrics.borderWidth
            color: Colors.border
        }

        TermInput {
            id: password

            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            prompt: "password:"
            placeholder: "type to unlock"
            echoMode: TextInput.Password
            onAccepted: t => {
                root.lockScope.tryUnlock(t);
                password.text = "";
            }

            Keys.onEscapePressed: password.text = ""
        }

        Label {
            Layout.fillWidth: true
            visible: text !== ""
            wrapMode: Text.Wrap
            text: root.lockScope.status === "" ? "" : (root.lockScope.status.startsWith("checking") ? "" : "[!] ") + root.lockScope.status
            color: root.lockScope.status.startsWith("checking") ? Colors.dim : Colors.warn
        }

        Label {
            Layout.fillWidth: true
            visible: root.lockScope.testLeft > 0
            text: `-- test mode: unlocks by itself in ${root.lockScope.testLeft}s --`
            color: Colors.dim
        }
    }

    Component.onCompleted: password.input.forceActiveFocus()
}
