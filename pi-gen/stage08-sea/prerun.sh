#!/bin/bash -e

if [ ! -d "${ROOTFS_DIR}" ]; then
	copy_previous
fi

export SHARED_FILES=../shared_files