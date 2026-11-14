#!/usr/bin/env python3
"""kawt VGA: the IBM PC's text mode font (VGA, 8 x 16), as a font kitty can use.

kitty only takes scalable fonts (no bitmap ones), and a pixel font drawn as curves goes soft. So
every pixel of the original becomes a square here, on a grid that is exactly one screen pixel at
16 px (12 pt at 96 dpi): at 16, 32, 48 px each pixel lands on the screen's own, sharp, with no
gray at the edges. kitty's font file is written for that by scripts/kitty-font.sh (settings ->
look -> terminal), which works out the points from the screen's scale.

The pixels: IBM's VGA font with latin, greek and cyrillic added, as BDF by farsil
(github.com/farsil/ibmfonts, iv8x16u.bdf, CC BY-SA 4.0). This one is under that license too:
quickshell/kawt-shell/fonts/VGA-LICENSE.txt.
Bold is the old way: each pixel drawn twice, one to the right (as terminals of the time did).

    python3 tools/vgafont.py [iv8x16u.bdf]    writes fonts/KawtVGA-Regular.ttf and -Bold.ttf
Without a file it's fetched, and checked against the one these were made from. Needs fontTools
(pip install fonttools); kawt itself only needs the .ttf files.
"""

import hashlib
import sys
import urllib.request
from pathlib import Path

try:
    from fontTools.fontBuilder import FontBuilder
    from fontTools.pens.ttGlyphPen import TTGlyphPen
    from fontTools.ttLib.tables.O_S_2f_2 import Panose
except ImportError:
    sys.exit("vgafont: needs fontTools (pip install fonttools)")
from pixeltrace import trace

SOURCE = "https://raw.githubusercontent.com/farsil/ibmfonts/master/bdf/iv8x16u.bdf"
SHA256 = "a6265fb1ec9c560cc8a81da86531f98c0fdca724f96c4727794cb107ea277ff5"
OUT = Path(__file__).resolve().parent.parent / "quickshell/kawt-shell/fonts"
FAMILY = "kawt VGA"
VERSION = "1.000"

W, H, ASCENT = 8, 16, 12  # the cell, in pixels; the baseline 12 rows down
UNIT = 128  # one pixel, in font units: 16 px = 2048, the usual em
UPM = H * UNIT


def read_bdf(text: str) -> dict[int, list[list[bool]]]:
    """{codepoint: rows of the 8 x 16 cell, top first}"""
    glyphs: dict[int, list[list[bool]]] = {}
    code = bbx = None
    bits: list[str] | None = None
    for line in text.splitlines():
        word, _, rest = line.partition(" ")
        if word == "ENCODING":
            code = int(rest.split()[0])
        elif word == "BBX":
            bbx = [int(v) for v in rest.split()]
        elif word == "BITMAP":
            bits = []
        elif word == "ENDCHAR":
            if code is not None and code >= 0 and bbx and bits is not None:
                bw, bh, bx, by = bbx
                cell = [[False] * W for _ in range(H)]
                for i, hexrow in enumerate(bits):
                    value = int(hexrow, 16)
                    width = len(hexrow) * 4
                    row = ASCENT - by - bh + i  # from the cell's top
                    for c in range(bw):
                        x = bx + c
                        if value >> (width - 1 - c) & 1 and 0 <= x < W and 0 <= row < H:
                            cell[row][x] = True
                glyphs[code] = cell
            code = bbx = bits = None
        elif bits is not None:
            bits.append(line.strip())
    return glyphs


def bold(cell: list[list[bool]]) -> list[list[bool]]:
    # each pixel twice, the second one to the right; what would leave the cell is cut
    return [[row[x] or (x > 0 and row[x - 1]) for x in range(W)] for row in cell]


def outline(cell: list[list[bool]]):
    """The pixels' outline in font units, y up from the baseline (tools/pixeltrace.py)."""
    return [[(x * UNIT, (y - (H - ASCENT)) * UNIT) for x, y in path] for path in trace(cell)]


def glyph_name(code: int) -> str:
    return "space" if code == 32 else f"uni{code:04X}"


def build(cells: dict[int, list[list[bool]]], style: str) -> FontBuilder:
    is_bold = style == "Bold"
    order = [".notdef"] + [glyph_name(c) for c in sorted(cells)]
    fb = FontBuilder(UPM, isTTF=True)
    fb.font.recalcTimestamp = False  # the same pixels, the same file
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap({c: glyph_name(c) for c in cells})
    glyphs, metrics = {}, {}
    notdef = [[0 < x < W - 1 and 1 < r < H - 2 and (x in (1, W - 2) or r in (2, H - 3)) for x in range(W)] for r in range(H)]
    for name, cell in [(".notdef", notdef)] + [(glyph_name(c), cells[c]) for c in sorted(cells)]:
        if is_bold and name != ".notdef":
            cell = bold(cell)
        pen = TTGlyphPen(None)
        for path in outline(cell):
            pen.moveTo(path[0])
            for p in path[1:]:
                pen.lineTo(p)
            pen.closePath()
        g = pen.glyph()
        glyphs[name] = g
        lsb = min((x for r in cell for x, v in enumerate(r) if v), default=0) * UNIT
        metrics[name] = (W * UNIT, lsb)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASCENT * UNIT, descent=-(H - ASCENT) * UNIT, lineGap=0)
    panose = Panose()  # text, monospaced: what fontconfig and others go by
    for k in ("bSerifStyle", "bWeight", "bContrast", "bStrokeVariation", "bArmStyle", "bLetterForm", "bMidline", "bXHeight"):
        setattr(panose, k, 0)
    panose.bFamilyType, panose.bProportion, panose.bWeight = 2, 9, 8 if is_bold else 5
    full = FAMILY if not is_bold else f"{FAMILY} Bold"
    fb.setupNameTable({
        "copyright": "IBM VGA 8x16 BDF (c) 2016 farsil, CC BY-SA 4.0; as truetype by kawt-shell (tools/vgafont.py), CC BY-SA 4.0",
        "familyName": FAMILY,
        "styleName": style,
        "uniqueFontIdentifier": f"kawt;{FAMILY.replace(' ', '')}-{style};{VERSION}",
        "fullName": full,
        "psName": f"{FAMILY.replace(' ', '')}-{style}",
        "version": f"Version {VERSION}",
        "licenseDescription": "Creative Commons Attribution-ShareAlike 4.0 International",
        "licenseInfoURL": "https://creativecommons.org/licenses/by-sa/4.0/",
    })
    fb.setupOS2(
        version=4,
        usWeightClass=700 if is_bold else 400,
        fsSelection=0x20 if is_bold else 0x40,  # bold / regular
        achVendID="KAWT",
        xAvgCharWidth=W * UNIT,
        sTypoAscender=ASCENT * UNIT, sTypoDescender=-(H - ASCENT) * UNIT, sTypoLineGap=0,
        usWinAscent=ASCENT * UNIT, usWinDescent=(H - ASCENT) * UNIT,
        sxHeight=7 * UNIT, sCapHeight=10 * UNIT,
        ulUnicodeRange1=(1 << 0) | (1 << 1) | (1 << 2) | (1 << 7) | (1 << 9),  # latin, latin-1, latin ext a, greek, cyrillic
        ulCodePageRange1=(1 << 0) | (1 << 1) | (1 << 2) | (1 << 3),  # 1252 1250 1251 1253
        panose=panose,
    )
    fb.setupPost(isFixedPitch=1, underlinePosition=-2 * UNIT, underlineThickness=UNIT)
    head = fb.font["head"]
    head.created = head.modified = 3_870_000_000  # fixed: the same file every time (2026)
    head.macStyle = 1 if is_bold else 0
    # whole pixels: freetype takes the size it's asked for to the nearest whole pixel (kitty asks
    # in points, which seldom land on one exactly: 9.6 pt at 1.25 is 16.016 px), so a pixel stays a pixel
    head.flags |= 1 << 3
    return fb


def main() -> None:
    if len(sys.argv) > 1:
        data = Path(sys.argv[1]).read_bytes()
    else:
        with urllib.request.urlopen(SOURCE, timeout=60) as r:
            data = r.read()
    if hashlib.sha256(data).hexdigest() != SHA256:
        sys.exit("vgafont: that's not the bdf these were made from (sha256 differs)")
    cells = read_bdf(data.decode("latin-1"))
    for style in ("Regular", "Bold"):
        path = OUT / f"KawtVGA-{style}.ttf"
        build(cells, style).save(str(path))
        print(f"vgafont: {path.relative_to(OUT.parent.parent.parent)} ({len(cells)} glyphs)")


if __name__ == "__main__":
    main()
