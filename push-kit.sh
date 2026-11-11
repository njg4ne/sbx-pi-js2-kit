#!/usr/bin/env bash
# usage: push.sh [-r|--reset-secret] [tag]   (default tag: latest)
#   -r, --reset-secret   force re-entry of the GHCR registry secret (overwrites existing)
set -euo pipefail

REGISTRY="ghcr.io"
KIT_DIR="./pi-js2-kit"
IMAGE="ghcr.io/njg4ne/sbx-pi-js2-kit"

# Parse args: one optional flag plus one optional positional tag.
RESET_SECRET=0
TAG=""
for arg in "$@"; do
  case "$arg" in
    -r|--reset-secret) RESET_SECRET=1 ;;
    -h|--help)
      sed -n '2,3p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*) echo "Error: unknown option: $arg" >&2; exit 1 ;;
    *)
      if [[ -n "$TAG" ]]; then
        echo "Error: unexpected argument: $arg" >&2
        exit 1
      fi
      TAG="$arg"
      ;;
  esac
done
TAG="${TAG:-latest}"

# Ensure the GHCR registry secret is set. `sbx secret ls -q` prints secret names
# only (registry credentials are named after the registry host, e.g. "ghcr.io"),
# so an exact match is a reliable existence check.
set_secret() {
  # $1: pass -f to overwrite an existing secret without confirmation.
  printf 'Enter the GHCR token: '
  IFS= read -r -s GHCR_TOKEN
  echo
  if [[ -z "$GHCR_TOKEN" ]]; then
    echo "Error: a GHCR token is required." >&2
    exit 1
  fi
  sbx secret set "$@" --registry "$REGISTRY" --password-stdin <<< "$GHCR_TOKEN"
}

if [[ "$RESET_SECRET" -eq 1 ]]; then
  echo "Reset requested: re-entering registry secret for ${REGISTRY}."
  set_secret -f
  echo "Registry secret reset."
elif sbx secret ls -q 2>/dev/null | grep -qxF "$REGISTRY"; then
  echo "Registry secret for ${REGISTRY} is already set."
else
  echo "No registry secret set for ${REGISTRY}."
  set_secret
  echo "Registry secret set."
fi

# Confirm before pushing.
read -r -p "Push ${IMAGE}:${TAG}? (y/N) " confirm
if [[ ! "${confirm:-}" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 1
fi

# sbx kit push "$KIT_DIR" "${IMAGE}:${TAG}" --sign
sbx kit push "$KIT_DIR" "${IMAGE}:${TAG}"
