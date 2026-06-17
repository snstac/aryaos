#!/usr/bin/env bash
# AryaOS lab Pi integration test runner.
#
# Usage (repo root):
#   ./scripts/aryaos-test/run.sh
#   ARYAOS_SSH=pi@10.0.0.5 ./scripts/aryaos-test/run.sh
#   ARYAOS_TEST_TIER=strict ./scripts/aryaos-test/run.sh
#   ARYAOS_TEST_PROFILE=uas ./scripts/aryaos-test/run.sh
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${REPO_ROOT}"

# shellcheck disable=SC1091
[[ -f scripts/.dev-pi-creds.local ]] && . scripts/.dev-pi-creds.local

PI_USER="${ARYAOS_DEV_PI_USER:-pi}"
PI_HOST="${ARYAOS_DEV_PI_HOST:-aryaos-dev-pi}"
if [[ -n "${ARYAOS_SSH:-}" ]]; then
	PI="${ARYAOS_SSH}"
else
	PI="${PI_USER}@${PI_HOST}"
fi
DEV_KEY="${ARYAOS_DEV_PI_SSH_KEY:-${REPO_ROOT}/shared_files/aryaos/ssh/aryaos-dev-lab}"

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new)
SCP=(scp -o StrictHostKeyChecking=accept-new)
SSH_METHOD="ssh defaults"

if [[ -n "${ARYAOS_DEV_PI_SSH_KEY:-}" && -r "${ARYAOS_DEV_PI_SSH_KEY}" ]]; then
	SSH=(ssh -i "${ARYAOS_DEV_PI_SSH_KEY}" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new)
	SCP=(scp -i "${ARYAOS_DEV_PI_SSH_KEY}" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new)
	SSH_METHOD="explicit key ${ARYAOS_DEV_PI_SSH_KEY}"
elif [[ -r "${DEV_KEY}" && -z "${ARYAOS_DEV_PI_SKIP_KEY:-}" ]]; then
	SSH=(ssh -i "${DEV_KEY}" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new)
	SCP=(scp -i "${DEV_KEY}" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new)
	SSH_METHOD="repo lab key ${DEV_KEY}"
	if ! "${SSH[@]}" "${PI}" true 2>/dev/null; then
		SSH=(ssh -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new)
		SCP=(scp -o StrictHostKeyChecking=accept-new)
		SSH_METHOD="ssh defaults"
	fi
fi

if ! "${SSH[@]}" "${PI}" true 2>/dev/null; then
	if [[ -n "${ARYAOS_DEV_PI_PASSWORD:-}" ]] && command -v sshpass >/dev/null; then
		export SSHPASS="${ARYAOS_DEV_PI_PASSWORD}"
		SSH=(sshpass -e ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new)
		SCP=(sshpass -e scp -o PreferredAuthentications=password -o PubkeyAuthentication=no -o StrictHostKeyChecking=accept-new)
		SSH_METHOD="password"
	elif command -v sshpass >/dev/null; then
		# shellcheck disable=SC1091
		[[ -f scripts/.dev-pi-creds.local ]] && . scripts/.dev-pi-creds.local
		if [[ -n "${ARYAOS_DEV_PI_PASSWORD:-}" ]]; then
			export SSHPASS="${ARYAOS_DEV_PI_PASSWORD}"
			SSH=(sshpass -e ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new)
			SCP=(sshpass -e scp -o PreferredAuthentications=password -o PubkeyAuthentication=no -o StrictHostKeyChecking=accept-new)
			SSH_METHOD="password"
		fi
	fi
fi

if ! "${SSH[@]}" "${PI}" true; then
	echo "Cannot SSH to ${PI}. See docs/dev-pi.md" >&2
	exit 2
fi

echo "==> AryaOS integration tests on ${PI} (tier=${ARYAOS_TEST_TIER:-default})"
echo "==> Profile: ${ARYAOS_TEST_PROFILE:-default}"
echo "==> SSH: using ${SSH_METHOD}"

REMOTE_STAGE="/tmp/aryaos-test.$$"
"${SSH[@]}" "${PI}" "mkdir -p '${REMOTE_STAGE}/tests'"
"${SCP[@]}" "${TEST_DIR}/lib.sh" "${PI}:${REMOTE_STAGE}/lib.sh"
"${SCP[@]}" "${TEST_DIR}/validate_portal.py" "${PI}:${REMOTE_STAGE}/validate_portal.py"
for t in "${TEST_DIR}"/tests/*.sh; do
	"${SCP[@]}" "${t}" "${PI}:${REMOTE_STAGE}/tests/$(basename "${t}")"
done
"${SSH[@]}" "${PI}" "chmod +x '${REMOTE_STAGE}'/lib.sh '${REMOTE_STAGE}'/tests/*.sh"

TOTAL_FAILED=0
for t in "${TEST_DIR}"/tests/*.sh; do
	name="$(basename "${t}")"
	echo ""
	echo "==> ${name}"
	set +e
	"${SSH[@]}" "${PI}" "export ARYAOS_TEST_TIER='${ARYAOS_TEST_TIER:-default}'; export ARYAOS_TEST_PROFILE='${ARYAOS_TEST_PROFILE:-default}'; export ARYAOS_VALIDATE_PORTAL='${REMOTE_STAGE}/validate_portal.py'; bash '${REMOTE_STAGE}/tests/${name}'"
	rc=$?
	set -e
	if [[ "${rc}" -ne 0 ]]; then
		TOTAL_FAILED=$((TOTAL_FAILED + 1))
	fi
done

"${SSH[@]}" "${PI}" "rm -rf '${REMOTE_STAGE}'" || true

echo ""
echo "==> suite complete on ${PI}"
if [[ "${TOTAL_FAILED}" -gt 0 ]]; then
	echo "${TOTAL_FAILED} test module(s) reported failures" >&2
	exit 1
fi
echo "all test modules passed (warnings may appear above)"
exit 0
