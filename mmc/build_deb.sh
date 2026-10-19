#!/bin/bash
set -e

VERSION="1.1.0"
MAINTAINER="MMC Maintainer <maintainer@example.com>"

# Build mmc-cli for amd64
cd mmc-cli
./build.sh amd64
cd ..

# Build mmc-host-daemon and mmc-vm-daemon for arm64
cd mmc-host-daemon
./build.sh arm64
cd ..

cd mmc-vm-daemon
./build.sh arm64
cd ..

# Create Debian packages
create_deb_package() {
    local name=$1
    local arch=$2
    local version=$3
    local dir="deb-pkg/${name}_${version}_${arch}"

    mkdir -p ${dir}/DEBIAN
    mkdir -p ${dir}/usr/local/bin
    mkdir -p ${dir}/etc/mmc
    mkdir -p ${dir}/etc/systemd/system
    mkdir -p ${dir}/var/log

    # Create control file
    cat > ${dir}/DEBIAN/control << EOF
Package: ${name}
Version: ${version}
Architecture: ${arch}
Maintainer: ${MAINTAINER}
Description: MMC (Message to Machine Communication) - ${name}
 Component of the MMC system for sending messages to virtual machines.
Depends: libjson-c5, libreadline8, libssl3
EOF

    # Copy binary
    cp ${name}/${name} ${dir}/usr/local/bin/

    # Copy config file if it exists
    if [ -f ${name}/${name}-config.json ]; then
        cp ${name}/${name}-config.json ${dir}/etc/mmc/
    fi

    # Copy service file if it exists
    if [ -f ${name}/${name}.service ]; then
        cp ${name}/${name}.service ${dir}/etc/systemd/system/
    fi

    # Create postinst script for daemons
    if [[ ${name} == *-daemon ]]; then
        cat > ${dir}/DEBIAN/postinst << EOF
#!/bin/bash
systemctl daemon-reload
systemctl enable ${name}
systemctl start ${name}
EOF
        chmod 755 ${dir}/DEBIAN/postinst
    fi

    # Build package
    dpkg-deb --build ${dir}
}

# Create packages directory
mkdir -p deb-pkg

# Create packages
create_deb_package "mmc-cli" "amd64" "${VERSION}"
create_deb_package "mmc-host-daemon" "arm64" "${VERSION}"
create_deb_package "mmc-vm-daemon" "arm64" "${VERSION}"

echo "Debian packages created in deb-pkg directory" 