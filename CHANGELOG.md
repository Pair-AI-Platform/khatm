# Changelog

Every release of `ghcr.io/pair-ai-platform/openssl-provider-fips` has an entry here, newest first. The
tag is `<version>-r<epoch>`. A released tag is never rebuilt or moved; only `latest` moves.
Renovate writes the entries for its updates with `scripts/bump-epoch.sh`. The GHCR package keeps
the five newest versions, and the GitHub release for each tag has the same notes.
<!-- releases -->

## 3.1.2-r2 (2026-10-31)

Rebuilt with updated Wolfi packages. The FIPS module itself (OpenSSL FIPS Provider 3.1.2,
CMVP #4985) is built from the same validated source.

| Package | From | To |
| :--- | :--- | :--- |
| `melange (image)` | sha256:b17c529b3473 | sha256:c6eea71bf274 |

## 3.1.2-r1 (2026-10-30)

Rebuilt with updated Wolfi packages. The FIPS module itself (OpenSSL FIPS Provider 3.1.2,
CMVP #4985) is built from the same validated source.

| Package | From | To |
| :--- | :--- | :--- |
| `linux-headers` | 7.3-r0 | 7.3.1-r0 |

## 3.1.2-r0 (2026-10-30)

First release.

- OpenSSL FIPS Provider 3.1.2 (FIPS 140-3, CMVP #4985), built by its security policy, for x86_64
  and aarch64: `openssl-provider-fips-3.1.2`, `openssl-config-fipshardened` (compatible TLS
  policy) and `openssl-config-fips-strict` (NCA NCS-1:2020 MODERATE TLS policy).
- Published as a multi-platform OCI artifact, signed keyless with Sigstore, with SPDX SBOMs and
  SLSA Build L3 provenance attached as OCI 1.1 referrers.
