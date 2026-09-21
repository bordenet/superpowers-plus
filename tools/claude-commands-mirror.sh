#!/usr/bin/env bash
# claude-commands-mirror.sh — emit one ~/.claude/commands/<skill>.md per Augment skill.
# Item 5 of the Claude Code 12-point guardrails plan.
# Source: ~/.agents/skills/ (Augment IDE slash menu, SKILL.md format).
# Target: ~/.claude/commands/ (Claude Code custom slash commands).
# Idempotent: overwrites on each run, prunes stale managed entries.
#
# Dedup: deploy installs aliased skills under their /sp-* trigger directory
# name (e.g. ~/.claude/skills/sp-debate) while the skill's own frontmatter
# `name:` stays the original (e.g. "debate") -- so a naive
# `-d "$SKILLS_DIR/$name"` check never matches an aliased skill, and every
# one gets ALSO mirrored as a second, model-visible command, duplicating the
# resident skill listing. Fix: index the frontmatter `name:` of every
# installed skill once, and treat a source as a duplicate if its name is
# either a $SKILLS_DIR/<name> directory OR appears in that index (covers the
# aliased/renamed-directory case). Duplicates still get a command file --
# users type /debate and /progressive-harsh-review daily and it must keep
# working -- but it carries `disable-model-invocation: true` so it costs
# zero resident context: hidden from the model, still runnable by the user.
#
# Also skips stale Codex "migrate from Claude" imports (source-command-*
# directories whose SKILL.md body says "migrated source command") entirely;
# any such command mirrored by a prior run is pruned.
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

A source whose frontmatter \`name:\` matches an installed skill under
\$CLAUDE_SKILLS_DIR (directly at \$SKILLS_DIR/<name>/, or indirectly via an
aliased /sp-* install directory whose own frontmatter name is <name>) is
already resident and model-visible there -- its mirrored command is still
written (so /<name> keeps working) but with \`disable-model-invocation: true\`,
hiding it from the model to avoid duplicating the skill listing.

Sources named source-command-* (or whose SKILL.md body says "migrated
source command") are stale Codex-migration imports and are skipped
entirely; any command previously mirrored for one is pruned.

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

# Build the installed-skill name index once: the frontmatter `name:` of
# every $SKILLS_DIR/*/{skill.md,SKILL.md}. Keyed by frontmatter name (not
# directory name) so an aliased install directory (e.g. sp-debate, whose
# frontmatter name is "debate") is still caught as a duplicate of "debate".
declare -A INSTALLED_NAME=()
if [[ -d "$SKILLS_DIR" ]]; then
    for installed_md in "$SKILLS_DIR"/*/skill.md "$SKILLS_DIR"/*/SKILL.md; do
        [[ -f "$installed_md" ]] || continue
        installed_name="$(awk '/^name:/{$1=""; sub(/^ /,""); gsub(/"/,""); print; exit}' "$installed_md")"
        [[ -n "$installed_name" ]] && INSTALLED_NAME["$installed_name"]=1
    done
fi

declare -a KEEP=()
mirrored_visible=0
mirrored_hidden_alias=0
skipped_source_command=0

for skill_dir in "$SRC"/*/; do
    [[ -f "$skill_dir/SKILL.md" ]] || continue

    skill_md="$skill_dir/SKILL.md"
    name="$(awk '/^name:/{$1=""; sub(/^ /,""); gsub(/"/,""); print; exit}' "$skill_md")"
    desc="$(awk '/^description:/{$1=""; sub(/^ /,""); gsub(/^"|"$/,""); print; exit}' "$skill_md")"

    [[ -z "$name" ]] && { log_warn "no name: in $skill_md — skipping"; continue; }
    [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || { log_warn "invalid name in $skill_md — skipping"; continue; }

    # Stale Codex "migrate from Claude" imports: never mirrored. Any
    # previously-mirrored command for one is caught by the prune pass below
    # (it simply is never added to KEEP).
    if [[ "$name" == source-command-* ]] || grep -q "migrated source command" "$skill_md" 2>/dev/null; then
        log_verbose "  skipped (source-command import): $name"
        skipped_source_command=$((skipped_source_command + 1))
        continue
    fi

    # Duplicate detection: the skill is already resident and model-visible
    # under $SKILLS_DIR, either directly ($SKILLS_DIR/$name/) or via an
    # aliased /sp-* install directory whose frontmatter name is $name.
    is_dup=0
    if [[ -d "$SKILLS_DIR/$name" ]] || [[ -n "${INSTALLED_NAME[$name]+x}" ]]; then
        is_dup=1
    fi

    out="$DST/${name}.md"
    if [[ "$WHAT_IF" -eq 0 ]]; then
        {
            printf -- '---\n'
            printf 'description: "%s"\n' "$desc"
            printf 'source: "claude-commands-mirror"\n'
            if [[ "$is_dup" -eq 1 ]]; then
                printf 'disable-model-invocation: true\n'
            fi
            printf -- '---\n'
            printf '\n'
            printf "Invoke the \`%s\` skill from \`%s\`. Read the SKILL.md file and follow its procedure exactly.\n" \
                "$name" "$skill_md"
        } > "$out"
    fi
    KEEP+=("${name}.md")
    if [[ "$is_dup" -eq 1 ]]; then
        mirrored_hidden_alias=$((mirrored_hidden_alias + 1))
        log_verbose "  mirrored (hidden alias, resident in $SKILLS_DIR): $name → $out"
    else
        mirrored_visible=$((mirrored_visible + 1))
        log_verbose "  mirrored: $name → $out"
    fi
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

log_info "Mirrored ${#KEEP[@]} skill(s) to $DST (visible=$mirrored_visible, hidden-alias=$mirrored_hidden_alias, skipped-source-command=$skipped_source_command)"
