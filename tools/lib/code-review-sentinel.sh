#!/usr/bin/env bash
# Shared, read-only parser for .code-review-cleared.
# Call parse_code_review_sentinel FILE, then read CODE_REVIEW_SENTINEL_{SHA,
# VERDICT,TIMESTAMP,ERROR}. The function never writes or consumes the file.

parse_code_review_sentinel() {
    local sentinel_file="$1" line line_count field_count
    local ver sha verdict timestamp min_score

    CODE_REVIEW_SENTINEL_SHA=""
    CODE_REVIEW_SENTINEL_VERDICT=""
    CODE_REVIEW_SENTINEL_TIMESTAMP=""
    CODE_REVIEW_SENTINEL_ERROR=""

    line_count="$(awk 'NF{c++} END{print c+0}' "$sentinel_file" 2>/dev/null || echo 0)"
    line="$(head -n1 "$sentinel_file" 2>/dev/null || true)"
    field_count="$(awk -F'|' '{print NF; exit}' <<< "$line")"
    IFS='|' read -r ver sha verdict timestamp min_score <<< "$line"

    # shellcheck disable=SC2034  # output variables are consumed by sourcing callers
    CODE_REVIEW_SENTINEL_SHA="$sha"
    # shellcheck disable=SC2034  # output variables are consumed by sourcing callers
    CODE_REVIEW_SENTINEL_VERDICT="$verdict"
    # shellcheck disable=SC2034  # output variables are consumed by sourcing callers
    CODE_REVIEW_SENTINEL_TIMESTAMP="$timestamp"

    if [[ "$line_count" -ne 1 ]]; then
        CODE_REVIEW_SENTINEL_ERROR="malformed (${line_count} non-blank lines; must be exactly 1)"
    elif [[ "$ver" != "v1" || "$field_count" -lt 4 || "$field_count" -gt 5 || -z "$sha" || -z "$timestamp" ]]; then
        CODE_REVIEW_SENTINEL_ERROR="format unrecognized (expected v1|SHA|VERDICT|TIMESTAMP[|min-score=N])"
    elif [[ "$field_count" -eq 5 && ! "$min_score" =~ ^min-score=[0-9]+(\.[0-9]+)?$ ]]; then
        CODE_REVIEW_SENTINEL_ERROR="format unrecognized (malformed min-score field '$min_score')"
    fi

    [[ -z "$CODE_REVIEW_SENTINEL_ERROR" ]]
}
