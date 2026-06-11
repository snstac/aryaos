#!/bin/bash -e
# Install the snstac sensor stack from the signed snstac apt repository
# (https://snstac.github.io/packages). Runs inside the pi-gen chroot or on a host. Package list comes from
# manifests/aryaos-sensor-packages.yml (sensor_apt_packages).
#
# Copyright Sensors & Signals LLC https://www.snstac.com
#
# SPDX-License-Identifier: Apache-2.0

MANIFEST="${1:-/usr/src/aryaos-sensor-packages.yml}"
KEYRING="${2:-/usr/src/snstac.gpg}"
SOURCES="${3:-/usr/src/snstac.sources}"

for f in "${MANIFEST}" "${KEYRING}" "${SOURCES}"; do
	if [[ ! -f "${f}" ]]; then
		echo "install-sensor-debs.sh: required file not found: ${f}" >&2
		exit 1
	fi
done

# snstac apt repository trust anchor (vendored in-repo; see
# shared_files/aryaos/snstac-packages/ and https://snstac.github.io/packages).
install -m 0644 "${KEYRING}" /usr/share/keyrings/snstac.gpg
install -m 0644 "${SOURCES}" /etc/apt/sources.list.d/snstac.sources

export _ARYAOS_SENSOR_MANIFEST="${MANIFEST}"
mapfile -t PKGS < <(python3 - <<'PY'
import os
import yaml

with open(os.environ["_ARYAOS_SENSOR_MANIFEST"], encoding="utf-8") as f:
    data = yaml.safe_load(f)
for pkg in data.get("sensor_apt_packages", []):
    print(pkg)
PY
)
unset _ARYAOS_SENSOR_MANIFEST

if [[ "${#PKGS[@]}" -eq 0 ]]; then
	echo "install-sensor-debs.sh: no sensor_apt_packages in ${MANIFEST}" >&2
	exit 1
fi

echo "install-sensor-debs.sh: installing from snstac apt repo: ${PKGS[*]}"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${PKGS[@]}"
