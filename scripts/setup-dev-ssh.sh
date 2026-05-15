#!/usr/bin/env bash
# Append ~/.ssh/config stanza for the lab Pi using the AryaOS dev lab private key.
#
# Uses (first hit): shared_files/aryaos/ssh/aryaos-dev-lab or ~/.ssh/aryaos-dev-lab
#
# Usage (from repo root):
#   ./scripts/setup-dev-ssh.sh
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST_IP="${ARYAOS_DEV_PI_HOST:-172.17.2.158}"
SSH_USER="${ARYAOS_DEV_PI_USER:-pi}"
HOST_ALIAS="${ARYAOS_DEV_PI_SSH_HOST:-aryaos-dev-pi}"

KEY_REPO="${REPO_ROOT}/shared_files/aryaos/ssh/aryaos-dev-lab"
KEY_HOME="${HOME}/.ssh/aryaos-dev-lab"

IDENTITY=""
if [[ -r "${KEY_REPO}" ]]; then
	IDENTITY="${KEY_REPO}"
elif [[ -r "${KEY_HOME}" ]]; then
	IDENTITY="${KEY_HOME}"
else
	echo "No private key found. Expected one of:" >&2
	echo "  ${KEY_REPO}" >&2
	echo "  ${KEY_HOME}" >&2
	echo "Generate in the repo (public key is tracked; private is gitignored):" >&2
	echo "  ssh-keygen -t ed25519 -f ${KEY_REPO} -N \"\" -C aryaos-lab-dev" >&2
	exit 1
fi

chmod 0600 "${IDENTITY}" 2>/dev/null || true

CFG="${HOME}/.ssh/config"
mkdir -p "${HOME}/.ssh"
touch "${CFG}"
chmod 0600 "${CFG}"

if grep -qE "^[[:space:]]*Host[[:space:]]+${HOST_ALIAS}([[:space:]]|\$)" "${CFG}" 2>/dev/null; then
	echo "SSH config already has Host ${HOST_ALIAS} — leaving ${CFG} unchanged."
	echo "Identity file in use for this repo: ${IDENTITY}"
	exit 0
fi

{
	echo ""
	echo "# AryaOS lab dev Pi (added by scripts/setup-dev-ssh.sh)"
	echo "Host ${HOST_ALIAS}"
	echo "  HostName ${HOST_IP}"
	echo "  User ${SSH_USER}"
	echo "  IdentityFile ${IDENTITY}"
} >> "${CFG}"

echo "Wrote Host ${HOST_ALIAS} -> ${SSH_USER}@${HOST_IP} using ${IDENTITY}"
echo "Try: ssh ${HOST_ALIAS}"
