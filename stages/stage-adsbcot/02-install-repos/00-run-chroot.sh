#!/bin/bash -e
# AryaOS 00-run-chroot.sh
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

dpkg -i /usr/src/flightaware-apt-repository_1.2_all.deb

# FlightAware does not publish a trixie dist; use the bookworm suite on Debian 13+ / Pi OS trixie images.
# See build log: "404  Not Found" on .../packages trixie Release.
if [[ -f /etc/apt/sources.list.d/flightaware-apt-repository.list ]]; then
	sed -i 's/trixie/bookworm/g' /etc/apt/sources.list.d/flightaware-apt-repository.list
	# apt 3.x + sqv on trixie rejects FlightAware's Release signing (SHA1 policy as of 2026-02-01).
	if ! grep -q 'trusted=yes' /etc/apt/sources.list.d/flightaware-apt-repository.list; then
		if grep -qE '^deb[[:space:]]+\[' /etc/apt/sources.list.d/flightaware-apt-repository.list; then
			sed -i -E 's/^deb([[:space:]]+)\[([^]]*)\]/deb\1[\2 trusted=yes]/' /etc/apt/sources.list.d/flightaware-apt-repository.list
		else
			sed -i -E 's/^deb([[:space:]]+)/deb [trusted=yes]\1/' /etc/apt/sources.list.d/flightaware-apt-repository.list
		fi
	fi
fi

# FlightAware's bookworm binaries pull runtime deps that are not on trixie under the same
# package names (e.g. Boost 1.74, liblimesuite22.x). Enable Debian bookworm main alongside
# trixie so apt can satisfy those Depends; prefer trixie when both suites ship a package.
if [[ -r /etc/os-release ]]; then
	# shellcheck disable=SC1091
	. /etc/os-release
	if [[ "${VERSION_CODENAME:-}" == "trixie" ]]; then
		if [[ ! -f /etc/apt/sources.list.d/debian-bookworm-deps.list ]]; then
			echo 'deb http://deb.debian.org/debian bookworm main' > /etc/apt/sources.list.d/debian-bookworm-deps.list
		fi
		install -d /etc/apt/preferences.d
		if [[ ! -f /etc/apt/preferences.d/01-aryaos-prefer-trixie-over-bookworm.pref ]]; then
			cat >/etc/apt/preferences.d/01-aryaos-prefer-trixie-over-bookworm.pref <<'EOF'
# Prefer trixie when the same package exists in bookworm; still allow bookworm-only libs.
Package: *
Pin: release n=bookworm
Pin-Priority: 500

Package: *
Pin: release n=trixie
Pin-Priority: 990
EOF
		fi
	fi
fi

apt update
