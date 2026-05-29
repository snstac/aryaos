#!/usr/bin/env bash
# 02-config.sh — config file parity checks (remote on Pi).
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

if grep -q 'COT_URL=udp://127.0.0.1:18087' /etc/aryaos/aryaos-config.txt 2>/dev/null; then
	ok "feeder COT_URL → charontak ingress"
else
	fail "COT_URL not udp://127.0.0.1:18087 in aryaos-config.txt"
fi

if grep -q 'ARYAOS_ADSB_JSON_DIR=/run/adsb' /etc/aryaos/aryaos-config.txt 2>/dev/null; then
	ok "ARYAOS_ADSB_JSON_DIR=/run/adsb"
else
	warn "ARYAOS_ADSB_JSON_DIR not set in aryaos-config.txt"
fi

if [[ -f /etc/charontak.ini ]]; then
	if grep -q '127.0.0.1:18087' /etc/charontak.ini; then
		ok "charontak.ini ingress 127.0.0.1:18087"
	else
		fail "charontak.ini missing ingress 127.0.0.1:18087"
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

if [[ -f /etc/default/lincot ]]; then
	if grep -q '^ENABLED=1' /etc/default/lincot && grep -q 'gpspipe' /etc/default/lincot; then
		ok "lincot enabled with gpspipe"
	else
		warn "lincot defaults not fully enabled"
	fi
else
	skip "lincot defaults not present"
fi

print_summary
