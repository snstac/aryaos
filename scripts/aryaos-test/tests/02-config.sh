#!/usr/bin/env bash
# 02-config.sh — config file parity checks (remote on Pi).
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

if grep -q 'COT_URL=udp+wo://127.0.0.1:28087' /etc/aryaos/aryaos-config.txt 2>/dev/null; then
	ok "feeder COT_URL → charontak ingress"
else
	fail "COT_URL not udp+wo://127.0.0.1:28087 in aryaos-config.txt"
fi

if grep -q 'ARYAOS_ADSB_JSON_DIR=/run/adsb' /etc/aryaos/aryaos-config.txt 2>/dev/null; then
	ok "ARYAOS_ADSB_JSON_DIR=/run/adsb"
else
	warn "ARYAOS_ADSB_JSON_DIR not set in aryaos-config.txt"
fi

if [[ -f /etc/charontak.ini ]]; then
	if grep -q '127.0.0.1:28087' /etc/charontak.ini; then
		ok "charontak.ini ingress 127.0.0.1:28087"
	else
		fail "charontak.ini missing ingress 127.0.0.1:28087"
	fi
	if grep -q '^\[lane:local-to-mesh\]' /etc/charontak.ini &&
		grep -q '^egress_cot_url = udp+wo://239.2.3.1:6969' /etc/charontak.ini; then
		ok "charontak default local-to-mesh egress"
	else
		fail "charontak default local-to-mesh egress missing"
	fi
	if grep -q '^\[lane:local-to-takserver\]' /etc/charontak.ini &&
		grep -q '^ingress_cot_url = udp+ro://127.0.0.1:28087' /etc/charontak.ini; then
		ok "charontak TAK Server lane uses local ingress"
	else
		fail "charontak TAK Server lane not wired to local ingress"
	fi
else
	skip "charontak.ini not present"
fi

if [[ -f /etc/default/adsbcot ]]; then
	if grep -q 'FEED_URL=file:///run/adsb/aircraft.json' /etc/default/adsbcot; then
		ok "adsbcot FEED_URL unified path"
	else
		fail "adsbcot FEED_URL not file:///run/adsb/aircraft.json"
	fi
else
	fail "/etc/default/adsbcot missing"
fi

if [[ -f /etc/default/readsb ]]; then
	if grep -q 'device-type rtlsdr' /etc/default/readsb; then
		ok "readsb device-type rtlsdr"
	else
		warn "readsb not configured for rtlsdr (Soapy/HackRF lab?)"
	fi
else
	warn "/etc/default/readsb missing"
fi

hn="$(hostname -s 2>/dev/null || hostname)"
if [[ "$hn" =~ ^aryaos-[0-9a-f]{4}$ ]]; then
	ok "hostname personalized ($hn)"
elif [[ "$hn" == aryaos ]]; then
	warn "hostname still factory 'aryaos' (run aryaos-firstboot or reflash)"
else
	warn "hostname unexpected: $hn"
fi

if grep -qE '^DEVICE_SUFFIX=[0-9a-f]{4}$' /etc/aryaos/aryaos-config.txt 2>/dev/null; then
	ok "DEVICE_SUFFIX set in aryaos-config.txt"
elif grep -q '^DEVICE_SUFFIX=""' /etc/aryaos/aryaos-config.txt 2>/dev/null; then
	warn "DEVICE_SUFFIX empty (aryaos-firstboot not run?)"
else
	warn "DEVICE_SUFFIX missing or invalid in aryaos-config.txt"
fi

if grep -qE '^AOS_SERVICES=.*(^|[[:space:]])(readsb|dump1090-fa|dump978-fa|gpsd|nodered|tar1090)([[:space:]]|")' /etc/aryaos/aryaos-config.txt 2>/dev/null; then
	fail "local decoder/system service included in AOS_SERVICES"
else
	ok "local decoder/system services excluded from network restart list"
fi

if [[ -f /etc/default/lincot ]]; then
	if grep -q '^ENABLED=1' /etc/default/lincot && grep -q 'gpspipe' /etc/default/lincot; then
		ok "lincot enabled with gpspipe"
	else
		warn "lincot defaults not fully enabled"
	fi
	if grep -q '^REMARKS_EXTRA_CMD=/usr/local/sbin/aryaos-lincot-remarks' /etc/default/lincot &&
		[[ -x /usr/local/sbin/aryaos-lincot-remarks ]]; then
		ok "lincot host environment remarks helper configured"
	else
		fail "lincot host environment remarks helper not configured"
	fi
	if id -nG lincot 2>/dev/null | grep -qw video; then
		ok "lincot can read Raspberry Pi firmware telemetry"
	else
		fail "lincot missing video group for Raspberry Pi firmware telemetry"
	fi
	REMARKS="$(sudo -u lincot /usr/local/sbin/aryaos-lincot-remarks 2>/dev/null || true)"
	if grep -q 'Throttle: Can.t open device file' <<<"${REMARKS}"; then
		fail "lincot remarks leak vcgencmd permission error"
	else
		ok "lincot remarks suppress vcgencmd permission errors"
	fi
	if grep -Eq 'Throttle: (ok|current:|history:).*\(0x[0-9a-fA-F]+\)' <<<"${REMARKS}"; then
		ok "lincot remarks decode throttle status"
	elif grep -q '^Throttle: 0x' <<<"${REMARKS}"; then
		fail "lincot remarks show raw throttle code only"
	else
		skip "lincot throttle status unavailable"
	fi
else
	skip "lincot defaults not present"
fi

if [[ -f /lib/systemd/system/sikw00fcot.service ]]; then
	if grep -q '^EnvironmentFile=/etc/aryaos/aryaos-config.txt$' /lib/systemd/system/sikw00fcot.service &&
		grep -q '^EnvironmentFile=/etc/default/sikw00fcot$' /lib/systemd/system/sikw00fcot.service; then
		ok "sikw00fcot inherits AryaOS site config before service defaults"
	else
		fail "sikw00fcot service missing AryaOS site config inheritance"
	fi
	if [[ -f /etc/systemd/system/sikw00fcot.service.d/after-charontak.conf ]]; then
		ok "sikw00fcot starts after charontak"
	else
		fail "sikw00fcot missing after-charontak drop-in"
	fi
else
	fail "sikw00fcot service missing"
fi

print_summary
