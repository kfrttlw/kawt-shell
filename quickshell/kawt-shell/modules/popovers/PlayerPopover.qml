import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services
import qs.utils

//  _spotify_________________________________ esc
// | [spotify]  firefox   mpv                 |   tabs: which player the bar and the keys follow
// | ▓▒░▓▒░  title                            |
// | ░▓▒░▓▒  artist                           |   the cover in phosphor pixels (CrtCover.qml)
// | ▒░▓▒░▓  album                            |
// |         [shuffle] [loop: all]            |
// | ▂▅▇▅▂▁▂▅▇▅▂▁▂▅▇▅▂▁▂▅▇▅▂                  |   cava, only while this is open
// |  1:23 [##########--------------]  3:45   |   click / drag / wheel to seek
// |     [-10] [<<] [||] [>>] [+10]           |
// | vol [▮▮▮▮▮▮▮▮▮▮▯▯▯▯▯▯▯▯▯▯]  50%           |   this player's own volume
// | -- earlier --                            |
// | artist — title                   spotify |   this session's tracks; click copies
// | space · ←→ 5 s · ↑↓ vol · n p · s r · tab|
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
    readonly property int innerWidth: cardW - Metrics.padding * 2

    name: "player"
    title: root.player ? Media.name(root.player) : "player"
    cardWidth: 360

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

    TextMetrics {
        id: cell

        font.family: Metrics.fontFamily
        font.pixelSize: Metrics.fontSize
        text: "0"
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

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.padding

        CrtCover {
            Layout.alignment: Qt.AlignTop
            source: root.artOnline && !Settings.playerNetCovers ? "" : root.art
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 2

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: root.player?.trackTitle || (root.player ? "nothing playing" : "no media")
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                visible: text !== ""
                text: root.player?.trackArtist ?? ""
                color: Colors.dim
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
                bordered: false
                onClicked: Settings.playerNetCovers = true
            }

            Item {
                Layout.fillHeight: true
            }

            Flow {
                Layout.fillWidth: true
                spacing: Metrics.spacing
                visible: (root.player?.shuffleSupported ?? false) || (root.player?.loopSupported ?? false)

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
        }
    }

    // ---- the spectrum: cava runs wide while this is open (services/Cava.qml); blocks stacked
    // like an old level meter: the bars, then lines in the card's color across them
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
                color: Colors.accent
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

    // ---- the position: click, drag or wheel inside [####----]
    Label {
        id: seek

        readonly property string total: Fmt.mmss(root.player?.length)
        readonly property string now: Fmt.mmss(root.shownPos).padStart(total.length)
        readonly property int barChars: Math.max(8, Math.floor(root.innerWidth / cell.advanceWidth) - now.length - total.length - 4)
        property real wheelAcc: 0

        visible: Media.hasLength
        text: `${now} [${Fmt.bar(root.shownPos / (root.player?.length || 1), barChars)}] ${total}`
        color: root.dragTo >= 0 ? Colors.fg : Colors.dim

        MouseArea {
            anchors.fill: parent
            enabled: root.player?.canSeek ?? false
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            // x on the bar -> seconds
            function at(x: real): real {
                const start = (seek.now.length + 2) * cell.advanceWidth;
                return Math.max(0, Math.min(1, (x - start) / (seek.barChars * cell.advanceWidth))) * root.player.length;
            }

            onPressed: mouse => root.dragTo = at(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    root.dragTo = at(mouse.x);
            }
            onReleased: {
                if (root.dragTo >= 0 && root.player) {
                    root.player.position = Math.min(root.dragTo, root.player.length - 1);
                    root.player.positionChanged();
                }
                root.dragTo = -1;
            }
            onCanceled: root.dragTo = -1
            // a notch: 5 s (touchpads send small steps: they add up to one)
            onWheel: wheel => {
                seek.wheelAcc += wheel.angleDelta.y;
                while (Math.abs(seek.wheelAcc) >= 120) {
                    Media.seekBy(seek.wheelAcc > 0 ? 5 : -5);
                    seek.wheelAcc -= Math.sign(seek.wheelAcc) * 120;
                }
            }
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Metrics.spacing

        BracketButton {
            visible: root.player?.canSeek ?? false
            label: "-10"
            textColor: Colors.dim
            onClicked: Media.seekBy(-10)
        }

        BracketButton {
            label: "<<"
            textColor: root.player?.canGoPrevious ? Colors.fg : Colors.dim
            onClicked: Media.command("prev")
        }

        BracketButton {
            label: root.player?.isPlaying ? "||" : ">"
            onClicked: Media.command("toggle")
        }

        BracketButton {
            label: ">>"
            textColor: root.player?.canGoNext ? Colors.fg : Colors.dim
            onClicked: Media.command("next")
        }

        BracketButton {
            visible: root.player?.canSeek ?? false
            label: "+10"
            textColor: Colors.dim
            onClicked: Media.seekBy(10)
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

                Label {
                    id: line

                    anchors.left: parent.left
                    anchors.right: from.left
                    anchors.rightMargin: Metrics.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: earlier.copied === track.index ? "copied" : Media.line(track.modelData)
                    color: earlier.copied === track.index ? Colors.accent : Colors.fg
                }

                Label {
                    id: from

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: track.modelData.player
                    color: Colors.dim
                    font.pixelSize: Metrics.fontSize - 2
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

    Label {
        Layout.fillWidth: true
        Layout.topMargin: Metrics.spacing
        visible: root.player !== null
        elide: Text.ElideRight
        text: "space · ←→ 5 s · ↑↓ vol · n p · s r" + (root.players.length > 1 ? " · tab" : "")
        color: Colors.dim
        font.pixelSize: Metrics.fontSize - 2
    }
}
