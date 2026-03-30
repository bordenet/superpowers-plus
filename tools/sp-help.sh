#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# tools/sp-help.sh
# PURPOSE: Comprehensive reference for the superpowers skill ecosystem.
#          Shows credits, overlays, CLI commands, and all installed skills
#          grouped by source with descriptions.
# USAGE: sp-help [--skills] [--commands] [--overlays] [--all] [--compact]
# INSTALLED TO: ~/.codex/superpowers-plus/tools/sp-help.sh
# SYMLINKED TO: <bin_dir>/sp-help (by install.sh)
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Colors (disabled if not a terminal) ---
if [[ -t 1 ]]; then
    BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'; ULINE='\033[4m'
    CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; WHITE='\033[1;37m'
else
    BOLD=''; DIM=''; RESET=''; ULINE=''
    CYAN=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; WHITE=''
fi

SKILLS_DIR="$HOME/.codex/skills"
SPP_DIR="$HOME/.codex/superpowers-plus"
ENV_FILE="$HOME/.codex/.env"

# --- Helpers ---

# Extract a YAML frontmatter field from a skill.md file
# Handles quoted values (preserves # inside quotes) and strips inline comments only
# when the value is unquoted. Does NOT handle block scalars (|, >).
_fm_field() {
    local file="$1" field="$2"
    awk -v f="$field" '
        /^---$/ { n++; next }
        n==1 && $0 ~ "^"f":" {
            sub("^"f": *", "")
            # If value is a block scalar indicator, skip it
            if ($0 ~ /^[|>][ ]*$/) { print ""; exit }
            # Trim trailing whitespace FIRST (before quote detection)
            sub(/[ \t]+$/, "")
            # Strip surrounding quotes if present
            if ($0 ~ /^".*"$/) {
                sub(/^"/, ""); sub(/"$/, "")
            } else if ($0 ~ /^'"'"'.*'"'"'$/) {
                sub(/^'"'"'/, ""); sub(/'"'"'$/, "")
            } else {
                # Unquoted: strip trailing inline comment
                sub(/ +#.*$/, "")
                sub(/[ \t]+$/, "")
            }
            print; exit
        }
    ' "$file" 2>/dev/null || true
}

# Truncate string to max length with ellipsis
_trunc() {
    local s="$1" max="${2:-72}"
    if [[ ${#s} -gt $max ]]; then
        echo "${s:0:$((max - 3))}..."
    else
        echo "$s"
    fi
}

# Map source name to display label
_source_label() {
    case "$1" in
        superpowers-plus)     echo "superpowers-plus (base framework)" ;;
        superpowers-[company])  echo "superpowers-[company] ([Company])" ;;
        superpowers-[product])     echo "superpowers-[product] ([PRODUCT] / Team Delta)" ;;
        unknown)              echo "other" ;;
        *)                    echo "$1" ;;
    esac
}

# --- Sections ---

show_header() {
    echo -e "${WHITE}⚡ Superpowers${RESET} ${DIM}— AI coding skill ecosystem${RESET}"
    echo ""
    echo -e "  ${DIM}Upstream:${RESET}  ${ULINE}https://github.com/obra/superpowers${RESET}"
    echo -e "  ${DIM}Extended:${RESET}  ${ULINE}https://github.com/bordenet/superpowers-plus${RESET}"
    local spp_version=""
    if [[ -d "$SPP_DIR/.git" ]] && command -v git >/dev/null 2>&1; then
        spp_version=$(cd "$SPP_DIR" && git log --oneline -1 2>/dev/null | cut -c1-7) || true
    fi
    if [[ -n "$spp_version" ]]; then
        echo -e "  ${DIM}Version:${RESET}   ${spp_version}"
    fi
    echo ""
}

show_overlays() {
    echo -e "${BOLD}Installed Overlays${RESET}"
    echo ""

    # Always show superpowers-plus as the base
    local spp_url=""
    if [[ -d "$SPP_DIR/.git" ]] && command -v git >/dev/null 2>&1; then
        spp_url=$(cd "$SPP_DIR" && git remote get-url origin 2>/dev/null) || true
    fi
    local spp_count=0
    for d in "$SKILLS_DIR"/*/; do
        [[ -d "$d" && -f "$d/skill.md" ]] || continue
        local src
        src=$(_fm_field "$d/skill.md" "source")
        [[ "$src" == "superpowers-plus" ]] && spp_count=$((spp_count + 1))
    done
    echo -e "  ${GREEN}superpowers-plus${RESET} ${DIM}(base · ${spp_count} skills)${RESET}"
    [[ -n "$spp_url" ]] && echo -e "    ${DIM}${spp_url}${RESET}"

    # Read overlay registrations from .env
    if [[ -f "$ENV_FILE" ]]; then
        local seen_names=""
        while IFS= read -r line; do
            # Match lines like FOO_SOURCE_DIR="..."
            if [[ "$line" =~ ^[A-Z_]+SOURCE_DIR=[\"\']?(.+)[\"\']?$ ]] || \
               [[ "$line" =~ ^[A-Z_]+OVERLAY[A-Z_]*=[\"\']?(.+)[\"\']?$ ]]; then
                local dir="${BASH_REMATCH[1]}"
                dir="${dir%\"}"
                dir="${dir%\'}"
                # Expand ~ and $HOME
                dir="${dir/#\~/$HOME}"
                dir="${dir/\$HOME/$HOME}"
                [[ -d "$dir" ]] || continue
                local overlay_name
                overlay_name=$(basename "$dir")
                # Skip superpowers-plus (already shown) and local overlay
                [[ "$overlay_name" == "superpowers-plus" ]] && continue
                # Deduplicate by overlay name (newline-separated list)
                case "$seen_names" in
                    *"|${overlay_name}|"*) continue ;;
                esac
                seen_names="${seen_names}|${overlay_name}|"
                # Count skills from this source
                local ov_count=0
                for d in "$SKILLS_DIR"/*/; do
                    [[ -d "$d" && -f "$d/skill.md" ]] || continue
                    local src
                    src=$(_fm_field "$d/skill.md" "source")
                    [[ "$src" == "$overlay_name" ]] && ov_count=$((ov_count + 1))
                done
                [[ $ov_count -eq 0 ]] && continue
                local ov_url=""
                if [[ -d "$dir/.git" ]] && command -v git >/dev/null 2>&1; then
                    ov_url=$(cd "$dir" && git remote get-url origin 2>/dev/null) || true
                fi
                echo -e "  ${GREEN}${overlay_name}${RESET} ${DIM}(${ov_count} skills)${RESET}"
                [[ -n "$ov_url" ]] && echo -e "    ${DIM}${ov_url}${RESET}"
            fi
        done < "$ENV_FILE"
    fi
    echo ""
}

show_commands() {
    echo -e "${BOLD}CLI Commands${RESET}"
    echo ""
    local found=0
    for candidate in /usr/local/bin "$HOME/.local/bin" "$HOME/bin"; do
        [[ -d "$candidate" ]] || continue
        for link in "$candidate"/sp-*; do
            [[ -e "$link" ]] || continue
            local cmd
            cmd=$(basename "$link")
            local target=""
            if [[ -L "$link" ]]; then
                target=$(readlink "$link" 2>/dev/null || true)
                target=" → $(basename "$target")"
            fi
            echo -e "  ${GREEN}${cmd}${RESET}${DIM}${target}${RESET}"
            found=$((found + 1))
        done
    done
    if [[ $found -eq 0 ]]; then
        echo -e "  ${DIM}(none installed)${RESET}"
    fi
    echo ""
}

show_skills() {
    local compact="${1:-false}"

    if [[ ! -d "$SKILLS_DIR" ]]; then
        echo -e "  ${YELLOW}Skills directory not found${RESET}"
        return
    fi

    # Build a temp file with source|name|description for all skills
    local tmpfile
    tmpfile=$(mktemp "${TMPDIR:-/tmp}/sp-help.XXXXXX") || return
    trap 'rm -f -- "$tmpfile"' RETURN

    local total=0

    for skill_dir in "$SKILLS_DIR"/*/; do
        [[ -d "$skill_dir" ]] || continue
        # Only count directories that contain skill.md
        [[ -f "$skill_dir/skill.md" ]] || continue
        local name
        name=$(basename "$skill_dir")
        [[ "$name" == "_shared" ]] && continue
        total=$((total + 1))

        local source=""
        local desc=""
        source=$(_fm_field "$skill_dir/skill.md" "source")
        [[ -z "$source" ]] && source="unknown"
        if [[ "$compact" != "true" ]]; then
            desc=$(_fm_field "$skill_dir/skill.md" "summary")
            [[ -z "$desc" ]] && desc=$(_fm_field "$skill_dir/skill.md" "description")
            if [[ -n "$desc" ]]; then
                desc=$(_trunc "$desc" 68)
            fi
        fi
        # Use tab as delimiter (safe — no tabs in source names or skill names)
        printf '%s\t%s\t%s\n' "$source" "$name" "$desc" >> "$tmpfile"
    done

    # Source display labels (defined at top level as _source_label)

    # Get sorted unique sources: superpowers-plus first, then alpha
    local sources_list
    sources_list=$(cut -f1 "$tmpfile" | sort -u | grep -v '^superpowers-plus$' || true)
    local num_sources=0

    # Helper: print skills for a given source (exact field match via awk)
    _print_source_group() {
        local src="$1" file="$2"
        local label count
        label=$(_source_label "$src")
        count=$(awk -F'\t' -v s="$src" '$1 == s { n++ } END { print n+0 }' "$file")
        [[ "$count" -eq 0 ]] && return 1
        echo -e "${BOLD}${label}${RESET} ${DIM}(${count} skills)${RESET}"
        echo ""
        awk -F'\t' -v s="$src" '$1 == s' "$file" | sort -t'	' -k2,2 | while IFS='	' read -r _src sname sdesc; do
            if [[ -n "$sdesc" ]]; then
                printf "  ${CYAN}%-38s${RESET} ${DIM}%s${RESET}\n" "$sname" "$sdesc"
            else
                echo -e "  ${CYAN}${sname}${RESET}"
            fi
        done
        echo ""
        return 0
    }

    # superpowers-plus first (if present)
    if _print_source_group "superpowers-plus" "$tmpfile"; then
        num_sources=$((num_sources + 1))
    fi

    # Remaining sources alphabetically
    if [[ -n "$sources_list" ]]; then
        while IFS= read -r src; do
            [[ -z "$src" ]] && continue
            if _print_source_group "$src" "$tmpfile"; then
                num_sources=$((num_sources + 1))
            fi
        done <<< "$sources_list"
    fi

    echo -e "  ${WHITE}${total}${RESET} skills installed across ${WHITE}${num_sources}${RESET} sources"
    echo ""
    echo -e "  ${DIM}Wiki:${RESET}  ${ULINE}https://cb-outline.getoutline.com/doc/superpowers-skills-cASQJAkNFD${RESET}"
    echo -e "  ${DIM}Audit:${RESET} ${ULINE}https://cb-outline.getoutline.com/doc/superpowers-audit-JZXrdyVBFg${RESET}"
    echo ""
}

show_summary() {
    # Quick skill counts per source without listing individual skills
    if [[ ! -d "$SKILLS_DIR" ]]; then
        echo -e "  ${YELLOW}Skills directory not found${RESET}"
        return
    fi

    echo -e "${BOLD}Installed Skills${RESET}"
    echo ""

    # Count skills per source in a single pass
    local total=0
    local counts_file
    counts_file=$(mktemp "${TMPDIR:-/tmp}/sp-counts.XXXXXX") || return
    trap 'rm -f -- "$counts_file"' RETURN

    for skill_dir in "$SKILLS_DIR"/*/; do
        [[ -d "$skill_dir" && -f "$skill_dir/skill.md" ]] || continue
        local name
        name=$(basename "$skill_dir")
        [[ "$name" == "_shared" ]] && continue
        total=$((total + 1))
        local source=""
        source=$(_fm_field "$skill_dir/skill.md" "source")
        [[ -z "$source" ]] && source="unknown"
        echo "$source" >> "$counts_file"
    done

    # superpowers-plus first, then others alphabetically
    if [[ -f "$counts_file" ]]; then
        # Use awk for all counting — avoids grep exit-code issues under set -e
        awk '
            { counts[$0]++ }
            END {
                # superpowers-plus first
                if ("superpowers-plus" in counts) {
                    printf "SPP\t%d\n", counts["superpowers-plus"]
                    delete counts["superpowers-plus"]
                }
                # remaining sources alphabetically
                n = 0
                for (s in counts) { sorted[n++] = s }
                for (i = 0; i < n; i++)
                    for (j = i+1; j < n; j++)
                        if (sorted[i] > sorted[j]) { t = sorted[i]; sorted[i] = sorted[j]; sorted[j] = t }
                for (i = 0; i < n; i++)
                    printf "OTHER\t%d\t%s\n", counts[sorted[i]], sorted[i]
            }
        ' "$counts_file" | while IFS='	' read -r tag cnt src; do
            if [[ "$tag" == "SPP" ]]; then
                echo -e "  ${GREEN}superpowers-plus${RESET} ${DIM}(base framework · ${cnt} skills)${RESET}"
            else
                local label
                label=$(_source_label "$src")
                echo -e "  ${GREEN}${label}${RESET} ${DIM}(${cnt} skills)${RESET}"
            fi
        done
    fi

    echo ""
    echo -e "  ${WHITE}${total}${RESET} skills total"
    echo -e "  ${DIM}Run ${RESET}sp-help --skills${DIM} to see all skills with descriptions${RESET}"
    echo ""
}

show_usage() {
    echo -e "${WHITE}sp-help${RESET} — Superpowers ecosystem reference"
    echo ""
    echo "Usage: sp-help [--skills | --commands | --overlays | --all | --compact]"
    echo ""
    echo "  (default)    Overview: credits, overlays, commands, and skill counts"
    echo "  --skills     List all installed skills grouped by source"
    echo "  --commands   List sp-* CLI commands"
    echo "  --overlays   Show installed overlay repos"
    echo "  --all        Show everything including full skill listing"
    echo "  --compact    Full listing without skill descriptions"
    echo ""
    echo "For AI-assisted help, ask your agent: \"what superpowers do I have?\""
    echo ""
}

# --- Main ---
mode="default"
compact="false"
for arg in "$@"; do
    case "$arg" in
        --skills)    mode="skills" ;;
        --commands)  mode="commands" ;;
        --overlays)  mode="overlays" ;;
        --all)       mode="all" ;;
        --compact)   compact="true" ;;
        -h|--help)   show_usage; exit 0 ;;
        *)
            echo "Unknown option: $arg" >&2
            show_usage
            exit 1
            ;;
    esac
done

# --compact without explicit mode implies --all (full listing, no descriptions)
if [[ "$compact" == "true" && "$mode" == "default" ]]; then
    mode="all"
fi

echo ""
case "$mode" in
    skills)    show_skills "$compact" ;;
    commands)  show_commands ;;
    overlays)  show_header; show_overlays ;;
    all)       show_header; show_overlays; show_commands; show_skills "$compact" ;;
    default)   show_header; show_overlays; show_commands; show_summary ;;
esac
