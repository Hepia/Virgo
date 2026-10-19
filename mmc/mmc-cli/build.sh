#!/bin/bash
set -e

TARGET_ARCH=$1

if [ -z "${TARGET_ARCH}" ]; then
    echo "Usage: $0 [arch]"
    echo "[arch]: x86_64|amd64 OR arm OR aarch64|arm64"
    exit 1
fi

case "${TARGET_ARCH}" in
    x86_64|amd64)
        export CC=gcc
        ;;
    arm)
        export CC=arm-linux-gnueabihf-gcc
        ;;
    aarch64|arm64)
        export CC=aarch64-linux-gnu-gcc
        ;;
    *)
        echo "Unsupported arch: ${TARGET_ARCH}"
        exit 1
        ;;
esac

make clean
make

echo "Build completed for ${TARGET_ARCH}" 