"""Pixels to outlines, for tools/vgafont.py and tools/termfont.py: a pixel font kitty can take
(it takes no bitmap fonts) is one whose outline goes round each pixel exactly."""


def trace(cell: list[list[bool]]) -> list[list[tuple[int, int]]]:
    """The pixels' outline, as closed paths of corner points in pixels (x right, y up from the
    cell's bottom), clockwise around what's inked, as truetype wants: whole runs, no square
    per pixel. cell: rows of booleans, the top one first."""
    h = len(cell)
    on = {(x, h - 1 - r) for r in range(h) for x, v in enumerate(cell[r]) if v}
    edges: dict[tuple[int, int], list[tuple[int, int]]] = {}

    def edge(a, b):
        edges.setdefault(a, []).append(b)

    # each side of an inked pixel with nothing next to it, walked with the ink on the right
    for x, y in on:
        if (x - 1, y) not in on:
            edge((x, y), (x, y + 1))
        if (x, y + 1) not in on:
            edge((x, y + 1), (x + 1, y + 1))
        if (x + 1, y) not in on:
            edge((x + 1, y + 1), (x + 1, y))
        if (x, y - 1) not in on:
            edge((x + 1, y), (x, y))
    paths = []
    while edges:
        start = min(edges)
        path = [start]
        here, came = start, None
        while True:
            nexts = edges[here]
            if len(nexts) > 1 and came:
                # two pixels touching only at a corner: turn right, so the paths never cross
                dx, dy = here[0] - came[0], here[1] - came[1]
                nexts.sort(key=lambda p: (p[0] - here[0]) * dy - (p[1] - here[1]) * dx, reverse=True)
            to = nexts.pop(0)
            if not nexts:
                del edges[here]
            came, here = here, to
            if here == start:
                break
            path.append(here)
        # corners only: points along a straight side go
        n = len(path)
        corners = [p for i, p in enumerate(path)
                   if (path[i - 1][0] - p[0]) * (path[(i + 1) % n][1] - p[1]) != (path[i - 1][1] - p[1]) * (path[(i + 1) % n][0] - p[0])]
        paths.append(corners)
    return paths
