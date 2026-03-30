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
_fm_field() {
    local file="$1" field="$2"
    awk -v f="$field" '
        /^---$/ { n++; next }
        n==1 && $0 ~ "^"f":" {
            sub("^"f": *", ""); gsub(/^"/, ""); gsub(/"$/, ""); gsub(/ *#.*$/, ""); print; exit
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

# --- Sections ---

show_header() {
    echo -e "${WHITE}⚡ Superpowers${RESET} ${DIM}— AI coding skill ecosystem${RESET}"
    echo ""
    echo -e "  ${DIM}Upstream:${RESET}  ${ULINE}https://github.com/obra/superpowers${RESET}"
    echo -e "  ${DIM}Extended:${RESET}  ${ULINE}https://github.com/bordenet/superpowers-plus${RESET}"
    local spp_version=""
    if [[ -d "$SPP_DIR/.git" ]]; then
        spp_version=$(cd "$SPP_DIR" && git log --oneline -1 2>/dev/null | cut -c1-7)
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
    if [[ -d "$SPP_DIR/.git" ]]; then
        spp_url=$(cd "$SPP_DIR" && git remote get-url origin 2>/dev/null || true)
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
        declare -A seen_names
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
                # Deduplicate by overlay name
                [[ -n "${seen_names[$overlay_name]+x}" ]] && continue
                seen_names[$overlay_name]=1
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
                if [[ -d "$dir/.git" ]]; then
                    ov_url=$(cd "$dir" && git remote get-url origin 2>/dev/null || true)
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

    # Collect skills grouped by source
    declare -A source_skills
    declare -A source_order
    local total=0
    local order_idx=0

    for skill_dir in "$SKILLS_DIR"/*/; do
        [[ -d "$skill_dir" ]] || continue
        local name
        name=$(basename "$skill_dir")
        [[ "$name" == "_shared" ]] && continue
        total=$((total + 1))

        local source="unknown"
        local desc=""
        if [[ -f "$skill_dir/skill.md" ]]; then
            source=$(_fm_field "$skill_dir/skill.md" "source")
            [[ -z "$source" ]] && source="unknown"
            if [[ "$compact" != "true" ]]; then
                desc=$(_fm_field "$skill_dir/skill.md" "summary")
                [[ -z "$desc" ]] && desc=$(_fm_field "$skill_dir/skill.md" "description")
            fi
        fi

        # Track source ordering (first-seen order)
        if [[ -z "${source_order[$source]+x}" ]]; then
            source_order[$source]=$order_idx
            order_idx=$((order_idx + 1))
        fi

        # Build entry
        if [[ -n "$desc" ]]; then
            desc=$(_trunc "$desc" 68)
            source_skills[$source]+="  ${name}|${desc}"$'\n'
        else
            source_skills[$source]+="  ${name}|"$'\n'
        fi
    done

    # Display source labels
    declare -A source_labels
    source_labels[superpowers-plus]="superpowers-plus (base framework)"
    source_labels[superpowers-[company]]="superpowers-[company] ([Company])"
    source_labels[superpowers-[product]]="superpowers-[product] ([PRODUCT] / Team Delta)"
    source_labels[unknown]="other"

    # Sort sources: superpowers-plus first, then alphabetical
    local sorted_sources=()
    [[ -n "${source_skills[superpowers-plus]+x}" ]] && sorted_sources+=("superpowers-plus")
    for src in $(echo "${!source_skills[@]}" | tr ' ' '\n' | sort); do
        [[ "$src" == "superpowers-plus" ]] && continue
        sorted_sources+=("$src")
    done

    for src in "${sorted_sources[@]}"; do
        local label="${source_labels[$src]:-$src}"
        local count
        count=$(echo -n "${source_skills[$src]}" | grep -c '.' || true)
        echo -e "${BOLD}${label}${RESET} ${DIM}(${count} skills)${RESET}"
        echo ""
        # Sort and print skills within this source
        echo -n "${source_skills[$src]}" | sort | while IFS='|' read -r sname sdesc; do
            sname="${sname## }"
            if [[ -n "$sdesc" ]]; then
                printf "  ${CYAN}%-38s${RESET} ${DIM}%s${RESET}\n" "$sname" "$sdesc"
            else
                echo -e "  ${CYAN}${sname}${RESET}"
            fi
        done
        echo ""
    done

    echo -e "  ${WHITE}${total}${RESET} skills installed across ${WHITE}${#sorted_sources[@]}${RESET} sources"
    echo ""
    echo -e "  ${DIM}Wiki:${RESET}  ${ULINE}https://cb-outline.getoutline.com/doc/superpowers-skills-cASQJAkNFD${RESET}"
    echo -e "  ${DIM}Audit:${RESET} ${ULINE}https://cb-outline.getoutline.com/doc/superpowers-audit-JZXrdyVBFg${RESET}"
    echo ""
}

show_usage() {
    echo -e "${WHITE}sp-help${RESET} — Superpowers ecosystem reference"
    echo ""
    echo "Usage: sp-help [--skills | --commands | --overlays | --all | --compact]"
    echo ""
    echo "  --skills     List installed skills grouped by source"
    echo "  --commands   List sp-* CLI commands"
    echo "  --overlays   Show installed overlay repos"
    echo "  --all        Show everything (default)"
    echo "  --compact    Show everything without skill descriptions"
    echo ""
    echo "For AI-assisted help, ask your agent: \"what superpowers do I have?\""
    echo ""
}

# --- Main ---
mode="all"
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

echo ""
case "$mode" in
    skills)    show_skills "$compact" ;;
    commands)  show_commands ;;
    overlays)  show_header; show_overlays ;;
    all)       show_header; show_overlays; show_commands; show_skills "$compact" ;;
esac
