#!/bin/bash

# Variables de configuration
REPO_URL="https://github.com/jgamblin/Mirai-Source-Code.git"
REPO_DIR="Mirai-Source-Code"
CNC_DIR="$REPO_DIR/mirai/cnc"
ARCH="arm64"
PACKAGE_NAME="mirai-cnc"
VERSION="1.0"
MAINTAINER="Joachim Schmidt <joachim.schmidt@hesge.ch>"
DESCRIPTION="Custom Go C&C server compiled for RPi5 (ARM64)"
APP_NAME="cnc"

# Check and install dependencies
echo "[*] Checking dependencies..."

install_if_missing() {
    if ! command -v "$1" &> /dev/null; then
        echo "[*] Installing missing dependency: $1"
        sudo apt-get update && sudo apt-get install -y "$2"
    fi
}

install_if_missing git git
install_if_missing go golang
install_if_missing dpkg-deb dpkg-dev

# Clone repository
if [ ! -d "$REPO_DIR" ]; then
    echo "[*] Cloning repository..."
    git clone "$REPO_URL"
else
    echo "[*] Repository already cloned. Pulling latest changes..."
    cd "$REPO_DIR" && git pull && cd ..
fi

# Prepare build directory
BUILD_DIR="$(pwd)/build"
INSTALL_DIR="$BUILD_DIR/usr/local/bin"
mkdir -p "$INSTALL_DIR"

# Compile the Go C&C binary
echo "[*] Compiling C&C binary..."

cd "$CNC_DIR"

# Initialize Go module if needed
if [ ! -f "go.mod" ]; then
    echo "[*] Initializing Go module..."
    go mod init cnc || true
fi

# Tidy dependencies
go mod tidy

# Build binary
GOARCH=$ARCH GOOS=linux go build -o "$INSTALL_DIR/$APP_NAME"

# Go back to base directory
cd -

# Create DEBIAN control files
DEBIAN_DIR="$BUILD_DIR/DEBIAN"
mkdir -p "$DEBIAN_DIR"

cat <<EOF | sudo tee "$DEBIAN_DIR/control" > /dev/null
Package: $PACKAGE_NAME
Version: $VERSION
Section: base
Priority: optional
Architecture: $ARCH
Maintainer: $MAINTAINER
Description: $DESCRIPTION
EOF

# Build the .deb package
echo "[*] Building .deb package..."
OUTPUT_FILE="${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
dpkg-deb --build "$BUILD_DIR" "$OUTPUT_FILE"

echo "[+] Done. Package built: $OUTPUT_FILE"
