#!/usr/bin/env python3
"""Finds QML files that use a type without importing the module it comes from
("Popover is not a type", "Type X unavailable"). Run from anywhere:
    python3 tools/check-imports.py
Exits 1 if something is missing."""
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
    "PanelWindow": "Quickshell", "Variants": "Quickshell", "Scope": "Quickshell", "ShellRoot": "Quickshell",
    "Singleton": "Quickshell", "Region": "Quickshell", "QsMenuOpener": "Quickshell", "ShellScreen": "Quickshell",
    "WlSessionLock": "Quickshell.Wayland", "WlSessionLockSurface": "Quickshell.Wayland",
    "WlrLayershell": "Quickshell.Wayland", "WlrLayer": "Quickshell.Wayland",
    "IconImage": "Quickshell.Widgets", "PamContext": "Quickshell.Services.Pam",
    "UPower": "Quickshell.Services.UPower", "PowerProfiles": "Quickshell.Services.UPower",
    "Pipewire": "Quickshell.Services.Pipewire", "PwObjectTracker": "Quickshell.Services.Pipewire",
    "Mpris": "Quickshell.Services.Mpris", "SystemTray": "Quickshell.Services.SystemTray",
    "NotificationServer": "Quickshell.Services.Notifications", "Hyprland": "Quickshell.Hyprland",
    "Networking": "Quickshell.Networking",
    "RowLayout": "QtQuick.Layouts", "ColumnLayout": "QtQuick.Layouts", "GridLayout": "QtQuick.Layouts",
    "MultiEffect": "QtQuick.Effects",
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

print(f"{problems} problem(s)" if problems else "imports ok")
sys.exit(1 if problems else 0)
