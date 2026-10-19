#!/bin/bash

set -e

ARCH=$1

if [ -z "$ARCH" ]; then
    echo "Usage: $0 [AMD64|ARM64]"
    exit 1
fi

# Fonction pour vérifier la présence de libcjson via ldconfig
check_cjson() {
    dpkg -s libcjson-dev &>/dev/null
    return $?
}

# Vérifier et installer libcjson si nécessaire
if ! check_cjson; then
    echo "[!] La bibliothèque cJSON n'est pas installée. Installation en cours..."
    sudo apt-get update
    sudo apt-get install -y libcjson-dev
    echo "[*] Installation terminée."
else
    echo "[*] La bibliothèque cJSON est déjà installée."
fi

# Configuration selon l'architecture
case "$ARCH" in
    AMD64)
        export CC=gcc
        ;;
    ARM64)
        export CC=aarch64-linux-gnu-gcc
        ;;
    *)
        echo "Architecture non supportée : $ARCH"
        echo "Choisissez entre : AMD64 ou ARM64"
        exit 1
        ;;
esac

echo "[*] Compilation pour architecture : $ARCH"
make clean
make
