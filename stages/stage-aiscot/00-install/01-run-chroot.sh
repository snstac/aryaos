#!/bin/bash -e
# AryaOS 01-run-chroot.sh
#
# Copyright Sensors & Signals LLC https://www.snstac.com/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


# Ensure AIS-catcher service user exists and is in required groups
if ! id -u ais-catcher >/dev/null 2>&1; then
    adduser --system --gecos 'AIS-catcher Service User' ais-catcher
fi

usermod -aG plugdev,dialout ais-catcher

# ais-catcher from the snstac apt repo (snstac/AIS-catcher fork releases
# amd64+arm64 debs via upstream's build-debian.sh). Binary: /usr/bin/AIS-catcher.
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ais-catcher

COCKPIT_AISCOT_DEB_URL='https://github.com/snstac/cockpit-aiscot/releases/download/v1.1.0/cockpit-aiscot_1.1.0_all.deb'
curl -fsSL -o /usr/src/cockpit-aiscot_1.1.0_all.deb "${COCKPIT_AISCOT_DEB_URL}"
dpkg -i /usr/src/cockpit-aiscot_1.1.0_all.deb

# cockpit-spyserver: SpyServer SDR-share admin page (drives `aryaos-sdr share
# N spyserver`, shipped by the AryaOS overlay). Installed here — the last heavy
# dpkg stage before export — alongside the other Cockpit plugins. Sourced from
# the plugin's GitHub release (nfpm-built _all.deb), same idiom as cockpit-aiscot.
COCKPIT_SPYSERVER_DEB_URL='https://github.com/snstac/cockpit-spyserver/releases/download/v0.1.0/cockpit-spyserver_0.1.0-1_all.deb'
curl -fsSL -o /usr/src/cockpit-spyserver.deb "${COCKPIT_SPYSERVER_DEB_URL}"
dpkg -i /usr/src/cockpit-spyserver.deb || apt-get install -f -y

# Ensure apt-listchanges stays off before export-image finalise (see stage-base note).
if dpkg -s apt-listchanges >/dev/null 2>&1; then
	echo 'apt-listchanges apt-listchanges/frontend select none' | debconf-set-selections
	DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -plow apt-listchanges || true
fi

# Last pi-gen stage with heavy dpkg activity before export; re-assert Cockpit socket
# enablement in case a maintainer script or preset disturbed symlinks after stage-aryaos.
systemctl enable cockpit.socket

# Add the line EnvironmentFile=/etc/aryaos/aryaos-config.txt to /lib/systemd/system/aiscot.service if the line does not already exist
grep -qxF "EnvironmentFile=/etc/aryaos/aryaos-config.txt" /lib/systemd/system/aiscot.service || \
grep -qxF "EnvironmentFile=-/etc/aryaos/aryaos-config.txt" /lib/systemd/system/aiscot.service || \
sed --follow-symlinks -i -E -e "/\[Service\]/a EnvironmentFile=\/etc\/aryaos\/aryaos-config.txt" /lib/systemd/system/aiscot.service

# APRS over RF (aryaos-sdr task N aprs): Dire Wolf decodes 144.39 MHz APRS to a
# KISS TNC; aprscot (>= 8.2.0, KISS input) forwards it to charontak as CoT.
# direwolf from Debian; aprscot from the snstac apt repo. Both are OFF by default
# (task-driven) — aprscot must NOT auto-connect to APRS-IS over the internet.
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends direwolf aprscot
# aprscot reads the local Dire Wolf KISS TNC (offline), not APRS-IS.
install -v -m 0644 /aryaos/shared_files/aryaos/aprscot.default /etc/default/aprscot 2>/dev/null || \
	install -v -m 0644 "${SHARED_FILES:-/aryaos/shared_files}/aryaos/aprscot.default" /etc/default/aprscot
# Inherit COT_URL (charontak) from the site config, like aiscot.
grep -qxF "EnvironmentFile=/etc/aryaos/aryaos-config.txt" /lib/systemd/system/aprscot.service || \
sed --follow-symlinks -i -E -e "/\[Service\]/a EnvironmentFile=\/etc\/aryaos\/aryaos-config.txt" /lib/systemd/system/aprscot.service
# Task-driven only: do not start aprscot at boot (would hit APRS-IS with no KISS peer).
systemctl disable aprscot >/dev/null 2>&1 || true
