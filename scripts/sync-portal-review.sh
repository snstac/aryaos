#!/usr/bin/env bash
# Push portal HTML, CGI status helper, lighttpd portal snippet, and Node-RED flows
# from the repo to a running AryaOS host for review.
#
# Usage:
#   ./scripts/sync-portal-review.sh pi@10.0.0.5
#   ARYAOS_SSH=pi@aryaos.local ./scripts/sync-portal-review.sh
#
# Without an explicit target, resolves a unique AryaOS device from LAN beacons.
#
# Requires SSH access. /var/www/html is owned by node-red on the image — we rsync to /tmp
# first, then sudo rsync into place (does not --delete; extra dirs on the box are kept).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
[[ -f "${REPO_ROOT}/scripts/.dev-pi-creds.local" ]] && . "${REPO_ROOT}/scripts/.dev-pi-creds.local"
# shellcheck source=scripts/lib/dev-device.sh
. "${REPO_ROOT}/scripts/lib/dev-device.sh"

DEST="$(aryaos_dev_target "${REPO_ROOT}" "${1:-}")"
DEV_KEY="$(aryaos_dev_key "${REPO_ROOT}")"
DEV_PASSWORD="$(aryaos_dev_password)"
KNOWN_HOSTS=(-o StrictHostKeyChecking=accept-new)
if [[ -n "${ARYAOS_SSH_KNOWN_HOSTS_FILE:-}" ]]; then
	KNOWN_HOSTS=(-o StrictHostKeyChecking=yes -o "UserKnownHostsFile=${ARYAOS_SSH_KNOWN_HOSTS_FILE}")
fi
RSYNC_E=(ssh "${KNOWN_HOSTS[@]}")
SSH_CMD=(ssh "${KNOWN_HOSTS[@]}")
SCP_CMD=(scp "${KNOWN_HOSTS[@]}")
if ssh -o BatchMode=yes -o ConnectTimeout=6 "${KNOWN_HOSTS[@]}" "${DEST}" true 2>/dev/null; then
	:
elif [[ -r "${DEV_KEY}" ]] && ssh -i "${DEV_KEY}" -o IdentitiesOnly=yes -o BatchMode=yes \
	-o ConnectTimeout=6 "${KNOWN_HOSTS[@]}" "${DEST}" true 2>/dev/null; then
	RSYNC_E=(ssh -i "${DEV_KEY}" -o IdentitiesOnly=yes "${KNOWN_HOSTS[@]}")
	SSH_CMD=(ssh -i "${DEV_KEY}" -o IdentitiesOnly=yes "${KNOWN_HOSTS[@]}")
	SCP_CMD=(scp -i "${DEV_KEY}" -o IdentitiesOnly=yes "${KNOWN_HOSTS[@]}")
elif [[ -n "${DEV_PASSWORD}" ]]; then
	if ! command -v sshpass >/dev/null; then
		echo "sshpass is required when ARYAOS_DEV_DEVICE_PASSWORD is set" >&2
		exit 1
	fi
	export SSHPASS="${DEV_PASSWORD}"
	RSYNC_E=(sshpass -e ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no "${KNOWN_HOSTS[@]}")
	SSH_CMD=(sshpass -e ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no "${KNOWN_HOSTS[@]}")
	SCP_CMD=(sshpass -e scp -o PreferredAuthentications=password -o PubkeyAuthentication=no "${KNOWN_HOSTS[@]}")
fi
printf -v RSYNC_RSH '%q ' "${RSYNC_E[@]}"

REMSTAGE="/tmp/aryaos-portal-review.$$"
echo "==> rsync portal HTML -> ${DEST}:${REMSTAGE}/ (staging)"
rsync -avz -e "${RSYNC_RSH}" "${REPO_ROOT}/shared_files/aryaos/html/" "${DEST}:${REMSTAGE}/"

echo "==> sudo install -> /var/www/html/ + ownership (may prompt for sudo password)"
"${SSH_CMD[@]}" "${DEST}" "set -e; sudo rsync -a '${REMSTAGE}/' /var/www/html/; sudo chown -R node-red:node-red /var/www/html; sudo rm -rf '${REMSTAGE}'"

echo "==> /etc/default/gpsd + gpsd.socket drop-in + www-data in gpsd group + restart gpsd / lighttpd"
"${SCP_CMD[@]}" "${REPO_ROOT}/shared_files/aryaos/gpsd.default" "${DEST}:/tmp/gpsd.default"
"${SCP_CMD[@]}" "${REPO_ROOT}/shared_files/aryaos/systemd/gpsd.socket.d/socket-group.conf" "${DEST}:/tmp/gpsd-socket-group.conf"
"${SSH_CMD[@]}" "${DEST}" "set -e
sudo install -m 0644 -o root -g root /tmp/gpsd.default /etc/default/gpsd
rm -f /tmp/gpsd.default
sudo getent group gpsd >/dev/null || sudo groupadd --system gpsd
sudo install -d -m 0755 /etc/systemd/system/gpsd.socket.d
sudo install -m 0644 -o root -g root /tmp/gpsd-socket-group.conf /etc/systemd/system/gpsd.socket.d/socket-group.conf
rm -f /tmp/gpsd-socket-group.conf
sudo usermod -aG gpsd www-data || true
sudo systemctl daemon-reload
sudo systemctl stop gpsd.service || true
sudo systemctl restart gpsd.socket
sudo systemctl start gpsd.service
sudo systemctl restart lighttpd.service"

F95="95-aryaos-cockpit-https.conf"
TMP95="/tmp/${F95}.$$"
echo "==> portal status CGI + lighttpd ${F95}"
"${SCP_CMD[@]}" "${REPO_ROOT}/shared_files/aryaos/cgi-bin/aryaos-portal-status" "${DEST}:/tmp/aryaos-portal-status"
"${SCP_CMD[@]}" "${REPO_ROOT}/shared_files/aryaos/${F95}" "${DEST}:${TMP95}"
"${SSH_CMD[@]}" "${DEST}" "set -e
sudo install -m 0755 -o root -g root /tmp/aryaos-portal-status /usr/lib/cgi-bin/aryaos-portal-status
rm -f /tmp/aryaos-portal-status
sudo install -m 0644 '${TMP95}' /etc/lighttpd/conf-available/${F95}
rm -f '${TMP95}'
if [[ -f /etc/lighttpd/conf-available/10-cgi.conf ]]; then
  sudo ln -sf /etc/lighttpd/conf-available/10-cgi.conf /etc/lighttpd/conf-enabled/10-cgi.conf
fi
if [[ -f /etc/lighttpd/conf-available/10-deflate.conf ]]; then
  sudo ln -sf /etc/lighttpd/conf-available/10-deflate.conf /etc/lighttpd/conf-enabled/10-deflate.conf
fi
sudo ln -sf /etc/lighttpd/conf-available/${F95} /etc/lighttpd/conf-enabled/${F95}
sudo lighttpd -tt -f /etc/lighttpd/lighttpd.conf
sudo systemctl reload lighttpd.service"

echo "==> systemd: lighttpd.service.d (AF_NETLINK for iproute2 in CGI)"
"${SSH_CMD[@]}" "${DEST}" "sudo install -d -m 0755 /etc/systemd/system/lighttpd.service.d"
"${SCP_CMD[@]}" "${REPO_ROOT}/shared_files/aryaos/systemd/lighttpd.service.d/aryaos-netlink.conf" "${DEST}:/tmp/aryaos-netlink.conf"
"${SSH_CMD[@]}" "${DEST}" "set -e
sudo install -m 0644 -o root -g root /tmp/aryaos-netlink.conf /etc/systemd/system/lighttpd.service.d/aryaos-netlink.conf
rm -f /tmp/aryaos-netlink.conf
sudo systemctl daemon-reload
sudo systemctl restart lighttpd.service"

TMPF="aryaos_flows.$$.$RANDOM.json"
echo "==> install flows + restart nodered on ${DEST}"
"${SCP_CMD[@]}" "${REPO_ROOT}/shared_files/node-red/aryaos_flows.json" "${DEST}:/tmp/${TMPF}"
"${SSH_CMD[@]}" "${DEST}" "set -e; sudo install -o node-red -g node-red -m 644 /tmp/${TMPF} /home/node-red/.node-red/aryaos_flows.json; sudo install -o node-red -g node-red -m 644 /tmp/${TMPF} /home/node-red/.node-red/flows.json; rm -f /tmp/${TMPF}; sudo systemctl restart nodered.service"

echo "Done. Open https://<host>/ — status loads via /cgi-bin/aryaos-portal-status (JSON)."
