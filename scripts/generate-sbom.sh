#!/bin/bash
# generate-sbom.sh — loop-mount a built AryaOS image and produce SBOMs.
#
# Usage: sudo scripts/generate-sbom.sh <image>.img|.img.xz|.zip <out-prefix>
#
# Writes <out-prefix>.spdx.json (SPDX 2.3) and <out-prefix>.cdx.json
# (CycloneDX) covering the full rootfs: dpkg packages, Python site-packages,
# and the Node-RED npm tree. Requires syft (override binary with SYFT_BIN).
#
# Mount handling mirrors scripts/verify-image.sh.
#
# Copyright Sensors & Signals LLC https://www.snstac.com/
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

IMAGE="${1:-}"
OUT_PREFIX="${2:-}"
SYFT_BIN="${SYFT_BIN:-syft}"

if [[ -z "${IMAGE}" || ! -f "${IMAGE}" || -z "${OUT_PREFIX}" ]]; then
	echo "Usage: sudo $0 <image>.img|.img.xz|.zip <out-prefix>" >&2
	exit 2
fi
if [[ "$(id -u)" != "0" ]]; then
	echo "Must run as root (loop-mounts the image)." >&2
	exit 2
fi
if ! command -v "${SYFT_BIN}" >/dev/null 2>&1; then
	echo "syft not found (install it or set SYFT_BIN)." >&2
	exit 2
fi

WORK="$(mktemp -d /tmp/aryaos-sbom.XXXXXX)"
MNT="${WORK}/mnt"
LOOP=""
cleanup() {
	set +e
	mountpoint -q "${MNT}" && umount "${MNT}"
	[[ -n "${LOOP}" ]] && losetup -d "${LOOP}"
	rm -rf "${WORK}"
}
trap cleanup EXIT

case "${IMAGE}" in
	*.zip)
		python3 -m zipfile -e "${IMAGE}" "${WORK}/extract"
		IMG="$(find "${WORK}/extract" -name '*.img' -print -quit)"
		;;
	*.img.xz | *.xz)
		IMG="${WORK}/image.img"
		xz -dkc "${IMAGE}" > "${IMG}"
		;;
	*.img)
		IMG="${IMAGE}"
		;;
	*)
		echo "Unsupported image format: ${IMAGE}" >&2
		exit 2
		;;
esac
if [[ -z "${IMG:-}" || ! -f "${IMG}" ]]; then
	echo "No .img found in ${IMAGE}" >&2
	exit 2
fi

LOOP="$(losetup -Pf --show "${IMG}")"
# Partition nodes can lag losetup -P briefly.
for _ in 1 2 3 4 5; do
	[[ -b "${LOOP}p2" ]] && break
	sleep 1
done
mkdir -p "${MNT}"
mount -o ro "${LOOP}p2" "${MNT}"

mkdir -p "$(dirname "${OUT_PREFIX}")"
echo "== Generating SBOMs from ${IMG##*/} =="
"${SYFT_BIN}" scan "dir:${MNT}" \
	--source-name aryaos \
	-o "spdx-json=${OUT_PREFIX}.spdx.json" \
	-o "cyclonedx-json=${OUT_PREFIX}.cdx.json"

for f in "${OUT_PREFIX}.spdx.json" "${OUT_PREFIX}.cdx.json"; do
	if [[ ! -s "${f}" ]]; then
		echo "SBOM output missing or empty: ${f}" >&2
		exit 1
	fi
	echo "wrote ${f} ($(stat -c %s "${f}") bytes)"
done
