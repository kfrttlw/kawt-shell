#!/usr/bin/env python3
"""kawt Term: Terminus, the linux console's font, with russian д и й в, as kitty takes it.

Terminus is drawn pixel by pixel at nine sizes (12 to 32 px), and its TrueType version carries
each of those drawings: at those sizes kitty shows them as they are, every pixel sharp. Its
lowercase д и й в are the handwritten ones, though (bulgarian, as in italics): "иду в дом"
reads "ugy B gom". Here they're the printed ones, built from Terminus' own capitals at each size
and weight: и from Н's stems and И's diagonal, й that with й's breve, д from Д with its sides
shortened to the lowercase height, в from В the same way. The outlines (for other sizes) get the
same shapes, from the 16 px drawing they were traced from.

Everything else is Terminus as it is (by Dimitar Toshkov Zhekov; as TrueType by Tilman
Blumenbach), as Nerd Fonts ship it, without the thousands of icons (kitty finds those in the
Nerd Font kawt has anyway). The license (SIL OFL 1.1) has a modified Terminus carry another name:
kawt Term. quickshell/kawt-shell/fonts/TERM-LICENSE.txt

    python3 tools/termfont.py [Regular.ttf Bold.ttf]   writes fonts/KawtTerm-Regular.ttf, -Bold.ttf
Without files they're fetched (Terminess Nerd Font Mono), and checked against the ones these were
made from. Needs fontTools (pip install fonttools); kawt itself only needs the .ttf files.
"""

import hashlib
import sys
import urllib.request
from collections import Counter
from io import BytesIO
from pathlib import Path

try:
    from fontTools import subset
    from fontTools.pens.ttGlyphPen import TTGlyphPen
    from fontTools.ttLib import TTFont
except ImportError:
    sys.exit("termfont: needs fontTools (pip install fonttools)")
from pixeltrace import trace

BASE = "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/Terminus/"
SOURCES = {
    "Regular": ("TerminessNerdFontMono-Regular.ttf", "1f0b30594e217a4771770dbdcae90ecbf1620b8b15429d01a23481865cce4de8"),
    "Bold": ("TerminessNerdFontMono-Bold.ttf", "cf1fb6943644d01fb8032a56e542af4c207d60b4d0eb80eb89cc0690ca3ae01a"),
}
OUT = Path(__file__).resolve().parent.parent / "quickshell/kawt-shell/fonts"
FAMILY = "kawt Term"
VERSION = "4.49.3; kawt 1"
# the outlines are the 16 px drawing traced: a pixel is 1000 / 16 units, the baseline 20 under
# the bottom row's foot (as Terminus TTF has them)
OUTLINE_PPEM, OUTLINE_UNIT, OUTLINE_LIFT = 16, 1000 / 16, 20


class Strike:
    """one of the font's drawings (a bitmap for every glyph, at one size), read and written as
    rows of booleans, the top one first, a full cell each"""

    def __init__(self, font: TTFont, index: int):
        self.font, self.index = font, index
        self.cmap = font.getBestCmap()
        self.strike = font["EBLC"].strikes[index]
        self.data = font["EBDT"].strikeData[index]
        self.ppem = self.strike.bitmapSizeTable.ppemY

    def _sub(self, name):
        return next(s for s in self.strike.indexSubTables if name in s.names)

    def get(self, ch: str):
        name = self.cmap[ord(ch)]
        g = self.data[name]
        g.ensureDecompiled()
        m = self._sub(name).metrics
        rows = [g.getRow(r, bitDepth=1, metrics=m) for r in range(m.height)]
        return [[bool(b[x // 8] & (128 >> (x % 8))) for x in range(m.width)] for b in rows], m

    def put(self, ch: str, grid) -> None:
        name = self.cmap[ord(ch)]
        m = self._sub(name).metrics
        rows = []
        for r in grid:
            bs = bytearray((m.width + 7) // 8)
            for x, v in enumerate(r):
                if v:
                    bs[x // 8] |= 128 >> (x % 8)
            rows.append(bytes(bs))
        self.data[name].setRows(rows, bitDepth=1, metrics=m)


def inked(grid) -> list[int]:
    return [i for i, r in enumerate(grid) if any(r)]


def russian(s: Strike) -> dict[str, list[list[bool]]]:
    """the printed д и й в at this size and weight, from the font's own letters"""
    n, m = s.get("н")
    H, W = len(n), len(n[0])
    B = m.horiBearingY  # rows above the baseline
    top = inked(n)[0]  # the x-height's top row
    xh = B - top
    blank = lambda: [[False] * W for _ in range(H)]  # noqa: E731

    # и: н's stems, with И's diagonal (its rows that are more than stems) in the middle
    stem = n[top]
    cap_i, _ = s.get("И")
    ir = [r for r in inked(cap_i) if r < B]
    diag = [cap_i[r] for r in ir if cap_i[r] != cap_i[ir[0]] and cap_i[r] != cap_i[ir[-1]]]
    i = blank()
    for r in range(top, B):
        i[r] = list(stem)
    at = top + (xh - len(diag) + 1) // 2
    for k, row in enumerate(diag):
        i[at + k] = list(row)

    # й: that, with й's breve above it
    y_old, _ = s.get("й")
    y = [list(r) for r in i]
    for r in range(top):
        y[r] = list(y_old[r])

    # д: Д's top and foot, its sides as long as the x-height leaves room for; its feet below
    cap_d, _ = s.get("Д")
    rows = [cap_d[r] for r in inked(cap_d) if r < B]
    side = Counter(tuple(r) for r in rows).most_common(1)[0][0]
    first = next(k for k, r in enumerate(rows) if tuple(r) == side)
    last = max(k for k, r in enumerate(rows) if tuple(r) == side)
    head, foot = rows[:first], rows[last + 1:]
    body = (head + [list(side)] * max(1, xh - len(head) - len(foot)) + foot)[-xh:]
    d = blank()
    for k, row in enumerate(body):
        d[top + k] = list(row)
    for r in range(B, H):
        d[r] = list(cap_d[r])

    # в: В, its longest runs of the same row shortened to the x-height (a tie: the upper bowl
    # gives, so the lower one stays the bigger, as printed в has it)
    cap_v, _ = s.get("В")
    vr = [list(cap_v[r]) for r in inked(cap_v) if r < B]
    while len(vr) > xh:
        runs, k = [], 0
        while k < len(vr):
            j = k
            while j + 1 < len(vr) and vr[j + 1] == vr[k]:
                j += 1
            runs.append((j - k + 1, k))
            k = j + 1
        length, at = max(runs, key=lambda run: (run[0], -run[1]))
        if length < 2:
            break
        del vr[at]
    v = blank()
    for k, row in enumerate(vr):
        v[B - len(vr) + k] = row

    return {"и": i, "й": y, "д": d, "в": v}


def outline_glyph(grid, baseline: int):
    """a 16 px drawing as Terminus TTF's outlines are: pixel squares, 62.5 units each"""
    pen = TTGlyphPen(None)
    h = len(grid)
    for path in trace(grid):
        # trace's y counts from the cell's bottom; the baseline is h - baseline rows up from it
        pts = [(round(x * OUTLINE_UNIT), round((yy - (h - baseline)) * OUTLINE_UNIT + OUTLINE_LIFT)) for x, yy in path]
        pen.moveTo(pts[0])
        for p in pts[1:]:
            pen.lineTo(p)
        pen.closePath()
    return pen.glyph()


def build(data: bytes, style: str) -> TTFont:
    font = TTFont(BytesIO(data), recalcTimestamp=False)
    cmap = font.getBestCmap()
    strikes = [Strike(font, k) for k in range(len(font["EBLC"].strikes))]
    for s in strikes:
        letters = russian(s)
        for ch, grid in letters.items():
            s.put(ch, grid)
        if s.ppem == OUTLINE_PPEM:
            _, m = s.get("н")
            glyf = font["glyf"]
            for ch, grid in letters.items():
                g = outline_glyph(grid, m.horiBearingY)
                g.recalcBounds(glyf)
                glyf[cmap[ord(ch)]] = g
                adv = font["hmtx"][cmap[ord(ch)]][0]
                font["hmtx"][cmap[ord(ch)]] = (adv, g.xMin if g.numberOfContours else 0)

    # without the icons: every character but the private use area's, and powerline's arrows
    keep = [c for c in cmap if not (0xE000 <= c <= 0xF8FF or c >= 0xF0000)] + [c for c in cmap if 0xE0A0 <= c <= 0xE0D7]
    o = subset.Options()
    o.layout_features = ["*"]
    o.name_IDs = ["*"]
    o.name_languages = ["*"]
    o.notdef_outline = True
    o.glyph_names = True
    o.hinting = True
    o.drop_tables = [t for t in o.drop_tables if t not in ("EBDT", "EBLC")] + ["BDF ", "PfEd"]
    sub = subset.Subsetter(o)
    sub.populate(unicodes=keep)
    sub.subset(font)

    # its own name: a changed Terminus can't be called Terminus (OFL, reserved font name)
    name = font["name"]
    copyright_ = name.getDebugName(0) or ""
    ps = f"{FAMILY.replace(' ', '')}-{style}"
    for rec in list(name.names):
        if rec.nameID in (16, 17, 18, 21, 22, 25):
            name.removeNames(nameID=rec.nameID)
    for nid, text in {
        0: f"{copyright_}; changed by kawt-shell (tools/termfont.py): russian lowercase de, i, short i, ve",
        1: FAMILY,
        2: style,
        3: f"kawt;{ps};{VERSION}",
        4: FAMILY if style == "Regular" else f"{FAMILY} {style}",
        5: f"Version {VERSION}",
        6: ps,
        13: "SIL Open Font License, Version 1.1",
        14: "https://openfontlicense.org",
    }.items():
        name.removeNames(nameID=nid)
        name.setName(text, nid, 3, 1, 0x409)
        name.setName(text, nid, 1, 0, 0)
    font["head"].modified = font["head"].created  # the same file every time
    return font


def main() -> None:
    given = sys.argv[1:]
    if given and len(given) != 2:
        sys.exit("termfont: give both (Regular.ttf Bold.ttf), or none")
    for k, (style, (file, sha)) in enumerate(SOURCES.items()):
        if given:
            data = Path(given[k]).read_bytes()
        else:
            with urllib.request.urlopen(BASE + file, timeout=120) as r:
                data = r.read()
        if hashlib.sha256(data).hexdigest() != sha:
            sys.exit(f"termfont: that's not the {style} these were made from (sha256 differs)")
        path = OUT / f"KawtTerm-{style}.ttf"
        font = build(data, style)
        font.save(str(path))
        print(f"termfont: {path.relative_to(OUT.parent.parent.parent)} ({len(font.getGlyphOrder())} glyphs, {len(font['EBLC'].strikes)} sizes)")


if __name__ == "__main__":
    main()
