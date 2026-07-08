#!/usr/bin/env bash
# Shared helpers for remote AryaOS integration tests.
# SPDX-License-Identifier: Apache-2.0

# Non-interactive SSH sessions get a PATH without sbin, hiding tools like
# sysctl and turning real checks into silent warns.
export PATH="${PATH}:/usr/sbin:/sbin"

ARYAOS_TEST_PASSED=0
ARYAOS_TEST_FAILED=0
ARYAOS_TEST_WARNED=0
ARYAOS_TEST_SKIPPED=0

ok() {
	echo "OK   $*"
	ARYAOS_TEST_PASSED=$((ARYAOS_TEST_PASSED + 1))
}

fail() {
	echo "FAIL $*" >&2
	ARYAOS_TEST_FAILED=$((ARYAOS_TEST_FAILED + 1))
}

warn() {
	echo "WARN $*"
	ARYAOS_TEST_WARNED=$((ARYAOS_TEST_WARNED + 1))
}

skip() {
	echo "SKIP $*"
	ARYAOS_TEST_SKIPPED=$((ARYAOS_TEST_SKIPPED + 1))
}

unit_loaded() {
	local unit="$1.service"
	systemctl show "${unit}" -p LoadState --value 2>/dev/null | grep -qx loaded
}

unit_active() {
	systemctl is-active --quiet "$1"
}

test_profile() {
	[[ "${ARYAOS_TEST_PROFILE:-default}" == "$1" ]]
}

print_summary() {
	echo "---"
	echo "passed=${ARYAOS_TEST_PASSED} failed=${ARYAOS_TEST_FAILED} warned=${ARYAOS_TEST_WARNED} skipped=${ARYAOS_TEST_SKIPPED}"
	if [[ "${ARYAOS_TEST_FAILED}" -gt 0 ]]; then
		return 1
	fi
	return 0
}
