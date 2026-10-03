#!/bin/sh
# One-shot system facts for the profile panel, as key=value lines (parsed by services/SysInfo.qml).

echo "pkgs=$( (pacman -Qq 2>/dev/null || dpkg-query -f '.\n' -W 2>/dev/null) | wc -l)"
lspci 2>/dev/null | grep -E 'VGA|3D|Display' | head -2 | cut -d: -f3- | sed 's/^/gpu=/'
echo "wm=$(hyprctl version -j 2>/dev/null | grep -m1 '"tag"' | cut -d'"' -f4)"
echo "monitors=$(hyprctl monitors -j 2>/dev/null | tr -d '\n')"

for b in /sys/class/power_supply/BAT*; do
    [ -e "$b" ] || continue
    full=$(cat "$b/energy_full" 2>/dev/null || cat "$b/charge_full" 2>/dev/null)
    design=$(cat "$b/energy_full_design" 2>/dev/null || cat "$b/charge_full_design" 2>/dev/null)
    echo "bathealth=$full $design"
    echo "batcycles=$(cat "$b/cycle_count" 2>/dev/null)"
    echo "batlimit=$(cat "$b/charge_control_end_threshold" 2>/dev/null)"
    break
done
