#!/usr/bin/env bash
# Shared target and credential resolution for AryaOS development tooling.

aryaos_dev_warn_legacy() {
	local old_name="$1"
	local new_name="$2"
	if [[ -n "${!old_name:-}" ]]; then
		echo "warning: ${old_name} is deprecated; use ${new_name}" >&2
	fi
}

aryaos_dev_user() {
	if [[ -n "${ARYAOS_DEV_DEVICE_USER:-}" ]]; then
		printf '%s\n' "${ARYAOS_DEV_DEVICE_USER}"
	elif [[ -n "${ARYAOS_DEV_PI_USER:-}" ]]; then
		aryaos_dev_warn_legacy ARYAOS_DEV_PI_USER ARYAOS_DEV_DEVICE_USER
		printf '%s\n' "${ARYAOS_DEV_PI_USER}"
	else
		printf '%s\n' pi
	fi
}

aryaos_dev_key() {
	local repo_root="$1"
	if [[ -n "${ARYAOS_DEV_DEVICE_SSH_KEY:-}" ]]; then
		printf '%s\n' "${ARYAOS_DEV_DEVICE_SSH_KEY}"
	elif [[ -n "${ARYAOS_DEV_PI_SSH_KEY:-}" ]]; then
		aryaos_dev_warn_legacy ARYAOS_DEV_PI_SSH_KEY ARYAOS_DEV_DEVICE_SSH_KEY
		printf '%s\n' "${ARYAOS_DEV_PI_SSH_KEY}"
	else
		printf '%s\n' "${repo_root}/shared_files/aryaos/ssh/aryaos-dev-lab"
	fi
}

aryaos_dev_password() {
	if [[ -n "${ARYAOS_DEV_DEVICE_PASSWORD:-}" ]]; then
		printf '%s\n' "${ARYAOS_DEV_DEVICE_PASSWORD}"
	elif [[ -n "${ARYAOS_DEV_PI_PASSWORD:-}" ]]; then
		aryaos_dev_warn_legacy ARYAOS_DEV_PI_PASSWORD ARYAOS_DEV_DEVICE_PASSWORD
		printf '%s\n' "${ARYAOS_DEV_PI_PASSWORD}"
	fi
}

aryaos_dev_target() {
	local repo_root="$1"
	local explicit="${2:-${ARYAOS_SSH:-}}"
	local user host
	user="$(aryaos_dev_user)"
	if [[ -n "${explicit}" ]]; then
		host="${explicit}"
	elif [[ -n "${ARYAOS_DEV_PI_HOST:-}" ]]; then
		aryaos_dev_warn_legacy ARYAOS_DEV_PI_HOST 'ARYAOS_SSH or ARYAOS_DEV_DEVICE'
		host="${ARYAOS_DEV_PI_HOST}"
	else
		host="$("${repo_root}/scripts/aryaos-dev-device" resolve "${ARYAOS_DEV_DEVICE:-}")"
	fi
	if [[ "${host}" == *@* ]]; then
		printf '%s\n' "${host}"
	else
		printf '%s@%s\n' "${user}" "${host}"
	fi
}
