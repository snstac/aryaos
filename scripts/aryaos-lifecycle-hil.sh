#!/usr/bin/env bash
# Destructive lab-only backup/restore, enrollment, and factory-reset HIL.
# Enrollment credentials are read from stdin and are never printed or passed in argv.
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY="${ARYAOS_DEV_PI_SSH_KEY:-${ROOT}/shared_files/aryaos/ssh/aryaos-dev-lab}"
USER_NAME="${ARYAOS_DEV_PI_USER:-pi}"
OUTPUT=""
RESET_HOST=""
ENROLL_STDIN=0
HOSTS=()

usage() {
	cat <<'EOF'
Usage: aryaos-lifecycle-hil.sh --hosts HOST... [options]

Options:
  --enroll-stdin       Read one tak:// enrollment URL from stdin, test it on
                       every host, then restore each host's original TAK state.
  --factory-reset HOST Factory-reset one host with networking retained, then
                       restore its encrypted off-host backup and reboot.
  --output DIR         Evidence directory (default .aryaos-lifecycle/<UTC>).
EOF
}

while (($#)); do
	case "$1" in
		--hosts)
			shift
			while (($#)) && [[ "$1" != --* ]]; do HOSTS+=("$1"); shift; done
			;;
		--enroll-stdin) ENROLL_STDIN=1; shift ;;
		--factory-reset) RESET_HOST="${2:-}"; shift 2 ;;
		--output) OUTPUT="${2:-}"; shift 2 ;;
		-h|--help) usage; exit 0 ;;
		*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
	esac
done

if ((${#HOSTS[@]} == 0)); then
	echo "at least one --hosts value is required" >&2
	exit 2
fi
if [[ -n "${RESET_HOST}" && ! " ${HOSTS[*]} " =~ [[:space:]]${RESET_HOST}[[:space:]] ]]; then
	echo "--factory-reset host must also be in --hosts" >&2
	exit 2
fi
if [[ ! -r "${KEY}" ]]; then
	echo "lab SSH key is not readable: ${KEY}" >&2
	exit 2
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTPUT="${OUTPUT:-${ROOT}/.aryaos-lifecycle/${STAMP}}"
umask 077
mkdir -p "${OUTPUT}"
PASS_FILE="$(mktemp /dev/shm/aryaos-lifecycle-pass.XXXXXX)"
openssl rand -base64 48 >"${PASS_FILE}"
ENROLLMENT_URL=""
SENSITIVE_FILES=()
ACTIVE_ENROLL_HOST=""
cleanup() {
	local rc=$?
	local path
	trap - EXIT
	set +e
	if [[ -n "${ACTIVE_ENROLL_HOST}" && -n "${FULL_REMOTE[${ACTIVE_ENROLL_HOST}]:-}" ]]; then
		echo "${ACTIVE_ENROLL_HOST}: recovering prior state after interrupted enrollment test" >&2
		remote "${ACTIVE_ENROLL_HOST}" "sudo -n sh -c 'for d in /etc/aryaos/tls /etc/cotbridge/tls /etc/adsbcot/tls /etc/aiscot/tls /etc/dronecot/tls /etc/lincot/tls; do [ ! -d \"\$d\" ] || find \"\$d\" -type f -delete; done'" >/dev/null 2>&1
		remote "${ACTIVE_ENROLL_HOST}" "sudo -n aryaos-config-backup restore '${FULL_REMOTE[${ACTIVE_ENROLL_HOST}]}' --service" >/dev/null 2>&1
	fi
	for path in "${SENSITIVE_FILES[@]}"; do
		[[ ! -f "${path}" ]] || shred -u "${path}" 2>/dev/null || rm -f "${path}"
	done
	shred -u "${PASS_FILE}" 2>/dev/null || rm -f "${PASS_FILE}"
	ENROLLMENT_URL=""
	exit "${rc}"
}
trap cleanup EXIT

if [[ "${ENROLL_STDIN}" == 1 ]]; then
	IFS= read -r -s ENROLLMENT_URL || true
	if [[ "${ENROLLMENT_URL}" != tak://com.atakmap.app/enroll\?* ]]; then
		echo "stdin did not contain a valid TAK enrollment deep link" >&2
		exit 2
	fi
fi

SSH=(ssh -i "${KEY}" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new)
SCP=(scp -i "${KEY}" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new)

remote() {
	local host="$1"
	shift
	"${SSH[@]}" "${USER_NAME}@${host}" "$@"
}

wait_for_ssh() {
	local host="$1" deadline=$((SECONDS + 900))
	while ((SECONDS < deadline)); do
		if remote "${host}" true >/dev/null 2>&1; then return 0; fi
		sleep 5
	done
	echo "${host}: SSH did not recover within 15 minutes" >&2
	return 1
}

config_digest() {
	local host="$1"
	remote "${host}" "sudo -n sh -c 'for p in /etc/aryaos /etc/cotbridge.ini /etc/cotbridge /etc/default/*cot* /etc/default/acarsdec; do [ ! -e \"\$p\" ] || find \"\$p\" -type f -print0; done | sort -z | xargs -0 sha256sum'" \
		| sha256sum | awk '{print $1}'
}

copy_root_file() {
	local host="$1" source="$2" destination="$3"
	remote "${host}" "sudo -n cat '$source'" >"${destination}"
	chmod 0600 "${destination}"
}

encrypt_and_remove() {
	local source="$1" destination="$2"
	openssl enc -aes-256-cbc -salt -pbkdf2 -in "${source}" -out "${destination}" -pass "file:${PASS_FILE}"
	shred -u "${source}" 2>/dev/null || rm -f "${source}"
}

decrypt_backup() {
	local source="$1" destination="$2"
	openssl enc -d -aes-256-cbc -pbkdf2 -in "${source}" -out "${destination}" -pass "file:${PASS_FILE}"
	chmod 0600 "${destination}"
}

declare -A FULL_REMOTE FULL_ENCRYPTED PRE_DIGEST CERT_FINGERPRINT

for host in "${HOSTS[@]}"; do
	echo "==> ${host}: backup and restore round trip"
	host_dir="${OUTPUT}/${host}"
	mkdir -p "${host_dir}"
	remote "${host}" "hostname; cat /etc/aryaos-version; cat /etc/machine-id; cat /proc/sys/kernel/random/boot_id; sed -n 's/^ARYAOS_CAPABILITIES=//p' /etc/aryaos/aryaos-config.txt" \
		>"${host_dir}/identity-before.txt"
	PRE_DIGEST["${host}"]="$(config_digest "${host}")"
	printf '%s\n' "${PRE_DIGEST[${host}]}" >"${host_dir}/config-before.sha256"

	full_path="$(remote "${host}" "sudo -n aryaos-config-backup backup" | tail -n 1)"
	share_path="$(remote "${host}" "sudo -n aryaos-config-backup backup --no-secrets" | tail -n 1)"
	[[ "${full_path}" == /var/lib/aryaos/backups/*.tar.gz && "${share_path}" == /var/lib/aryaos/backups/*.tar.gz ]]
	FULL_REMOTE["${host}"]="${full_path}"

	remote "${host}" "sudo -n tar -tzf '${full_path}'" >"${host_dir}/full-manifest.txt"
	remote "${host}" "sudo -n tar -tzf '${share_path}'" >"${host_dir}/no-secrets-manifest.txt"
	grep -q '/MANIFEST.txt$' "${host_dir}/full-manifest.txt"
	grep -qE '(^|/)etc/aryaos/aryaos-config.txt$' "${host_dir}/full-manifest.txt"
	if grep -qE '(^|/)etc/(aryaos|cotbridge|adsbcot|aiscot|dronecot|lincot)/tls/' "${host_dir}/no-secrets-manifest.txt"; then
		echo "${host}: no-secrets archive contains TAK TLS material" >&2
		exit 1
	fi

	plain="${host_dir}/full-backup.tar.gz"
	cipher="${plain}.enc"
	SENSITIVE_FILES+=("${plain}" "${cipher}")
	copy_root_file "${host}" "${full_path}" "${plain}"
	sha256sum "${plain}" >"${host_dir}/full-backup.sha256"
	encrypt_and_remove "${plain}" "${cipher}"
	FULL_ENCRYPTED["${host}"]="${cipher}"

	sentinel="HIL_RESTORE_SENTINEL=${STAMP}-${host//./-}"
	remote "${host}" "printf '\n# %s\n' '${sentinel}' | sudo -n tee -a /etc/aryaos/aryaos-config.txt >/dev/null"
	remote "${host}" "sudo -n aryaos-config-backup restore '${full_path}' --service"
	post_digest="$(config_digest "${host}")"
	printf '%s\n' "${post_digest}" >"${host_dir}/config-after-restore.sha256"
	if [[ "${post_digest}" != "${PRE_DIGEST[${host}]}" ]]; then
		echo "${host}: configuration digest differs after restore" >&2
		exit 1
	fi
	if remote "${host}" "grep -Fq '${sentinel}' /etc/aryaos/aryaos-config.txt"; then
		echo "${host}: restore sentinel remained after restore" >&2
		exit 1
	fi
done

if [[ "${ENROLL_STDIN}" == 1 ]]; then
	for host in "${HOSTS[@]}"; do
		echo "==> ${host}: enrollment, redaction, and prior-state restore"
		host_dir="${OUTPUT}/${host}"
		ACTIVE_ENROLL_HOST="${host}"
		# printf is a shell builtin; the secret crosses only stdin and is absent
		# from both local and remote process argument lists.
		printf '%s' "${ENROLLMENT_URL}" | remote "${host}" "sudo -n aryaos-tak-dp-import --enroll-stdin" \
			>"${host_dir}/enrollment-result.json"
		python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); assert data.get("ok") and str(data.get("cot_url", "")).startswith("tls://")' \
			"${host_dir}/enrollment-result.json"
		remote "${host}" "sudo -n aryaos-tak-dp-import --status" >"${host_dir}/enrollment-status.json"
		python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); assert data["enrollment_status"]["configured"]' \
			"${host_dir}/enrollment-status.json"
		deadline=$((SECONDS + 60))
		while ((SECONDS < deadline)); do
			if remote "${host}" "sudo -n python3 -c 'import json; d=json.load(open(\"/run/cotbridge/status.json\")); lane=d.get(\"lanes\",{}).get(\"site-output\",{}).get(\"output\",{}); assert d.get(\"health\",{}).get(\"state\")==\"ok\" and lane.get(\"state\")==\"connected\"'" >/dev/null 2>&1; then
				break
			fi
			sleep 2
		done
		remote "${host}" "sudo -n python3 -c 'import json; d=json.load(open(\"/run/cotbridge/status.json\")); lane=d.get(\"lanes\",{}).get(\"site-output\",{}).get(\"output\",{}); assert d.get(\"health\",{}).get(\"state\")==\"ok\" and lane.get(\"state\")==\"connected\"'"
		CERT_FINGERPRINT["${host}"]="$(remote "${host}" "sudo -n openssl x509 -in /etc/aryaos/tls/client.pem -noout -fingerprint -sha256" | sed 's/.*=//')"
		printf '%s\n' "${CERT_FINGERPRINT[${host}]}" >"${host_dir}/enrollment-cert-fingerprint.txt"

		bundle_path="$(remote "${host}" "sudo -n aryaos-support-bundle" | tail -n 1)"
		bundle="${host_dir}/support-bundle.tar.gz"
		copy_root_file "${host}" "${bundle_path}" "${bundle}"
		printf '%s' "${ENROLLMENT_URL}" | python3 -c '
import sys, tarfile
secret = sys.stdin.buffer.read()
with tarfile.open(sys.argv[1], "r:gz") as archive:
    for member in archive.getmembers():
        if member.isfile():
            stream = archive.extractfile(member)
            if stream and secret and secret in stream.read():
                raise SystemExit(f"enrollment credential leaked into {member.name}")
' "${bundle}"
		rm -f "${bundle}"

		remote "${host}" "sudo -n sh -c 'for d in /etc/aryaos/tls /etc/cotbridge/tls /etc/adsbcot/tls /etc/aiscot/tls /etc/dronecot/tls /etc/lincot/tls; do [ ! -d \"\$d\" ] || find \"\$d\" -type f -delete; done'"
		remote "${host}" "sudo -n aryaos-config-backup restore '${FULL_REMOTE[${host}]}' --service"
		post_digest="$(config_digest "${host}")"
		if [[ "${post_digest}" != "${PRE_DIGEST[${host}]}" ]]; then
			echo "${host}: prior configuration was not recovered after enrollment" >&2
			exit 1
		fi
		ACTIVE_ENROLL_HOST=""
	done
	if [[ "$(printf '%s\n' "${CERT_FINGERPRINT[@]}" | sort -u | wc -l)" -ne "${#HOSTS[@]}" ]]; then
		echo "enrollment did not issue a unique client certificate to every host" >&2
		exit 1
	fi
fi

if [[ -n "${RESET_HOST}" ]]; then
	echo "==> ${RESET_HOST}: factory reset with network retained"
	host_dir="${OUTPUT}/${RESET_HOST}"
	before_hostname="$(head -n 1 "${host_dir}/identity-before.txt")"
	remote "${RESET_HOST}" "sudo -n aryaos-factory-reset --service" >/dev/null 2>&1 || true
	sleep 10
	wait_for_ssh "${RESET_HOST}"
	deadline=$((SECONDS + 600))
	while ((SECONDS < deadline)); do
		if remote "${RESET_HOST}" "test -f /etc/aryaos/.capabilities-autodetected && systemctl is-active --quiet aryaos-firstboot.service" >/dev/null 2>&1; then break; fi
		sleep 5
	done
	remote "${RESET_HOST}" "hostname; cat /etc/aryaos-version; cat /etc/machine-id; cat /proc/sys/kernel/random/boot_id; sed -n 's/^ARYAOS_CAPABILITIES=//p' /etc/aryaos/aryaos-config.txt" \
		>"${host_dir}/identity-after-reset.txt"
	after_hostname="$(head -n 1 "${host_dir}/identity-after-reset.txt")"
	if [[ "${after_hostname}" == "${before_hostname}" || "${after_hostname}" == "aryaos" ]]; then
		echo "${RESET_HOST}: factory reset did not regenerate a device hostname" >&2
		exit 1
	fi
	plain="${host_dir}/factory-restore.tar.gz"
	decrypt_backup "${FULL_ENCRYPTED[${RESET_HOST}]}" "${plain}"
	remote_tmp="/tmp/aryaos-lifecycle-${STAMP}.tar.gz"
	"${SCP[@]}" "${plain}" "${USER_NAME}@${RESET_HOST}:${remote_tmp}"
	remote "${RESET_HOST}" "sudo -n install -m 0600 '${remote_tmp}' /var/lib/aryaos/backups/lifecycle-restore.tar.gz && rm -f '${remote_tmp}' && sudo -n aryaos-config-backup restore /var/lib/aryaos/backups/lifecycle-restore.tar.gz --service && sudo -n systemctl --no-block reboot"
	shred -u "${plain}" 2>/dev/null || rm -f "${plain}"
	sleep 10
	wait_for_ssh "${RESET_HOST}"
	post_digest="$(config_digest "${RESET_HOST}")"
	if [[ "${post_digest}" != "${PRE_DIGEST[${RESET_HOST}]}" ]]; then
		echo "${RESET_HOST}: configuration digest differs after factory-reset restore" >&2
		exit 1
	fi
fi

for host in "${HOSTS[@]}"; do
	rm -f "${FULL_ENCRYPTED[${host}]}"
done
echo "Lifecycle HIL passed; redacted evidence: ${OUTPUT}"
