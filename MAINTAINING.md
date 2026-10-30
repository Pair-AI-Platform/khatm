# Maintaining

## Repository setup

| Setting | Why |
| :--- | :--- |
| Secret `RENOVATE_TOKEN`: fine-grained token on this repository with Contents, Pull requests, Issues and Workflows read/write, and Dependabot alerts read | Pull requests opened with `GITHUB_TOKEN` start no checks, so nothing would automerge, and merges made with it start no release |
| Package `openssl-provider-fips` → *Manage Actions access*: this repository with **Admin** role | Lets `GITHUB_TOKEN` push to the package and delete old versions |
| Branch protection on `main`, requiring the `PR` checks (`build (x86_64)`, `build (aarch64)`, `version`) | Optional for Renovate, which merges only after the checks pass, but stops manual merges that skip them |
| Secret `MELANGE_SIGNING_KEY` (optional) | One fixed APK signing key instead of a throwaway key per build |

## Changing the packages

Every change under `melange/` needs a new epoch and a CHANGELOG entry; `pr.yml` fails without
them. Run `scripts/bump-epoch.sh`, then complete the entry it adds. Renovate does this itself for
its updates.

The FIPS module version (3.1.2, certificate #4985) only changes by hand, when NIST lists a new
certificate. Never edit `fipsmodule.cnf` or patch the module.
