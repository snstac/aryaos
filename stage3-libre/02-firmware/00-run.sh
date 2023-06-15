#!/bin/bash -e

cat files/libre-computer-deb.gpg > "${ROOTFS_DIR}/etc/apt/trusted.gpg.d/libre-computer-deb.gpg"

install -m 644 files/libre-computer-deb.list "${ROOTFS_DIR}/etc/apt/sources.list.d/"

# FIXME: ${BOARD%%-*}
echo "deb [ arch=arm64 ] http://deb.debian.org/debian/ ${RELEASE} main" > "${ROOTFS_DIR}/etc/apt/sources.list.d/debian-main.list"
echo "deb [ arch=arm64 ] http://deb.debian.org/debian/ ${RELEASE}-updates main" >> "${ROOTFS_DIR}/etc/apt/sources.list.d/debian-main.list"
echo "deb [ arch=arm64 ] http://security.debian.org/debian-security/ ${RELEASE}-security main" >> "${ROOTFS_DIR}/etc/apt/sources.list.d/debian-main.list"
