#!/usr/bin/env bash
# Sync (optional) and verify readsb + adsbcot + portal on the lab Pi (aryaos-dev-pi).
#
# Usage (repo root):
#   ./scripts/test-dev-pi.sh              # verify only
#   ARYAOS_DEV_PI_SYNC=1 ./scripts/test-dev-pi.sh   # rsync + portal review, then verify
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

# shellcheck disable=SC1091
[[ -f scripts/.dev-pi-creds.local ]] && . scripts/.dev-pi-creds.local

PI_USER="${ARYAOS_DEV_PI_USER:-pi}"
PI_HOST="${ARYAOS_DEV_PI_HOST:-aryaos-dev-pi}"
PI="${PI_USER}@${PI_HOST}"
DEV_KEY="${ARYAOS_DEV_PI_SSH_KEY:-${REPO_ROOT}/shared_files/aryaos/ssh/aryaos-dev-lab}"

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new)
if [[ -n "${ARYAOS_DEV_PI_SSH_KEY:-}" && -r "${ARYAOS_DEV_PI_SSH_KEY}" ]]; then
	SSH=(ssh -i "${ARYAOS_DEV_PI_SSH_KEY}" -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new)
elif [[ -r "${DEV_KEY}" ]]; then
	if ! "${SSH[@]}" "${PI}" true 2>/dev/null; then
		SSH=(ssh -i "${DEV_KEY}" -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new)
	fi
fi

if ! "${SSH[@]}" "${PI}" true 2>/dev/null; then
	if [[ -n "${ARYAOS_DEV_PI_PASSWORD:-}" ]] && command -v sshpass >/dev/null; then
		export SSHPASS="${ARYAOS_DEV_PI_PASSWORD}"
		SSH=(sshpass -e ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new)
	elif command -v sshpass >/dev/null; then
		# shellcheck disable=SC1091
		[[ -f scripts/.dev-pi-creds.local ]] && . scripts/.dev-pi-creds.local
		if [[ -n "${ARYAOS_DEV_PI_PASSWORD:-}" ]]; then
			export SSHPASS="${ARYAOS_DEV_PI_PASSWORD}"
			SSH=(sshpass -e ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new)
		fi
	fi
fi

if ! "${SSH[@]}" "${PI}" true; then
	echo "Cannot SSH to ${PI}. Power/network the lab Pi or fix ~/.ssh/config — see docs/dev-pi.md" >&2
	exit 1
fi

if [[ "${ARYAOS_DEV_PI_SYNC:-0}" == 1 ]]; then
	echo "==> sync-to-dev-pi"
	./scripts/sync-to-dev-pi.sh
	echo "==> sync-portal-review"
	ARYAOS_SSH="${PI}" ./scripts/sync-portal-review.sh
fi

echo "==> remote checks on ${PI}"
"${SSH[@]}" "${PI}" bash -s <<'REMOTE'
set -euo pipefail
fail=0
check() {
	if "$@"; then
		echo "OK  $*"
	else
		echo "FAIL $*" >&2
		fail=1
	fi
}

check systemctl is-active --quiet readsb
check systemctl is-active --quiet charontak || echo "SKIP charontak (not installed yet)"
check systemctl is-active --quiet lincot || echo "SKIP lincot (not installed yet)"
check systemctl is-active --quiet adsbcot
check systemctl is-active --quiet lighttpd
check test -f /run/adsb/aircraft.json
grep -q 'COT_URL=udp://127.0.0.1:18087' /etc/aryaos/aryaos-config.txt && echo "OK  feeder COT_URL → charontak" || { echo "FAIL feeder COT_URL" >&2; fail=1; }
test -f /etc/charontak.ini && grep -q '127.0.0.1:18087' /etc/charontak.ini && echo "OK  charontak.ini ingress" || echo "SKIP charontak.ini (image not updated)"
grep -q '^ENABLED=1' /etc/default/lincot 2>/dev/null && grep -q 'gpspipe' /etc/default/lincot && echo "OK  lincot defaults" || echo "SKIP lincot defaults (image not updated)"
READSB_HELP="$(/usr/bin/readsb --help 2>&1)"
echo "${READSB_HELP}" | grep -qE 'RTL-SDR|rtlsdr' && echo "OK  readsb RTL-SDR" || { echo "FAIL readsb RTL-SDR" >&2; fail=1; }
echo "${READSB_HELP}" | grep -qiE 'SoapySDR|soapysdr' && echo "OK  readsb SoapySDR" || { echo "FAIL readsb SoapySDR" >&2; fail=1; }
echo "${READSB_HELP}" | grep -qiE 'HackRF|hackrf' && echo "OK  readsb HackRF" || { echo "FAIL readsb HackRF" >&2; fail=1; }
grep -q 'device-type rtlsdr' /etc/default/readsb && echo "OK  readsb RTL config" || { echo "FAIL readsb RTL config" >&2; fail=1; }
grep -q 'FEED_URL=file:///run/adsb/aircraft.json' /etc/default/adsbcot && echo "OK  adsbcot FEED_URL" || { echo "FAIL adsbcot FEED_URL" >&2; fail=1; }

PI_IP="$(hostname -I | awk '{print $1}')"
JSON="$(curl -gk --max-time 8 -sS "https://${PI_IP}/cgi-bin/aryaos-portal-status" 2>/dev/null || curl -g --max-time 8 -sS "http://127.0.0.1/cgi-bin/aryaos-portal-status")"
python3 -c "
import json, sys
d = json.loads(sys.argv[1])
assert d.get('hostname'), 'missing hostname'
assert 'system' in d and d['system'].get('ok') is not None, 'missing system'
assert 'tak_gateways' in d, 'missing tak_gateways'
print('OK  portal JSON keys (hostname, system, tak_gateways)')
" "${JSON}"

echo "--- readsb (last 5 log lines) ---"
journalctl -u readsb -n 5 --no-pager 2>/dev/null || true
echo "--- aircraft.json (head) ---"
head -c 300 /run/adsb/aircraft.json 2>/dev/null || true
echo
exit "${fail}"
REMOTE

echo "==> all checks passed on ${PI}"
