#!/bin/sh
# usage: wifi-hidden.sh <ssid>      the password on stdin (an empty line: an open network)
# Connects to a wifi network that doesn't announce its name (modules/popovers/WifiPopover.qml).
# NetworkManager keeps it afterwards, like any saved network. The password never goes into an
# argument (those can be read by anyone in /proc): printf is built into sh, and nmcli reads it
# from its passwd-file, here stdin.
# exit 0: connected · 1: failed (the half-made connection is removed again; why: on stdout) · 2: usage

ssid=$1
[ -n "$ssid" ] || exit 2
command -v nmcli > /dev/null || {
    echo "nmcli isn't installed"
    exit 1
}
IFS= read -r pw || true

# saved without the password: nmcli hands it over while connecting, and NetworkManager stores it
if [ -n "$pw" ]; then
    out=$(nmcli connection add type wifi con-name "$ssid" ssid "$ssid" 802-11-wireless.hidden yes 802-11-wireless-security.key-mgmt wpa-psk 2>&1)
else
    out=$(nmcli connection add type wifi con-name "$ssid" ssid "$ssid" 802-11-wireless.hidden yes 2>&1)
fi
# "Connection 'home' (8f2c...-...) successfully added."
uuid=$(printf '%s\n' "$out" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -n 1)
if [ -z "$uuid" ]; then
    printf '%s\n' "$out" | tail -n 1
    exit 1
fi

if [ -n "$pw" ]; then
    err=$(printf '802-11-wireless-security.psk:%s\n' "$pw" | nmcli -w 40 connection up uuid "$uuid" passwd-file /dev/stdin 2>&1)
else
    err=$(nmcli -w 40 connection up uuid "$uuid" 2>&1)
fi
code=$?
if [ $code -ne 0 ]; then
    nmcli connection delete uuid "$uuid" > /dev/null 2>&1
    printf '%s\n' "$err" | grep -v '^\s*$' | tail -n 1
    exit 1
fi
exit 0
