# shellcheck shell=bash
# -----------------------------------------------------------------------------
# lib/install/skill-naming.sh
# PURPOSE: Compute the install-destination name for a source skill directory,
#          based on the first /sp* trigger declared in its skill.md.
# SOURCED BY: lib/install/deploy.sh, tools/doctor-checks.sh, test/*
# DEPENDENCIES: none — pure shell helpers, no globals required.
# -----------------------------------------------------------------------------
# Idempotent guard: safe to source multiple times (deploy.sh + doctor source it).
[[ -n "${_SKILL_NAMING_SH_LOADED:-}" ]] && return 0
_SKILL_NAMING_SH_LOADED=1

# Extract the first /sp* trigger from a skill.md file.
# Covers /sp-*, /spr-*, /spc-*, etc. Handles inline YAML array (double- or
# single-quoted) and block list formats. Prints empty string if no /sp* trigger.
_extract_sp_trigger() {
    local skill_file="$1"
    local t
    # Inline array, double-quoted: triggers: ["/sp-foo", "/spr-bar", ...]
    t=$(grep "^triggers:" "$skill_file" 2>/dev/null | grep -o '"/sp[^"]*"' | head -1 | tr -d '"')
    [[ -n "$t" ]] && echo "$t" && return
    # Inline array, single-quoted: triggers: ['/sp-foo', ...]
    t=$(grep "^triggers:" "$skill_file" 2>/dev/null | grep -o "'/sp[^']*'" | head -1 | tr -d "'")
    [[ -n "$t" ]] && echo "$t" && return
    # Block list: - /sp-foo  or  - /spr-bar
    t=$(grep -m1 '^ *- /sp' "$skill_file" 2>/dev/null | sed 's/^ *- //')
    echo "$t"
}

# Compute the install destination name for a skill directory.
# Uses the first /sp* trigger from the skill file (minus leading /) if present;
# otherwise falls back to the source directory basename.
_skill_dest_name() {
    local skill_dir="$1"
    local skill_file=""
    [[ -f "$skill_dir/skill.md" ]] && skill_file="$skill_dir/skill.md"
    [[ -f "$skill_dir/SKILL.md" ]] && skill_file="$skill_dir/SKILL.md"
    if [[ -n "$skill_file" ]]; then
        local sp_trigger
        sp_trigger=$(_extract_sp_trigger "$skill_file")
        if [[ -n "$sp_trigger" ]]; then
            printf '%s\n' "${sp_trigger#/}"
            return
        fi
    fi
    basename "$skill_dir"
}

# Walk one or more source-skill roots and populate the global SOURCE_DEST_NAME,
# DEST_NAME_SOURCE, and DEST_NAMES_SET associative arrays.
# Caller must `declare -A` those three before invoking.
# Each argument is treated as a root that may either contain `skills/` or be a
# `skills/` directory itself — same convention as the doctor's COMPARE_DIRS.
_build_dest_name_index() {
    local root search_root skill_md skill_path src_name dest_name
    for root in "$@"; do
        search_root="$root"
        [[ -d "$root/skills" ]] && search_root="$root/skills"
        while IFS= read -r skill_md; do
            skill_path=$(dirname "$skill_md")
            src_name=$(basename "$skill_path")
            dest_name=$(_skill_dest_name "$skill_path")
            # SC2034 disabled: these arrays are declared by the caller and used cross-module
            # SC2004 disabled: string keys in array subscripts don't need $ but are clear this way
            # shellcheck disable=SC2034,SC2004
            SOURCE_DEST_NAME["$src_name"]="$dest_name"
            # shellcheck disable=SC2034,SC2004
            DEST_NAME_SOURCE["$dest_name"]="$src_name"
            # shellcheck disable=SC2034,SC2004
            DEST_NAMES_SET["$dest_name"]="1"
        done < <(find "$search_root" -name "skill.md" -not -path "*/references/*" -not -path "*/.worktrees/*" 2>/dev/null)
    done
}
