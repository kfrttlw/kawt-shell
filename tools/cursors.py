#!/usr/bin/env python3
"""kawt's two cursor themes, drawn here a pixel at a time and written as XCursor files:

  kawt-stripes    the face cut in kawt's bars, like the logo; busy: the bars run, red when it
                  can't be used at all
  kawt-terminal   the console's: fat pixels (each one 2 x 2), the text cursor kawt's red block,
                  busy: a spinner | / - \\

    python3 tools/cursors.py                    draws them again into quickshell/kawt-shell/cursors
    python3 tools/cursors.py --check            exit 1 if what's there isn't what this draws (ci)
    python3 tools/cursors.py --preview out.png  a sheet of every cursor (needs pillow)

Each in four sizes, 24 48 72 96 (x1 to x4 of the same pixels, never smoothed), the busy ones a few
frames each. XCursor, because everything reads it: Hyprland (with no hyprcursor theme of that name
it takes the XCursor one), GTK, Qt, XWayland. The names programs ask for (left_ptr, hand2, xterm,
the css ones...) are links to the few drawn here; the rest comes from Adwaita (index.theme).
Only the standard library: no pillow, no xcursorgen (the preview alone wants pillow)."""
import math
import os
import struct
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "quickshell", "kawt-shell", "cursors")
BASE = 24  # the canvas at x1, in pixels
SCALES = (1, 2, 3, 4)

BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
DARK = (60, 60, 58)  # a bar's gap, in the stripes
PAPER = (232, 230, 224)  # the console's ink
RED = (226, 35, 26)  # kawt's one light


def rows(s):
    r = [l for l in s.strip("\n").split("\n")]
    w = max(len(l) for l in r)
    return [l.ljust(w, ".") for l in r]


def outlined(mask):
    """a shape given as # cells, with a one cell edge (K) all round: the face (W) and its edge"""
    m = rows(mask)
    h, w = len(m), len(m[0])
    out = [["."] * (w + 2) for _ in range(h + 2)]
    for y in range(h):
        for x in range(w):
            if m[y][x] == "#":
                out[y + 1][x + 1] = "W"
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if out[y + 1 + dy][x + 1 + dx] == ".":
                            out[y + 1 + dy][x + 1 + dx] = "K"
    # a cell of the face drawn over an edge set before it
    for y in range(h):
        for x in range(w):
            if m[y][x] == "#":
                out[y + 1][x + 1] = "W"
    return ["".join(r) for r in out]


def transpose(g):
    return ["".join(g[y][x] for y in range(len(g))) for x in range(len(g[0]))]


def mirror(g):
    return [r[::-1] for r in g]


def ring(n, inner, outer, slash):
    """the 'not allowed' sign: a ring n x n and a slash from the top left"""
    c = (n - 1) / 2
    out = []
    for y in range(n):
        line = ""
        for x in range(n):
            d = math.hypot(x - c, y - c)
            on = inner <= d <= outer or (abs((x - c) - (y - c)) <= slash and d < outer)
            line += "#" if on else "."
        out.append(line)
    return "\n".join(out)


# ---------------------------------------------------------------- the shapes, a cell a pixel
# K the edge, W the face, R the light, . nothing; a mask's # is the face, its edge comes by itself

ARROW = rows("""
K..........
KK.........
KWK........
KWWK.......
KWWWK......
KWWWWK.....
KWWWWWK....
KWWWWWWK...
KWWWWWWWK..
KWWWWWWWWK.
KWWWWWKKKKK
KWWKWWK....
KWK.KWWK...
KK..KWWK...
K....KWWK..
.....KWWK..
......KK...
""")
HAND = rows("""
.....KK........
....KWWK.......
....KWWK.......
....KWWK.......
....KWWK.......
....KWWKKK.....
....KWWKWWKKK..
....KWWKWWKWWK.
.KK.KWWKWWKWWKK
KWWKKWWWWWWWWWK
KWWWKWWWWWWWWWK
.KWWWWWWWWWWWWK
..KWWWWWWWWWWWK
..KWWWWWWWWWWK.
...KWWWWWWWWWK.
....KWWWWWWWK..
....KWWWWWWWK..
....KKKKKKKKK..
""")
IBEAM = rows("""
WWW.WWW
WKKWKKW
WWWKWWW
..WKW..
..WKW..
..WKW..
..WKW..
..WKW..
..WKW..
..WKW..
..WKW..
..WKW..
WWWKWWW
WKKWKKW
WWW.WWW
""")
CROSS = outlined("""
.....#.....
.....#.....
.....#.....
.....#.....
...........
####.#.####
...........
.....#.....
.....#.....
.....#.....
.....#.....
""")
MOVE = outlined("""
......#......
.....###.....
....#####....
......#......
..#...#...#..
.##...#...##.
#############
.##...#...##.
..#...#...#..
......#......
....#####....
.....###.....
......#......
""")
EW = outlined("""
..#.......#..
.##.......##.
#############
.##.......##.
..#.......#..
""")
NWSE = outlined("""
#####....
##.......
#.#......
#..#.....
....#....
.....#..#
......#.#
.......##
....#####
""")
NO = outlined(ring(13, 4.6, 6.4, 0.75))
QUESTION = outlined("""
.###.
#...#
....#
...#.
..#..
.....
..#..
""")
PLUS = outlined("""
..#..
..#..
#####
..#..
..#..
""")

# the console's, in fat cells (each 2 x 2 pixels at x1)
FAT_ARROW = rows("""
K......
KK.....
KWK....
KWWK...
KWWWK..
KWWWWK.
KWWWWWK
KWWKKKK
KWK....
KK.....
K......
""")
FAT_HAND = outlined("""
..#....
..#....
..#.#.#
#.#####
#######
.######
..####.
..####.
""")
FAT_TEXT = outlined("\n".join(["###"] * 7))
FAT_CROSS = outlined("""
...#...
...#...
.......
##.#.##
.......
...#...
...#...
""")
FAT_MOVE = outlined("""
....#....
...###...
....#....
.#..#..#.
#########
.#..#..#.
....#....
...###...
....#....
""")
FAT_EW = outlined("""
.#...#.
#######
.#...#.
""")
FAT_NWSE = outlined("""
###....
##.....
#.#....
...#...
....#.#
.....##
....###
""")
FAT_NO = outlined(ring(9, 3.0, 4.3, 0.6))
FAT_QUESTION = outlined("""
##.
..#
.#.
...
.#.
""")
FAT_PLUS = outlined("""
.#.
###
.#.
""")
# the spinner: | / - \, big for wait, small next to the arrow for progress
SPIN_BIG = [outlined(m) for m in (
    "...#...\n...#...\n...#...\n...#...\n...#...\n...#...\n...#...",
    "......#\n.....#.\n....#..\n...#...\n..#....\n.#.....\n#......",
    ".......\n.......\n.......\n#######\n.......\n.......\n.......",
    "#......\n.#.....\n..#....\n...#...\n....#..\n.....#.\n......#",
)]
SPIN_SMALL = [outlined(m) for m in (".#.\n.#.\n.#.", "..#\n.#.\n#..", "...\n###\n...", "#..\n.#.\n..#")]


# ---------------------------------------------------------------- drawing
class Layer:
    """a shape at (x, y) on the canvas, each cell `cell` pixels; ink(ch, px, py) -> color or None"""

    def __init__(self, grid, x, y, ink, cell=1):
        self.grid, self.x, self.y, self.ink, self.cell = grid, x, y, ink, cell


def render(layers):
    """the canvas at x1: BASE x BASE colors (None: nothing), later layers over earlier ones"""
    px = [[None] * BASE for _ in range(BASE)]
    for l in layers:
        for gy, row in enumerate(l.grid):
            for gx, ch in enumerate(row):
                if ch == ".":
                    continue
                for dy in range(l.cell):
                    for dx in range(l.cell):
                        x, y = l.x + gx * l.cell + dx, l.y + gy * l.cell + dy
                        assert 0 <= x < BASE and 0 <= y < BASE, f"a cursor runs off the {BASE} px canvas"
                        c = l.ink(ch, x, y)
                        if c is not None:
                            px[y][x] = c
    return px


def solid(face, edge=BLACK):
    return lambda ch, x, y: edge if ch == "K" else face if ch == "W" else RED if ch == "R" else None


def striped(lit, phase=0):
    """kawt's bars: two rows lit, one dark, counted on the canvas so every shape lines up; the
    phase moves them down a row a frame"""
    return lambda ch, x, y: BLACK if ch == "K" else (lit if (y - phase) % 3 != 2 else DARK) if ch == "W" else None


def center(grid, cell=1):
    """where a shape goes to sit in the middle of the canvas, and its middle there (the hotspot)"""
    w, h = len(grid[0]) * cell, len(grid) * cell
    x, y = (BASE - w) // 2, (BASE - h) // 2
    return x, y, (x + w // 2, y + h // 2)


def centered(grid, ink, cell=1):
    x, y, hot = center(grid, cell)
    return [[Layer(grid, x, y, ink, cell)]], hot


# each cursor: (frames: a list of layer lists, hotspot at x1, ms a frame)
def stripes_theme():
    c = {}
    white = solid(WHITE)
    c["default"] = ([[Layer(ARROW, 0, 0, striped(WHITE))]], (0, 0), 0)
    c["pointer"] = ([[Layer(HAND, 0, 0, striped(WHITE))]], (5, 0), 0)
    c["text"] = ([[Layer(IBEAM, 8, 4, solid(WHITE))]], (11, 11), 0)
    c["progress"] = ([[Layer(ARROW, 0, 0, striped(WHITE, f))] for f in range(3)], (0, 0), 110)
    c["wait"] = ([[Layer(ARROW, 0, 0, striped(RED, f))] for f in range(3)], (0, 0), 110)
    c["help"] = ([[Layer(ARROW, 0, 0, striped(WHITE)), Layer(QUESTION, 12, 12, white)]], (0, 0), 0)
    c["copy"] = ([[Layer(ARROW, 0, 0, striped(WHITE)), Layer(PLUS, 12, 13, white)]], (0, 0), 0)
    for name, grid, ink in (("crosshair", CROSS, white), ("move", MOVE, white), ("ew-resize", EW, white),
                            ("ns-resize", transpose(EW), white), ("nwse-resize", NWSE, white),
                            ("nesw-resize", mirror(NWSE), white), ("not-allowed", NO, solid(RED))):
        frames, hot = centered(grid, ink)
        c[name] = (frames, hot, 0)
    return c


def terminal_theme():
    c = {}
    paper, red = solid(PAPER), solid(RED)
    c["default"] = ([[Layer(FAT_ARROW, 0, 0, paper, 2)]], (0, 0), 0)
    c["pointer"] = ([[Layer(FAT_HAND, 0, 0, paper, 2)]], (7, 2), 0)
    frames, hot = centered(FAT_TEXT, red, 2)
    c["text"] = (frames, hot, 0)
    c["progress"] = ([[Layer(FAT_ARROW, 0, 0, paper, 2), Layer(s, 12, 12, red, 2)] for s in SPIN_SMALL], (0, 0), 130)
    x, y, hot = center(SPIN_BIG[0], 2)
    c["wait"] = ([[Layer(s, x, y, red, 2)] for s in SPIN_BIG], hot, 130)
    c["help"] = ([[Layer(FAT_ARROW, 0, 0, paper, 2), Layer(FAT_QUESTION, 14, 10, paper, 2)]], (0, 0), 0)
    c["copy"] = ([[Layer(FAT_ARROW, 0, 0, paper, 2), Layer(FAT_PLUS, 14, 14, paper, 2)]], (0, 0), 0)
    for name, grid, ink in (("crosshair", FAT_CROSS, paper), ("move", FAT_MOVE, paper), ("ew-resize", FAT_EW, paper),
                            ("ns-resize", transpose(FAT_EW), paper), ("nwse-resize", FAT_NWSE, paper),
                            ("nesw-resize", mirror(FAT_NWSE), paper), ("not-allowed", FAT_NO, red)):
        frames, hot = centered(grid, ink, 2)
        c[name] = (frames, hot, 0)
    return c


THEMES = {
    "kawt-stripes": ("kawt's cursor: the face cut in kawt's bars, like the logo", stripes_theme),
    "kawt-terminal": ("kawt's cursor: the console's, fat pixels and a red block", terminal_theme),
}

# the names programs ask for -> the one drawn (css names from the cursor-shape protocol, the old
# X11 ones, the ones gtk and qt use)
ALIASES = {
    "default": ["left_ptr", "arrow", "top_left_arrow", "left-arrow", "context-menu", "alias", "dnd-link", "dnd-none"],
    "pointer": ["hand", "hand1", "hand2", "pointing_hand", "grab", "grabbing", "openhand", "closedhand"],
    "text": ["xterm", "ibeam", "vertical-text"],
    "progress": ["left_ptr_watch", "half-busy"],
    "wait": ["watch"],
    "help": ["question_arrow", "whats_this", "left_ptr_help", "dnd-ask"],
    "copy": ["dnd-copy"],
    "crosshair": ["cross", "tcross", "cross_reverse", "diamond_cross", "cell", "plus"],
    "move": ["fleur", "all-scroll", "size_all", "dnd-move"],
    "not-allowed": ["crossed_circle", "forbidden", "no-drop", "dnd-no-drop", "circle"],
    "ew-resize": ["e-resize", "w-resize", "left_side", "right_side", "size_hor", "h_double_arrow",
                  "sb_h_double_arrow", "col-resize", "split_h"],
    "ns-resize": ["n-resize", "s-resize", "top_side", "bottom_side", "size_ver", "v_double_arrow",
                  "sb_v_double_arrow", "row-resize", "split_v"],
    "nwse-resize": ["nw-resize", "se-resize", "top_left_corner", "bottom_right_corner", "size_fdiag",
                    "bd_double_arrow"],
    "nesw-resize": ["ne-resize", "sw-resize", "top_right_corner", "bottom_left_corner", "size_bdiag",
                    "fd_double_arrow"],
}


# ---------------------------------------------------------------- XCursor
def xcursor(frames, hot, delay):
    """the file: every frame in every size. A table of contents, then each image: a 36 byte header
    and its pixels as ARGB (premultiplied: here every pixel is whole or nothing)"""
    images = []
    for s in SCALES:
        for layers in frames:
            px = render(layers)
            n = BASE * s
            argb = []
            for y in range(n):
                row = px[y // s]
                for x in range(n):
                    c = row[x // s]
                    argb.append(0 if c is None else 0xFF000000 | c[0] << 16 | c[1] << 8 | c[2])
            images.append((n, n, n, hot[0] * s, hot[1] * s, delay, argb))
    head = struct.pack("<4sIII", b"Xcur", 16, 0x10000, len(images))
    toc, body = b"", b""
    at = 16 + 12 * len(images)
    for size, w, h, xh, yh, d, argb in images:
        chunk = struct.pack("<9I", 36, 0xFFFD0002, size, 1, w, h, xh, yh, d) + struct.pack(f"<{w * h}I", *argb)
        toc += struct.pack("<3I", 0xFFFD0002, size, at)
        body += chunk
        at += len(chunk)
    return head + toc + body


def build(out):
    for theme, (comment, draw) in THEMES.items():
        d = os.path.join(out, theme, "cursors")
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(out, theme, "index.theme"), "w") as f:
            f.write(f"[Icon Theme]\nName={theme}\nComment={comment} (tools/cursors.py)\nInherits=Adwaita\n")
        for name, (frames, hot, delay) in draw().items():
            with open(os.path.join(d, name), "wb") as f:
                f.write(xcursor(frames, hot, delay))
            for alias in ALIASES.get(name, []):
                os.symlink(name, os.path.join(d, alias))


def snapshot(root):
    """every file and link under root: path -> bytes, or ("link", target)"""
    out = {}
    for d, dirs, files in os.walk(root):
        for f in files + [x for x in dirs if os.path.islink(os.path.join(d, x))]:
            p = os.path.join(d, f)
            out[os.path.relpath(p, root)] = ("link", os.readlink(p)) if os.path.islink(p) else open(p, "rb").read()
    return out


def preview(path):
    from PIL import Image, ImageDraw

    themes = {t: draw() for t, (_, draw) in THEMES.items()}
    names = list(next(iter(themes.values())).keys())
    z, pad = 3, 10
    cellw = BASE * z + pad
    bgs = [(12, 12, 12), (232, 229, 221)]
    W = pad + cellw * len(names)
    H = pad + (BASE * z + pad) * len(themes) * len(bgs)
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    y = 0
    for bg in bgs:
        for t, cursors in themes.items():
            d.rectangle([0, y, W, y + BASE * z + pad], fill=bg)
            for i, name in enumerate(names):
                frames, hot, _ = cursors[name]
                px = render(frames[min(1, len(frames) - 1)])
                x0 = pad + i * cellw
                for py in range(BASE):
                    for pxx in range(BASE):
                        c = px[py][pxx]
                        if c:
                            d.rectangle([x0 + pxx * z, y + pad + py * z, x0 + pxx * z + z - 1, y + pad + py * z + z - 1], fill=c)
            y += BASE * z + pad
    img.save(path)
    print(path, img.size)


if __name__ == "__main__":
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])
        sys.exit(0)
    if "--check" in sys.argv:
        with tempfile.TemporaryDirectory() as tmp:
            build(tmp)
            want, have = snapshot(tmp), snapshot(OUT) if os.path.isdir(OUT) else {}
        bad = sorted(set(want) ^ set(have)) + sorted(p for p in want if p in have and want[p] != have[p])
        for p in bad[:20]:
            print(f"cursors/{p}: not what tools/cursors.py draws")
        print(f"{len(bad)} cursor file(s) to draw again: python3 tools/cursors.py" if bad else "cursors ok")
        sys.exit(1 if bad else 0)
    import shutil

    for theme in THEMES:
        shutil.rmtree(os.path.join(OUT, theme), ignore_errors=True)
    build(OUT)
    n = sum(len(fs) for _, _, fs in os.walk(OUT))
    print(f"drawn into {os.path.relpath(OUT)}: {', '.join(THEMES)} ({n} files and links)")
