#!/usr/bin/env bash
# Regenerates package-lock.json for the pi-web version in default.nix.
#
# The published tarball has no lockfile, and npm leaves `integrity` empty for the
# @earendil-works packages nested under pi-coding-agent, which makes
# prefetch-npm-deps panic. We fill those in from the registry metadata.
set -euo pipefail

cd "$(dirname "$0")"
version=$(sed -n 's/.*version = "\(.*\)".*/\1/p' default.nix | head -1)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

curl -sL "https://registry.npmjs.org/@agegr/pi-web/-/pi-web-${version}.tgz" |
  tar xz -C "$work" --strip-components=1 package/package.json

# Drop devDependencies - `.next` is prebuilt, so only runtime deps are needed.
jq 'del(.devDependencies)' "$work/package.json" >"$work/package.json.tmp"
mv "$work/package.json.tmp" "$work/package.json"

(cd "$work" && npm install --package-lock-only --ignore-scripts >/dev/null)

lock="$work/package-lock.json"
jq -r '.packages | to_entries[] | select(.value.resolved != null and .value.integrity == null) | .key' "$lock" |
  while read -r key; do
    name=${key##*node_modules/}
    pkg_version=$(jq -r --arg k "$key" '.packages[$k].version' "$lock")
    integrity=$(curl -s "https://registry.npmjs.org/${name}" |
      jq -r --arg v "$pkg_version" '.versions[$v].dist.integrity')
    jq --arg k "$key" --arg i "$integrity" '.packages[$k].integrity = $i' "$lock" >"$lock.tmp"
    mv "$lock.tmp" "$lock"
  done

cp "$lock" package-lock.json
echo "npmDepsHash: $(prefetch-npm-deps package-lock.json)"
