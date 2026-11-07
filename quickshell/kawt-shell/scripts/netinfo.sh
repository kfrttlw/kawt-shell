#!/bin/sh
# usage: netinfo.sh
# The connection in use, for the wifi panel (services/NetInfo.qml), as key=value lines:
#   dev=wlan0  ip=192.168.1.30/24  ip6=...  gw=192.168.1.1  dns=192.168.1.1 1.1.1.1  mac=...
#   freq=5180 MHz  rate=866 Mbit/s  chan=36  security=WPA2     (wifi, from networkmanager)
# It only reads (ip, nmcli, /etc/resolv.conf) and asks nothing on the network: the wifi
# details are networkmanager's last scan, not a new one. No default route: nothing printed.

export LC_ALL=C # nmcli speaks the system's language otherwise ("да" for yes in russian)

route=$(ip route show default 2> /dev/null | head -n 1)
dev=$(printf '%s\n' "$route" | awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
[ -n "$dev" ] || exit 0
echo "dev=$dev"
echo "gw=$(printf '%s\n' "$route" | awk '{ for (i = 1; i < NF; i++) if ($i == "via") { print $(i + 1); exit } }')"
echo "ip=$(ip -o -4 addr show dev "$dev" 2> /dev/null | awk '{ print $4; exit }')"
echo "ip6=$(ip -o -6 addr show dev "$dev" scope global 2> /dev/null | awk '{ print $4; exit }')"
echo "mac=$(cat "/sys/class/net/$dev/address" 2> /dev/null)"

dns=""
command -v nmcli > /dev/null && dns=$(nmcli -g IP4.DNS dev show "$dev" 2> /dev/null | tr '|\n' '  ')
[ -n "$(printf '%s' "$dns" | tr -d ' ')" ] || dns=$(awk '/^nameserver/ { printf "%s ", $2 }' /etc/resolv.conf 2> /dev/null)
echo "dns=$(printf '%s' "$dns" | tr -s ' ' | sed 's/^ //; s/ $//')"

if command -v nmcli > /dev/null; then
    nmcli -t -f ACTIVE,FREQ,RATE,CHAN,SECURITY dev wifi list ifname "$dev" --rescan no 2> /dev/null |
        awk -F: '$1 == "yes" { print "freq=" $2; print "rate=" $3; print "chan=" $4; print "security=" $5; exit }'
fi
exit 0
