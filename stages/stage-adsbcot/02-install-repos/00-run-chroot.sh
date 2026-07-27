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

# Never let apt pull flightaware-apt-repository from FlightAware's own repo.
#
# Their pool and their index disagree about 1.3 — same 4664-byte size, different
# content — so any apt run that tries to upgrade it aborts the whole
# transaction and fails the build:
#
#   E: Failed to fetch .../flightaware-apt-repository_1.3_all.deb Hash Sum mismatch
#      expected SHA256: b0a60c0d...fc9df1   (their index)
#      received SHA256: 20bdb735...1046cc   (their pool)
#
# Verified by hand 2026-07-27: fetching that URL really does yield the "received"
# hash. Upstream inconsistency, not a corrupt download — three builds failed
# identically. It bites in pi-gen's OWN export-image/02-set-sources step, which
# runs a blanket `apt-get dist-upgrade` long after this stage.
#
# We install this package solely for the sources.list it drops, and 1.2 is
# vendored in shared_files precisely so the repo definition is reproducible, so
# a remote copy is never wanted. Two independent guards, because a dpkg hold
# alone did not survive to export-image:
#   1. a negative pin, so no remote version is ever a candidate (any version —
#      1.4 would presumably be just as broken)
#   2. a dpkg hold, so upgrade passes skip it
# Nothing in FlightAware's index Depends on this package, so neither can block
# dump978-fa/skyaware978.
install -d /etc/apt/preferences.d
cat >/etc/apt/preferences.d/02-aryaos-pin-flightaware-apt-repository.pref <<'EOF'
# flightaware-apt-repository is installed from a vendored .deb; FlightAware's
# hosted copy has a pool/index SHA256 mismatch that breaks any apt transaction
# that tries to fetch it. Refuse every remote version.
Package: flightaware-apt-repository
Pin: release *
Pin-Priority: -1
EOF
apt-mark hold flightaware-apt-repository

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
