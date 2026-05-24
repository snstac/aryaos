#!/usr/bin/env bash
# Deploy readsb (SoapySDR/Airspy) + adsbcot on dragonball via Docker (no sudo password).
# Run on dragonball: bash ~/aryaos-sync/scripts/dragonball-deploy-readsb-adsbcot.sh
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

REPO="${1:-$HOME/aryaos-sync}"
AIRSPY_SERIAL="${AIRSPY_SERIAL:-258c62dc2da65a8f}"
GAIN="${READSB_GAIN:-15}"

if [[ ! -d "${REPO}/shared_files/adsbcot" ]]; then
	echo "Missing repo at ${REPO}" >&2
	exit 1
fi

echo "==> Deploy from ${REPO} (Airspy serial ${AIRSPY_SERIAL})"

docker run -i --rm --privileged \
	-v "${REPO}:/aryaos:ro" \
	-v /:/host \
	-e "AIRSPY_SERIAL=${AIRSPY_SERIAL}" \
	-e "GAIN=${GAIN}" \
	debian:bookworm bash -euxo pipefail -s <<'INCHROOT'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates git

# Host paths via bind mount
install -d /host/etc/aryaos /host/usr/local/sbin /host/usr/local/share/adsb-wiki/readsb-install
install -m 0644 /aryaos/shared_files/aryaos/aryaos-config.txt /host/etc/aryaos/aryaos-config.txt

# Build readsb with RTL + Soapy (Airspy); copy binaries onto host rootfs
bash /aryaos/shared_files/adsbcot/readsb-install.sh no-tar1090
cp -f /usr/bin/readsb /host/usr/bin/readsb
cp -f /usr/bin/viewadsb /host/usr/bin/viewadsb 2>/dev/null || true
touch /host/usr/local/share/adsb-wiki/readsb-install/aryaos-readsb-built

if [[ ! -f /host/etc/default/readsb ]]; then
	cp /aryaos/shared_files/adsbcot/readsb-config.txt /host/etc/default/readsb
fi

install -m 644 /aryaos/shared_files/adsbcot/readsb.service /host/lib/systemd/system/readsb.service
install -m 755 /aryaos/shared_files/adsbcot/run_readsb.sh /host/usr/local/sbin/run_readsb.sh
install -d -m 755 /host/etc/systemd/system/readsb.service.d
install -m 644 /aryaos/shared_files/adsbcot/systemd/readsb.service.d/aryaos-conflicts.conf \
	/host/etc/systemd/system/readsb.service.d/aryaos-conflicts.conf

RECEIVER_OPTIONS="--device-type soapysdr --soapy-device driver=airspy,serial=${AIRSPY_SERIAL} --gain ${GAIN}"
if [[ -f /host/etc/default/readsb ]]; then
	sed -i -E "s|^RECEIVER_OPTIONS=.*|RECEIVER_OPTIONS=\"${RECEIVER_OPTIONS}\"|" /host/etc/default/readsb
fi

# adsbcot: point at readsb JSON
if [[ -f /host/etc/default/adsbcot ]]; then
	if grep -q '^#.*FEED_URL' /host/etc/default/adsbcot; then
		sed -i -E 's|^#.*FEED_URL=.*|FEED_URL=file:///run/readsb/aircraft.json|' /host/etc/default/adsbcot
	elif grep -q '^FEED_URL=' /host/etc/default/adsbcot; then
		sed -i -E 's|^FEED_URL=.*|FEED_URL=file:///run/readsb/aircraft.json|' /host/etc/default/adsbcot
	else
		echo 'FEED_URL=file:///run/readsb/aircraft.json' >>/host/etc/default/adsbcot
	fi
	if ! grep -q 'EnvironmentFile=/etc/aryaos/aryaos-config.txt' /host/lib/systemd/system/adsbcot.service; then
		sed -i '/\[Service\]/a EnvironmentFile=/etc/aryaos/aryaos-config.txt' /host/lib/systemd/system/adsbcot.service
	fi
fi

# readsb user for systemd
if ! chroot /host id -u readsb &>/dev/null; then
	chroot /host adduser --system --home /usr/local/share/adsb-wiki --no-create-home readsb || true
fi
chroot /host adduser readsb plugdev 2>/dev/null || true

INCHROOT

echo "==> Enable services (host PID namespace)"
docker run --rm --privileged --pid=host debian:bookworm \
	nsenter -t 1 -m -u -i -n -p -- bash -euxo pipefail -c '
		systemctl daemon-reload
		systemctl disable --now dump1090-fa.service 2>/dev/null || true
		systemctl enable readsb.service
		systemctl restart readsb.service
		systemctl restart adsbcot.service
	'

echo "==> Status"
systemctl is-active readsb adsbcot || true
/usr/bin/readsb --device-type soapysdr --device "driver=airspy,serial=${AIRSPY_SERIAL}" 2>&1 | head -3 || true
sleep 3
ls -la /run/readsb/aircraft.json 2>/dev/null || echo "waiting for aircraft.json…"
