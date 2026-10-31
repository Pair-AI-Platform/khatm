#!/usr/bin/env bash
# Writes the cryptographic inventory of the packages: for each configuration package, what OpenSSL
# actually allows once it is installed, read from a running OpenSSL rather than from the files.
#
#   scripts/crypto-inventory.sh <packages-dir> <public-key> <arch> <out.json>
#
# <packages-dir> is the APK repository built by melange (<arch>/APKINDEX.tar.gz), signed with
# <public-key>. For openssl-config-fipshardened and openssl-config-fips-strict, a small image with
# Wolfi's OpenSSL and that configuration is built with apko and asked for its providers, TLS 1.2
# and TLS 1.3 cipher suites, minimum protocol, key-exchange groups and signature algorithms. The
# result feeds a cryptographic asset inventory (SAMA circular 482021280, CBK CORF 7.1.4.3).
set -euo pipefail

packages="$(cd "$1" && pwd)"
key="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
arch="$3"
out="$4"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

module_version="$(awk -F'"' '/^  version:/ {print $2; exit}' melange/openssl-provider-fips-3.1.2.yaml)"
module_epoch="$(awk '/^  epoch:/ {print $2; exit}' melange/openssl-provider-fips-3.1.2.yaml)"

profiles=()
for config in openssl-config-fipshardened openssl-config-fips-strict; do
  cat > "$work/$config.yaml" <<EOF
contents:
  keyring:
    - https://packages.wolfi.dev/os/wolfi-signing.rsa.pub
  repositories:
    - https://packages.wolfi.dev/os
  packages:
    - wolfi-baselayout
    - busybox
    - openssl-3.6
    - $config
archs:
  - $arch
EOF
  apko build "$work/$config.yaml" "inventory:$config" "$work/$config.tar" --arch "$arch" \
    --sbom=false -b "$packages" -k "$key" >/dev/null 2>&1
  ref="$(docker load -i "$work/$config.tar" | sed -n 's/^Loaded image: //p')"
  conf=/etc/ssl/openssl.cnf
  docker run --rm --entrypoint sh "$ref" -c "
    openssl version | sed 's/^/version=/'
    openssl list -providers | awk '/^  [a-z]/ {p=\$1} /name:/ {sub(/^ *name: /, \"\"); n=\$0} /version:/ {print \"provider=\" p \"|\" n \"|\" \$2}'
    echo tls12=\$(openssl ciphers -s -tls1_2)
    echo tls13=\$(openssl ciphers -s -tls1_3)
    sed -n 's/^MinProtocol *= *//p;' $conf | sed 's/^/min_protocol=/'
    sed -n 's/^Groups *= *//p;' $conf | sed 's/^/groups=/'
    sed -n 's/^SignatureAlgorithms *= *//p;' $conf | sed 's/^/signature_algorithms=/'
    sed -n 's/^CipherString *= *.*@SECLEVEL=\([0-9]\).*/\1/p' $conf | sed 's/^/security_level=/'
  " > "$work/$config.txt"
  docker image rm "$ref" >/dev/null
  profiles+=("$config")
done

python3 - "$work" "$out" "$arch" "$module_version-r$module_epoch" "${profiles[@]}" <<'PY'
import json, pathlib, sys
work, out, arch, release, *profiles = sys.argv[1:]
inventory = {
    "module": {"name": "OpenSSL FIPS Provider", "version": "3.1.2", "cmvp_certificate": 4985,
               "fips": "140-3", "package_release": release},
    "architecture": arch,
    "configurations": {},
}
for profile in profiles:
    entry = {"providers": []}
    for line in (pathlib.Path(work) / f"{profile}.txt").read_text().splitlines():
        key, _, value = line.partition("=")
        if key == "provider":
            pid, name, version = value.split("|")
            entry["providers"].append({"id": pid, "name": name, "version": version})
        elif key in ("tls12", "tls13", "groups", "signature_algorithms"):
            entry[key] = [v for v in value.split(":") if v]
        elif key == "security_level":
            entry[key] = int(value)
        else:
            entry[key] = value
    inventory["configurations"][profile] = entry
pathlib.Path(out).write_text(json.dumps(inventory, indent=2) + "\n")
print(json.dumps({p: {k: (len(v) if isinstance(v, list) else v) for k, v in e.items()}
                  for p, e in inventory["configurations"].items()}, indent=1))
PY
