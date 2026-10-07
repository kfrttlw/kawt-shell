pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Volume and mic for the media keys (ipc: kawt volume up|down|mute, kawt mic mute).
// The bar and the osd read pipewire themselves; this is only the writing side.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    function step(delta: real): void {
        if (!sink?.audio)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + delta));
    }

    function toggleMute(): void {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleMicMute(): void {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    // pipewire nodes can only be changed while tracked
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n)
    }
}
