import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services
import qs.utils

//  ┌─spotify──────────────────────────────── esc┐
//  │ [spotify]  firefox   mpv                  │  tabs: which player the bar and the keys follow
//  │ ▓▒░▓▒░  now playing                       │
//  │ ░▓▒░▓▒  teardrop                          │  the cover in phosphor pixels (CrtCover.qml)
//  │ ▒░▓▒░▓  massive attack · mezzanine        │
//  │         1:42 ▮▮▮▮▮▮▮▮▮▯▯▯▯▯▯▯▯ 5:29       │  click / drag / wheel to seek; the red one is now
//  │ [|<] [||] [>|]   [shuffle] [loop: all]          │  || red while it plays
//  │ ▂▅▇▅▂▁▂▅▇▅▂▁▂▅▇▅▂▁▂▅▇▅▂                   │  cava, only while this is open
//  │ vol ▮▮▮▮▮▮▮▮▮▮▯▯▯▯▯▯▯▯▯▯  50%              │  this player's own volume
//  │ -- earlier · click copies --              │
//  │ artist — title ···················· spotify│  this session's tracks
//  │ [space] play [←→] seek [↑↓] vol [n p] next [s] [r] [tab]
Popover {
    id: root

    readonly property list<MprisPlayer> players: Media.players
    readonly property MprisPlayer player: Media.player
    // covers online (spotify's) only when allowed: kawt fetches nothing by itself otherwise
    readonly property string art: player?.trackArtUrl ?? ""
    readonly property bool artOnline: /^https?:/i.test(art)
    // where a drag on the position would put it, in seconds; -1 = no drag
    property real dragTo: -1
    readonly property real shownPos: dragTo >= 0 ? dragTo : (player?.position ?? 0)

    name: "player"
    title: root.player ? Media.name(root.player) : "player"
    cardWidth: 440

    // MPRIS doesn't push position updates; poll while visible
    Timer {
        running: root.open && (root.player?.isPlaying ?? false)
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    // ---- this player's volume: its sound stream in pipewire, or its own (mpris) volume
    readonly property list<PwNode> streams: open ? Pipewire.nodes.values.filter(n => n.isStream && n.audio) : []
    readonly property PwNode stream: {
        if (!player)
            return null;
        const names = [player.desktopEntry, Media.base(Media.key(player)), player.identity].filter(s => s).map(s => s.toLowerCase());
        return streams.find(n => {
            const p = n.properties ?? {};
            if ((p["media.class"] ?? "").includes("Input"))
                return false; // a recording, not what it plays
            const app = [p["application.process.binary"], p["application.name"], p["application.id"]].filter(s => s && s.length >= 3).map(s => s.toLowerCase());
            return app.some(a => names.some(m => a === m || a.startsWith(m) || m.startsWith(a)));
        }) ?? null;
    }
    readonly property bool streamVolume: stream?.audio ? true : false
    readonly property bool ownVolume: !streamVolume && (player?.volumeSupported ?? false) && (player?.canControl ?? false)
    readonly property real volume: streamVolume ? stream.audio.volume : ownVolume ? player.volume : 0

    PwObjectTracker {
        objects: root.streams
    }

    // up to 100%; one above that (set in pavucontrol) stays, like the main volume (services/Audio.qml)
    function setVolume(v: real): void {
        v = Math.max(0, Math.min(Math.max(1, volume), v));
        if (streamVolume) {
            stream.audio.muted = false;
            stream.audio.volume = v;
        } else if (ownVolume) {
            player.volume = v;
        }
    }

    function cycleLoop(): void {
        if (!player?.loopSupported)
            return;
        // off -> all -> one -> off
        player.loopState = player.loopState === MprisLoopState.None ? MprisLoopState.Playlist : player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
    }

    function toggleShuffle(): void {
        if (player?.shuffleSupported)
            player.shuffle = !player.shuffle;
    }

    function nextPlayer(step: int): void {
        if (players.length < 2)
            return;
        const i = players.indexOf(player);
        Media.pick(players[(i + step + players.length) % players.length]);
    }

    onCardKey: event => {
        const shift = event.modifiers & Qt.ShiftModifier;
        switch (event.key) {
        case Qt.Key_Space:
            Media.command("toggle");
            break;
        case Qt.Key_Left:
            Media.seekBy(shift ? -30 : -5);
            break;
        case Qt.Key_Right:
            Media.seekBy(shift ? 30 : 5);
            break;
        case Qt.Key_Up:
            setVolume(volume + 0.05);
            break;
        case Qt.Key_Down:
            setVolume(volume - 0.05);
            break;
        case Qt.Key_N:
            Media.command("next");
            break;
        case Qt.Key_P:
            Media.command("prev");
            break;
        case Qt.Key_S:
            toggleShuffle();
            break;
        case Qt.Key_R:
            cycleLoop();
            break;
        case Qt.Key_Tab:
            nextPlayer(1);
            break;
        case Qt.Key_Backtab:
            nextPlayer(-1);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    // ---- which player: two firefoxes are "firefox" and "firefox 2"
    Tabs {
        visible: root.players.length > 1
        tabs: {
            const seen = {};
            return root.players.map(p => {
                const n = Media.name(p);
                seen[n] = (seen[n] ?? 0) + 1;
                return seen[n] > 1 ? `${n} ${seen[n]}` : n;
            });
        }
        current: root.players.indexOf(root.player)
        onCurrentChanged: {
            const p = root.players[current];
            if (p && p !== root.player)
                Media.pick(p);
            current = Qt.binding(() => root.players.indexOf(root.player));
        }
    }

    // ---- the cover, then what's playing and where it is
    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.padding * 2

        CrtCover {
            id: cover

            Layout.alignment: Qt.AlignTop
            source: root.artOnline && !Settings.playerNetCovers ? "" : root.art
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: cover.implicitHeight
            spacing: 2

            Label {
                text: !root.player ? "no media" : root.player.isPlaying ? "now playing" : "paused"
                color: Colors.dim
                font.pixelSize: Metrics.fontSize - 2
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                visible: root.player !== null
                text: root.player?.trackTitle || "nothing playing"
                font.pixelSize: Math.round(Metrics.fontSize * 1.35)
                font.weight: Font.Medium
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                visible: text !== ""
                text: root.player?.trackArtist ?? ""
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                visible: text !== ""
                text: root.player?.trackAlbum ?? ""
                color: Colors.dim
            }

            // spotify's covers are on its servers: fetched only once you say so (profile -> cfg)
            BracketButton {
                Layout.topMargin: 2
                visible: root.artOnline && !Settings.playerNetCovers
                tag: "cover"
                label: "load from the net"
                onClicked: Settings.playerNetCovers = true
            }

            Item {
                Layout.fillHeight: true
            }

            // ---- the position: click, drag or wheel (5 s a notch) on the segments; the red
            // one is where it is now
            RowLayout {
                Layout.fillWidth: true
                visible: Media.hasLength
                spacing: Metrics.spacing

                Label {
                    text: Fmt.mmss(root.shownPos)
                    color: root.dragTo >= 0 ? Colors.fg : Colors.dim
                }

                LevelSlider {
                    Layout.fillWidth: true
                    enabled: root.player?.canSeek ?? false
                    playhead: true
                    value: root.shownPos / (root.player?.length || 1)
                    wheelStep: 5 / (root.player?.length || 1)
                    onMoved: v => root.dragTo = v * (root.player?.length ?? 0)
                    onReleased: {
                        if (root.dragTo >= 0 && root.player) {
                            root.player.position = Math.min(root.dragTo, root.player.length - 1);
                            root.player.positionChanged();
                        }
                        root.dragTo = -1;
                    }
                }

                Label {
                    text: Fmt.mmss(root.player?.length)
                    color: Colors.dim
                }
            }
        }
    }

    // ---- play, and how (seeking: the segments above, or ←→)
    Flow {
        Layout.fillWidth: true
        spacing: Metrics.spacing

        BracketButton {
            label: "|<"
            textColor: root.player?.canGoPrevious ? Colors.fg : Colors.dim
            onClicked: Media.command("prev")
        }

        // red while it plays
        BracketButton {
            label: root.player?.isPlaying ? "||" : ">"
            textColor: root.player?.isPlaying ? Colors.accent : Colors.fg
            onClicked: Media.command("toggle")
        }

        BracketButton {
            label: ">|"
            textColor: root.player?.canGoNext ? Colors.fg : Colors.dim
            onClicked: Media.command("next")
        }

        Item {
            width: Metrics.padding
            height: 1
        }

        BracketButton {
            visible: root.player?.shuffleSupported ?? false
            label: "shuffle"
            textColor: root.player?.shuffle ? Colors.accent : Colors.dim
            onClicked: root.toggleShuffle()
        }

        BracketButton {
            visible: root.player?.loopSupported ?? false
            label: "loop: " + (root.player?.loopState === MprisLoopState.Track ? "one" : root.player?.loopState === MprisLoopState.Playlist ? "all" : "off")
            textColor: root.player?.loopState !== MprisLoopState.None ? Colors.accent : Colors.dim
            onClicked: root.cycleLoop()
        }
    }

    // ---- the spectrum: cava runs wide while this is open (services/Cava.qml); blocks stacked
    // like an old level meter: grey bars with a bright cap, lines in the card's color across them
    Item {
        id: spectrum

        readonly property int seg: Math.max(3, Math.round(4 * Metrics.scale))
        readonly property real gap: 2
        readonly property real barW: (width - gap * (Cava.wideBars - 1)) / Cava.wideBars

        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        visible: Cava.available && root.player !== null
        implicitHeight: Cava.wideMax * seg

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Colors.border
        }

        Repeater {
            model: Cava.wideBars

            Rectangle {
                required property int index

                x: index * (spectrum.barW + spectrum.gap)
                width: spectrum.barW
                height: (Cava.wideLevels[index] ?? 0) * spectrum.seg
                anchors.bottom: parent.bottom
                color: Colors.dim

                Rectangle {
                    width: parent.width
                    height: Math.min(parent.height, spectrum.seg)
                    color: Colors.fg
                }
            }
        }

        Repeater {
            model: Cava.wideMax - 1

            Rectangle {
                required property int index

                y: (index + 1) * spectrum.seg - 1
                width: spectrum.width
                height: 1
                color: Colors.bg
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.streamVolume || root.ownVolume
        spacing: Metrics.spacing

        Label {
            text: "vol"
            color: Colors.dim
        }

        LevelSlider {
            Layout.fillWidth: true
            value: root.volume
            onMoved: v => root.setVolume(v)
        }

        Label {
            text: `${Math.round(root.volume * 100)}%`.padStart(4)
            color: Colors.dim
        }
    }

    // ---- this session's tracks (kept in memory only), the one playing left out
    ColumnLayout {
        id: earlier

        readonly property var tracks: Media.history.filter(t => `${t.artist}\n${t.title}` !== Media.now).slice(0, 5)
        property int copied: -1

        Layout.fillWidth: true
        visible: tracks.length > 0
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacing
            Layout.bottomMargin: Metrics.spacing
            implicitHeight: Metrics.borderWidth
            color: Colors.border
        }

        Label {
            text: "-- earlier · click copies --"
            color: Colors.dim
            font.pixelSize: Metrics.fontSize - 2
        }

        Repeater {
            model: earlier.tracks

            Item {
                id: track

                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: line.implicitHeight + 2

                Rectangle {
                    anchors.fill: parent
                    visible: area.containsMouse
                    color: Colors.hoverFill
                }

                // artist — title ··········· spotify
                RowLayout {
                    anchors.fill: parent
                    spacing: Metrics.spacing

                    Label {
                        id: line

                        Layout.maximumWidth: track.width - from.implicitWidth - Metrics.spacing * 4
                        elide: Text.ElideRight
                        text: earlier.copied === track.index ? "copied" : Media.line(track.modelData)
                        color: earlier.copied === track.index ? Colors.accent : Colors.fg
                    }

                    Leader {
                        Layout.fillWidth: true
                    }

                    Label {
                        id: from

                        text: track.modelData.player
                        color: Colors.dim
                        font.pixelSize: Metrics.fontSize - 2
                    }
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.clipboardText = Media.line(track.modelData);
                        earlier.copied = track.index;
                        copiedGone.restart();
                    }
                }
            }
        }

        Timer {
            id: copiedGone

            interval: 1200
            onTriggered: earlier.copied = -1
        }
    }

    // ---- the keys, like a bios's legend: [key] what it does
    Flow {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        visible: root.player !== null
        spacing: Metrics.padding

        Repeater {
            model: [["space", "play"], ["←→", "5 s"], ["↑↓", "vol"], ["n p", "next"], ["s", "shuffle"], ["r", "loop"], ...(root.players.length > 1 ? [["tab", "player"]] : [])]

            Row {
                required property var modelData

                spacing: 4

                Brackets {
                    text: modelData[0]
                    font.pixelSize: Metrics.fontSize - 2
                }

                Label {
                    text: modelData[1]
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
                }
            }
        }
    }
}
