#!/bin/bash

# Version souhaitée de Go
GO_VERSION="1.22.3"

# Détection architecture (ici pour x86_64)
ARCH="amd64"

# Destination
INSTALL_DIR="/usr/local"

echo "[*] Téléchargement de Go ${GO_VERSION} pour ${ARCH}..."

# Téléchargement
wget -q "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" -O "/tmp/go${GO_VERSION}.tar.gz"

# Suppression d'une ancienne version éventuelle
sudo rm -rf ${INSTALL_DIR}/go

# Extraction
sudo tar -C ${INSTALL_DIR} -xzf "/tmp/go${GO_VERSION}.tar.gz"

# Nettoyage
rm "/tmp/go${GO_VERSION}.tar.gz"

# Ajout au PATH (si pas déjà dans le shell)
if ! grep -q 'export PATH=$PATH:/usr/local/go/bin' ~/.bashrc; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    echo 'export GOPATH=$HOME/go' >> ~/.bashrc
    echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
fi

# Application immédiate
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# Vérification
echo "[+] Version installée :"
go version
