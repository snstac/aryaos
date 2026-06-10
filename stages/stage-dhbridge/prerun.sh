#!/bin/bash -e
# stage-dhbridge prerun — ensure rootfs from previous stage (pi-gen skips non-+x prerun.sh).
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

if [ ! -f "${ROOTFS_DIR}/etc/os-release" ]; then
	copy_previous
fi
