#!/bin/bash -e
# Install AryaOS sensor stack .debs from manifests/aryaos-sensor-packages.yml (inside chroot or on host).
#
# Copyright Sensors & Signals LLC https://www.snstac.com
#
# SPDX-License-Identifier: Apache-2.0

MANIFEST="${1:-/usr/src/aryaos-sensor-packages.yml}"

if [[ ! -f "${MANIFEST}" ]]; then
	echo "install-sensor-debs.sh: manifest not found: ${MANIFEST}" >&2
	exit 1
fi

export _ARYAOS_SENSOR_MANIFEST="${MANIFEST}"
mapfile -t URLS < <(python3 - <<'PY'
import os
import yaml

with open(os.environ["_ARYAOS_SENSOR_MANIFEST"], encoding="utf-8") as f:
    data = yaml.safe_load(f)
for url in data.get("sensor_deb_urls", []):
    print(url)
PY
)
unset _ARYAOS_SENSOR_MANIFEST

for url in "${URLS[@]}"; do
	[[ -z "${url}" ]] && continue
	fn=$(basename "${url}")
	echo "install-sensor-debs.sh: fetching ${fn}"
	curl -fsSL -o "/usr/src/${fn}" "${url}"
	dpkg -i "/usr/src/${fn}" || apt-get install -fy -y
done

# Vendored debs (e.g. dhbridge from private snstac/dhbridge).
for deb in /usr/src/dhbridge_*_all.deb; do
	[[ -f "${deb}" ]] || continue
	echo "install-sensor-debs.sh: installing $(basename "${deb}")"
	dpkg -i "${deb}" || apt-get install -fy -y
done
