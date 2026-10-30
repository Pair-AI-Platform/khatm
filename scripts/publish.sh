#!/usr/bin/env bash
# Pushes the built packages as one multi-platform OCI artifact.
#
#   scripts/publish.sh <repository> <tag> <dist-dir>
#
# <dist-dir> holds one APK repository per architecture (<arch>/APKINDEX.tar.gz and <arch>/*.apk)
# and the public keys the packages are signed with (*.rsa.pub), which go into every manifest.
# Each architecture becomes a manifest with its platform set, and <tag> points at an image index
# over them, so `oras pull --platform` fetches one architecture. The platform manifests are pushed untagged: <tag> is the only tag.
#
# Prints the index digest. Set PLAIN_HTTP=1 for a local registry without TLS.
set -euo pipefail

repo="$1"
tag="$2"
dist="$(cd "$3" && pwd)"
layout="$(mktemp -d)"
trap 'rm -rf "$layout"' EXIT

ARTIFACT_TYPE="application/vnd.wolfi.apk.repository.v1"

declare -A platform=([x86_64]=linux/amd64 [aarch64]=linux/arm64)
keys=()
for k in "$dist"/*.rsa.pub; do
  keys+=("$(basename "$k"):application/vnd.wolfi.apk.key.v1")
done

sources=()
for arch in x86_64 aarch64; do
  [ -d "$dist/$arch" ] || continue
  files=("${keys[@]}")
  for f in "$dist/$arch"/*.apk; do
    files+=("$arch/$(basename "$f"):application/vnd.wolfi.apk")
  done
  files+=("$arch/APKINDEX.tar.gz:application/vnd.wolfi.apk.index.v1+gzip")
  (cd "$dist" && oras push --oci-layout "$layout:$arch" \
    --artifact-type "$ARTIFACT_TYPE" \
    --artifact-platform "${platform[$arch]}" \
    --annotation "org.opencontainers.image.version=$tag" \
    "${files[@]}" >&2)
  sources+=("$arch")
done

if [ "${#sources[@]}" -eq 0 ]; then
  echo "no packages in $dist" >&2
  exit 1
fi

oras manifest index create --oci-layout "$layout:$tag" "${sources[@]}" \
  --annotation "org.opencontainers.image.version=$tag" >&2

# Copies the index and its platform manifests; only <tag> is created in the registry
oras cp ${PLAIN_HTTP:+--to-plain-http} --from-oci-layout "$layout:$tag" "$repo:$tag" >&2
oras resolve ${PLAIN_HTTP:+--plain-http} "$repo:$tag"
