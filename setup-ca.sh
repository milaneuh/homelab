#!/bin/bash
set -euo pipefail

prog="${0##*/}"

usage() {
	echo "usage: ${prog} root|intermediate" >&2
	exit 2
}

[ $# -eq 1 ] || usage

case "$1" in
	root|r)
		ca_name="root-ca"
		;;
	intermediate|i)
		ca_name="intermediate-ca"
		;;
	*)
		usage
		;;
esac

ca_dir="/var/lib/${ca_name}"
ca_user="${ca_name}"
ca_shell="/usr/sbin/nologin"

if [ "$(id -u)" -ne 0 ]; then
	echo "${prog}: must run as root" >&2
	exit 1
fi

if ! getent passwd "${ca_user}" >/dev/null; then
	useradd --system --no-create-home --home-dir "${ca_dir}" --shell "${ca_shell}" "${ca_user}"
fi

install -d -o "${ca_user}" -g "${ca_user}" -m 0755 "${ca_dir}"
install -d -o "${ca_user}" -g "${ca_user}" -m 0755 "${ca_dir}/certs"
install -d -o "${ca_user}" -g "${ca_user}" -m 0755 "${ca_dir}/newcerts"
install -d -o "${ca_user}" -g "${ca_user}" -m 0700 "${ca_dir}/private"

if [ "${ca_name}" = "intermediate-ca" ]; then
	install -d -o "${ca_user}" -g "${ca_user}" -m 0755 "${ca_dir}/csr"
fi

if [ ! -e "${ca_dir}/index.txt" ]; then
	install -o "${ca_user}" -g "${ca_user}" -m 0644 /dev/null "${ca_dir}/index.txt"
fi

echo "${ca_name} ready at ${ca_dir}, owned by ${ca_user}"
