#!/bin/bash
# Script to remove routes to networks behind PC2

GATEWAY="10.136.1.1"
NETA="192.168.10.0/24"
NETB="192.168.20.0/24"

echo "[*] Removing routes via ${GATEWAY}..."

sudo ip route del ${NETA} via ${GATEWAY}
sudo ip route del ${NETB} via ${GATEWAY}

echo "[+] Routes removed."
ip route show | grep 192.168 || echo "No active 192.168 routes"
