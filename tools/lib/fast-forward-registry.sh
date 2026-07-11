#!/usr/bin/env bash
# fast-forward-registry.sh -- registry of path prefix -> deterministic
# regeneration command, consumed by tools/try-sentinel-fast-forward.sh.
#
# A changed file must match one of these prefixes, AND re-running its
# generator command must reproduce the committed content byte-for-byte,
# before a sentinel fast-forward is allowed to skip a full AI review for it.
#
# Add entries here as new mechanically-regenerated fixture classes appear.
# Do NOT widen this to arbitrary globs without the same byte-diff proof
# try-sentinel-fast-forward.sh already requires for every entry -- a path
# match alone is not sufficient; see that script's header for why (a prior
# path-only design was rejected in review for exactly this reason).
# shellcheck disable=SC2034  # consumed by the sourcing script (try-sentinel-fast-forward.sh)
declare -A FASTFORWARD_GENERATORS=(
    ["test/golden-compression/"]="node test/compress.test.js --update"
    ["test/ei-baseline.json"]="node test/ei-move-detector.test.js --update"
)
