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
