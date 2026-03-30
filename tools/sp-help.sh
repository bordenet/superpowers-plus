#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# tools/sp-help.sh
# PURPOSE: Show available superpowers skills and CLI commands.
#          Provides quick reference without needing an AI session.
# USAGE: sp-help [--skills] [--commands] [--all]
# INSTALLED TO: ~/.codex/superpowers-plus/tools/sp-help.sh
# SYMLINKED TO: <bin_dir>/sp-help (by install.sh)
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Colors (disabled if not a terminal) ---
if [[ -t 1 ]]; then
    BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
    CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
else
    BOLD=''; DIM=''; RESET=''; CYAN=''; GREEN=''; YELLOW=''
fi

SKILLS_DIR="$HOME/.codex/skills"

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
    echo -e "${BOLD}Installed Skills${RESET} (${SKILLS_DIR})"
    echo ""
    if [[ -d "$SKILLS_DIR" ]]; then
        local count=0
        for skill_dir in "$SKILLS_DIR"/*/; do
            [[ -d "$skill_dir" ]] || continue
            local name
            name=$(basename "$skill_dir")
            local desc=""
            if [[ -f "$skill_dir/skill.md" ]]; then
                # Extract description from YAML frontmatter
                desc=$(sed -n '/^---$/,/^---$/{ /^description:/{ s/^description: *//; s/^"//; s/"$//; p; q; } }' "$skill_dir/skill.md" 2>/dev/null || true)
            fi
            if [[ -n "$desc" ]]; then
                # Truncate long descriptions
                if [[ ${#desc} -gt 70 ]]; then
                    desc="${desc:0:67}..."
                fi
                echo -e "  ${CYAN}${name}${RESET} ${DIM}— ${desc}${RESET}"
            else
                echo -e "  ${CYAN}${name}${RESET}"
            fi
            count=$((count + 1))
        done
        echo ""
        echo -e "  ${BOLD}${count}${RESET} skill(s) installed"
    else
        echo -e "  ${YELLOW}Skills directory not found${RESET}"
    fi
    echo ""
}

show_usage() {
    echo -e "${BOLD}sp-help${RESET} — Superpowers quick reference"
    echo ""
    echo "Usage: sp-help [--skills | --commands | --all]"
    echo ""
    echo "  --skills     List installed skills with descriptions"
    echo "  --commands   List sp-* CLI commands"
    echo "  --all        Show everything (default)"
    echo ""
    echo "For AI-assisted help, ask your agent: \"what superpowers do I have?\""
    echo ""
}

# --- Main ---
mode="all"
for arg in "$@"; do
    case "$arg" in
        --skills)   mode="skills" ;;
        --commands) mode="commands" ;;
        --all)      mode="all" ;;
        -h|--help)  show_usage; exit 0 ;;
        *)
            echo "Unknown option: $arg" >&2
            show_usage
            exit 1
            ;;
    esac
done

echo ""
case "$mode" in
    skills)   show_skills ;;
    commands) show_commands ;;
    all)      show_commands; show_skills ;;
esac
