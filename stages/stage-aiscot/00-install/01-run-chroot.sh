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

# Cockpit plugins: install from the signed snstac apt repository instead of
# downloading version-pinned debs from (now-private) GitHub release URLs. The
# snstac apt repo is configured upstream (stage-pytak; also this stage's
# ais-catcher.yml), so apt resolves dependencies and tracks each plugin's
# current release:
#   cockpit-aiscot     — AIS-catcher / aiscot admin page
#   cockpit-spyserver  — SpyServer SDR-share admin page (`aryaos-sdr share N spyserver`)
#   cockpit-aprscot    — APRS-to-TAK gateway admin page (`aryaos-sdr task N aprs`)
#   cockpit-sapientcot — SAPIENT (BSI Flex 335) C-UAS/ISR gateway admin page
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    cockpit-aiscot cockpit-spyserver cockpit-aprscot cockpit-sapientcot

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
# KISS TNC; aprscot (>= 8.2.0, KISS input) forwards it to cotbridge as CoT.
# direwolf from Debian; aprscot from the snstac apt repo. Both are OFF by default
# (task-driven) — aprscot must NOT auto-connect to APRS-IS over the internet.
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends direwolf aprscot
# aprscot reads the local Dire Wolf KISS TNC (offline), not APRS-IS.
install -v -m 0644 /usr/share/aryaos/aprscot.default /etc/default/aprscot
# Inherit COT_URL (cotbridge) from the site config, like aiscot.
grep -qxF "EnvironmentFile=/etc/aryaos/aryaos-config.txt" /lib/systemd/system/aprscot.service || \
sed --follow-symlinks -i -E -e "/\[Service\]/a EnvironmentFile=\/etc\/aryaos\/aryaos-config.txt" /lib/systemd/system/aprscot.service
# Task-driven only: do not start aprscot at boot (would hit APRS-IS with no KISS peer).
systemctl disable aprscot >/dev/null 2>&1 || true

# SAPIENT C-UAS gateway (sapientcot): SAPIENT (BSI Flex 335) DetectionReports -> CoT.
# sapientcot deb Depends only on pytak (apt); its sapient-msg protobuf binding is
# NOT in Debian, so pip-install it (pure-python; pulls a matching protobuf).
# sapientcot from the snstac apt repo (was a version-pinned GitHub release deb).
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends sapientcot
pip3 install --break-system-packages --no-input sapient-msg || \
	python3 -m pip install --break-system-packages --no-input sapient-msg
install -v -m 0644 /usr/share/aryaos/sapientcot.default /etc/default/sapientcot
grep -qxF "EnvironmentFile=/etc/aryaos/aryaos-config.txt" /lib/systemd/system/sapientcot.service || \
sed --follow-symlinks -i -E -e "/\[Service\]/a EnvironmentFile=\/etc\/aryaos\/aryaos-config.txt" /lib/systemd/system/sapientcot.service
# Off at boot; the cuas/multi role (or the operator) starts it once a SAPIENT node is set.
systemctl disable sapientcot >/dev/null 2>&1 || true
