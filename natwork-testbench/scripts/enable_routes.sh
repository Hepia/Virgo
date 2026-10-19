#!/bin/bash
# Script to add routes to networks behind PC2

GATEWAY="10.136.127.186"
NETA="192.168.10.0/24"
NETB="192.168.20.0/24"

echo "[*] Enabling routes via ${GATEWAY}..."

sudo ip route add ${NETA} via ${GATEWAY}
sudo ip route add ${NETB} via ${GATEWAY}

echo "[+] Routes added."
ip route show | grep 192.168
