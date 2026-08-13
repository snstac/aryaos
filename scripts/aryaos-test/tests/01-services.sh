#!/usr/bin/env bash
# 01-services.sh — systemd service checks (remote on Pi).
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

TIER="${ARYAOS_TEST_TIER:-default}"

FAILED_UNITS="$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | paste -sd ' ' -)"
if [[ -n "${FAILED_UNITS}" ]]; then
	fail "system has failed units: ${FAILED_UNITS}"
else
	ok "no failed systemd units"
fi

CORE_SERVICES=(lighttpd gpsd gpscot)
if capability_enabled adsb; then
	CORE_SERVICES=(readsb adsbcot "${CORE_SERVICES[@]}")
fi
if capability_enabled ais; then
	CORE_SERVICES=(ais-catcher aiscot "${CORE_SERVICES[@]}")
fi

for svc in "${CORE_SERVICES[@]}"; do
	if unit_active "${svc}"; then
		ok "${svc} active"
	else
		fail "${svc} not active"
	fi
done

if unit_loaded aryaos-gps-time-sync && systemctl is-enabled --quiet aryaos-gps-time-sync.service 2>/dev/null; then
	ok "aryaos-gps-time-sync installed and enabled"
else
	fail "aryaos-gps-time-sync not installed/enabled"
fi

if test_profile uas; then
	for svc in readsb adsbcot dump1090-fa dump978-fa; do
		if unit_active "${svc}"; then
			fail "${svc} active on UAS profile"
		elif systemctl is-active "${svc}" 2>/dev/null | grep -qE 'activating|reloading|deactivating'; then
			fail "${svc} restarting on UAS profile"
		else
			skip "${svc} inactive on UAS profile"
		fi
	done
else
	for svc in dump978-fa; do
		if unit_loaded "${svc}" && systemctl is-enabled --quiet "${svc}" 2>/dev/null; then
			if unit_active "${svc}"; then
				ok "${svc} active"
			elif systemctl is-active "${svc}" 2>/dev/null | grep -qE 'activating|reloading|deactivating'; then
				fail "${svc} restarting"
			else
				fail "${svc} enabled but not active"
			fi
		fi
	done
fi

for svc in cotbridge lincot adsbcot aiscot dronecot sikw00fcot; do
	if ! unit_loaded "${svc}"; then
		fail "TAK gateway unit ${svc} missing (portal expects it)"
		continue
	fi
	if unit_active "${svc}"; then
		ok "TAK gateway ${svc} active"
	elif [[ "${svc}" == "adsbcot" ]] && ! capability_enabled adsb; then
		skip "TAK gateway ${svc} inactive (adsb capability disabled)"
	elif test_profile uas && [[ "${svc}" == "adsbcot" ]]; then
		skip "TAK gateway ${svc} inactive on UAS profile"
	elif ! test_profile uas && [[ "${svc}" == "dronecot" ]]; then
		skip "TAK gateway ${svc} inactive outside UAS profile"
	elif [[ "${svc}" == "sikw00fcot" ]]; then
		warn "TAK gateway ${svc} loaded but not active (SiK radio/fan-out optional)"
	else
		warn "TAK gateway ${svc} loaded but not active"
	fi
done

# ACARSCOT >= 0.1.1/PyTAK >= 7.5.2 owns reconnects inside one long-running
# process. A TAK server outage or transient local network-policy replacement
# must not become a systemd crash loop, exhaust the RAM-backed temporary
# filesystems, or discard the enrollment certificate.
if capability_enabled acars; then
	for svc in acarsdec acarscot; do
		if unit_active "${svc}"; then
			ok "${svc} active for acars capability"
		else
			fail "${svc} not active for acars capability"
		fi
	done
	acarscot_restarts="$(systemctl show acarscot.service -p NRestarts --value 2>/dev/null || true)"
	if [[ "${acarscot_restarts}" == "0" ]]; then
		ok "acarscot has not entered a systemd restart loop"
	else
		fail "acarscot has ${acarscot_restarts:-unknown} systemd restarts"
	fi
	if systemctl show acarscot.service -p StateDirectory --value 2>/dev/null | grep -qw acarscot; then
		ok "acarscot enrollment state is persistent"
	else
		fail "acarscot StateDirectory is not configured"
	fi
	if systemctl show acarscot.service -p Environment --value 2>/dev/null | grep -q 'HOME=/var/lib/acarscot'; then
		ok "acarscot HOME uses persistent state"
	else
		fail "acarscot HOME is not /var/lib/acarscot"
	fi
	if [[ -z "$(sudo -n find /tmp /var/tmp -maxdepth 1 -type f -user acarscot -name 'tmp*.pem' -print -quit 2>/dev/null)" ]]; then
		ok "acarscot has not leaked temporary certificate PEMs"
	else
		fail "acarscot leaked temporary certificate PEMs"
	fi
fi

if unit_loaded aryaos-bt-pan; then
	if unit_active aryaos-bt-pan; then
		ok "aryaos-bt-pan active"
	else
		warn "aryaos-bt-pan installed but not active"
	fi
else
	warn "aryaos-bt-pan unit not installed (older image?)"
fi

# Wi-Fi onboarding and Bluetooth PAN are deliberately simultaneous. Their two
# dnsmasq DHCP servers can share UDP/67 only when each is pinned to one
# interface; the broken state still showed both parent services as active.
if unit_active comitup && unit_active aryaos-bt-pan; then
	if pgrep -f '^dnsmasq .*--interface=pan0([[:space:]]|$)' >/dev/null; then
		ok "Bluetooth PAN DHCP active on pan0"
	else
		fail "Bluetooth PAN active without a pan0 DHCP server"
	fi
	if pgrep -f '^dnsmasq .*--interface=wlan0([[:space:]]|$)' >/dev/null; then
		ok "WiFi onboarding DHCP active on wlan0"
	else
		fail "Comitup active without a wlan0 DHCP server"
	fi
fi

if [[ -x /etc/NetworkManager/dispatcher.d/99-aryaos-dispatcher ]]; then
	if env IP4_NUM_ADDRESSES=0 IP6_NUM_ADDRESSES=0 \
		/etc/NetworkManager/dispatcher.d/99-aryaos-dispatcher wlan0 reapply; then
		ok "NetworkManager dispatcher accepts reapply events"
	else
		fail "NetworkManager dispatcher rejects reapply events"
	fi
fi

print_summary
