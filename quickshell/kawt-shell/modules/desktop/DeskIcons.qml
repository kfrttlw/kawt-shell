import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Qt.labs.folderlistmodel
import qs.config
import qs.components
import qs.services

// Files on the desktop, as KDE has them (Settings.deskIcons): the home folder and the bin on
// top, then what's in ~/Desktop, a column after another (services/Desk.qml). Under the windows,
// on the main screen.
//   a click picks one (ctrl: one more), a band picks many, a double click (or enter) opens it
//   dragged, it stands where it's let go, in the grid (every place is kept, by name)
//   right click: what can be done with it (or, on the empty desktop: a new folder, paste...)
//   F2 renames it under its picture, del puts it into the bin, ctrl+c / x / v as everywhere
//   dropped here from a file manager, a file is copied in
// The pictures are kawt's own (utils/classicicons.js: classic; utils/folders.js: pixel), a
// picture file shows itself.
Scope {
    id: root

    required property ShellScreen forScreen

    readonly property int cellW: Math.round(96 * Metrics.scale)
    readonly property int cellH: 64 + 10 + (Metrics.fontSize + 3) * 2 + 6
    readonly property int edge: 6
    readonly property int cols: Math.max(1, Math.floor((desk.width - edge * 2) / cellW))
    readonly property int rows: Math.max(1, Math.floor((desk.height - edge * 2) / cellH))

    // [{ key, name, path, kind, dir, modified, icon (an app's) }]: the home folder, the bin, the files
    property var entries: []
    property var at: ({}) // key -> [column, row]
    property var selected: ({}) // key -> true
    readonly property var picked: entries.filter(e => selected[e.key])
    property string renaming: ""
    property string renameNext: "" // a new folder or file: named as soon as it's there
    property bool dragging: false
    property point dragBy: Qt.point(0, 0)
    property bool banding: false
    property rect band: Qt.rect(0, 0, 0, 0)

    // ---- what's there
    FolderListModel {
        id: files

        folder: `file://${Desk.dir}`
        showDirsFirst: true
        showHidden: false
        onCountChanged: rebuild.restart()
        onStatusChanged: rebuild.restart()
    }

    // a rename keeps the count: the list is read again on any change
    Connections {
        target: files

        function onDataChanged(): void {
            rebuild.restart();
        }

        function onRowsInserted(): void {
            rebuild.restart();
        }

        function onRowsRemoved(): void {
            rebuild.restart();
        }
    }

    Timer {
        id: rebuild

        interval: 80
        onTriggered: root.build()
    }

    Connections {
        target: Desk

        function onCellsChanged(): void {
            root.layout();
        }

        function onSortChanged(): void {
            root.build();
        }
    }

    onColsChanged: layout()
    onRowsChanged: layout()

    function build(): void {
        const list = [];
        for (let i = 0; i < files.count; i++) {
            const name = files.get(i, "fileName"), dir = files.get(i, "fileIsDir");
            const e = { key: name, name, path: files.get(i, "filePath"), dir, kind: Desk.kindOf(name, dir), modified: Number(files.get(i, "fileModified")) };
            // a launcher: its app's name and icon
            if (name.endsWith(".desktop")) {
                const app = DesktopEntries.heuristicLookup(name.slice(0, -8));
                e.name = app?.name || name.slice(0, -8);
                e.icon = app?.icon ? Quickshell.iconPath(app.icon, true) : "";
            }
            list.push(e);
        }
        const by = Desk.sort;
        list.sort((a, b) => (b.dir - a.dir) || (by === "kind" ? a.kind.localeCompare(b.kind) : by === "date" ? b.modified - a.modified : 0) || a.name.localeCompare(b.name));
        entries = [{ key: ":home", path: Desk.home, dir: true, kind: "home" }, { key: ":trash", path: "trash:///", dir: true, kind: "trash" }, ...list];
        // gone files aren't picked any more
        const keep = {};
        for (const e of entries)
            if (selected[e.key])
                keep[e.key] = true;
        selected = keep;
        layout();
        if (renameNext && list.some(e => e.key === renameNext)) {
            selected = { [renameNext]: true };
            renaming = renameNext;
            renameNext = "";
        }
    }

    // the kept places first (inside the grid, one each), then the rest from the top left,
    // a column after another
    function layout(): void {
        const saved = Desk.cells, out = {}, taken = {};
        for (const e of entries) {
            const p = saved[e.key];
            if (p && p[0] < cols && p[1] < rows && !taken[`${p[0]},${p[1]}`]) {
                out[e.key] = [p[0], p[1]];
                taken[`${p[0]},${p[1]}`] = true;
            }
        }
        let c = 0, r = 0;
        for (const e of entries) {
            if (out[e.key])
                continue;
            while (taken[`${c},${r}`]) {
                if (++r >= rows) {
                    r = 0;
                    c++;
                }
            }
            out[e.key] = [c, r];
            taken[`${c},${r}`] = true;
        }
        at = out;
    }

    function cellRect(key: string): rect {
        const p = at[key] ?? [0, 0];
        return Qt.rect(edge + p[0] * cellW, edge + p[1] * cellH, cellW, cellH);
    }

    // the free place nearest to c, r
    function nearestFree(c: int, r: int, taken: var): var {
        for (let d = 1; d < cols + rows; d++)
            for (let dc = -d; dc <= d; dc++)
                for (let dr = -d; dr <= d; dr++) {
                    const x = c + dc, y = r + dr;
                    if (Math.max(Math.abs(dc), Math.abs(dr)) === d && x >= 0 && y >= 0 && x < cols && y < rows && !taken[`${x},${y}`])
                        return [x, y];
                }
        return [c, r];
    }

    // the picked ones let go after a drag: each to the place under it, or the nearest free one;
    // every place is kept from now on, so the rest don't move when something is added
    function dropMoved(): void {
        const dc = Math.round(dragBy.x / cellW), dr = Math.round(dragBy.y / cellH);
        if (dc === 0 && dr === 0)
            return;
        const taken = {}, all = {};
        for (const e of entries)
            if (!selected[e.key])
                taken[`${at[e.key]}`] = true;
        for (const e of picked) {
            let c = Math.max(0, Math.min(cols - 1, at[e.key][0] + dc)), r = Math.max(0, Math.min(rows - 1, at[e.key][1] + dr));
            if (taken[`${c},${r}`])
                [c, r] = nearestFree(c, r, taken);
            taken[`${c},${r}`] = true;
            all[e.key] = [c, r];
        }
        for (const e of entries)
            all[e.key] = all[e.key] ?? at[e.key];
        Desk.setCells(all);
    }

    // ---- picking
    function selectOnly(key: string): void {
        selected = { [key]: true };
    }

    function toggle(key: string): void {
        const s = Object.assign({}, selected);
        if (s[key])
            delete s[key];
        else
            s[key] = true;
        selected = s;
    }

    function selectIn(r: rect): void {
        const s = {};
        for (const e of entries) {
            const c = cellRect(e.key);
            if (c.x + 16 < r.x + r.width && c.x + c.width - 16 > r.x && c.y + 4 < r.y + r.height && c.y + c.height - 10 > r.y)
                s[e.key] = true;
        }
        selected = s;
    }

    // ↑ ↓ ← →: the next one that way
    function step(dx: int, dy: int): void {
        const now = picked[0];
        if (!now) {
            if (entries.length)
                selectOnly(entries[0].key);
            return;
        }
        const [c, r] = at[now.key];
        let best = null, bestD = 1e9;
        for (const e of entries) {
            const [x, y] = at[e.key];
            const ax = (x - c) * dx + (y - r) * dy; // along the way asked
            const off = Math.abs((x - c) * dy) + Math.abs((y - r) * dx); // off to the side
            if (ax > 0 && ax + off * 2 < bestD) {
                best = e;
                bestD = ax + off * 2;
            }
        }
        if (best)
            selectOnly(best.key);
    }

    // ---- doing things
    function openEntry(e: var): void {
        if (e.key === ":trash")
            Desk.openTrash();
        else
            Desk.open(e.path);
    }

    function openPicked(): void {
        for (const e of picked)
            openEntry(e);
    }

    // the files picked (not the home folder and the bin)
    function pickedPaths(): var {
        return picked.filter(e => !e.key.startsWith(":")).map(e => e.path);
    }

    function newFolder(): void {
        const name = Desk.freeName(Strings.t("deskNewFolderName"), "", entries.map(e => e.key));
        renameNext = name;
        Desk.newFolder(name);
    }

    function newFile(): void {
        const name = Desk.freeName(Strings.t("deskNewFileName"), ".txt", entries.map(e => e.key));
        renameNext = name;
        Desk.newFile(name);
    }

    function lineUp(): void {
        // in the order they stand now, a column after another, no gaps
        const order = entries.slice().sort((a, b) => (at[a.key][0] - at[b.key][0]) || (at[a.key][1] - at[b.key][1]));
        const all = {};
        order.forEach((e, i) => all[e.key] = [Math.floor(i / rows), i % rows]);
        Desk.setCells(all);
    }

    // ---- the menus: what's there to do with what's picked, or on the empty desktop
    property bool menuOpen: false
    property point menuAt: Qt.point(0, 0)
    property var menuItems: []
    property bool trashArmed: false

    function openMenu(what: string, p: point): void {
        const one = picked.length === 1 ? picked[0] : null;
        const sep = { sep: true };
        let items = [];
        if (what === "desk") {
            items = [
                { icon: "folder", text: Strings.t("deskNewFolder"), key: "ctrl+shift+n", act: () => newFolder() },
                { icon: "notes", text: Strings.t("deskNewFile"), act: () => newFile() },
                { icon: "clip", text: Strings.t("deskPaste"), key: "ctrl+v", act: () => Desk.paste() },
                sep,
                { icon: "", text: Strings.t("deskArrange"), sub: [["name", "deskByName"], ["kind", "deskByKind"], ["date", "deskByDate"]].map(s => ({ text: Strings.t(s[1]), on: Desk.sort === s[0], act: () => Desk.arrange(s[0]) })) },
                { icon: "check", text: Strings.t("deskLineUp"), act: () => lineUp() },
                sep,
                { icon: "terminal", text: Strings.t("deskTerminal"), act: () => Desk.terminalIn(Desk.dir) },
                { icon: "folder", text: Strings.t("deskOpenFolder"), act: () => Desk.open(Desk.dir) },
                sep,
                { icon: "wallpaper", text: Strings.t("styleTitle") + "…", key: "super+w", act: () => Panels.openWindow("style", "wall") },
                { icon: "gear", text: Strings.t("settingsDots"), key: "super+,", act: () => Panels.openWindow("settings", "look") }
            ];
        } else if (one && one.key === ":trash") {
            trashArmed = false;
            items = [
                { icon: "trash", text: Strings.t("deskOpen"), key: "enter", act: () => Desk.openTrash(), bold: true },
                sep,
                { icon: "trash", text: Strings.t("deskEmptyTrash"), off: !Desk.trashFull, keep: true, armed: true, act: () => {
                        if (!root.trashArmed) {
                            root.trashArmed = true;
                            return false; // stays open: once more to be sure
                        }
                        Desk.emptyTrash();
                        return true;
                    } }
            ];
        } else if (one && one.key === ":home") {
            items = [
                { icon: "folder", text: Strings.t("deskOpen"), key: "enter", act: () => Desk.open(Desk.home), bold: true },
                { icon: "terminal", text: Strings.t("deskTerminal"), act: () => Desk.terminalIn(Desk.home) }
            ];
        } else {
            const paths = pickedPaths();
            items = [
                { icon: "folder", text: Strings.t("deskOpen"), key: "enter", act: () => openPicked(), bold: true },
                ...(one?.dir ? [{ icon: "terminal", text: Strings.t("deskTerminal"), act: () => Desk.terminalIn(one.path) }] : []),
                sep,
                { icon: "", text: Strings.t("deskCut"), key: "ctrl+x", off: !paths.length, act: () => Desk.copy(paths, true) },
                { icon: "clip", text: Strings.t("deskCopy"), key: "ctrl+c", off: !paths.length, act: () => Desk.copy(paths, false) },
                sep,
                ...(one && !one.key.startsWith(":") ? [{ icon: "edit", text: Strings.t("deskRename"), key: "F2", act: () => root.renaming = one.key }] : []),
                { icon: "trash", text: Strings.t("deskToTrash"), key: "del", off: !paths.length, act: () => Desk.toTrash(paths) },
                ...(one?.kind === "image" ? [sep, { icon: "ai", text: Strings.t("deskAskAi"), act: () => Ai.askAbout(one.path) }] : [])
            ];
        }
        menuItems = items;
        menuAt = p;
        Panels.close();
        menuOpen = true;
    }

    // another panel coming up closes the menu
    Connections {
        target: Panels

        function onCurrentChanged(): void {
            if (Panels.current !== "")
                root.menuOpen = false;
        }
    }

    // ------------------------------------------------------------------ the desktop
    PanelWindow {
        id: desk

        screen: root.forScreen
        color: "transparent"

        WlrLayershell.namespace: "kawt-desktop"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: root.renaming !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

        // under the bar's room, like the windows (the bar's exclusive zone)
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        // dropped in from a file manager: copied here
        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: drop => {
                if (drop.hasUrls) {
                    Desk.copyIn(drop.urls);
                    drop.acceptProposedAction();
                }
            }
        }

        // the empty desktop: a click lets go of what's picked, a drag draws the band, a right
        // click is the desktop's menu
        MouseArea {
            id: back

            property point from: Qt.point(0, 0)

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: mouse => {
                keys.forceActiveFocus();
                root.renaming = "";
                if (mouse.button === Qt.RightButton) {
                    root.selected = {};
                    root.openMenu("desk", Qt.point(mouse.x, mouse.y));
                    return;
                }
                if (!(mouse.modifiers & Qt.ControlModifier))
                    root.selected = {};
                from = Qt.point(mouse.x, mouse.y);
                root.band = Qt.rect(mouse.x, mouse.y, 0, 0);
                root.banding = true;
            }
            onPositionChanged: mouse => {
                if (!root.banding)
                    return;
                root.band = Qt.rect(Math.min(from.x, mouse.x), Math.min(from.y, mouse.y), Math.abs(mouse.x - from.x), Math.abs(mouse.y - from.y));
                root.selectIn(root.band);
            }
            onReleased: root.banding = false
        }

        Rectangle {
            visible: root.banding
            x: root.band.x
            y: root.band.y
            width: root.band.width
            height: root.band.height
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.18)
            border.color: Colors.accent
            border.width: 1
        }

        // the keys while the desktop has them (after a click on it)
        Item {
            id: keys

            focus: true
            Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.openPicked();
                else if (event.key === Qt.Key_Delete)
                    Desk.toTrash(root.pickedPaths());
                else if (event.key === Qt.Key_F2 && root.picked.length === 1 && !root.picked[0].key.startsWith(":"))
                    root.renaming = root.picked[0].key;
                else if (event.key === Qt.Key_Escape)
                    root.selected = {};
                else if (ctrl && event.key === Qt.Key_A) {
                    const all = {};
                    for (const e of root.entries)
                        all[e.key] = true;
                    root.selected = all;
                }
                else if (ctrl && event.key === Qt.Key_C)
                    Desk.copy(root.pickedPaths(), false);
                else if (ctrl && event.key === Qt.Key_X)
                    Desk.copy(root.pickedPaths(), true);
                else if (ctrl && event.key === Qt.Key_V)
                    Desk.paste();
                else if (ctrl && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_N)
                    root.newFolder();
                else if (event.key === Qt.Key_Up)
                    root.step(0, -1);
                else if (event.key === Qt.Key_Down)
                    root.step(0, 1);
                else if (event.key === Qt.Key_Left)
                    root.step(-1, 0);
                else if (event.key === Qt.Key_Right)
                    root.step(1, 0);
                else
                    return;
                event.accepted = true;
            }
        }

        Repeater {
            model: root.entries

            Item {
                id: icon

                required property var modelData
                readonly property string key: modelData.key
                readonly property var cell: root.at[key] ?? [0, 0]
                readonly property bool sel: !!root.selected[key]
                readonly property bool moving: sel && root.dragging
                readonly property string kind: key === ":trash" ? (Desk.trashFull ? "trash-full" : "trash") : modelData.kind
                readonly property string label: key === ":home" ? Strings.t("deskHome") : key === ":trash" ? Strings.t("deskTrash") : modelData.name
                property point pressAt: Qt.point(0, 0)

                x: root.edge + cell[0] * root.cellW + (moving ? root.dragBy.x : 0)
                y: root.edge + cell[1] * root.cellH + (moving ? root.dragBy.y : 0)
                z: moving ? 2 : 1
                width: root.cellW
                height: root.cellH
                opacity: moving ? 0.7 : 1

                // the picture: kawt's icon, the app's, or the picture itself in a white frame
                Item {
                    id: pic

                    x: Math.round((parent.width - 64) / 2)
                    y: 4
                    width: 64
                    height: 64
                    layer.enabled: icon.sel
                    layer.effect: MultiEffect {
                        colorization: 0.45
                        colorizationColor: Colors.accent
                    }

                    Image {
                        anchors.fill: parent
                        visible: !thumb.visible
                        source: icon.modelData.icon ? icon.modelData.icon : Desk.iconsReady ? Desk.iconOf(icon.kind) : ""
                        sourceSize: Qt.size(64, 64)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                    }

                    Item {
                        id: thumb

                        anchors.fill: parent
                        visible: icon.kind === "image" && shot.status === Image.Ready

                        Rectangle {
                            x: Math.round((parent.width - width) / 2) + 2
                            y: Math.round((parent.height - height) / 2) + 2
                            width: shot.paintedWidth + 4
                            height: shot.paintedHeight + 4
                            color: Qt.rgba(0, 0, 0, 0.45)
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: shot.paintedWidth + 4
                            height: shot.paintedHeight + 4
                            color: "#fbfaf6"
                            border.color: "#5f5c55"
                            border.width: 1
                        }

                        Image {
                            id: shot

                            anchors.centerIn: parent
                            width: 58
                            height: 58
                            source: icon.modelData.kind === "image" ? `file://${icon.modelData.path}` : ""
                            sourceSize: Qt.size(116, 116)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }
                }

                // the name: white with a shadow on any wallpaper; picked: on the light
                Rectangle {
                    visible: root.renaming !== icon.key
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: pic.y + pic.height + 4
                    width: Math.ceil(name.contentWidth) + 6
                    height: Math.ceil(name.contentHeight) + 2
                    color: icon.sel ? Colors.accent : area.containsMouse ? Qt.rgba(0, 0, 0, 0.35) : "transparent"

                    Text {
                        id: name

                        y: 1
                        width: root.cellW - 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        maximumLineCount: icon.sel ? 5 : 2
                        elide: Text.ElideRight
                        text: icon.label
                        color: icon.sel ? Colors.onAccent : "#ffffff"
                        style: icon.sel ? Text.Normal : Text.Raised // a dark copy a pixel under it
                        styleColor: "#000000"
                        font.family: Metrics.fontFamily
                        font.pixelSize: Metrics.fontSize
                        renderType: Metrics.pixel ? Text.NativeRendering : Text.QtRendering
                    }
                }

                // F2: the name in a field under the picture (enter keeps it, esc doesn't)
                TermInput {
                    id: rename

                    visible: root.renaming === icon.key
                    x: 2
                    y: pic.y + pic.height + 3
                    width: parent.width - 4
                    prompt: ""
                    onVisibleChanged: if (visible) {
                        text = icon.modelData.name;
                        input.forceActiveFocus();
                        // the name without its ending picked, as file managers do
                        const dot = text.lastIndexOf(".");
                        input.select(0, icon.modelData.dir || dot <= 0 ? text.length : dot);
                    }
                    onAccepted: t => {
                        Desk.rename(icon.modelData.path, t);
                        root.renaming = "";
                        keys.forceActiveFocus();
                    }
                    Keys.onEscapePressed: {
                        root.renaming = "";
                        keys.forceActiveFocus();
                    }
                }

                MouseArea {
                    id: area

                    // the picture and the name, not the whole cell: between icons is the desktop
                    x: 6
                    width: parent.width - 12
                    height: pic.y + pic.height + 4 + (Metrics.fontSize + 3) * 2
                    enabled: root.renaming !== icon.key
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => {
                        keys.forceActiveFocus();
                        root.renaming = "";
                        if (mouse.button === Qt.RightButton) {
                            if (!icon.sel)
                                root.selectOnly(icon.key);
                            root.openMenu("file", mapToItem(back, mouse.x, mouse.y));
                            return;
                        }
                        if (mouse.modifiers & Qt.ControlModifier)
                            root.toggle(icon.key);
                        else if (!icon.sel)
                            root.selectOnly(icon.key);
                        icon.pressAt = mapToItem(back, mouse.x, mouse.y);
                    }
                    onPositionChanged: mouse => {
                        if (!pressed || !(mouse.buttons & Qt.LeftButton) || !icon.sel)
                            return;
                        const p = mapToItem(back, mouse.x, mouse.y);
                        const d = Qt.point(p.x - icon.pressAt.x, p.y - icon.pressAt.y);
                        if (!root.dragging && Math.abs(d.x) + Math.abs(d.y) > 8)
                            root.dragging = true;
                        if (root.dragging)
                            root.dragBy = d;
                    }
                    onReleased: {
                        if (!root.dragging)
                            return;
                        root.dropMoved();
                        root.dragging = false;
                        root.dragBy = Qt.point(0, 0);
                    }
                    onDoubleClicked: mouse => {
                        if (mouse.button === Qt.LeftButton)
                            root.openEntry(icon.modelData);
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------ the menu, over everything
    PanelWindow {
        id: menuWindow

        screen: root.forScreen
        visible: root.menuOpen
        color: "transparent"

        WlrLayershell.namespace: "kawt-desktop-menu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // the same room as the desktop's: the points line up
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        OpenWatch {
            open: root.menuOpen
            onOpened: {
                menuBox.current = -1;
                menuBox.subOpen = -1;
                menuKeys.forceActiveFocus();
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: root.menuOpen = false
        }

        Item {
            id: menuKeys

            focus: true
            Keys.onPressed: event => {
                const n = root.menuItems.length;
                const can = i => !root.menuItems[i].sep && !root.menuItems[i].off;
                if (event.key === Qt.Key_Escape) {
                    if (menuBox.subOpen >= 0)
                        menuBox.subOpen = -1;
                    else
                        root.menuOpen = false;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                    const d = event.key === Qt.Key_Down ? 1 : -1;
                    let i = menuBox.current;
                    for (let k = 0; k < n; k++) {
                        i = (i + d + n) % n;
                        if (can(i))
                            break;
                    }
                    menuBox.current = i;
                } else if (event.key === Qt.Key_Right && root.menuItems[menuBox.current]?.sub) {
                    menuBox.subOpen = menuBox.current;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (menuBox.current >= 0)
                        menuBox.activate(root.menuItems[menuBox.current], menuBox.current);
                } else {
                    return;
                }
                event.accepted = true;
            }
        }

        MenuBox {
            id: menuBox

            items: root.menuItems
            armed: root.trashArmed
            onDone: root.menuOpen = false
            x: Math.max(0, Math.min(menuWindow.width - width - 6, root.menuAt.x))
            y: Math.max(0, Math.min(menuWindow.height - height - 6, root.menuAt.y))
        }

        // "Arrange": its choices beside it
        MenuBox {
            id: subBox

            visible: menuBox.subOpen >= 0
            onDone: root.menuOpen = false
            items: menuBox.subOpen >= 0 ? root.menuItems[menuBox.subOpen]?.sub ?? [] : []
            x: menuBox.x + menuBox.width - 3 + width > menuWindow.width ? menuBox.x - width + 3 : menuBox.x + menuBox.width - 3
            y: menuBox.y + menuBox.rowY(menuBox.subOpen) - 3
        }
    }

    // a menu: raised, a hard shadow, a line each (the start menu's look); the one under the
    // pointer or picked with the arrows on the light
    // (an inline component doesn't see this file's ids: what it needs comes in, `done` goes out)
    component MenuBox: Item {
        id: box

        property var items: []
        property int current: -1
        property int subOpen: -1
        property bool armed: false // the bin's "empty" was pressed once
        readonly property int rowH: Metrics.fontSize + 11

        signal done

        function rowY(i: int): int {
            let y = 3;
            for (let k = 0; k < i && k < items.length; k++)
                y += items[k].sep ? 6 : rowH;
            return y;
        }

        function activate(it: var, i: int): void {
            if (!it || it.sep || it.off)
                return;
            if (it.sub) {
                subOpen = i;
                return;
            }
            if (it.act?.() === false)
                return; // asked once more (emptying the bin)
            done();
        }

        width: Math.round(Metrics.fontSize * 0.6 * 40) + 30
        height: column.implicitHeight + 6

        Rectangle {
            x: 4
            y: 4
            width: parent.width
            height: parent.height
            color: Qt.rgba(0, 0, 0, 0.45)
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.face

            Bevel {
                style: "raised"
            }

            MouseArea {
                anchors.fill: parent
            }
        }

        Column {
            id: column

            x: 3
            y: 3
            width: parent.width - 6

            Repeater {
                model: box.items

                Item {
                    id: line

                    required property var modelData
                    required property int index
                    readonly property bool lit: !modelData.sep && !modelData.off && (box.current === index || lineArea.containsMouse)
                    readonly property bool armedNow: !!modelData.armed && box.armed

                    width: column.width
                    height: modelData.sep ? 6 : box.rowH

                    // a groove between the groups
                    Rectangle {
                        visible: !!line.modelData.sep
                        y: 2
                        width: parent.width
                        height: 1
                        color: Colors.lo

                        Rectangle {
                            y: 1
                            width: parent.width
                            height: 1
                            color: Colors.hi
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: line.lit
                        color: Colors.accent
                    }

                    PixIcon {
                        visible: !line.modelData.sep && (line.modelData.icon ?? "") !== ""
                        x: 4
                        anchors.verticalCenter: parent.verticalCenter
                        name: line.modelData.icon ?? ""
                    }

                    // a choice that's on (the order it's arranged in)
                    Label {
                        visible: !!line.modelData.on
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "•"
                        color: line.lit ? Colors.onAccent : Colors.fg
                    }

                    Label {
                        visible: !line.modelData.sep
                        x: 26
                        width: parent.width - x - keyLabel.width - 12
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: line.armedNow ? Strings.t("deskEmptySure").arg(Desk.trashCount) : line.modelData.text ?? ""
                        color: line.modelData.off ? Colors.dim : line.lit ? Colors.onAccent : line.armedNow ? Colors.warn : Colors.fg
                    }

                    Label {
                        id: keyLabel

                        visible: !line.modelData.sep && text !== ""
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: line.modelData.sub ? "►" : line.modelData.key ?? ""
                        color: line.lit ? Colors.onAccent : Colors.dim
                    }

                    MouseArea {
                        id: lineArea

                        anchors.fill: parent
                        enabled: !line.modelData.sep
                        hoverEnabled: true
                        cursorShape: line.modelData.off ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onEntered: {
                            box.current = line.index;
                            box.subOpen = line.modelData.sub ? line.index : -1;
                        }
                        onClicked: box.activate(line.modelData, line.index)
                    }
                }
            }
        }
    }
}
