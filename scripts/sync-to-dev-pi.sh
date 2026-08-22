#!/usr/bin/env bash
# Rsync this repository to a dynamically discovered AryaOS development device.
#
# From repo root:
#   ./scripts/sync-to-dev-pi.sh
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

# shellcheck disable=SC1091
[[ -f scripts/.dev-pi-creds.local ]] && . scripts/.dev-pi-creds.local
# shellcheck source=scripts/lib/dev-device.sh
. scripts/lib/dev-device.sh

TARGET="$(aryaos_dev_target "${REPO_ROOT}" "${1:-}")"
DEST="${TARGET}:~/aryaos-sync/"
DEV_KEY="$(aryaos_dev_key "${REPO_ROOT}")"
DEV_PASSWORD="$(aryaos_dev_password)"
KNOWN_HOSTS=(-o StrictHostKeyChecking=accept-new)
if [[ -n "${ARYAOS_SSH_KNOWN_HOSTS_FILE:-}" ]]; then
	KNOWN_HOSTS=(-o StrictHostKeyChecking=yes -o "UserKnownHostsFile=${ARYAOS_SSH_KNOWN_HOSTS_FILE}")
fi

if ! command -v rsync >/dev/null; then
	echo "rsync is required." >&2
	exit 1
fi

RSYNC_RSH=""
# 1) Default ssh (ssh-agent and user config).
if ssh -o BatchMode=yes -o ConnectTimeout=6 "${KNOWN_HOSTS[@]}" "${TARGET}" true 2>/dev/null; then
	printf -v RSYNC_RSH '%q ' ssh -o BatchMode=yes "${KNOWN_HOSTS[@]}"
# 2) Explicit repo key file (optional; avoids relying on agent/config)
elif [[ -r "${DEV_KEY}" ]] && [[ -z "${ARYAOS_DEV_PI_SKIP_KEY:-}" ]]; then
	if ssh -i "${DEV_KEY}" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=6 \
		"${KNOWN_HOSTS[@]}" "${TARGET}" true 2>/dev/null; then
		printf -v RSYNC_RSH '%q ' ssh -i "${DEV_KEY}" -o IdentitiesOnly=yes -o BatchMode=yes "${KNOWN_HOSTS[@]}"
	fi
fi
if [[ -z "${RSYNC_RSH}" ]] && [[ -n "${DEV_PASSWORD}" ]]; then
	if ! command -v sshpass >/dev/null; then
		echo "sshpass is required when ARYAOS_DEV_DEVICE_PASSWORD is set (SSH probes to ${TARGET} failed)." >&2
		exit 1
	fi
	export SSHPASS="${DEV_PASSWORD}"
	printf -v RSYNC_RSH '%q ' sshpass -e ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no "${KNOWN_HOSTS[@]}"
elif [[ -z "${RSYNC_RSH}" ]]; then
	echo "Cannot SSH to ${TARGET}." >&2
	echo "Enroll ${DEV_KEY}, set ARYAOS_DEV_DEVICE_PASSWORD, or use an explicit ARYAOS_SSH target; see docs/dev-pi.md" >&2
	exit 1
fi

if [[ "${RSYNC_RSH}" == sshpass* ]]; then
	echo "==> SSH: using password (agent/config and repo key probes failed for ${TARGET})"
elif [[ "${RSYNC_RSH}" == ssh\ -i* ]]; then
	echo "==> SSH: using explicit key file ${DEV_KEY}"
else
	echo "==> SSH: using ssh defaults (agent / ~/.ssh/config)"
fi

EXCLUDES=(
	--exclude '.git'
	--exclude '.aryaos-pigen-work'
	--exclude '.aryaos-pigen-deploy'
	--exclude 'pi-gen'
	--exclude '.venv'
	--exclude 'site'
	--exclude 'deploy'
	--exclude '__pycache__'
	--exclude '*.pyc'
	--exclude '.DS_Store'
)

echo "==> rsync ${REPO_ROOT}/ -> ${DEST}"
rsync -avz --delete \
	"${EXCLUDES[@]}" \
	-e "${RSYNC_RSH}" \
	./ "${DEST}"

echo "==> Done. Tree is under ~/aryaos-sync/ on the device. For portal/CGI install: ARYAOS_SSH=${TARGET} ./scripts/sync-portal-review.sh"
