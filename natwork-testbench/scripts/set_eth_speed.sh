#!/bin/bash
set -eu

# Usage function
usage() {
    echo "Usage: $0 <interface>"
    echo "Example: $0 eno2"
    exit 1
}

# Check arguments
if [ $# -ne 1 ]; then
    usage
fi

IFACE="$1"

# Check if interface exists
if ! nmcli device status | awk '{print $1}' | grep -q "^${IFACE}$"; then
    echo "Error: Interface ${IFACE} not found in NetworkManager."
    exit 1
fi

# Show current configuration
echo "[*] Current configuration for ${IFACE}:"
ethtool "${IFACE}" | grep -E "Speed|Duplex|Auto-negotiation"

# Apply configuration with nmcli
echo "[*] Applying 1000 Mbps Full Duplex configuration..."
nmcli connection modify "${IFACE}" ethtool.speed 1000 ethtool.duplex full ethtool.autoneg off

# Restart the connection
nmcli connection down "${IFACE}" && nmcli connection up "${IFACE}"

# Show new configuration
echo "[+] New configuration for ${IFACE}:"
ethtool "${IFACE}" | grep -E "Speed|Duplex|Auto-negotiation"
