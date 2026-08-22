#!/usr/bin/env bash
# AryaOS lab Pi integration test runner.
#
# Usage (repo root):
#   ./scripts/aryaos-test/run.sh
#   ARYAOS_SSH=pi@10.0.0.5 ./scripts/aryaos-test/run.sh
#   ARYAOS_TEST_TIER=strict ./scripts/aryaos-test/run.sh
#   ARYAOS_TEST_PROFILE=uas ./scripts/aryaos-test/run.sh
#   ARYAOS_EXPECT_CAPABILITIES="adsb rid" ./scripts/aryaos-test/run.sh
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${REPO_ROOT}"

# An explicit one-shot password wins over the gitignored fallback file. This is
# important for freshly flashed release images, which deliberately do not carry
# the lab key and may not use the same password as the usual development Pi.
if [[ -z "${ARYAOS_DEV_DEVICE_PASSWORD:-}" && -z "${ARYAOS_DEV_PI_PASSWORD:-}" && -f scripts/.dev-pi-creds.local ]]; then
	# shellcheck disable=SC1091
	. scripts/.dev-pi-creds.local
fi
# shellcheck source=scripts/lib/dev-device.sh
. scripts/lib/dev-device.sh

PI="$(aryaos_dev_target "${REPO_ROOT}")"
DEV_KEY="$(aryaos_dev_key "${REPO_ROOT}")"
DEV_PASSWORD="$(aryaos_dev_password)"
KNOWN_HOSTS_ARGS=()
if [[ -n "${ARYAOS_SSH_KNOWN_HOSTS_FILE:-}" ]]; then
	KNOWN_HOSTS_ARGS=(-o StrictHostKeyChecking=yes -o "UserKnownHostsFile=${ARYAOS_SSH_KNOWN_HOSTS_FILE}")
else
	KNOWN_HOSTS_ARGS=(-o StrictHostKeyChecking=accept-new)
fi
SSH_CONFIG_ARGS=()
if [[ -n "${ARYAOS_SSH_CONFIG_FILE:-}" ]]; then
	SSH_CONFIG_ARGS=(-F "${ARYAOS_SSH_CONFIG_FILE}")
fi

SSH=(ssh "${SSH_CONFIG_ARGS[@]}" -o BatchMode=yes -o ConnectTimeout=12 "${KNOWN_HOSTS_ARGS[@]}")
SCP=(scp "${SSH_CONFIG_ARGS[@]}" "${KNOWN_HOSTS_ARGS[@]}")
SSH_METHOD="ssh defaults"

if [[ -n "${ARYAOS_DEV_DEVICE_SSH_KEY:-}${ARYAOS_DEV_PI_SSH_KEY:-}" && -r "${DEV_KEY}" ]]; then
	SSH=(ssh "${SSH_CONFIG_ARGS[@]}" -i "${DEV_KEY}" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=12 "${KNOWN_HOSTS_ARGS[@]}")
	SCP=(scp "${SSH_CONFIG_ARGS[@]}" -i "${DEV_KEY}" -o IdentitiesOnly=yes "${KNOWN_HOSTS_ARGS[@]}")
	SSH_METHOD="explicit key ${DEV_KEY}"
elif [[ -r "${DEV_KEY}" && -z "${ARYAOS_DEV_PI_SKIP_KEY:-}" ]]; then
	SSH=(ssh "${SSH_CONFIG_ARGS[@]}" -i "${DEV_KEY}" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=12 "${KNOWN_HOSTS_ARGS[@]}")
	SCP=(scp "${SSH_CONFIG_ARGS[@]}" -i "${DEV_KEY}" -o IdentitiesOnly=yes "${KNOWN_HOSTS_ARGS[@]}")
	SSH_METHOD="repo lab key ${DEV_KEY}"
	if ! "${SSH[@]}" "${PI}" true 2>/dev/null; then
		SSH=(ssh "${SSH_CONFIG_ARGS[@]}" -o BatchMode=yes -o ConnectTimeout=12 "${KNOWN_HOSTS_ARGS[@]}")
		SCP=(scp "${SSH_CONFIG_ARGS[@]}" "${KNOWN_HOSTS_ARGS[@]}")
		SSH_METHOD="ssh defaults"
	fi
fi

if ! "${SSH[@]}" "${PI}" true 2>/dev/null; then
	if [[ -n "${DEV_PASSWORD}" ]] && command -v sshpass >/dev/null; then
		export SSHPASS="${DEV_PASSWORD}"
		SSH=(sshpass -e ssh "${SSH_CONFIG_ARGS[@]}" -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=12 "${KNOWN_HOSTS_ARGS[@]}")
		SCP=(sshpass -e scp "${SSH_CONFIG_ARGS[@]}" -o PreferredAuthentications=password -o PubkeyAuthentication=no "${KNOWN_HOSTS_ARGS[@]}")
		SSH_METHOD="password"
	elif command -v sshpass >/dev/null; then
		# shellcheck disable=SC1091
		[[ -f scripts/.dev-pi-creds.local ]] && . scripts/.dev-pi-creds.local
		DEV_PASSWORD="$(aryaos_dev_password)"
		if [[ -n "${DEV_PASSWORD}" ]]; then
			export SSHPASS="${DEV_PASSWORD}"
			SSH=(sshpass -e ssh "${SSH_CONFIG_ARGS[@]}" -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=12 "${KNOWN_HOSTS_ARGS[@]}")
			SCP=(sshpass -e scp "${SSH_CONFIG_ARGS[@]}" -o PreferredAuthentications=password -o PubkeyAuthentication=no "${KNOWN_HOSTS_ARGS[@]}")
			SSH_METHOD="password"
		fi
	fi
fi

if ! "${SSH[@]}" "${PI}" true; then
	echo "Cannot SSH to ${PI}. See docs/dev-pi.md" >&2
	exit 2
fi

EXPECTED_CAPABILITIES="${ARYAOS_EXPECT_CAPABILITIES:-}"
if [[ ! "${EXPECTED_CAPABILITIES}" =~ ^[a-z0-9,_[:space:]-]*$ ]]; then
	echo "ARYAOS_EXPECT_CAPABILITIES contains an invalid character" >&2
	exit 2
fi

# Lab images grant the development key passwordless sudo. Release images keep
# the field security policy and require pi's password. Authenticate once without
# putting that password in argv; /etc/sudoers.d/aryaos uses a global timestamp,
# so the existing sudo -n assertions can then run unchanged over later SSH
# connections. Fail before staging tests if neither form of elevation works,
# instead of turning every privileged assertion into a misleading product fault.
SUDO_METHOD="noninteractive"
if ! "${SSH[@]}" "${PI}" "sudo -n true" >/dev/null 2>&1; then
	if [[ -z "${DEV_PASSWORD}" ]]; then
		echo "Cannot use noninteractive sudo on ${PI}; set ARYAOS_DEV_DEVICE_PASSWORD for a release image" >&2
		exit 2
	fi
	if ! printf '%s\n' "${DEV_PASSWORD}" \
		| "${SSH[@]}" "${PI}" "sudo -S -p '' -v" >/dev/null 2>&1; then
		echo "Cannot authenticate sudo on ${PI}" >&2
		exit 2
	fi
	if ! "${SSH[@]}" "${PI}" "sudo -n true" >/dev/null 2>&1; then
		echo "Authenticated sudo on ${PI} did not create a reusable noninteractive timestamp" >&2
		exit 2
	fi
	SUDO_METHOD="password credential cached"
fi

echo "==> AryaOS integration tests on ${PI} (tier=${ARYAOS_TEST_TIER:-default})"
echo "==> Profile: ${ARYAOS_TEST_PROFILE:-default}"
echo "==> SSH: using ${SSH_METHOD}"
echo "==> Sudo: ${SUDO_METHOD}"
if [[ -n "${EXPECTED_CAPABILITIES}" ]]; then
	echo "==> Required capabilities: ${EXPECTED_CAPABILITIES}"
fi

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
	"${SSH[@]}" "${PI}" "export ARYAOS_TEST_TIER='${ARYAOS_TEST_TIER:-default}'; export ARYAOS_TEST_PROFILE='${ARYAOS_TEST_PROFILE:-default}'; export ARYAOS_EXPECT_CAPABILITIES='${EXPECTED_CAPABILITIES}'; export ARYAOS_VALIDATE_PORTAL='${REMOTE_STAGE}/validate_portal.py'; bash '${REMOTE_STAGE}/tests/${name}'"
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
