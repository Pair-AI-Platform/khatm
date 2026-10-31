#!/usr/bin/env bash
# Gives the packages a new version for a pull request that changes them: bumps the melange epoch by
# one from the base branch and adds a CHANGELOG.md entry with the pins that changed.
#
# Renovate runs it as a post-upgrade task (renovate.json) after it has updated the pins, before it
# commits. Run it by hand after changing melange/ yourself, then edit the entry if needed. It reads
# the base version from HEAD, so running it twice gives the same result.
set -euo pipefail

config=melange/openssl-provider-fips-3.1.2.yaml
changelog=CHANGELOG.md
marker='<!-- releases -->'

base_epoch="$(git show "HEAD:$config" | awk '/^  epoch:/ {print $2; exit}')"
epoch=$((base_epoch + 1))
sed -i "s/^  epoch: .*/  epoch: $epoch/" "$config"

version="$(awk -F'"' '/^  version:/ {print $2; exit}' "$config")"
tag="$version-r$epoch"

# "name=version" pins (melange environments) and the melange version, before and after
changes="$(git diff -U0 HEAD -- melange/ scripts/install-tools.sh | awk '
  function record(side, line,    name, value) {
    sub(/^[-+][[:space:]]*(- )?/, "", line)
    if (line ~ /^MELANGE_VERSION=/) {
      name = "melange"
      value = line; sub(/^MELANGE_VERSION=/, "", value)
    } else if (line ~ /^[a-z0-9][a-z0-9._+-]*=[0-9]/) {
      name = line; sub(/=.*/, "", name)
      value = line; sub(/^[^=]*=/, "", value); sub(/[[:space:]].*/, "", value)
    } else {
      return
    }
    if (side == "-") old[name] = value; else new[name] = value
  }
  /^-[^-]/ { record("-", $0) }
  /^\+[^+]/ { record("+", $0) }
  END {
    for (name in new)
      if (old[name] != new[name])
        printf "| `%s` | %s | %s |\n", name, (name in old ? old[name] : "new"), new[name]
  }
' | sort)"

entry="$(mktemp)"
{
  echo "## $tag ($(date -u +%Y-%m-%d))"
  echo
  if [ -n "$changes" ]; then
    echo "Rebuilt with updated Wolfi packages. The FIPS module itself (OpenSSL FIPS Provider 3.1.2,"
    echo "CMVP #4985) is built from the same validated source."
    echo
    echo "| Package | From | To |"
    echo "| :--- | :--- | :--- |"
    echo "$changes"
  else
    echo "- Describe the change here."
  fi
} > "$entry"

# Replaces an entry for the same tag from an earlier run, then inserts the new one at the top
awk -v tag="$tag" -v marker="$marker" -v entry="$entry" '
  $0 ~ "^## " tag " " {skip = 1; next}
  skip && /^## / {skip = 0}
  skip {next}
  {print}
  $0 == marker {print ""; while ((getline line < entry) > 0) print line}
' "$changelog" > "$changelog.tmp"
mv "$changelog.tmp" "$changelog"
rm -f "$entry"

echo "$tag"
