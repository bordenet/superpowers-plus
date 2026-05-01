#!/usr/bin/env bash
# claude-commands-mirror.sh — emit one ~/.claude/commands/<skill>.md per Augment skill.
# Item 5 of the Claude Code 12-point guardrails plan.
# Source: ~/.agents/skills/ (Augment IDE slash menu, SKILL.md format).
# Target: ~/.claude/commands/ (Claude Code custom slash commands).
# Idempotent: overwrites on each run, prunes stale managed entries.
set -euo pipefail

SRC="${AUGMENT_MENU_DIR:-$HOME/.agents/skills}"
DST="${CLAUDE_COMMANDS_DIR:-$HOME/.claude/commands}"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

VERBOSE=0
WHAT_IF=0

show_help() {
    cat <<EOF
Usage: ${0##*/} [options]

Mirror Augment IDE slash-menu skills to Claude Code custom commands.

Reads SKILL.md files from: $SRC
Writes command files to:   $DST

Each \$SRC/<skill>/SKILL.md becomes \$DST/<name>.md with:
  ---
  description: "<description from SKILL.md>"
  ---
  Invoke the \`<name>\` skill ...

Idempotent: files are overwritten on every run.
Stale entries (managed by this script, no longer in source) are removed.

Options:
  -v, --verbose    Show per-skill progress on stderr
  --what-if        Dry run — show what would be written/pruned, no changes made
  -h, --help       Show this help
EOF
}

log_info()    { echo "[claude-commands-mirror] $*" >&2; }
log_verbose() { [[ "$VERBOSE" -eq 1 ]] && echo "[claude-commands-mirror] $*" >&2 || true; }
log_warn()    { echo "[claude-commands-mirror] WARN: $*" >&2; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)    show_help; exit 0 ;;
        -v|--verbose) VERBOSE=1; shift ;;
        --what-if)    WHAT_IF=1; shift ;;
        *) echo "Unknown option: $1" >&2; show_help >&2; exit 1 ;;
    esac
done

[[ "$WHAT_IF" -eq 1 ]] && log_info "DRY RUN (--what-if) — no files will be written or removed"

if [[ ! -d "$SRC" ]]; then
    log_info "no Augment skills dir at $SRC — skipping"
    exit 0
fi

mkdir -p "$DST"

declare -a KEEP=()

for skill_dir in "$SRC"/*/; do
    [[ -f "$skill_dir/SKILL.md" ]] || continue

    skill_md="$skill_dir/SKILL.md"
    name="$(awk '/^name:/{$1=""; sub(/^ /,""); gsub(/"/,""); print; exit}' "$skill_md")"
    desc="$(awk '/^description:/{$1=""; sub(/^ /,""); gsub(/^"|"$/,""); print; exit}' "$skill_md")"

    [[ -z "$name" ]] && { log_warn "no name: in $skill_md — skipping"; continue; }
    [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || { log_warn "invalid name in $skill_md — skipping"; continue; }

    # If a ~/.claude/skills/<name>/ entry exists, it takes precedence — skip the mirror
    # to avoid showing two entries with the same name in the slash-command menu.
    if [[ -d "$SKILLS_DIR/$name" ]]; then
        log_verbose "  skipped (skills-dir entry exists): $name"
        continue
    fi

    out="$DST/${name}.md"
    if [[ "$WHAT_IF" -eq 0 ]]; then
        {
            printf -- '---\n'
            printf 'description: "%s"\n' "$desc"
            printf 'source: "claude-commands-mirror"\n'
            printf -- '---\n'
            printf '\n'
            printf "Invoke the \`%s\` skill from \`%s\`. Read the SKILL.md file and follow its procedure exactly.\n" \
                "$name" "$skill_md"
        } > "$out"
    fi
    KEEP+=("${name}.md")
    log_verbose "  mirrored: $name → $out"
done

# Prune stale managed commands — only files this script owns (source: "claude-commands-mirror").
for existing in "$DST"/*.md; do
    [[ -f "$existing" ]] || continue
    base="$(basename "$existing")"
    in_keep=0
    for k in "${KEEP[@]+"${KEEP[@]}"}"; do
        [[ "$k" == "$base" ]] && in_keep=1 && break
    done
    if [[ $in_keep -eq 0 ]] && grep -q '^source: "claude-commands-mirror"' "$existing" 2>/dev/null; then
        if [[ "$WHAT_IF" -eq 0 ]]; then
            rm -f "$existing"
        fi
        log_verbose "  pruned stale: $base"
    fi
done

log_info "Mirrored ${#KEEP[@]} skill(s) to $DST"
