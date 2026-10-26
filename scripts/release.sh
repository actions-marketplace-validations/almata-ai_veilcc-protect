#!/usr/bin/env bash
# Cut a release from the CLI: tag vX.Y.Z and push it. The `release` workflow then
# creates the GitHub Release and moves the major tag (vN).
#   scripts/release.sh v1.2.3
set -euo pipefail
VER="${1:?usage: scripts/release.sh vX.Y.Z}"
[[ "$VER" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must look like v1.2.3"; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "working tree not clean; commit first"; exit 1; }
git tag -a "$VER" -m "VeilCC Protect $VER"
git push origin "$VER"
echo "pushed $VER → the release workflow will create the GitHub Release and move the major tag."
