#!/usr/bin/env bash
# Rsync this repository to the lab Raspberry Pi (default pi@aryaos-dev-pi — use ~/.ssh/config Host from scripts/setup-dev-ssh.sh; override with ARYAOS_DEV_PI_HOST=172.17.2.158 if needed).
# Prefers shared_files/aryaos/ssh/aryaos-dev-lab (or ARYAOS_DEV_PI_SSH_KEY); else sshpass
# when ARYAOS_DEV_PI_PASSWORD is set (or scripts/.dev-pi-creds.local).
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

PI_USER="${ARYAOS_DEV_PI_USER:-pi}"
PI_HOST="${ARYAOS_DEV_PI_HOST:-aryaos-dev-pi}"
DEST="${PI_USER}@${PI_HOST}:~/aryaos-sync/"

DEV_KEY="${ARYAOS_DEV_PI_SSH_KEY:-${REPO_ROOT}/shared_files/aryaos/ssh/aryaos-dev-lab}"

if ! command -v rsync >/dev/null; then
	echo "rsync is required." >&2
	exit 1
fi

RSYNC_RSH=""
# 1) Default ssh (ssh-agent + ~/.ssh/config Host / IdentityFile — matches interactive `ssh pi@aryaos-dev-pi`)
if ssh -o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=accept-new "${PI_USER}@${PI_HOST}" true 2>/dev/null; then
	RSYNC_RSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
# 2) Explicit repo key file (optional; avoids relying on agent/config)
elif [[ -r "${DEV_KEY}" ]] && [[ -z "${ARYAOS_DEV_PI_SKIP_KEY:-}" ]]; then
	if ssh -i "${DEV_KEY}" -o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=accept-new \
		"${PI_USER}@${PI_HOST}" true 2>/dev/null; then
		RSYNC_RSH="ssh -i $(printf '%q' "${DEV_KEY}") -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
	fi
fi
if [[ -z "${RSYNC_RSH}" ]] && [[ -n "${ARYAOS_DEV_PI_PASSWORD:-}" ]]; then
	if ! command -v sshpass >/dev/null; then
		echo "sshpass is required when ARYAOS_DEV_PI_PASSWORD is set (SSH probes to ${PI_HOST} failed)." >&2
		exit 1
	fi
	export SSHPASS="${ARYAOS_DEV_PI_PASSWORD}"
	RSYNC_RSH="sshpass -e ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -o StrictHostKeyChecking=accept-new"
elif [[ -z "${RSYNC_RSH}" ]]; then
	echo "Cannot SSH to ${PI_USER}@${PI_HOST}." >&2
	echo "Fix ~/.ssh/config (see ./scripts/setup-dev-ssh.sh), enroll ${DEV_KEY}, set ARYAOS_DEV_PI_PASSWORD, or add scripts/.dev-pi-creds.local — see docs/dev-pi.md" >&2
	exit 1
fi

if [[ "${RSYNC_RSH}" == sshpass* ]]; then
	echo "==> SSH: using password (agent/config and repo key probes failed for ${PI_HOST})"
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

echo "==> Done. Tree is under ~/aryaos-sync/ on the Pi. For portal/CGI install: ARYAOS_SSH=${PI_USER}@${PI_HOST} ./scripts/sync-portal-review.sh"
