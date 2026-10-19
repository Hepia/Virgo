#!/bin/bash
set -euo pipefail

# SCRIPT: update-r8152-driver.sh
# Purpose: Download, compile, install, and load the latest Realtek r8152 USB Ethernet driver

cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "[*] Installing prerequisites..."
apt update -qq
apt install -y --no-install-recommends build-essential dkms git wget linux-headers-"$(uname -r)"

TMPDIR=$(mktemp -d)
cd "$TMPDIR"

# Try GitHub first (latest stable release)
echo "[*] Cloning latest Realtek r8152 driver from GitHub..."
git clone https://github.com/wget/realtek-r8152-linux.git
cd realtek-r8152-linux

# Checkout latest tag if available
LATEST_TAG=$(git tag --sort=-v:refname | head -n1)
[ -n "$LATEST_TAG" ] && git checkout "$LATEST_TAG"

echo "[*] Compiling the driver..."
make -j"$(nproc)"

echo "[*] Installing driver..."
make install
depmod -a

echo "[*] Reloading module..."
modprobe -r r8152 || true
modprobe r8152

echo "[*] Driver update complete. New module info:"
modinfo r8152 | grep -E 'version:|filename:'

echo "[*] Verifying interface configuration now may allow gigabit link and autoneg."
echo "Use: ethtool <interface> | grep Speed"
