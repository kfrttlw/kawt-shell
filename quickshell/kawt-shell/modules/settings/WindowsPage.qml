import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Settings -> Windows and desks: apps at their own size (they float from the start, in the
// middle, at the size they ask for: services/Hypr.qml writes the list, hypr/kawt.lua the rules);
// free desks are a right click on a desk's number
ColumnLayout {
    id: page

    required property ShellScreen forScreen

    spacing: 10

    PageHead {
        title: Strings.t("pageWindows")
        note: Strings.t("windowsNote")
    }

    Group {
        title: Strings.t("ownSize")

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Strings.t("ownSizeNote")
            color: Colors.dim
        }

        Label {
            Layout.fillWidth: true
            visible: !Hypr.lua
            wrapMode: Text.WordWrap
            text: Strings.t("needsLua")
            color: Colors.warn
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            TermInput {
                id: winFind

                Layout.fillWidth: true
                prompt: "find>"
                placeholder: Strings.t("findApp")
            }

            PushButton {
                text: Strings.t("lookAgain")
                onClicked: Hypr.refreshWindows()
            }
        }

        // each app once: the open ones (from hyprland), then the picked ones not open now
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.max(60, apps.implicitHeight + 8)
            color: Colors.well

            Bevel {
                style: "sunk"
            }

            ColumnLayout {
                id: apps

                readonly property var list: {
                    const seen = {}, out = [], q = winFind.text.trim().toLowerCase();
                    for (const w of Hypr.windows) {
                        const c = Hypr.classOf(w);
                        if (c && !seen[c]) {
                            seen[c] = true;
                            out.push({ cls: c, title: w.title ?? "" });
                        }
                    }
                    for (const c of Hypr.floating)
                        if (!seen[c])
                            out.push({ cls: c, title: Strings.t("notOpen") });
                    return out.filter(a => !q || `${a.cls} ${a.title}`.toLowerCase().includes(q));
                }

                x: 6
                y: 4
                width: parent.width - 12
                spacing: 2
                Component.onCompleted: Hypr.refreshWindows()

                Repeater {
                    model: apps.list

                    Check {
                        required property var modelData

                        Layout.fillWidth: true
                        text: `${modelData.cls}   ${modelData.title}`
                        checked: Hypr.floating.includes(modelData.cls)
                        onToggled: Hypr.setFloating(modelData.cls, !checked)
                    }
                }

                Label {
                    visible: apps.list.length === 0
                    text: winFind.text ? Strings.t("noMatch") : Strings.t("noWindows")
                    color: Colors.dim
                }
            }
        }
    }

    Group {
        title: Strings.t("freeDesks")

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Strings.t("freeDesksNote")
            color: Colors.dim
        }
    }
}
