import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.config
import qs.services

// kawt's lock screen (ext-session-lock). The password is checked by the system's own
// PAM "login" stack, the same one swaylock and hyprlock use.
//
//   qs -c kawt-shell ipc call kawt lockTest   locks, and unlocks by itself after 30 s: try this first
//   qs -c kawt-shell ipc call kawt lock       the real thing
Scope {
    id: root

    // how the last try went: "" | "checking" | "denied" | "tries" (too many) | "error"; status
    // says it in words
    property string result: ""
    property string pamMessage: ""
    readonly property string status: result === "" ? "" : result === "checking" ? Strings.t("lockChecking") : result === "denied" ? Strings.t("lockDenied").arg(fails) : result === "tries" ? Strings.t("lockTooMany") : Strings.t("lockPamError").arg(pamMessage || "unknown")
    property int fails: 0
    // the right password: the lock switches off like an old tube first (LockSurface.qml says
    // when it's done; a second at most), then it's gone
    property bool leaving: false
    property string pending: "" // the password, until PAM asks for it
    property int testLeft: 0

    readonly property bool checking: pam.active

    function tryUnlock(password: string): void {
        if (pam.active || password === "")
            return;
        pending = password;
        result = "checking";
        pam.start();
    }

    function unlock(): void {
        pam.abort();
        leaveTimeout.stop();
        leaving = false;
        pending = "";
        result = "";
        fails = 0;
        testLeft = 0;
        Panels.lockTest = false;
        Panels.locked = false;
    }

    function leave(): void {
        if (!Settings.crt) {
            unlock();
            return;
        }
        result = "";
        leaving = true;
        leaveTimeout.restart();
    }

    // never stuck behind an animation that didn't end
    Timer {
        id: leaveTimeout

        interval: 1000
        onTriggered: root.unlock()
    }

    Connections {
        target: Panels

        function onLockedChanged(): void {
            if (Panels.locked) {
                Panels.close(); // popovers would sit above nothing
                root.result = "";
                root.testLeft = Panels.lockTest ? 30 : 0;
            }
        }

        // a real lock (super+l) during a test makes it real: no unlocking by itself.
        // (the other way round never happens: a test can't turn a real lock into one)
        function onLockTestChanged(): void {
            if (Panels.locked && !Panels.lockTest)
                root.testLeft = 0;
        }
    }

    // test mode: unlock on a timer no matter what, so a broken setup can't lock you out
    Timer {
        running: root.testLeft > 0
        repeat: true
        interval: 1000
        onTriggered: {
            root.testLeft--;
            if (root.testLeft <= 0)
                root.unlock();
        }
    }

    PamContext {
        id: pam

        // default config "login" from /etc/pam.d

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            respond(root.pending);
            root.pending = "";
        }

        onCompleted: result => {
            root.pending = "";
            if (result === PamResult.Success) {
                root.leave();
            } else {
                root.fails++;
                root.pamMessage = message || "";
                root.result = result === PamResult.MaxTries ? "tries" : result === PamResult.Error ? "error" : "denied";
            }
        }
    }

    // Panels.suspend(): sleep only once the lock is really on (the compositor confirmed it), so
    // the machine never wakes up to an open desktop. If the lock doesn't come within 5 s it
    // stays awake: better than sleeping unlocked.
    function trySuspend(): void {
        if (!Panels.suspendAfterLock || !lock.secure)
            return;
        Panels.suspendAfterLock = false;
        suspendTimeout.stop();
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    Connections {
        target: Panels

        function onSuspendAfterLockChanged(): void {
            if (Panels.suspendAfterLock)
                suspendTimeout.restart();
            root.trySuspend();
        }
    }

    Timer {
        id: suspendTimeout

        interval: 5000
        onTriggered: Panels.suspendAfterLock = false
    }

    WlSessionLock {
        id: lock

        locked: Panels.locked
        onSecureChanged: {
            Panels.lockSecure = secure;
            root.trySuspend();
        }

        LockSurface {
            lockScope: root
        }
    }
}
