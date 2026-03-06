#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# skill-trigger-validator.sh
# PURPOSE: Validate skill triggers - detect overlaps, missing triggers, and
#          ensure all skills have machine-readable trigger definitions.
# USAGE: ./tools/skill-trigger-validator.sh [command]
#        Commands: audit, overlaps, missing, registry
# -----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/../skills"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Extract triggers from skill.md YAML frontmatter
# Looks for: triggers: ["phrase1", "phrase2"] or description with "Triggers on" / "Use when"
extract_triggers() {
    local skill_file="$1"
    local skill_name
    skill_name=$(basename "$(dirname "$skill_file")")

    # Try to extract from 'triggers:' field first (preferred - new format)
    local triggers
    triggers=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep -E "^triggers:" | sed 's/triggers://' | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*"//;s/"[[:space:]]*$//' | grep -v '^$' | grep -v '^triggers')

    if [[ -z "$triggers" ]]; then
        # Fall back to extracting quoted phrases from description
        local desc_line
        desc_line=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep -E "^description:")

        if echo "$desc_line" | grep -qE "(Triggers on|Use when|triggers on)"; then
            # Extract quoted strings after trigger keywords
            triggers=$(echo "$desc_line" | sed -E 's/.*(Triggers on|Use when|triggers on)//' | grep -oE '"[^"]+"' | tr -d '"' | grep -v '^$')
        fi

        # If still empty, try extracting all quoted strings that look like triggers
        if [[ -z "$triggers" ]]; then
            triggers=$(echo "$desc_line" | grep -oE "'[^']+'" | tr -d "'" | grep -v '^$' | head -10)
        fi
    fi

    # Filter out any remaining noise
    echo "$triggers" | grep -v '^description' | grep -v '^name' | grep -v '^\s*$' | head -20
}

# Build registry of all triggers -> skills
build_registry() {
    log_info "Building trigger registry from $SKILLS_DIR..."
    echo ""
    
    local total_triggers=0
    local total_skills=0
    
    while IFS= read -r skill_file; do
        local skill_name
        skill_name=$(basename "$(dirname "$skill_file")")
        local domain
        domain=$(basename "$(dirname "$(dirname "$skill_file")")")
        
        ((total_skills++)) || true
        
        local triggers
        triggers=$(extract_triggers "$skill_file")
        
        if [[ -n "$triggers" ]]; then
            echo -e "${GREEN}$domain/$skill_name${NC}:"
            while IFS= read -r trigger; do
                if [[ -n "$trigger" ]]; then
                    echo "  - \"$trigger\""
                    ((total_triggers++)) || true
                fi
            done <<< "$triggers"
            echo ""
        else
            echo -e "${YELLOW}$domain/$skill_name${NC}: (no triggers found)"
            echo ""
        fi
    done < <(find "$SKILLS_DIR" -name "skill.md" -type f | sort)
    
    echo "---"
    log_info "Total: $total_skills skills, $total_triggers triggers"
}

# Intentional overlaps (skill pairs that SHOULD share triggers)
# Format: "skill1:skill2" (alphabetical order)
ALLOWED_OVERLAPS=(
    # Wiki skill dependency chain - link-verification is a prerequisite
    "link-verification:wiki-editing"          # link-verification fires before wiki-editing
    "link-verification:wiki-orchestrator"     # link-verification fires before wiki-orchestrator
    # Research skills - both activate on "stuck" patterns
    "perplexity-research:think-twice"         # Both help when stuck, user chooses approach
)

is_allowed_overlap() {
    local skill1="$1"
    local skill2="$2"

    # Sort alphabetically for consistent comparison
    if [[ "$skill1" > "$skill2" ]]; then
        local tmp="$skill1"
        skill1="$skill2"
        skill2="$tmp"
    fi

    local pair="$skill1:$skill2"
    for allowed in "${ALLOWED_OVERLAPS[@]}"; do
        if [[ "$pair" == "$allowed" ]]; then
            return 0
        fi
    done
    return 1
}

# Detect overlapping triggers between skills
detect_overlaps() {
    log_info "Checking for trigger phrase overlaps..."
    echo ""

    # Build trigger -> skill mapping using temp file (more portable than associative arrays)
    local temp_file
    temp_file=$(mktemp)
    trap "rm -f $temp_file" EXIT

    local overlaps=0
    local allowed_overlaps=0

    # First pass: collect all triggers
    while IFS= read -r skill_file; do
        local skill_name
        skill_name=$(basename "$(dirname "$skill_file")")

        local triggers
        triggers=$(extract_triggers "$skill_file")

        while IFS= read -r trigger; do
            if [[ -n "$trigger" ]]; then
                local normalized
                normalized=$(echo "$trigger" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | tr -s ' ')
                echo "$normalized|$skill_name" >> "$temp_file"
            fi
        done <<< "$triggers"
    done < <(find "$SKILLS_DIR" -name "skill.md" -type f | sort)

    # Second pass: find duplicates
    local prev_trigger="" prev_skill=""
    while IFS='|' read -r trigger skill; do
        if [[ "$trigger" == "$prev_trigger" && -n "$trigger" ]]; then
            if is_allowed_overlap "$prev_skill" "$skill"; then
                log_info "ALLOWED OVERLAP: \"$trigger\" ($prev_skill ↔ $skill)"
                ((allowed_overlaps++)) || true
            else
                log_warn "UNEXPECTED OVERLAP: \"$trigger\""
                echo "  - $prev_skill"
                echo "  - $skill"
                ((overlaps++)) || true
            fi
        fi
        prev_trigger="$trigger"
        prev_skill="$skill"
    done < <(sort "$temp_file")

    echo ""
    if [[ $overlaps -eq 0 ]]; then
        log_success "No unexpected overlaps ($allowed_overlaps intentional overlap(s) found)"
        return 0
    else
        log_error "$overlaps unexpected overlap(s) found"
        return 1
    fi
}

# Find skills with missing or weak trigger definitions  
find_missing() {
    log_info "Checking for skills with missing triggers..."
    echo ""
    
    local missing=0
    
    while IFS= read -r skill_file; do
        local skill_name
        skill_name=$(basename "$(dirname "$skill_file")")
        local domain
        domain=$(basename "$(dirname "$(dirname "$skill_file")")")
        
        local triggers
        triggers=$(extract_triggers "$skill_file")
        local count
        count=$(echo "$triggers" | grep -c . || echo 0)
        
        if [[ $count -lt 2 ]]; then
            log_warn "$domain/$skill_name: only $count trigger(s) defined"
            ((missing++)) || true
        fi
    done < <(find "$SKILLS_DIR" -name "skill.md" -type f | sort)
    
    echo ""
    if [[ $missing -eq 0 ]]; then
        log_success "All skills have adequate trigger definitions"
    else
        log_warn "$missing skill(s) have weak trigger coverage"
    fi
}

# Full audit
full_audit() {
    echo "========================================"
    echo "  Skill Trigger Validation Audit"
    echo "========================================"
    echo ""
    
    detect_overlaps
    echo ""
    find_missing
    echo ""
    
    log_info "Registry summary:"
    build_registry | tail -5
}

# Main
case "${1:-audit}" in
    registry)
        build_registry
        ;;
    overlaps)
        detect_overlaps
        ;;
    missing)
        find_missing
        ;;
    audit)
        full_audit
        ;;
    *)
        echo "Usage: $0 [audit|registry|overlaps|missing]"
        exit 1
        ;;
esac

