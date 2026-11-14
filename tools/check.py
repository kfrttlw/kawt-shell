#!/usr/bin/env python3
"""Static checks for the kawt QML, the two mistakes that stop the whole shell from loading:
  - a type used without importing its module   ("Popover is not a type", "Type X unavailable")
  - the same property set twice in one object  ("Property value set multiple times")
  - JavaScript newer than Qt's engine            (matchAll, flatMap, ...)
  - a property named like one an Item already has, left / x / visible...
                                                 ("Cannot override FINAL property", Qt 6.10+)
  - an ipc call (a key in hypr/, a script) with another number of words than its function
    takes: quickshell refuses it and the key does nothing
  - a Connections handler for a signal one of kawt's singletons doesn't have
    (a setting renamed or gone: qt only warns, at run time)
  - kawt's words (config/Strings.qml): a line without its comma, a key used
    with Strings.t("...") that one of the two languages doesn't have, a word
    given more or fewer .arg(...) than it has places (%1, %2...)
Run from anywhere, best before every commit:
    python3 tools/check.py
Exits 1 if something is wrong."""
import os
import re
import shlex
import sys

shell = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "quickshell", "kawt-shell")
os.chdir(shell)

# our own modules: type name -> import
provides = {}
for d, mod in [("components", "qs.components"), ("services", "qs.services"), ("config", "qs.config"), ("utils", "qs.utils")]:
    for f in os.listdir(d):
        if f.endswith(".qml"):
            provides[f[:-4]] = mod

# Qt / Quickshell types used in kawt -> import
external = {
    "Process": "Quickshell.Io", "StdioCollector": "Quickshell.Io", "SplitParser": "Quickshell.Io",
    "FileView": "Quickshell.Io", "JsonAdapter": "Quickshell.Io", "IpcHandler": "Quickshell.Io",
    "PanelWindow": "Quickshell", "Variants": "Quickshell", "LazyLoader": "Quickshell", "Scope": "Quickshell", "ShellRoot": "Quickshell",
    "Singleton": "Quickshell", "Region": "Quickshell", "QsMenuOpener": "Quickshell", "ShellScreen": "Quickshell",
    "WlSessionLock": "Quickshell.Wayland", "WlSessionLockSurface": "Quickshell.Wayland",
    "WlrLayershell": "Quickshell.Wayland", "WlrLayer": "Quickshell.Wayland",
    "IconImage": "Quickshell.Widgets", "PamContext": "Quickshell.Services.Pam",
    "UPower": "Quickshell.Services.UPower", "PowerProfiles": "Quickshell.Services.UPower",
    "Pipewire": "Quickshell.Services.Pipewire", "PwObjectTracker": "Quickshell.Services.Pipewire",
    "Mpris": "Quickshell.Services.Mpris", "SystemTray": "Quickshell.Services.SystemTray",
    "NotificationServer": "Quickshell.Services.Notifications", "Hyprland": "Quickshell.Hyprland",
    "Networking": "Quickshell.Networking", "Bluetooth": "Quickshell.Bluetooth",
    "BluetoothDeviceState": "Quickshell.Bluetooth",
    "RowLayout": "QtQuick.Layouts", "ColumnLayout": "QtQuick.Layouts", "GridLayout": "QtQuick.Layouts",
    "MultiEffect": "QtQuick.Effects",
    "ScriptModel": "Quickshell", "SystemClock": "Quickshell", "QsWindow": "Quickshell", "DesktopEntries": "Quickshell",
    "IdleMonitor": "Quickshell.Wayland", "IdleInhibitor": "Quickshell.Wayland",
    "HyprlandFocusGrab": "Quickshell.Hyprland", "PwNode": "Quickshell.Services.Pipewire",
}

problems = 0
for dirpath, _, files in os.walk("."):
    for f in files:
        if not f.endswith(".qml"):
            continue
        path = os.path.join(dirpath, f)
        src = open(path).read()
        here = os.path.dirname(path)
        imports = set(re.findall(r"^import\s+(\S+)", src, re.M))
        visible = {x[:-4] for x in os.listdir(here) if x.endswith(".qml")}  # same folder
        for imp in imports:  # "../popovers" style imports
            if imp.startswith('"'):
                d = os.path.normpath(os.path.join(here, imp.strip('"')))
                if os.path.isdir(d):
                    visible |= {x[:-4] for x in os.listdir(d) if x.endswith(".qml")}
        code = re.sub(r"//.*", "", src)
        code = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', code)
        visible |= set(re.findall(r"component\s+(\w+)\s*:", code))
        used = set(re.findall(r"\b([A-Z]\w+)\s*\{", code)) | set(re.findall(r"\b([A-Z]\w+)\.[a-z]", code)) \
            | set(re.findall(r"property\s+([A-Z]\w+)\s", code))
        for t in sorted(used - visible):
            need = provides.get(t) or external.get(t)
            if need and need not in imports:
                print(f"{path}: uses {t} but doesn't import {need}")
                problems += 1

# the same property assigned twice inside one object
for dirpath, _, files in os.walk("."):
    for f in files:
        if not f.endswith(".qml"):
            continue
        path = os.path.join(dirpath, f)
        stack = [set()]
        for n, line in enumerate(open(path).read().split("\n"), 1):
            code = re.sub(r"//.*", "", line)
            m = re.match(r"\s*([a-zA-Z][\w.]*)\s*:\s*\S", code)
            if m and not code.strip().startswith(("property", "readonly", "required", "signal", "function", "case", "default")):
                key = m.group(1)
                if key in stack[-1] and not key.startswith("on"):
                    print(f"{path}:{n}: {key} is set twice in one object")
                    problems += 1
                stack[-1].add(key)
            for ch in code:
                if ch == "{":
                    stack.append(set())
                elif ch == "}" and len(stack) > 1:
                    stack.pop()

# JavaScript newer than Qt's engine understands (it stops the file from loading)
too_new = {r"\.matchAll\(": "matchAll", r"\.flatMap\(": "flatMap", r"\.flat\(": "flat", r"\.replaceAll\(": "replaceAll",
           r"Object\.fromEntries": "Object.fromEntries", r"\?\?=|\|\|=|&&=": "logical assignment", r"\.at\(-?\d": ".at()", r"\?\.\[": "?.[ (write it out with && or ||)"}
for dirpath, _, files in os.walk("."):
    for f in files:
        if not f.endswith((".qml", ".js")):
            continue
        path = os.path.join(dirpath, f)
        for n, line in enumerate(open(path).read().split("\n"), 1):
            code = re.sub(r"//.*", "", line)
            for pattern, name in too_new.items():
                if re.search(pattern, code):
                    print(f"{path}:{n}: {name} is too new for Qt's JavaScript engine")
                    problems += 1

# an Item's own properties that newer Qt marks FINAL (Qt 6.12: these 22, the same on Text,
# Rectangle, MouseArea, the layouts...): a property of ours with one of those names stops the file
# from loading. A QtObject or a Singleton has none of them, so its own top-level ones are fine
final_names = "parent x y z width height opacity visible childrenRect anchors left right horizontalCenter top bottom verticalCenter baseline focus activeFocus activeFocusOnTab transform layer"
final = re.compile(r"^(\s*)(?:(?:readonly|required|default)\s+)*property\s+[\w<>.]+\s+(" + "|".join(final_names.split()) + r")\b")
not_items = ("QtObject", "Singleton", "Scope", "Variants", "Process", "Timer", "FileView", "Connections")
for dirpath, _, files in os.walk("."):
    for f in files:
        if not f.endswith(".qml"):
            continue
        path = os.path.join(dirpath, f)
        lines = open(path).read().split("\n")
        root_type = next((m.group(1) for l in lines for m in [re.match(r"^(\w+)\s*\{", l)] if m), "")
        for n, line in enumerate(lines, 1):
            m = final.match(line)
            if m and not (root_type in not_items and len(m.group(1)) == 4):
                print(f"{path}:{n}: a property named {m.group(2)}: every Item has one already (Cannot override FINAL property)")
                problems += 1

# a handler in Connections { target: Settings } (or another of kawt's singletons) for a signal it
# doesn't have: a setting renamed or gone leaves it behind, and qt only warns at run time
def block(src, at):
    """the text from the { at `at` to its }"""
    depth, i = 0, at
    while i < len(src):
        depth += {"{": 1, "}": -1}.get(src[i], 0)
        i += 1
        if depth == 0:
            break
    return src[at:i]


signals = {}
for d in ("config", "services"):
    for f in os.listdir(d):
        if f.endswith(".qml"):
            src = re.sub(r"//.*", "", open(os.path.join(d, f), encoding="utf-8").read())
            props = re.findall(r"\bproperty\s+[\w<>.]+\s+(\w+)", src)
            sigs = re.findall(r"^\s*signal\s+(\w+)", src, re.M)
            signals[f[:-4]] = {f"on{p[0].upper()}{p[1:]}Changed" for p in props} | {f"on{s[0].upper()}{s[1:]}" for s in sigs}
for dirpath, _, files in os.walk("."):
    for f in files:
        if not f.endswith(".qml"):
            continue
        path = os.path.join(dirpath, f)
        src = re.sub(r"//.*", "", open(path, encoding="utf-8").read())
        for m in re.finditer(r"\bConnections\s*\{", src):
            body = block(src, m.end() - 1)
            t = re.search(r"^\s*target:\s*(\w+)\s*$", body, re.M)
            if not t or t.group(1) not in signals:
                continue
            for h in re.findall(r"function\s+(on\w+)\s*\(", body):
                if h not in signals[t.group(1)]:
                    print(f"{path}: Connections on {t.group(1)} has {h}, but {t.group(1)} has no such signal")
                    problems += 1

# an ipc call (a key in hypr/, a script) with another number of words than its function in
# services/Panels.qml takes: quickshell refuses it ("Too few arguments") and the key does nothing
panels = open(os.path.join("services", "Panels.qml"), encoding="utf-8").read()
handler = panels[panels.index("IpcHandler {"):]
takes = {m.group(1): len([a for a in m.group(2).split(",") if a.strip()]) for m in re.finditer(r"function (\w+)\(([^)]*)\)", handler)}
repo_root = os.path.join("..", "..")
for dirpath, dirs, files in os.walk(repo_root):
    dirs[:] = [d for d in dirs if d != ".git"]
    for f in files:
        if not f.endswith((".lua", ".conf", ".sh")):
            continue
        path = os.path.join(dirpath, f)
        for n, line in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
            if line.strip().startswith(("--", "#")):
                continue
            found = re.findall(r'kawt \.\. "([^"]*)"', line) + re.findall(r"\$kawt ([^#\n]*)", line) + re.findall(r"ipc call kawt ([^|;&)\n]*)", line)
            for c in found:
                c = re.split(r"\s+\d*[<>]", c.split("||")[0])[0]  # no fallback after ||, no redirections
                try:
                    words = shlex.split(c)
                except ValueError:
                    continue
                if words and words[0] in takes and len(words) - 1 != takes[words[0]]:
                    print(f"{os.path.relpath(path, repo_root)}:{n}: kawt {' '.join(words)}: {words[0]} takes {takes[words[0]]} word(s) after it, quickshell refuses another number")
                    problems += 1

# kawt's words: both dictionaries whole, every line but the last with its comma
words = open(os.path.join("config", "Strings.qml"), encoding="utf-8").read()
langs = {}
places = {}  # (dictionary, word) -> how many places it has: %1, %2...
for name in ("enWords", "ruWords"):
    m = re.search(name + r": \(\{\n(.*?)\n    \}\)", words, re.S)
    if not m:
        print(f"config/Strings.qml: no {name}")
        problems += 1
        continue
    lines = [l for l in m.group(1).split("\n") if l.strip()]
    for i, l in enumerate(lines):
        if i < len(lines) - 1 and not l.rstrip().endswith(","):
            print(f"config/Strings.qml: {name}: no comma after {l.strip()[:40]}")
            problems += 1
    langs[name] = set(re.findall(r"^\s+(\w+):", m.group(1), re.M))
    for key, value in re.findall(r'^\s+(\w+): ("(?:[^"\\]|\\.)*")', m.group(1), re.M):
        places[(name, key)] = len(set(re.findall(r"%\d", value)))


def args_after(src, at):
    """how many .arg(...) follow at `at`, each with whatever is in its brackets"""
    n = 0
    while src.startswith(".arg(", at):
        depth, at = 1, at + 5
        while at < len(src) and depth:
            depth += {"(": 1, ")": -1}.get(src[at], 0)
            at += 1
        n += 1
    return n


for dirpath, _, files in os.walk("."):
    for f in files:
        if not f.endswith(".qml") or f == "Strings.qml":
            continue
        path = os.path.join(dirpath, f)
        src = open(path, encoding="utf-8").read()
        for m in re.finditer(r'Strings\.t\("(\w+)"\)', src):
            key = m.group(1)
            given = args_after(src, m.end())
            for name, keys in langs.items():
                if key not in keys:
                    print(f"{path}: \"{key}\" is missing in {name}")
                    problems += 1
                elif given and places.get((name, key)) != given:
                    print(f"{path}: \"{key}\" gets {given} .arg() but has {places.get((name, key))} places in {name}")
                    problems += 1

print(f"{problems} problem(s)" if problems else "all checks ok")
sys.exit(1 if problems else 0)
