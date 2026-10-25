#!/usr/bin/env python3
"""Writes quickshell/kawt-shell/data/emoji.tsv, the launcher's emoji list (the `.` mode).
One line per emoji: the emoji, its english name, its russian name, other names, all lowercase.
Skin tones are left out (the plain one stays), so are the not fully qualified forms.
The names are unicode's own (CLDR), through the python `emoji` package:
    pip install emoji && python3 tools/emoji-list.py
Nothing reads the network at run time: the list lives in the repo."""
import os

import emoji
from emoji.unicode_codes import load_from_json

load_from_json("ru")
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "quickshell", "kawt-shell", "data", "emoji.tsv")
tones = set("\U0001F3FB\U0001F3FC\U0001F3FD\U0001F3FE\U0001F3FF")


def words(name):
    return name.strip(":").replace("_", " ").lower()


rows = []
for e, v in emoji.EMOJI_DATA.items():
    if v["status"] != emoji.STATUS["fully_qualified"] or any(c in tones for c in e):
        continue
    en = words(v["en"])
    other = [words(a) for a in v.get("alias", [])]
    other = [a for a in dict.fromkeys(other) if a != en]
    rows.append((e, en, words(v.get("ru", "")), " ".join(other)))

# in code point order: the faces together, then the people, the animals...
rows.sort(key=lambda r: [ord(c) for c in r[0]])
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w", encoding="utf-8") as f:
    f.write(f"# kawt emoji list: emoji, english, russian, other names. Made by tools/emoji-list.py (emoji {emoji.__version__}, unicode CLDR names)\n")
    for r in rows:
        f.write("\t".join(r) + "\n")
print(f"{len(rows)} emoji -> {os.path.relpath(out)}")
