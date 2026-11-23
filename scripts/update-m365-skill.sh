#!/usr/bin/env bash
# Pin the m365 agent skill (pkgs/m365-skill.nix) to a release of
# intel-manufacturing/applications.manufacturing.intel.ai.agents.
#
# That repo is internal to mfg-github, and its release downloads redirect to a login
# page for anything but a signed-in browser or an API call -- neither of which Nix's
# fetchers can make. So this downloads the asset with the already-authenticated gh,
# adds it to the Nix store where pkgs/m365-skill.nix's requireFile finds it, and
# records the version and hash in pkgs/m365-skill.json.
#
# Usage: scripts/update-m365-skill.sh [tag]    (default: the latest release)
# Rerun with the pinned tag to put the zip back into the store if it goes missing,
# e.g. on a fresh machine.
set -euo pipefail

repo=mfg-github.mfg.intel.com/intel-manufacturing/applications.manufacturing.intel.ai.agents
asset=m365-skill-linux-x64.zip
pin="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/pkgs/m365-skill.json"
gcroot="${XDG_STATE_HOME:-$HOME/.local/state}/m365-skill/$asset"

tag="${1:-$(gh release view --repo "$repo" --json tagName --jq .tagName)}"
version="${tag#v}"
name="m365-skill-linux-x64-$version.zip"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

gh release download "$tag" --repo "$repo" --pattern "$asset" --output "$tmp/$name"
hash="$(nix-hash --type sha256 --flat --sri "$tmp/$name")"
path="$(nix-store --add-fixed sha256 "$tmp/$name")"

# Nothing in the built skill references the zip, so without a GC root a garbage
# collection would delete it, and the next rebuild that changes the derivation
# (e.g. a nixpkgs bump) would fail. Repointing the root releases the previous zip.
mkdir -p "$(dirname "$gcroot")"
nix-store --add-root "$gcroot" --realise "$path" >/dev/null

printf '{\n  "version": "%s",\n  "hash": "%s"\n}\n' "$version" "$hash" > "$pin"
echo "m365 skill pinned to $tag ($path)"
