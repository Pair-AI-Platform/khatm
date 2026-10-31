# Maintaining

## Repository setup

| Setting | Why |
| :--- | :--- |
| GitHub App `renovate(bot)-updater` installed on this repository, with Contents, Pull requests, Issues and Workflows read/write, Checks, Commit statuses and Dependabot alerts read | Renovate runs as this App. Pull requests opened with `GITHUB_TOKEN` would start no checks, so nothing would automerge, and its merges would start no release |
| Variable `RENOVATE_APP_CLIENT_ID` and secret `RENOVATE_APP_PRIVATE_KEY` (the App's `.pem`) | `renovate.yml` turns them into a short-lived installation token on every run; `release.yml` uses the same App to create and delete release tags, which `GITHUB_TOKEN` cannot do when the tagged commit's workflow files differ from main |
| Package `openssl-provider-fips` → *Manage Actions access*: this repository with **Admin** role | Lets `GITHUB_TOKEN` push to the package and delete old versions |
| Branch protection on `main`, requiring the `PR` checks (`build (x86_64)`, `build (aarch64)`, `version`) | Optional for Renovate, which merges only after the checks pass, but stops manual merges that skip them |
| Secret `MELANGE_SIGNING_KEY`: the private half of `keys/khatm.rsa.pub` | Signs the APK files; releases fail without it, and the build checks it matches the committed public key. Replacing it means committing the new public key and telling users |

## Changing the packages

Every change under `melange/` needs a new epoch and a CHANGELOG entry; `pr.yml` fails without
them. Run `scripts/bump-epoch.sh`, then complete the entry it adds. Renovate does this itself for
its updates.

The FIPS module version (3.1.2, certificate #4985) only changes by hand, when NIST lists a new
certificate. Never edit `fipsmodule.cnf` or patch the module.

## APK signing key

The APK files are signed with one RSA key (4096 bits), separate from the keyless Sigstore signature
of the artifact. Its private half exists only as the `MELANGE_SIGNING_KEY` secret and in an offline
backup; its public half is `keys/khatm.rsa.pub`.

- **Protection:** GitHub encrypts the secret and exposes it only to workflow runs of this repository
  (not to pull requests from forks); `build.yml` checks it against the committed public key and
  deletes it from the runner after signing. Keep the backup in a password manager or vault, never on
  a laptop disk.
- **Rotation (yearly, or at once if the key may have leaked):**
  1. Generate a new key: `melange keygen khatm-<year>.rsa`.
  2. Commit the new public key under `keys/`, keep the old one, and set the new private key as
     `MELANGE_SIGNING_KEY`; update `name=` in `build.yml` to the new file name.
  3. Bump the epoch and release: the new version is signed with the new key.
  4. Tell users to add the new public key; remove the old one from `keys/` after the five kept
     versions have rolled over.

## Branch rules

Changes reach `main` through pull requests, so the `PR` checks run first. Pushing directly to `main`
skips them, as happened with the merge conflict in 7e4ecb7; with the ruleset active, only
repository admins can push directly, and they should not.
