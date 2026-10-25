pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.config

// The player kawt shows and the media keys control: the bar's player button, its popover, the
// lock screen and `kawt media` all follow the same one.
// It's the one picked in the popover's tabs, until another one starts playing: then that one
// (the last one started wins, so play / pause goes to what you were listening to, not to
// whatever player happens to be first). The pick is remembered (Settings.mediaPlayer).
//   qs -c kawt-shell ipc call kawt media toggle|play|pause|next|prev|stop|back|forward
// Also the tracks played this session, in memory only (gone with a restart, never written).
Singleton {
    id: root

    readonly property list<MprisPlayer> players: Mpris.players.values
    property string chosen: Settings.mediaPlayer // until a player starts by itself
    readonly property MprisPlayer player: players.find(p => key(p) === chosen) ?? players.find(p => base(key(p)) === base(chosen)) ?? players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool hasLength: (player?.lengthSupported ?? false) && player.length > 0

    // "spotify", "firefox.instance_1_84": the bus name without the mpris part
    function key(p: MprisPlayer): string {
        return (p?.dbusName ?? "").replace(/^org\.mpris\.MediaPlayer2\./, "") || p?.desktopEntry || p?.identity || "";
    }

    // the same player after a restart: "firefox.instance_1_84" -> "firefox"
    function base(k: string): string {
        return k.replace(/\.instance\S*$/, "");
    }

    // a short name for its tab: "spotify", "firefox", "mpv"
    function name(p: MprisPlayer): string {
        return (p?.desktopEntry || p?.identity || base(key(p)) || "player").toLowerCase().replace(/^org\.[^.]+\./, "");
    }

    function pick(p: MprisPlayer): void {
        if (!p)
            return;
        chosen = key(p);
        Settings.mediaPlayer = chosen;
    }

    // another player started: it becomes the one
    readonly property list<string> playing: players.filter(p => p.isPlaying).map(p => key(p))
    property list<string> lastPlaying: []
    onPlayingChanged: {
        const fresh = playing.find(k => !lastPlaying.includes(k));
        lastPlaying = playing;
        if (fresh && fresh !== chosen)
            chosen = fresh;
    }

    function seekBy(seconds: real): void {
        const p = player;
        if (!p?.canSeek)
            return;
        const end = root.hasLength ? p.length : Infinity;
        p.position = Math.max(0, Math.min(end - 1, p.position + seconds));
        p.positionChanged();
    }

    function command(what: string): void {
        const p = player;
        if (!p)
            return;
        switch (what) {
        case "toggle":
        case "play-pause":
            if (p.canTogglePlaying)
                p.togglePlaying();
            break;
        case "play":
            if (!p.isPlaying && p.canTogglePlaying)
                p.togglePlaying();
            break;
        case "pause":
        case "stop":
            if (p.isPlaying && p.canTogglePlaying)
                p.togglePlaying();
            break;
        case "next":
            if (p.canGoNext)
                p.next();
            break;
        case "prev":
        case "previous":
            if (p.canGoPrevious)
                p.previous();
            break;
        case "back":
            seekBy(-10);
            break;
        case "forward":
            seekBy(10);
            break;
        }
    }

    // ---- this session's tracks, newest first: { artist, title, player }
    readonly property int historyMax: 10
    property var history: []
    readonly property string now: player?.isPlaying && player.trackTitle ? `${player.trackArtist ?? ""}\n${player.trackTitle}` : ""
    onNowChanged: {
        if (!now || history.length > 0 && `${history[0].artist}\n${history[0].title}` === now)
            return;
        history = [
            {
                artist: player.trackArtist ?? "",
                title: player.trackTitle,
                player: name(player)
            },
            ...history.filter(t => `${t.artist}\n${t.title}` !== now)
        ].slice(0, historyMax);
    }

    function line(t: var): string {
        return [t.artist, t.title].filter(s => s).join(" — ");
    }

    Component.onCompleted: lastPlaying = playing
}
