#!/usr/bin/env bash
set -euo pipefail

# CI-only fallback for the pinned Linux x86_64 release asset.
output="${1:?usage: provision-shellcheck-fallback.sh EMPTY_DIRECTORY}"
archive="$(mktemp "${RUNNER_TEMP:?}/spp-shellcheck.XXXXXX")"
trap 'rm -f -- "$archive"' EXIT

policy=config/validation-toolchain.json
expected="$(jq -er '.shellcheck_release.assets["linux.x86_64"].sha256 | select(test("^[0-9a-f]{64}$"))' "$policy")"
version="$(jq -er '.shellcheck_release.version | select(test("^[0-9]+[.][0-9]+[.][0-9]+$"))' "$policy")"
# Update this official asset ID alongside the Linux pin when changing versions.
curl --fail --silent --show-error --location --proto '=https' \
  --max-time 30 --max-filesize 33554432 --output "$archive" \
  --header 'Accept: application/octet-stream' \
  https://api.github.com/repos/koalaman/shellcheck/releases/assets/279056942
printf '%s  %s\n' "$expected" "$archive" | sha256sum --check --status

mkdir -- "$output"
tar -xOJf "$archive" -- "shellcheck-v$version/shellcheck" > "$output/shellcheck"
test -s "$output/shellcheck"
chmod 0755 "$output/shellcheck"
