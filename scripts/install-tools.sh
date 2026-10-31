#!/usr/bin/env bash
# Installs apko and melange from their GitHub releases (open source, Apache License 2.0), not
# from a container registry.
#
#   scripts/install-tools.sh <bin-dir> <tool>...       # tools: apko, melange
#
# Each download is checked against the release's checksums.txt, and checksums.txt itself is
# verified with cosign: it must be signed keyless by that project's own release workflow on
# GitHub. Needs curl, sha256sum and cosign.
set -euo pipefail

# renovate: datasource=github-releases depName=chainguard-dev/apko
APKO_VERSION=1.4.14
# renovate: datasource=github-releases depName=chainguard-dev/melange
MELANGE_VERSION=0.63.2

bin="$1"; shift
mkdir -p "$bin"
case "$(uname -m)" in
  x86_64) arch=amd64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *) echo "unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac

for tool in "$@"; do
  case "$tool" in
    apko) version="$APKO_VERSION" ;;
    melange) version="$MELANGE_VERSION" ;;
    *) echo "unknown tool $tool" >&2; exit 1 ;;
  esac
  base="https://github.com/chainguard-dev/$tool/releases/download/v$version"
  archive="${tool}_${version}_linux_${arch}.tar.gz"
  work="$(mktemp -d)"
  for f in "$archive" checksums.txt checksums.txt.sig checksums.txt.crt; do
    curl -fsSL --retry 3 -o "$work/$f" "$base/$f"
  done
  cosign verify-blob "$work/checksums.txt" \
    --certificate "$work/checksums.txt.crt" --signature "$work/checksums.txt.sig" \
    --certificate-identity-regexp "^https://github.com/chainguard-dev/$tool/" \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
  (cd "$work" && grep " $archive\$" checksums.txt | sha256sum -c -)
  tar -xzf "$work/$archive" -C "$work"
  install -m 0755 "$work/${tool}_${version}_linux_${arch}/$tool" "$bin/$tool"
  rm -rf "$work"
  "$bin/$tool" version 2>&1 | grep -m1 GitVersion
done
