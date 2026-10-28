pragma Singleton
import Quickshell

// kawt's own release, for the boot screen and the profile's sys tab ("kawt bios 1.0"). The commit
// you're on is in profile -> cfg -> kawt (services/Update.qml)
Singleton {
    readonly property string version: "1.0"
}
