#!/usr/bin/env bash
# Does kawt load? It starts in a headless sway (no screen needed), every panel, window, tab and
# settings page is opened over ipc (and the lock, as a test), and what qt says went wrong while
# loading QML is listed. Exit 1 if anything did: a type that isn't there, a property that isn't,
# javascript too new for qt, a handler for a signal that's gone... what tools/check.py can only
# guess at, here as qt itself sees it.
#   tools/load-test.sh        (needs sway and quickshell; ci runs it in an arch container)
# All of it in a world of its own: its own HOME and runtime folder, its own session bus, no
# Hyprland (hyprctl answers nothing), so your settings, your desktop and your Hyprland are never
# touched. What depends on the machine (no Hyprland here, no system bus in a container) is shown,
# not counted.
set -uo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
for c in sway qs dbus-run-session; do
    command -v "$c" > /dev/null || { echo "load-test: needs $c"; exit 2; }
done

tmp=$(mktemp -d "${TMPDIR:-/tmp}/kawt-load.XXXXXX")
mkdir -p "$tmp/home" "$tmp/run" "$tmp/bin" "$tmp/home/.config/quickshell"
chmod 700 "$tmp/run"
ln -s "$repo/quickshell/kawt-shell" "$tmp/home/.config/quickshell/kawt-shell"
# no Hyprland to talk to: hyprctl says nothing, so nothing is reloaded or dispatched anywhere
printf '#!/bin/sh\nexit 1\n' > "$tmp/bin/hyprctl"
chmod +x "$tmp/bin/hyprctl"
printf 'output * resolution 1920x1080\n' > "$tmp/sway.conf"

# the run itself, inside its own session bus
cat > "$tmp/run.sh" << 'EOF'
set -uo pipefail
cd "$HOME"
WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_HEADLESS_OUTPUTS=1 sway -c "$TMPD/sway.conf" > "$TMPD/sway.log" 2>&1 &
sway_pid=$!
for _ in $(seq 50); do
    sock=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-*' ! -name '*.lock' -print -quit)
    [[ -n $sock ]] && break
    sleep 0.2
done
[[ -n ${sock:-} ]] || { echo "load-test: sway didn't start"; tail -n 20 "$TMPD/sway.log"; exit 2; }
export WAYLAND_DISPLAY=${sock##*/}

qs -c kawt-shell > "$TMPD/qs.log" 2>&1 &
qs_pid=$!
ipc() { qs -c kawt-shell ipc call kawt "$@" > /dev/null 2>&1; }
# up once ipc answers
for _ in $(seq 100); do
    qs -c kawt-shell ipc show > /dev/null 2>&1 && break
    kill -0 "$qs_pid" 2> /dev/null || break
    sleep 0.2
done
if ! qs -c kawt-shell ipc show > /dev/null 2>&1; then
    echo "load-test: kawt didn't come up (no ipc)"
    tail -n 40 "$TMPD/qs.log"
    kill "$sway_pid" 2> /dev/null
    exit 1
fi
sleep 2
step() {
    ipc "$@"
    sleep 0.6
}
# the panels under the bar, the run box, the start menu, the others
for p in launcher menu tray power keys calendar player volume brightness battery mic bluetooth wifi notifs home; do
    step toggle "$p"
    ipc close
done
step welcome
ipc close
step sidebar
step sidebar
step selection
ipc close
# kawt's windows, at each tab; the settings at each page; the theme editor
for t in today todo notes focus; do step window today "$t"; done
for t in sys top net power; do step window system "$t"; done
for t in wall theme change; do step window style "$t"; done
for p in look bar screen media device windows kawt; do step settings "$p"; done
step theme new
# stripes out of the corner, the lock (a test one: it opens by itself)
step companion call
step lockTest
sleep 2
kill -0 "$qs_pid" 2> /dev/null && echo alive > "$TMPD/alive"
kill "$qs_pid" 2> /dev/null
sleep 0.5
kill "$sway_pid" 2> /dev/null
wait 2> /dev/null
exit 0
EOF

env -i PATH="$tmp/bin:$PATH" HOME="$tmp/home" USER="${USER:-tester}" TMPD="$tmp" \
    XDG_RUNTIME_DIR="$tmp/run" XDG_CONFIG_HOME="$tmp/home/.config" LANG=C.UTF-8 \
    QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software \
    dbus-run-session -- bash "$tmp/run.sh"
code=$?
((code == 2)) && exit 2

log=$tmp/qs.log
# what stops a part of kawt from loading: qt's words for it
broken='is not a type|Type [A-Za-z_.]+ unavailable|non-existent (default )?property|Non-existent attached object|Invalid property assignment|Cannot override FINAL|Expected token|Syntax ?[Ee]rror|Unexpected token|is not installed|Property value set multiple times|Invalid alias|in Connections element|ReferenceError|is not a function|Failed to load|failed to load|Cannot assign to read-only|Cannot assign object'
# what kawt itself may say about a machine without Hyprland, a system bus, pipewire...: shown
mapfile -t bad < <(grep -E "$broken" "$log" | sed 's/^[^:]*file:\/\/[^ ]*kawt-shell\//kawt-shell\//' | sort | uniq -c | sort -rn)
mapfile -t other < <(grep -iE 'warn|error|TypeError' "$log" | grep -vE "$broken" | sed 's/^ *//' | cut -c1-200 | sort | uniq -c | sort -rn | head -n 25)

echo "kawt loaded in a headless sway: $(grep -c . "$log") log lines"
[[ -f $tmp/alive ]] && echo "it was still running at the end" || echo "it was NOT running at the end"
if ((${#other[@]})); then
    echo "-- what depends on this machine (not counted) --"
    printf '  %s\n' "${other[@]}"
fi
if ((${#bad[@]})); then
    echo "-- what didn't load --"
    printf '  %s\n' "${bad[@]}"
fi
if ((${#bad[@]} == 0)) && [[ -f $tmp/alive ]]; then
    echo "load-test: ok"
    rm -rf -- "$tmp"
    exit 0
fi
echo "load-test: failed (the whole log: $log)"
exit 1
