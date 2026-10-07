#!/usr/bin/env python3
"""Static checks for the kawt QML, the two mistakes that stop the whole shell from loading:
  - a type used without importing its module   ("Popover is not a type", "Type X unavailable")
  - the same property set twice in one object  ("Property value set multiple times")
  - JavaScript newer than Qt's engine            (matchAll, flatMap, ...)
Run from anywhere, best before every commit:
    python3 tools/check.py
Exits 1 if something is wrong."""
import os
import re
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

print(f"{problems} problem(s)" if problems else "all checks ok")
sys.exit(1 if problems else 0)
