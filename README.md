# Khatm: OpenSSL FIPS Provider for Wolfi

[![FIPS 140-3](https://img.shields.io/badge/FIPS%20140--3-CMVP%20%234985-blue?style=for-the-badge)](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4985)
[![SLSA Build L3](https://img.shields.io/badge/SLSA-Build%20L3-orange?style=for-the-badge)](#slsa-build-level-3)
[![Signed with Sigstore](https://img.shields.io/badge/signed-Sigstore%20keyless-purple?style=for-the-badge)](#verify)

Wolfi APK packages of the **OpenSSL FIPS Provider 3.1.2**, the FIPS 140-3 validated module with
[CMVP certificate #4985](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4985),
plus the system configuration that puts OpenSSL in the approved mode. They are built with
[melange](https://github.com/chainguard-dev/melange) for `x86_64` and `aarch64`.

Each release is published to GHCR as a signed multi-platform OCI artifact. Its signatures, SBOMs
and SLSA Build Level 3 provenance are attached as OCI 1.1 referrers. Renovate keeps the Wolfi build
environment current, and every update becomes a new release automatically.

Every release publishes three packages, for `x86_64` and `aarch64`. Install the provider with
**one** of the two configurations:

| Package | What it is | Aligned with |
| :--- | :--- | :--- |
| `openssl-provider-fips-3.1.2` | The validated module: `/usr/lib/ossl-modules/fips.so` and `/etc/ssl/fipsmodule.cnf` with its integrity MAC | FIPS 140-3, [CMVP #4985](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4985) (Level 1, approved mode) |
| `openssl-config-fipshardened` | `/etc/ssl/openssl.cnf` for systems that also talk to the internet: only the FIPS and base providers (`fips=yes`), TLS 1.2+, AEAD suites with forward secrecy, no X25519/X448/Ed25519/Ed448, no SHA-1 signatures, DH from 3072 bits | 🇰🇼 CBK CORF §5.3.1.3(i), §8.1.4.5 · NBCC CLD-16 · 🇶🇦 QNCS v1.0 algorithms and TLS (Tables 1, 2, 5, 10) · 🇸🇦 NCA Cryptography Standard Template 1-3 · 🇧🇭 CBB OM Appendix C · 🇦🇪 IA Regulation v1.1 T7.4.1 |
| `openssl-config-fips-strict` | `/etc/ssl/openssl.cnf` for closed networks and national PKIs: everything above, plus RSA ≥ 3072 and EC ≥ 256 bits in every certificate chain, only `TLS_AES_256_GCM_SHA384` in TLS 1.3, only ECDHE-ECDSA AES-GCM/CCM in TLS 1.2, P-384/P-256 only, SHA-384 handshake signatures | Everything above, plus 🇸🇦 **NCA NCS-1:2020 MODERATE** for TLS (§2.2, §3.6.2, §3.8, §4.2, §5.1 key sizes), which ECC-2:2024 2-8-3 and DCC-1:2022 2-5-1-2 (Confidential data) require · 🇶🇦 QNCS RSA ≥ 3000 (Tables 4, 7) |

"Aligned with" covers the cryptographic part of each clause; the clause numbers, the links, what
we added for each, and what stays with the operator (HSMs, key management, post-quantum) are in
[Cryptography rules in Kuwait and the GCC](#cryptography-rules-in-kuwait-and-the-gcc).

> **Not affiliated.** This project is not affiliated with or endorsed by the OpenSSL Project or
> OpenSSL Foundation, NIST, Chainguard or any regulator named below. "OpenSSL" is a trademark of
> its owners and is used here only to name the software these packages contain. OpenSSL is
> licensed under the Apache License 2.0; the provider package ships its `LICENSE.txt` under
> `/usr/share/licenses/`.

> **Certification.** Cryptography is provided by the OpenSSL FIPS Provider 3.1.2, a FIPS 140-3
> validated module ([CMVP #4985](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4985)),
> running in its approved mode. The certificate covers the module; how it is built and run here
> is described in [What the certificate covers](#what-the-certificate-covers).

---

## Use it

The artifact is `ghcr.io/pair-ai-platform/openssl-provider-fips:<tag>`. Pulling one platform gives an
APK repository (`<arch>/APKINDEX.tar.gz` and the `.apk` files) and the public key the packages
are signed with.

```sh
oras pull ghcr.io/pair-ai-platform/openssl-provider-fips:latest --platform linux/amd64 -o fips
# fips/khatm.rsa.pub  fips/x86_64/APKINDEX.tar.gz  fips/x86_64/*.apk

cp fips/*.rsa.pub /etc/apk/keys/
apk add --repository "$PWD/fips" openssl openssl-config-fipshardened
openssl list -providers          # OpenSSL FIPS Provider 3.1.2, status: active
openssl dgst -md5 /etc/os-release  # refused
```

`openssl-config-fipshardened` pulls in the provider and takes over `/etc/ssl/openssl.cnf` from
Wolfi's libcrypto, so every program that uses the system OpenSSL runs in the approved mode. To load
the module through your own configuration instead, install only `openssl-provider-fips-3.1.2`.

Install **one** of the two configuration packages, since both own `/etc/ssl/openssl.cnf`:

| Use | Package | Trade-off |
| :--- | :--- | :--- |
| Services that also talk to the internet | `openssl-config-fipshardened` | Public servers with RSA-2048 and SHA-256 chains keep working |
| Government, banking and national-PKI systems where NCA NCS-1 applies | `openssl-config-fips-strict` | Servers with an RSA-2048 key anywhere in their chain (most public websites) are refused; TLS 1.3 needs P-384 or RSA-PSS certificates |

In a Dockerfile:

```dockerfile
# Your Wolfi-based image with apk, for example one built with apko
ARG BASE_IMAGE

FROM ghcr.io/oras-project/oras:v1.3.6 AS fips
ARG TAG=latest
ARG TARGETARCH
RUN oras pull ghcr.io/pair-ai-platform/openssl-provider-fips:${TAG} --platform linux/${TARGETARCH} -o /fips

FROM ${BASE_IMAGE}
COPY --from=fips /fips /tmp/fips
RUN cp /tmp/fips/*.rsa.pub /etc/apk/keys/ && \
    apk add --no-cache --repository /tmp/fips openssl openssl-config-fipshardened && \
    rm -rf /tmp/fips && \
    openssl list -providers
```

With apko, pull the artifact first and add it as a build repository:
`apko build ... -b ./fips -k ./fips/khatm.rsa.pub`.

---

## Verify

Every release carries this evidence, all discoverable with `oras discover`:

| Evidence | Attached to | Verify with |
| :--- | :--- | :--- |
| Sigstore signature (keyless, logged in Rekor) | the index and each platform manifest | `cosign verify` |
| SPDX SBOM of each package | each platform manifest | `cosign verify-attestation --type spdxjson` |
| Cryptographic inventory (what each configuration allows) | each platform manifest, and the GitHub release | `cosign verify-attestation --type https://github.com/Pair-AI-Platform/khatm/attestations/crypto-inventory/v1` |
| SLSA v1 build provenance | the index, and each `.apk` file | `gh attestation verify` |

```sh
IMAGE=ghcr.io/pair-ai-platform/openssl-provider-fips:3.1.2-r0
REPO=Pair-AI-Platform/khatm
WORKFLOW="$REPO/.github/workflows/build.yml"

# Signature: made by this repository's build workflow, nothing else
cosign verify "$IMAGE" \
  --certificate-identity-regexp "^https://github.com/$WORKFLOW@" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

# SLSA provenance, bound to the build workflow
gh attestation verify "oci://$IMAGE" --repo "$REPO" --signer-workflow "$WORKFLOW"

# SBOM of one platform
cosign verify-attestation --type spdxjson "$IMAGE" --platform linux/arm64 \
  --certificate-identity-regexp "^https://github.com/$WORKFLOW@" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  | jq -r '.payload | @base64d | fromjson | .predicate.packages[].name'

# A downloaded package file
gh attestation verify fips/x86_64/openssl-provider-fips-3.1.2-3.1.2-r0.apk \
  --repo "$REPO" --signer-workflow "$WORKFLOW"

# Everything attached to a release
oras discover --format tree "$IMAGE"
```

The artifact is signed keyless: Sigstore Fulcio issues a short-lived certificate to the build
workflow's GitHub OIDC identity. The APK files themselves are signed with one fixed RSA key, whose
public half is [keys/khatm.rsa.pub](keys/khatm.rsa.pub) in this repository and also ships inside
every artifact. Check that the two match before trusting a download:

```sh
curl -fsSLO https://raw.githubusercontent.com/Pair-AI-Platform/khatm/main/keys/khatm.rsa.pub
cmp khatm.rsa.pub fips/khatm.rsa.pub
```

---

## Versions, tags and changelog

Only the **five newest versions** exist at any time, and every tag that exists is complete:

- **A version is tagged only when it is complete.** The artifact is pushed by digest, without a
  tag. It is signed, attested, and the signatures, SBOMs and provenance are verified; only then
  are the release tag (`<version>-r<epoch>`, for example `3.1.2-r4`) and `latest` created, in the
  last step. If a run fails before that, no tag exists and the untagged leftovers are deleted;
  re-running it publishes the version from the start.
- **Release tags are immutable.** An existing tag is never overwritten or rebuilt, and a pull
  request that changes the packages must bring a new epoch (`pr.yml` checks it). A tag always
  points to the same digest and the same evidence.
- **`latest` is the only tag that moves**, always to the newest verified version.
- **Five versions are kept.** After each release the five newest release tags stay in GHCR with
  their platform manifests and referrers; older versions, and anything untagged or orphaned, are
  deleted ([ghcr-cleanup-action](https://github.com/dataaxiom/ghcr-cleanup-action)). Only release
  tags are counted, so `latest` and the `sha256-…` referrer tags never push a version out. The
  GitHub releases and git tags follow the same rule. A version is published only when the packages
  change (a Renovate update or a manual change), so five versions usually cover a long period.
- **The evidence outlives the version.** The [CHANGELOG](CHANGELOG.md) keeps every version's
  changes in git, and the Sigstore transparency log (Rekor) permanently records every signature and
  attestation. To keep old versions themselves, mirror them with their referrers (`oras cp -r`).
- **[CHANGELOG.md](CHANGELOG.md)** has an entry for every version, listing each package that
  changed (from → to). The GitHub release of the tag carries the same notes.

---

## How updates flow

```
Wolfi publishes a fix (packages.wolfi.dev)
        │
        ▼
Renovate (.github/workflows/renovate.yml, hourly, after every check run and push, this repository only)
  • bumps the pinned packages in melange/*.yaml and the melange image, in one pull request
  • scripts/bump-epoch.sh: new epoch + CHANGELOG.md entry in the same pull request
        │
        ▼
pr.yml: build and test natively on x86_64 and aarch64, check new version + changelog
        │  all checks green
        ▼
Renovate automerges (squash)
        │
        ▼
release.yml → build.yml: build, test, push, sign, attest, verify, tag latest
           → GitHub release with the changelog entry
           → keep the five newest versions
```

| What | How it is kept current |
| :--- | :--- |
| Wolfi packages in the build and test environments | Renovate `apk` datasource on `https://packages.wolfi.dev/os`, pinned as `name=version`, one grouped PR, automerged |
| melange (from its GitHub release, version in `scripts/install-tools.sh`) | Renovate, same group |
| GitHub Actions, oras, cosign | Renovate, pinned to commit SHAs and versions, one grouped PR once a release is 3 days old, automerged |
| Major versions (for example OpenSSL 4 in the test environment) | Renovate opens the PR and leaves it for a human |
| The FIPS module itself (3.1.2, cert #4985) | Never automatic: changes only by hand, when NIST lists a new certificate |

Rebuilding the provider with a newer toolchain does not change the validated module. The source
tarball is pinned to the SHA-256 named in the security policy, and the build steps follow the
policy exactly.

---

## SLSA Build Level 3

| SLSA v1.0 Build L3 requirement | How it is met |
| :--- | :--- |
| Provenance exists and is complete | `actions/attest-build-provenance` records the source commit, the workflow, the inputs and the runner environment for the OCI index and every `.apk` file |
| Provenance is authentic | Signed through Sigstore with the build workflow's OIDC identity and logged in Rekor; the signature is checked again before `latest` moves |
| Hosted build platform | GitHub-hosted, ephemeral runners: `ubuntu-24.04` for x86_64, `ubuntu-24.04-arm` for aarch64, with no QEMU |
| Isolated builds, provenance not forgeable by the build | Building, signing and attesting all run inside the reusable workflow `.github/workflows/build.yml`. Its identity (`job_workflow_ref`) signs the provenance, and the calling workflow can only pass `publish: true/false`. `--signer-workflow` checks exactly that identity |

---

## What the certificate covers

- **The module and its build.** The CMVP validated the OpenSSL FIPS Provider 3.1.2.
  `melange/openssl-provider-fips-3.1.2.yaml` builds it as section 11.1 of the
  [security policy](https://csrc.nist.gov/CSRC/media/projects/cryptographic-module-validation-program/documents/security-policies/140sp4985.pdf)
  requires:
  - from the `openssl-3.1.2.tar.gz` with SHA-256
    `a0ce69b8b97ea6a35b96875235aa453b966ba3cba8af2de23657d8b6767d6539`;
  - with `./Configure enable-fips`, `make`, `make install_fips`, and no patches;
  - with `fipsmodule.cnf` written only by `openssl fipsinstall -pedantic`;
  - with `fips.so` never stripped.
- **Self tests.** The known-answer self tests and the integrity check run each time the module
  loads.
- **Tested operational environments.** The security policy (Table 3) lists Ubuntu 22.04 and
  Debian 11 (Intel i7-8550U), FreeBSD 13.1 and Windows 10 (Intel i7-10510U), and macOS 11 on Intel
  and on Apple M1, and states "No operational environments are vendor affirmed". Running the
  module on Wolfi is therefore a port to an operational environment that was not tested. The
  [CMVP FIPS 140-3 Management Manual](https://csrc.nist.gov/projects/cryptographic-module-validation-program)
  (v2.7, 4 September 2026) allows exactly this in §7.9.2: a user may perform post-validation
  porting of a Level 1 module to "any general-purpose platform/processor that supports the
  specified operating system… or another compatible operating system", and, per its footnote 5,
  recompile it "if the unmodified source code is available and the module's Security Policy
  provides specific guidance on acceptable recompilation methods", which is how khatm builds it.
  The CMVP makes no statement about correct operation there; the operator affirms that the module
  is used unchanged. That applies to `x86_64`, and more strongly to `aarch64`, because Linux
  on ARM is not among the tested environments.
- **Status.** #4985 is a FIPS 140-3 certificate: Active, sunset date 10 March 2030, overall
  Level 1, caveat "When operated in approved mode". It is the only active certificate of the
  OpenSSL Project: the FIPS 140-2 certificates of the 3.0 providers (#4282, #4811) are on the
  Historical list since the FIPS 140-2 sunset of 21 September 2026
  ([NIST transition page](https://csrc.nist.gov/projects/fips-140-3-transition-effort)). A new
  OpenSSL FIPS Provider submission is on the CMVP "Modules In Process" list with status "Comment
  Resolution - CMVP" (21 October 2026); no certificate has been issued for it yet. The
  current status is always on the
  [certificate page](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4985).
- **Legacy provider.** Wolfi's libcrypto depends on `openssl-provider-legacy-allowed`, which
  installs `legacy.so`. The FIPS configuration does not load it, but an application can still load
  a provider explicitly. Audit your applications for that.

The package tests run on both architectures for every pull request and every release. They check:

| Approved, must work | Unapproved, must be refused |
| :--- | :--- |
| SHA-256/384/512, SHA3-256, HMAC-SHA256 | MD5, MD4, RIPEMD-160 |
| AES-256-CTR, AES-256-CBC | DES, 3DES encryption, RC4, Blowfish, ChaCha20 |
| RSA-3072 key generation and signature | RSA-1024 key generation |
| ECDSA P-256 and P-384 key generation, DRBG | secp256k1 key generation |

They also check that only the FIPS and base providers are active, and that a tampered integrity MAC
stops the module from loading. Each configuration package is tested with real TLS handshakes on
the loopback interface: `fipshardened` must reach an RSA-2048 / SHA-256 server and refuse X25519
and TLS 1.1; `fips-strict` must offer exactly the NCS-1 suites, negotiate `TLS_AES_256_GCM_SHA384`
with a P-384 certificate, and refuse X25519, suites outside NCS-1, an RSA-2048 CA in the chain and
an RSA-2048 server certificate. Under `fips=yes`, provider 3.1.2 still allows SHA-1 hashing and
RSA-2048 (both approved by its security policy) and offers X25519, which the security policy lists
as "Non-Approved, Not Allowed". Applications that must stay in approved mode, or meet stricter
national rules, should not use X25519 and should set their own minimums. See
[Gaps](#gaps-to-close-in-the-deployment).

---

## Cryptography rules in Kuwait and the GCC

*Checked on 31 October 2026 against the current version of each document. Each row links the document it comes from. "Primary" means the official
text was read; rows marked **secondary** rely on news or law-firm summaries because the official
text could not be opened. This is technical information, not legal advice.*

### What we added to align with these rules

The certified module alone only guarantees that its algorithms are implemented correctly. It does
not decide which of them a system uses, and with OpenSSL's default settings weak protocols, small
keys and curves the module does not allow can still be negotiated. So, on top of the module, we
wrote the two configuration packages by hand, setting by setting, against the clauses of the
Saudi, Qatari and Kuwaiti documents below. Every setting is checked by the package tests on each
build: real TLS handshakes that must succeed, and ones that must be refused.

| What we added | Where | Rule it follows |
| :--- | :--- | :--- |
| Only the FIPS 140-3 validated module and the base provider are loaded; every algorithm comes from the module (`fips=yes`) | both configuration packages | CORF §5.3.1.3(i) and §8.1.4.5, ECC 2-8-3-1, SAMA CSF 3.3.9, UAE IA Regulation v1.1 T7.4.1 |
| MD5, MD4, RIPEMD-160, DES, 3DES encryption, RC4, Blowfish, ChaCha20, RSA-1024 and secp256k1 are refused, tested on every build | the FIPS module, enforced by the configuration | NCS-1 whitelist (§2–§3), NCA Template 1-3, CORF §5.3.1.3(i) |
| TLS 1.0 and 1.1, SSLv2 and SSLv3 are refused | both configurations | NCS-1 §4.2, QNCS Table 10, NCA Template 1-3 |
| TLS 1.2 only with forward secrecy and AEAD (no CBC or SHA-1 MAC suites) | both configurations | NCS-1 §3.6.2 ("with forward secrecy"), CORF §5.3.1.3(i) |
| X25519, X448, Ed25519 and Ed448 removed from TLS | both configurations | Security policy of #4985, Table 8 ("Non-Approved, Not Allowed") |
| Finite-field DH only from 3072 bits | `fipshardened` (strict uses ECDHE only) | NCS-1 §2.2 and §3.6.2 |
| RSA keys ≥ 3072 bits and EC keys ≥ 256 bits in every certificate of the chain, ours and the peer's (OpenSSL security level 3) | `fips-strict` | NCS-1 §2.2, §3.8 and §5.1; QNCS Tables 4 and 7 |
| TLS 1.3 limited to `TLS_AES_256_GCM_SHA384`; TLS 1.2 limited to ECDHE-ECDSA with AES-256-GCM-SHA384 or AES-CCM | `fips-strict` | NCS-1 §4.2 |
| Key exchange on P-384 and P-256 only; handshake signatures ECDSA-SHA384 and RSA-PSS-SHA384 only | `fips-strict` | NCS-1 §2.3, §3.6.2 and §3.8 |
| The module is built exactly as its security policy requires, tested on x86_64 and aarch64, signed, with SBOMs and SLSA L3 provenance | the build | ECC 2-8-3-1 (approved solutions), supply-chain and vulnerability-management controls |

### What we cannot change

These limits come from the validated module, from OpenSSL, or from what a package can control.
They have to be handled by the application, the CA or the operator:

| Limit | Why it cannot be changed here | What to do |
| :--- | :--- | :--- |
| RSA-2048 keys can still be **generated and used** through the API and the `openssl` command | The configuration controls TLS only. Provider 3.1.2 has no setting for a minimum RSA size, and RSA-2048 is approved by its security policy | Generate keys with ≥ 3072 bits; the strict TLS policy refuses smaller keys on the wire |
| SHA-1, SHA-256 and SHA-512 remain available as hash functions | They are approved by the module and needed by TLS, certificates and most software; NCS-1 §2.3 lists only SHA2-384 and SHA2-512/256 | Use SHA-384 in your own signatures and protocols where NCS-1 applies |
| X25519 is still offered by the module to applications (outside TLS) | Provider 3.1.2 exposes it under `fips=yes`; the configuration can only remove it from TLS | Do not use X25519 or Ed25519 in your code |
| Certificate chains signed with SHA-256 are still accepted by the strict policy | OpenSSL has no configuration setting for the hash used in certificate signatures (`SignatureAlgorithmsCert` is not a configuration command, and setting it breaks every TLS program) | Have your CA issue SHA-384 certificates (NCS-1 §5.1); key sizes in the chain are enforced |
| Root CA RSA ≥ 4096 bits (NCS-1 §5.1) | Security level 3 enforces 3072 bits, the next level (192-bit) would refuse P-256 and RSA-3072 | Root CA policy of your PKI |
| NCS ADVANCED level, and hardware key storage | NCS-1 §6.1 does not accept software modules at ADVANCED; CCC-2:2024 and DCC-1:2022 (Secret, Top Secret) require ADVANCED; QNCS VIII.6.1.1 and NIA CY 7 require HSMs. This is a software module (Level 1) | Keep keys in an HSM validated to FIPS 140-2/140-3 Level 3 |
| Post-quantum algorithms (ML-KEM, ML-DSA) | Provider 3.1.2 has none; no validated OpenSSL provider with them exists yet | Plan migration with the next certified provider |
| `fipsmodule.cnf` and the module itself | The security policy (§11.1) forbids changing them; a change would leave the validated module | Never edit them; update only when NIST lists a new certificate |
| Wolfi as an operational environment | The certificate lists other environments; Wolfi and aarch64 are a port affirmed by the operator (CMVP Management Manual, Section 7.9) | Documented in [What the certificate covers](#what-the-certificate-covers) |
| An application that loads another provider (for example `legacy`) on purpose | OpenSSL lets programs load providers explicitly, and Wolfi's libcrypto installs `legacy.so` as a dependency | Review applications; the configuration never loads it |
| Key management, dual control, rotation | Processes, not software (CORF §5.7.1.2, §5.7.1.5, §5.7.1.6; ECC 2-8-3-2; UAE IA Regulation v1.1 T7.4.2) | Operator procedures and an HSM or KMS |

### Why some requirements are out of reach for any software package

Three groups of requirements cannot be met by this package, or by any other software package,
however it is configured:

**Hardware key storage (HSM).** NCS-1 §6.1 does not accept software cryptographic modules at the
ADVANCED level, and CCC-2:2024 (cloud) and DCC-1:2022 (Secret and Top Secret data) require
ADVANCED. Qatar QNCS VIII.6.1.1 and NIA CY 7 ask for HSMs certified to FIPS 140-2 Level 3 or
Level 2. The reason is physical: a software module keeps its keys in the memory of the host, where
an administrator or an attacker with root access can read them. FIPS 140-3 therefore validates
software modules at Level 1 at most, and #4985 is Level 1. Only tamper-resistant hardware, such as
an HSM or a cloud HSM, reaches Level 3. OpenSSL can use an HSM through a PKCS#11 provider, which is
outside this package.

**Key management (KMS).** CBK CORF §5.7.1.2, §5.7.1.5 and §5.7.1.6, ECC 2-8-3-2 and UAE IA Regulation v1.1 T7.4.2
cover generating, storing, separating, rotating and destroying keys under dual control. OpenSSL
performs cryptographic operations with the keys it is given; it does not manage their lifecycle.
That needs a key management system and documented procedures.

**Post-quantum cryptography.** The UAE National Encryption Policy asks for post-quantum migration
plans, SAMA's circular 482021280 (27 August 2026) asks banks to inventory their cryptographic
assets by the end of 2026 and assess quantum risk by the end of March 2027, and the NCS-2:2025
draft would require every cryptographic system to support post-quantum algorithms in hybrid mode
(2-5-5-1, 2-5-5-2). OpenSSL implements ML-KEM and ML-DSA from version 3.5, but no OpenSSL FIPS
provider with them is validated yet: the next OpenSSL submission is still in CMVP review
("Comment Resolution", October 2026). Using an unvalidated provider would give up the FIPS 140-3
validation, so the packages stay on 3.1.2 until NIST lists a certificate. The build pipeline is
ready to switch to the new module as soon as it is validated.

#### Post-quantum readiness

Several documents now ask for a post-quantum plan rather than post-quantum algorithms today:

| Document | Clause | What it asks |
| :--- | :--- | :--- |
| 🇰🇼 CBK CORF v1.0 | §7.1.4.1, §7.1.4.3 | Start adopting quantum-resistant algorithms; a quantum-readiness strategy with migration timelines |
| 🇸🇦 SAMA Circular 482021280 (27 Aug 2026) | — | Inventory of cryptographic assets by the end of 2026; quantum risk assessment by March 2027 |
| 🇦🇪 National Encryption Policy v1.0 (Nov 2025, **secondary**) | — | Approved post-quantum transition plans for government entities |
| 🇸🇦 NCS-2:2025 (draft) | 2-5-5-1, 2-5-5-2 | All cryptographic systems to support PQC, used with classical algorithms |

What this project gives toward them:

- **An inventory, per release and per architecture:** `crypto-inventory-<arch>.json`, attached to
  the GitHub release and to the artifact as a signed attestation, lists what OpenSSL actually allows
  with each configuration: the active providers, the TLS 1.2 and TLS 1.3 suites, the minimum
  protocol, the key-exchange groups, the signature algorithms and the security level. It is read
  from a running OpenSSL during the build, not written by hand.
- **Crypto agility:** the algorithm set is configuration only; switching to a provider with ML-KEM
  and ML-DSA is a package change, released through the same signed pipeline.
- **The dependency, stated plainly:** provider 3.1.2 (CMVP #4985) has no post-quantum algorithms,
  and no FIPS-validated OpenSSL provider with them exists yet. No date is promised.

### Algorithms at a glance

| Algorithm | What the GCC documents say | In this package |
| :--- | :--- | :--- |
| AES-128 / 192 / 256 | Accepted: Saudi NCS-1 §2.1.2 (only 256 at ADVANCED), Qatar QNCS Table 1 | ✅ approved |
| AES-GCM, CCM, CTR | Accepted: NCS-1 §3.1 and §3.3, QNCS Table 2 (GCM tags ≥ 96 bits) | ✅ approved |
| AES-CBC | NCS-1 §3.1: "only accepted for MODERATE"; QNCS Table 2 | ✅ approved |
| 3DES | Not on the NCS-1 list; QNCS §1.2 "legacy"; Qatar NIA v2.0 Appendix B (2014) still allows it as a fallback | ❌ encryption refused |
| DES, MD5 | NCA Cryptography Standard Template 1-3: "weak ciphers (e.g., DES or MD5)"; not on NCS-1 or QNCS lists | ❌ refused |
| RC4, Blowfish | Not on the NCS-1 list; QNCS §1.2: Blowfish only for legacy use | ❌ refused |
| SHA-1 | Not on the NCS-1 or QNCS lists | ⚠️ still available for hashing and legacy signature verification; do not use in new designs |
| SHA-256, SHA-512 | QNCS Table 5 "shall be used"; **not on the NCS-1 list** (§2.3), which accepts only SHA2-384 and SHA2-512/256 | ✅ available; `fips-strict` signs TLS handshakes with SHA-384 only; use SHA-384 in your own code where NCS-1 applies |
| SHA-384, SHA-512/256 | NCS-1 §2.3 (MODERATE), QNCS Table 5 | ✅ approved |
| SHA3-256 / 384 / 512 | NCS-1 §2.3 (SHA3-512 only at ADVANCED), QNCS Table 5 | ✅ approved |
| HMAC (SHA-2 / SHA-3) | NCS-1 §3.2 (FIPS 198-1) | ✅ approved |
| RSA-2048 | Below NCS-1 §2.2 ("at least 3072 bits"); QNCS Table 4 only until 2022 | ❌ refused in TLS by `fips-strict`; ⚠️ still possible through the API |
| RSA ≥ 3072 | NCS-1 §2.2 and §3.8 (MODERATE; RSA not accepted at ADVANCED); QNCS after 2022; NCS-1 §5.1: root CA ≥ 4096 | ✅ approved (tested) |
| ECDSA / ECDH P-256, P-384 | NCS-1 §2.2 and §3.6.2 (MODERATE), QNCS | ✅ approved (tested) |
| ECDSA / ECDH P-521 | NCS-1 §2.2 (ADVANCED), QNCS | ✅ approved |
| X25519 / Curve25519 | NCS-1 §2.2 accepts it at MODERATE | ❌ removed from TLS (both configurations): the security policy (Table 8) lists it as "Non-Approved, Not Allowed"; ⚠️ still offered through the API |
| Brainpool, Camellia, Serpent, SNOW 2.0 | NCS-1 accepts them | Not in the FIPS module |
| TLS 1.2 | NCS-1 §4.2 (restricted suites), QNCS Table 10, Kuwait NBCC CLD-16 (secondary) | ✅ the minimum version; AEAD with forward secrecy only; NCS-1 suites only in `fips-strict` |
| TLS 1.3 suites | NCS-1 §4.2: only `TLS_AES_256_GCM_SHA384`; QNCS: AES-GCM, AES-CCM, ChaCha20 | ✅ only `TLS_AES_256_GCM_SHA384` in `fips-strict` (tested); AES-128/256-GCM in `fipshardened` |
| SSLv2, SSLv3 | NCA Cryptography Standard Template 1-3: avoid | ❌ below the TLS 1.2 minimum |
| Post-quantum (ML-KEM, ML-DSA) | NCS-2:2025 draft; UAE National Encryption Policy (summary only) | Not in provider 3.1.2 |
| Hardware key storage | QNCS VIII.6.1.1: HSMs FIPS 140-1/140-2 Level 3; Qatar NIA CY 7: Level 2; NCS-1 §6.1: software modules not accepted at ADVANCED | ⚠️ this is a software module (Level 1): use an HSM where these apply |

### Kuwait 🇰🇼

| Document | Clause | What it requires | Source |
| :--- | :--- | :--- | :--- |
| **CBK – Cyber and Operational Resilience Framework (CORF) v1.0**, Dec 2025, binding on local banks, succeeds the 2020 framework | §5.7.1.1 | Cryptographic policy reviewed annually, following "industry standards, best practices, and any legal and regulatory requirements" | [CORF PDF](https://www.cbk.gov.kw/en/images/corf-170113_v10_tcm10-170113.pdf) · [press release](https://www.cbk.gov.kw/en/cbk-news/announcements-and-press-releases/press-releases/2025/12/202512031000-cbk-launches-the-cyber-operational-resilience-framework-for-local-banks-and) |
| | §5.7.1.2(c) | MFA, combination keys, split knowledge, dual control for keys | ″ |
| | §5.7.1.3 | Key length "as per the latest globally acceptable industry best practices, and reviewed at least annually" | ″ |
| | §5.7.1.4 | Encrypt sensitive data in logs, databases, networks, applications, configuration files and backups, on-premise and in the cloud | ″ |
| | §5.7.1.5, §5.7.1.6 | Store key-encrypting keys separately from data keys; rotate keys suspected of compromise | ″ |
| | §5.3.1.3(i) | "disabling weak or insecure protocols and algorithms and ensuring that only latest and industry-supported algorithms are used" | ″ |
| | §8.1.4.5 | "secure and internationally recognized strong encryption algorithms" at rest and in transit | ″ |
| | §7.1.4.1, §7.1.4.3 | Banks "shall start considering the implications" of quantum computing "by starting to adopt quantum-resistant cryptographic algorithms", and develop a quantum-readiness strategy with "timelines and milestones for cryptographic migration" | ″ |
| CBK – Cybersecurity Baselines v1.0, Jan 2020 (§5.7, §7.1.10) | — | Superseded by CORF; the same principles, cite CORF instead | [2020 baselines](https://fsb.org/uploads/Central-Bank-of-Kuwait.pdf) |
| **CITRA – Data Privacy Protection Regulation**, Decision 26/2024 (7 Feb 2024), service providers licensed by CITRA | Art. 5(1)(1) | Encrypt personal data according to the provider's own data classification policy; no algorithm named | [decision](https://www.citra.gov.kw/sites/ar/Pages/DecisionsDetails.aspx?id=6) |
| CITRA – Data Classification Policy (Decisions 9/2021 and 95/2021) | — | **Repealed** by CITRA Decision 34/2024 (18 Feb 2024): do not cite | [repeal decision](https://www.citra.gov.kw/sites/ar/Pages/DecisionsDetails.aspx?id=2) |
| **NCSC – National Basic Cybersecurity Controls**, Decision 2 of 2026 (published 5 Apr 2026), mandatory minimum for government and critical entities | CLD-11, CLD-16 (**secondary**) | Cloud data encrypted at rest by default; cloud traffic encrypted "using industry-standard protocols (e.g., TLS 1.2 or higher)"; reported deadline 5 Oct 2027 | [Al-Rai](https://www.alraimedia.com/article/1761987) · [community copy of the annex](https://github.com/SiteQ8/Kuwait-NBCC) |
| Decree-Law 148/2025 amending Law 20/2014 (Electronic Transactions) | Art. 19 (**secondary**) | A "protected" signature uses a secure tool under the signer's sole control; technical standards left to executive regulations | [GLA & Co](https://www.glaco.com/blog/kuwait-enacts-decree-law-no-148-of-2025-amending-the-electronic-transactions-law/) |

No Kuwaiti document names FIPS 140 or a specific algorithm. Mapping "internationally recognized
strong encryption algorithms" to a FIPS 140-3 validated module is our interpretation, and a common
one, not a Kuwaiti requirement.

### Saudi Arabia 🇸🇦

| Document | Clause | What it requires | Source |
| :--- | :--- | :--- | :--- |
| **NCA – National Cryptographic Standards NCS-1:2020** | §1.2 | Two levels: MODERATE (128-bit security), ADVANCED (256-bit) | [NCS-1 PDF](https://cdn.nca.gov.sa/ar/ncs_en.pdf) · [NCS page](https://nca.gov.sa/en/regulatory-documents/frameworks-and-standard-list/ncs/) |
| | §2.1–§2.3, §3, §4.2, §5.1 | The algorithm whitelist in the table above: anything not listed is not accepted | ″ |
| | §6.1 | Software cryptographic modules: private keys valid ≤ 2 years at MODERATE; **not accepted at ADVANCED** | ″ |
| NCS-2:2025 | — | **Consultation draft, not issued** as of 31 October 2026 (consultation 10–25 Dec 2025; NCA's NCS page still publishes NCS-1:2020). See [NCS-2 readiness](#ncs-2-readiness) | [Arabic draft](https://cdn.nca.gov.sa/api/files/public/upload/22ec7618-3d9a-4f04-994e-9ff77f5d1146_NCS-2-ar---Copy.pdf) · [English draft (Istitlaa)](https://istitlaa.ncc.gov.sa/en/security/nca/ncs/Documents/NCS-2-en.pdf) |
| **NCA – Essential Cybersecurity Controls ECC-2:2024** | 2-8-3, 2-8-3-1 to 2-8-3-3 | Cryptography requirements "shall include at least the requirements in the National Cryptographic Standards"; approved solutions, key lifecycle, encryption in transit and at rest | [NCA controls](https://nca.gov.sa/en/regulatory-documents/controls-list/) |
| **NCA – Cloud Cybersecurity Controls CCC-2:2024** | 2-7-P-1-1, 2-7-T-1-1 | Strong encryption "in according to the advanced level" of NCS-1:2020, for cloud providers and tenants (the applicability table marks both optional at Level 4) | ″ |
| **NCA – Data Cybersecurity Controls DCC-1:2022** | 2-5-1-1, 2-5-1-2 | NCS ADVANCED level for Secret and Top Secret data; MODERATE for Confidential | ″ |
| NCA – Critical Systems Cybersecurity Controls CSCC-1:2019 | 2-7-1-1 to 2-7-1-3 | Encrypt critical systems' data in transit and at rest with "secure and up-to-date methods, algorithms, keys and devices in accordance with what NCA issues" | ″ |
| NCA – Cryptography Standard Template | 1-3 | Avoid "weak protocols (e.g., SSLv3 or SSLv2), and weak ciphers (e.g., DES or MD5)" | [template](https://cdn.nca.gov.sa/api/public/cms/files/e6e85d58-3ba7-4a71-93b2-438d08b737e2_STANDARD_Cryptography_Template_en--.pdf) |
| **SAMA – Cyber Security Framework** (2017, in force) | 3.3.9 | A defined, approved cryptographic standard: approved solutions and their restrictions, when to apply them, key management; no algorithms named | [SAMA rulebook](https://rulebook.sama.gov.sa/en/node/3941) |
| **SAMA – Circular 482021280** "Enhancement of Operational Resilience to Address Quantum Computing Risks" (27 Aug 2026, in force) | — | Banks identify and classify their cryptographic assets by the end of Q4 2026 and assess quantum risk by the end of Q1 2027; no algorithms named. The two configurations document exactly which algorithms, key sizes and TLS suites they allow, which feeds that inventory | [SAMA rulebook](https://rulebook.sama.gov.sa/en/enhancement-operational-resilience-address-quantum-computing-risks) |
| SDAIA – PDPL Implementing Regulation | Art. 23 | Security measures and NCA controls (or recognized best practice); does not mention encryption itself | [regulation PDF](https://sdaia.gov.sa/en/SDAIA/about/Documents/ImplementingRegulationPersonalDataProtectionLaw.pdf) |

**Important:** CCC-2:2024 (except Level 4, where it is optional) and DCC-1:2022 (Secret and Top
Secret) require the NCS ADVANCED level, and NCS-1 §6.1 does not accept software modules at that
level. For those systems, keep the keys in an HSM; this package then covers the software side only.

#### NCS-2 readiness

NCS-2:2025 is a consultation draft; if NCA issues it as drafted it replaces NCS-1:2020, and ECC-2:2024
2-8-3 follows it automatically. Against the draft:

| Area | NCS-2 draft | `fipshardened` | `fips-strict` (built for NCS-1 MODERATE) |
| :--- | :--- | :--- | :--- |
| Hashes | SHA2-256, SHA2-384, SHA2-512/256 at the basic level (2-3-1-1) | ✅ aligned, SHA-256 now accepted | ✅ SHA-384 accepted |
| RSA | ≥ 3072 basic; not accepted at advanced (2-4-1) | Allows 2048 (compatibility) | ✅ ≥ 3072 |
| Curves | P-256, P-384, Curve25519 basic; P-521 advanced (2-4-3) | ✅ NIST curves | ✅ P-384, P-256 |
| TLS 1.3 | `TLS_AES_128_GCM_SHA256` basic (4-2-5); `TLS_AES_256_GCM_SHA384` advanced (4-2-6) | ✅ offers both | Offers only the advanced suite: would need `TLS_AES_128_GCM_SHA256` added to be the basic profile |
| TLS 1.2 | basic adds AES-128-GCM, ECDHE-RSA-AES-256-GCM, CBC with Encrypt-then-MAC (4-2-3) | ✅ AEAD only, stricter | ✅ within the list |
| Certificates | intermediate and end-user ECC: P-384, P-521, Curve448, Brainpool 384/512 only; P-256 removed (5-1-4-1) | — | Accepts P-256 chains: the CA must issue P-384 or stronger |
| Post-quantum | all cryptographic systems must support PQC, used together with classical algorithms (2-5-5-1, 2-5-5-2) | ❌ not possible with provider 3.1.2 | ❌ same |
| Software modules | ≤ 2-year keys at basic, not accepted at advanced (6-1-2) | Same as NCS-1 | Same as NCS-1 |

When NCS-2 is issued, `fips-strict` will be updated to its basic level (adding the TLS 1.3 basic
suite and documenting the certificate rule). The post-quantum requirement can only be met by a
FIPS provider with ML-KEM and ML-DSA, once NIST validates one.

### United Arab Emirates 🇦🇪

| Document | Clause | What it requires | Source |
| :--- | :--- | :--- | :--- |
| **TDRA – UAE Information Assurance Regulation v1.1** (March 2020); **superseded** by the UAE IA Standard v2.x (UAE Cyber Security Council, 2025, **secondary**: official text not public), which keeps the T/M control families and maps v1.1 in an annex | T7.4.1 | A policy on the use of cryptographic controls that "takes into account the sector or national level restrictions including TRA's relevant issuances"; guidance on "type, strength, and quality of the encryption algorithm" | [IA Regulation (archived)](https://web.archive.org/web/2025/https://u.ae/-/media/guidelines/Guidelines-2020/UAE-IA-Regulation-v11-1.pdf) |
| | T7.4.2 | Key management for the entity's cryptographic techniques | ″ |
| | M5.2.6 | Use cryptographic controls in line with legislation and agreements, including restrictions on import, export and use of encryption | ″ |
| **UAE Cyber Security Council – National Encryption Policy v1.0** and Executive Regulation (Nov 2025) | **secondary** | Encryption of data at rest and in motion, key management, post-quantum migration plans; full text could not be opened | [u.ae summary](https://u.ae/en/about-the-uae/strategies-initiatives-and-awards/policies/cyber-activities/National-Encryption-Policy) |
| **Federal Decree-Law 45/2021 (PDPL)** | Art. 20(1)(a) | "Encryption of Personal Data and the application of Pseudonymisation", per "best international practices and standards" | [UAE legislation](https://uaelegislation.gov.ae/en/legislations/1972) |
| Dubai DESC ISR, CBUAE | — | Not verified: no public primary text | — |

The UAE IA Regulation v1.1 has no algorithm list and no FIPS reference; it defers to TDRA's issuances. The clauses above are mapped to v1.1; the mapping to the v2 standard follows once its official text is available.

### Qatar 🇶🇦

| Document | Clause | What it requires | Source |
| :--- | :--- | :--- | :--- |
| **Qatar National Cryptographic Standard v1.0** (MOTC, Oct 2019) | Tables 1, 2, 4, 5, 10 | The algorithm list in the table above: AES, SHA-2/SHA-3, RSA 3000+ after 2022, ECDSA 256–512, TLS 1.2/1.3 | [QNCS v1.0 (archived)](https://web.archive.org/web/2023/https://www.qcert.org/sites/default/files/public/documents/qatar_national_cryptographic_standard_-_version_1.0.pdf) · [MOTC](https://www.mot.gov.qa/en/news/ministry-launches-qatar-national-cryptographic-standard) |
| | §1.2 | 3DES, Kasumi, Blowfish are legacy; "Mechanisms which are not listed are not necessarily considered by QPKI to be insecure" | ″ |
| | VIII.6.1.1 | Keys generated and stored in systems where the "Hardware Security device should be certified FIPS 140-1 Level 3, FIPS 140-2 Level 3 or Common Criteria (CC) EAL 4 or above" | ″ |
| Qatar NIA Policy v2.0 (MICT, 2014) | CY 1, CY 5, CY 7 | Algorithms per Appendix B (still allows 3DES and MD5 as fallbacks); TLS for C3 data in transit; HSMs at FIPS 140-2 Level 2 or EAL4. Superseded by the National Information Assurance Standard v2.1 (May 2023, not public), whose cryptography control CY-5 points to the Qatar National Cryptographic Standard v1.0 or higher (**secondary**) | [archived copies](https://web.archive.org/web/*/qcert.org/*nia_policy_english_v2.0.pdf) |

The only GCC clauses that name FIPS 140 are Qatar's, and they apply to HSMs and smartcards, not
to software modules.

### Bahrain 🇧🇭

| Document | Clause | What it requires | Source |
| :--- | :--- | :--- | :--- |
| **CBB Rulebook Vol. 1, OM module** (April 2023 text; the module was realigned in May 2026, OM-5.5 wording unchanged) | OM-5.5.3 | Cyber security framework per the NIST Cybersecurity Framework | [OM module (archived)](https://web.archive.org/web/2023/https://cbben.thomsonreuters.com/sites/default/files/net_file_store/Vol_1_OM_April_2023.pdf) |
| | Appendix C, Data Security 1–2 | Critical or confidential data at rest and in transit "protected through strong encryption" | ″ |
| | OM-5.5.12(e), OM-5.2.9 | Classification decides what is encrypted; ATM account data encrypted | ″ |
| PDPL, Law 30/2018 | Art. 8, Art. 3(5) | Appropriate technical measures (no encryption named); identities in long-retained data encrypted when anonymisation is not possible | [LLOC translation](https://www.lloc.gov.bh/FullEn/K3018.docx) |

### Oman 🇴🇲

| Document | Clause | What it requires | Source |
| :--- | :--- | :--- | :--- |
| PDPL, Royal Decree 6/2022 | Arts. 13(c), 14, 21 | Technical and procedural measures, confidentiality; no encryption or algorithm named | [decree.om (unofficial translation)](https://decree.om/2022/l20220006/) |
| **CBO Cyber Security & Resilience Framework** (Sept 2023, **secondary**) | §3.3.4 | "Do not use weak or broken algorithms"; key length "as per the latest security standards" | Seclore regulatory brief (secondary; no public primary text found) |
| MTCIT, OCERT | — | No public official cryptography standard found. A third-party claim that an Omani framework requires FIPS 140 could not be traced to an official source and is not relied on | — |

### In short

- Cryptography comes from a FIPS 140-3 validated module (CMVP #4985), running in its approved mode.
- Weak algorithms (MD5, DES, 3DES, RC4, Blowfish) and old protocols (SSL, TLS 1.0/1.1) are
  refused system-wide, as CBK CORF §5.3.1.3(i) and the NCA and Qatari standards require.
- With `openssl-config-fips-strict`, TLS is limited to the NCA NCS-1:2020 MODERATE suites, groups
  and key sizes.
- Every release has SLSA Build Level 3 provenance, Sigstore signatures and SBOMs.

### Gaps to close in the deployment

The short list from [What we cannot change](#what-we-cannot-change):

1. **RSA ≥ 3072 and SHA-384** in keys, certificates and signatures that applications create
   (NCS-1 §2.2, §2.3, §5.1; QNCS Tables 4 and 7; CORF §5.7.1.3).
2. **SHA-384 certificates** from your CA, and a root CA with RSA ≥ 4096 or P-384/P-521 (NCS-1 §5.1).
3. **No X25519 or Ed25519** in application code.
4. **HSMs** for NCS ADVANCED (CCC-2:2024, DCC-1:2022 Secret and Top Secret) and for Qatar QNCS
   VIII.6.1.1 and NIA CY 7.
5. **Post-quantum migration** (CBK CORF §7.1.4.1 and §7.1.4.3, UAE National Encryption Policy, SAMA circular 482021280, NCS-2:2025 draft). See [Post-quantum readiness](#post-quantum-readiness).
6. **Key management and dual control** (CORF §5.7.1.2 and §5.7.1.5, ECC 2-8-3-2, UAE IA Regulation v1.1 T7.4.2).

### Sources we could not read in full

- Kuwait: the official NBCC annex (gazette or ncsc.gov.kw); NCSC Decision 1/2025 (data
  classification); executive regulations of Decree-Law 148/2025.
- Saudi: the English NCS-2 draft (Istitlaa's certificate had expired when checked); whether NCA has
  adopted NCS-2 since the consultation.
- UAE: National Encryption Policy full text (csc.gov.ae unreachable); the UAE IA Standard v2.x text and its control numbers; DESC ISR; CBUAE encryption rules.
- Qatar: NCSA NIA Standard v2.1. Bahrain: NCSC standards, Resolution 43/2022. Oman: any official
  cryptography standard, Executive Regulation 34/2024.
- Licensing or import approval for encryption products in any GCC state: no primary rule found.

---

## Maintainers

Repository settings, secrets and the release process are in [MAINTAINING.md](MAINTAINING.md).

## Build locally

Needs Docker, curl and cosign. melange comes from its GitHub release, signature and checksum
verified, and builds in Docker containers it assembles from the Wolfi packages:

```sh
scripts/install-tools.sh ./bin melange
mkdir -p .keys && (cd .keys && ../bin/melange keygen melange-x86_64.rsa)
./bin/melange build melange/openssl-provider-fips-3.1.2.yaml --runner docker --arch x86_64 \
  --source-dir melange/openssl-provider-fips-3.1.2 --signing-key .keys/melange-x86_64.rsa --out-dir packages
./bin/melange test melange/openssl-provider-fips-3.1.2.yaml --runner docker --arch x86_64 \
  --source-dir melange/openssl-provider-fips-3.1.2 \
  --repository-append "$PWD/packages" --keyring-append "$PWD/.keys/melange-x86_64.rsa.pub"
```

## Layout

```
melange/openssl-provider-fips-3.1.2.yaml   package recipe, build/test environments pinned for Renovate
melange/openssl-provider-fips-3.1.2/       fips-openssl.cnf and fips-strict.cnf (the two /etc/ssl/openssl.cnf)
scripts/install-tools.sh                   melange and apko from their GitHub releases, signature and checksum verified
scripts/crypto-inventory.sh                what OpenSSL allows with each configuration, per architecture
scripts/publish.sh                         push both architectures as one OCI index (oras)
scripts/bump-epoch.sh                      new epoch + CHANGELOG entry (Renovate post-upgrade task)
.github/workflows/build.yml                reusable: build, test, push, sign, attest, verify (SLSA L3)
.github/workflows/pr.yml                   checks for every pull request
.github/workflows/release.yml              release on merge, GitHub release, keep five versions
.github/workflows/renovate.yml             self-hosted Renovate for this repository
renovate.json                              update rules, grouping, automerge
CHANGELOG.md                               what changed in every tag
MAINTAINING.md                             repository settings and release process
```

## License

The code in this repository (build definitions, workflows, scripts and documentation) is licensed
under the [Apache License 2.0](LICENSE). The software inside the packages keeps its own license:
the OpenSSL FIPS Provider is Apache License 2.0, and the provider package ships its `LICENSE.txt`.
[NOTICE](NOTICE) lists the third-party software, the build tools and the trademarks.
