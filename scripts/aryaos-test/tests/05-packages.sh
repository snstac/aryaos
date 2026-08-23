#!/usr/bin/env bash
# 05-packages.sh — image package / artifact checks (remote on Pi).
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

require_package_version() {
	local package="$1" minimum="$2" version
	version="$(dpkg-query -W -f='${Version}' "${package}" 2>/dev/null || true)"
	if [[ -n "${version}" ]] && dpkg --compare-versions "${version}" ge "${minimum}"; then
		ok "${package} ${version} >= ${minimum}"
	else
		fail "${package} ${version:-missing} is older than ${minimum}"
	fi
}

require_cockpit_root_scroll() {
	local plugin="$1" css="/usr/share/cockpit/${plugin}/index.css"
	if [[ -r "${css}" ]]; then
		if tr -d '\r\n' < "${css}" | grep -E '#app[[:space:]]*\{[^}]*overflow-y:[[:space:]]*auto' >/dev/null; then
			ok "cockpit-${plugin} provides its Cockpit root scroller"
		else
			fail "cockpit-${plugin} CSS does not provide #app overflow-y:auto"
		fi
	elif [[ -r "${css}.gz" ]]; then
		if gzip -cd "${css}.gz" | tr -d '\r\n' | grep -E '#app[[:space:]]*\{[^}]*overflow-y:[[:space:]]*auto' >/dev/null; then
			ok "cockpit-${plugin} provides its Cockpit root scroller"
		else
			fail "cockpit-${plugin} compressed CSS does not provide #app overflow-y:auto"
		fi
	else
		fail "cockpit-${plugin} index.css is missing"
	fi
}

require_cockpit_stylesheets() {
	local plugin="$1" html="/usr/share/cockpit/${plugin}/index.html"
	if [[ ! -r "${html}" ]]; then
		fail "cockpit-${plugin} index.html is missing"
		return
	fi
	if grep -Fq 'href="index.css"' "${html}" && \
	   grep -Fq 'href="../../static/branding.css"' "${html}"; then
		ok "cockpit-${plugin} loads plugin CSS and shared AryaOS branding"
	else
		fail "cockpit-${plugin} does not load plugin CSS and shared AryaOS branding"
	fi
}

if command -v dhbridge >/dev/null || dpkg -s dhbridge >/dev/null 2>&1; then
	warn "dhbridge present (private package; expected absent on public images)"
else
	ok "dhbridge absent (private package)"
fi

require_package_version aryaos-overlay 2.2.0
require_package_version cotbridge 1.1.0

if [[ -d /var/www/html/calfire_airbases ]]; then
	warn "calfire_airbases tiles still present (removal not on this image)"
else
	ok "calfire_airbases tiles absent"
fi

if [[ -f /etc/aryaos-release || -f /etc/aryaos-version ]]; then
	ok "aryaos release/version files present"
else
	warn "aryaos release metadata missing"
fi

# Cockpit pins the document body and expects each page to supply its own scroll
# container. These versions include the common #app root scroller, preventing
# expanded Debug Logs and Advanced Details cards from being clipped.
require_package_version aiscot 7.3.1
require_package_version pytak 7.6.0
require_package_version gpscot 2.0.1
require_package_version sikw00fcot 1.0.2
require_package_version dronecot 2.3.9
require_package_version gutcheck 0.4.0
require_package_version cockpit-adsbcot 1.2.3
require_package_version cockpit-aiscot 1.2.3
require_package_version cockpit-aprscot 0.1.1
require_package_version cockpit-cotbridge 1.2.2
require_package_version cockpit-dronecot 1.2.0
require_package_version cockpit-lincot 1.1.3
require_package_version cockpit-sapientcot 0.1.1
require_package_version cockpit-aryaos 2.1.0
# GDLCOT 2.0.1 retains the NaN/Inf guards from 1.0.1 and also rebuilds its
# custom PyTAK client in-process after transient CoT transport failures.
require_package_version gdlcot 2.0.1

for plugin in adsbcot aiscot aprscot cotbridge dronecot lincot sapientcot; do
	require_cockpit_root_scroll "${plugin}"
	require_cockpit_stylesheets "${plugin}"
done

print_summary
