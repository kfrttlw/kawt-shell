pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The system kawt runs on, from /etc/os-release, and the start button's logo for it: one of
// kawt's own pixel ones (utils/pixicons.js, distro-<id>) for the systems below, kawt's red block
// for every other. Settings.startLogo picks one by hand ("kawt" the block, or an id), for a
// system that says it's another, or a taste of your own; "auto" (the standard) looks.
// Only a system's own ID counts, not what it's based on: EndeavourOS isn't Arch, so it keeps
// kawt's block (or picks the Arch logo by hand).
Singleton {
    id: root

    readonly property var known: ["arch", "debian", "gentoo", "fedora", "ubuntu", "nixos", "manjaro"]
    readonly property var names: ({ arch: "Arch", debian: "Debian", gentoo: "Gentoo", fedora: "Fedora", ubuntu: "Ubuntu", nixos: "NixOS", manjaro: "Manjaro" })
    property string id: "" // os-release's ID: "arch", "debian"...
    property string name: "" // its PRETTY_NAME
    readonly property string found: known.includes(id) ? id : "" // one kawt has a logo for
    readonly property string picked: Settings.startLogo === "auto" ? found : known.includes(Settings.startLogo) ? Settings.startLogo : ""
    readonly property string logo: picked ? `distro-${picked}` : "logo" // the icon's name

    FileView {
        path: "/etc/os-release"
        printErrors: false
        onLoaded: {
            const t = text();
            root.id = ((t.match(/^ID="?([^"\n]*)/m) ?? [])[1] ?? "").toLowerCase();
            root.name = (t.match(/^PRETTY_NAME="?([^"\n]*)/m) ?? [])[1] ?? "";
        }
    }
}
