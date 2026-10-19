#!/bin/bash
set -e

APP=$1
ARCH=$2

if [ -z "${APP}" ] || [ -z "${ARCH}" ]; then
    echo "Usage: $0 <program> <arch>"
    echo "Example: ./build_deb.sh host_daemon amd64"
    exit 1
fi

# 1. Clean old package build
rm -rf ${APP}_package

# 2. Build the binary first
echo "[*] Building binary for ${APP} (${ARCH})..."
pushd ${APP}
./build.sh ${ARCH}
popd

# 3. Create packaging folder structure
echo "[*] Preparing packaging directory..."
mkdir -p ${APP}_package/DEBIAN
mkdir -p ${APP}_package/usr/local/bin

# Create systemd folder only if service file exists
if [ -f ${APP}/${APP}.service ]; then
    mkdir -p ${APP}_package/etc/systemd/system
fi

# 4. Copy files
cp ${APP}/${APP} ${APP}_package/usr/local/bin/
if [ -f ${APP}/${APP}.service ]; then
    cp ${APP}/${APP}.service ${APP}_package/etc/systemd/system/
fi

# 5. Create control file
PACKAGE_NAME="${APP//_/-}" # replace underscores with dashes

cat > ${APP}_package/DEBIAN/control << EOF
Package: ${PACKAGE_NAME}
Version: 1.0
Section: misc
Priority: optional
Architecture: ${ARCH}
Maintainer: Packager <joachim.schmidt@hesge.ch>
Description: Auto-built package for ${APP}.
EOF

# 6. Fix permissions
chmod 755 ${APP}_package/usr/local/bin/${APP}
[ -f ${APP}_package/etc/systemd/system/${APP}.service ] && chmod 644 ${APP}_package/etc/systemd/system/${APP}.service
chmod 755 ${APP}_package/DEBIAN
chmod 644 ${APP}_package/DEBIAN/control

# 7. Build the .deb package
OUTPUT_DEB="${PACKAGE_NAME}_1.0_${ARCH}.deb"
echo "[*] Building .deb package: ${OUTPUT_DEB}..."
dpkg-deb --build ${APP}_package "${OUTPUT_DEB}"

echo "[+] Package created: ${APP}_package.deb"
