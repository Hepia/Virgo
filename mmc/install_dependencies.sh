#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print error messages
error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

# Function to print success messages
success() {
    echo -e "${GREEN}$1${NC}"
}

# Function to print info messages
info() {
    echo -e "${YELLOW}$1${NC}"
}

# Function to print usage
print_usage() {
    echo "Usage: $0 [mode]"
    echo "Install dependencies for MMC project"
    echo ""
    echo "Arguments:"
    echo "  mode    Installation mode: host or target"
    echo ""
    echo "Modes:"
    echo "  host    Install on AMD64 host machine for:"
    echo "          - Building mmc-cli for AMD64"
    echo "          - Building mmc-vm-daemon and mmc-host-daemon for ARM64"
    echo "          - Running mmc-cli"
    echo ""
    echo "  target  Install on ARM64 target machine for:"
    echo "          - Running mmc-vm-daemon"
    echo "          - Running mmc-host-daemon"
    exit 1
}

# Check if mode parameter is provided
if [ $# -ne 1 ]; then
    print_usage
fi

MODE=$1

# Validate mode
case "${MODE}" in
    host)
        info "Installing dependencies for host machine (AMD64)"
        ;;
    target)
        info "Installing dependencies for target machine (ARM64)"
        ;;
    *)
        error "Invalid mode: ${MODE}"
        print_usage
        ;;
esac

# Check if script is run as root or with sudo
if [ "$EUID" -ne 0 ]; then
    info "This script requires root privileges to install packages."
    info "Requesting sudo access..."
    if ! sudo -v; then
        error "Failed to obtain sudo privileges"
        exit 1
    fi
fi

# Detect Linux distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    error "Could not detect Linux distribution"
    exit 1
fi

# Check if we're on a Debian-based system
if [[ "$DISTRO" != "debian" && "$DISTRO" != "ubuntu" ]]; then
    error "This script only supports Debian-based systems"
    error "Detected distribution: $DISTRO"
    exit 1
fi

# Update package lists
info "Updating package lists..."
sudo apt-get update || exit 1

if [ "${MODE}" = "host" ]; then
    # Installation pour la machine hôte (AMD64)
    info "Installing native development tools..."
    sudo apt-get install -y \
        gcc \
        pkg-config \
        dpkg-dev \
        make \
        libreadline-dev \
        libjson-c-dev \
        libssl-dev || exit 1

    info "Installing native runtime libraries..."
    sudo apt-get install -y \
        libreadline8 \
        libjson-c5 \
        libssl3 || exit 1

    info "Installing ARM64 cross-compilation tools..."
    sudo dpkg --add-architecture arm64
    sudo apt-get update
    sudo apt-get install -y \
        gcc-aarch64-linux-gnu \
        crossbuild-essential-arm64 \
        libreadline-dev:arm64 \
        libjson-c-dev:arm64 \
        libssl-dev:arm64 || exit 1

else
    # Installation pour la machine cible (ARM64)
    info "Installing development libraries..."
    sudo apt-get install -y \
        pkg-config \
        libreadline-dev \
        libjson-c-dev \
        libssl-dev || exit 1

    info "Installing runtime libraries..."
    sudo apt-get install -y \
        libreadline8 \
        libjson-c5 \
        libssl3 || exit 1
fi

# Verify installation
info "Verifying installation..."

if [ "${MODE}" = "host" ]; then
    # Vérification des outils natifs
    if ! command -v gcc >/dev/null 2>&1; then
        error "Native gcc is not installed"
        exit 1
    fi

    # Vérification du cross-compilateur
    if ! command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
        error "ARM64 cross-compiler is not installed"
        exit 1
    fi

    # Vérification des bibliothèques natives
    MISSING_NATIVE_LIBS=()
    
    # Vérification de la présence des fichiers de développement
    if ! [ -f /usr/include/readline/readline.h ]; then
        MISSING_NATIVE_LIBS+=("libreadline-dev")
    fi
    if ! [ -f /usr/include/json-c/json.h ]; then
        MISSING_NATIVE_LIBS+=("libjson-c-dev")
    fi
    if ! [ -f /usr/include/openssl/ssl.h ]; then
        MISSING_NATIVE_LIBS+=("libssl-dev")
    fi

    if [ ${#MISSING_NATIVE_LIBS[@]} -ne 0 ]; then
        error "Some native development libraries are missing: ${MISSING_NATIVE_LIBS[*]}"
        exit 1
    fi

    # Vérification des bibliothèques ARM64
    MISSING_ARM64_LIBS=()
    for lib in "libreadline8:arm64" "libjson-c5:arm64" "libssl3:arm64"; do
        if ! dpkg -l | grep -q "$lib"; then
            MISSING_ARM64_LIBS+=("$lib")
        fi
    done

    if [ ${#MISSING_ARM64_LIBS[@]} -ne 0 ]; then
        error "Some ARM64 libraries are missing: ${MISSING_ARM64_LIBS[*]}"
        exit 1
    fi

else
    # Vérification des bibliothèques sur la machine cible
    MISSING_LIBS=()
    for lib in "libreadline8" "libjson-c5" "libssl3"; do
        if ! dpkg -l | grep -q "$lib"; then
            MISSING_LIBS+=("$lib")
        fi
    done

    if [ ${#MISSING_LIBS[@]} -ne 0 ]; then
        error "Some libraries are missing: ${MISSING_LIBS[*]}"
        exit 1
    fi
fi

success "All dependencies are properly installed for mode: ${MODE}"
if [ "${MODE}" = "host" ]; then
    info "You can now:"
    info "- Build mmc-cli for AMD64"
    info "- Build mmc-vm-daemon and mmc-host-daemon for ARM64"
    info "- Run mmc-cli on this machine"
else
    info "You can now run mmc-vm-daemon and mmc-host-daemon on this machine"
fi

exit 0 