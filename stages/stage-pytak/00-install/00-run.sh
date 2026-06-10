#!/bin/bash -e
# Copy sensor stack manifest and installer into rootfs for 01-run-chroot.sh.
#
# Copyright Sensors & Signals LLC https://www.snstac.com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../../.." && pwd)

install -v -m 0644 "${REPO_ROOT}/manifests/aryaos-sensor-packages.yml" "${ROOTFS_DIR}/usr/src/aryaos-sensor-packages.yml"
install -v -m 0755 "${REPO_ROOT}/shared_files/aryaos/install-sensor-debs.sh" "${ROOTFS_DIR}/usr/src/install-sensor-debs.sh"
# snstac apt repository trust anchor (signed repo at https://snstac.github.io/packages).
install -v -m 0644 "${REPO_ROOT}/shared_files/aryaos/snstac-packages/snstac.gpg" "${ROOTFS_DIR}/usr/src/snstac.gpg"
install -v -m 0644 "${REPO_ROOT}/shared_files/aryaos/snstac-packages/snstac.sources" "${ROOTFS_DIR}/usr/src/snstac.sources"
# dhbridge .deb (snstac/dhbridge is private — not in the public apt repo).
install -v -m 0644 "${REPO_ROOT}/shared_files/dhbridge/dhbridge_"*"_all.deb" "${ROOTFS_DIR}/usr/src/"
