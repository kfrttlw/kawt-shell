#!/bin/sh
# usage: netlinks.sh
# The wired and vpn links in use, for the bar (services/NetLinks.qml), as two lines:
#   wired=enp3s0    a cable interface (en*, eth*) that is up and has an address; empty: none
#   vpn=wg0         a tunnel with an address; empty: none
# A tunnel is told by its link type, not its name: wireguard, openvpn's tun, tailscale and
# zerotier show "link/none", ppp-based ones "link/ppp", whatever they're called.
# Needs only ip (iproute2) and /sys.

# interfaces holding an address that reaches beyond this machine
addr=$(ip -o addr show scope global 2> /dev/null | awk '{ print $2 }' | sort -u)
# "3: wg0: <POINTOPOINT,...> ... link/none" -> wg0
tunnels=$(ip -o link show 2> /dev/null | awk -F': ' '/link\/(none|ppp)/ { sub(/@.*/, "", $2); print $2 }')

wired=
vpn=
for i in $addr; do
    case $i in
        en* | eth*)
            [ -z "$wired" ] && [ "$(cat "/sys/class/net/$i/operstate" 2> /dev/null)" = up ] && wired=$i
            ;;
    esac
    if [ -z "$vpn" ]; then
        for t in $tunnels; do
            [ "$t" = "$i" ] && vpn=$i && break
        done
    fi
done

echo "wired=$wired"
echo "vpn=$vpn"
