#!/bin/bash
# slop-infrastructure.sh
# Manages shared infrastructure for detecting-ai-slop and eliminating-ai-slop skills
# Usage: ./slop-infrastructure.sh <command> [workspace_root]
#
# Commands:
#   init       - Initialize dictionary and metrics files in workspace
#   status     - Show current dictionary and metrics summary
#   reset      - Reset metrics (keeps dictionary)
#   gitignore  - Add slop files to .gitignore

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="${2:-$(pwd)}"
DICTIONARY_FILE="$WORKSPACE_ROOT/.slop-dictionary.json"
METRICS_FILE="$WORKSPACE_ROOT/.slop-metrics.json"
GITIGNORE_FILE="$WORKSPACE_ROOT/.gitignore"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default dictionary with built-in patterns
DEFAULT_DICTIONARY='{
  "version": "1.0",
  "created": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
  "patterns": [],
  "exceptions": []
}'

# Default metrics
DEFAULT_METRICS='{
  "version": "1.0",
  "created": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
  "detection": {
    "documents_analyzed": 0,
    "total_patterns_found": 0,
    "by_category": {
      "generic-booster": 0,
      "buzzword": 0,
      "filler-phrase": 0,
      "hedge-pattern": 0,
      "sycophantic-phrase": 0,
      "transitional-filler": 0
    },
    "average_slop_score": 0
  },
  "elimination": {
    "documents_processed": 0,
    "patterns_fixed": 0,
    "user_kept": 0,
    "false_positives_reported": 0
  }
}'

init_infrastructure() {
    echo -e "${GREEN}Initializing slop infrastructure in: $WORKSPACE_ROOT${NC}"
    
    # Create dictionary if not exists
    if [ ! -f "$DICTIONARY_FILE" ]; then
        echo "$DEFAULT_DICTIONARY" > "$DICTIONARY_FILE"
        echo -e "  ${GREEN}✓${NC} Created $DICTIONARY_FILE"
    else
        echo -e "  ${YELLOW}→${NC} Dictionary already exists: $DICTIONARY_FILE"
    fi
    
    # Create metrics if not exists
    if [ ! -f "$METRICS_FILE" ]; then
        echo "$DEFAULT_METRICS" > "$METRICS_FILE"
        echo -e "  ${GREEN}✓${NC} Created $METRICS_FILE"
    else
        echo -e "  ${YELLOW}→${NC} Metrics already exists: $METRICS_FILE"
    fi
    
    # Add to gitignore if git repo
    if [ -d "$WORKSPACE_ROOT/.git" ]; then
        add_to_gitignore
    else
        echo -e "  ${YELLOW}→${NC} Not a git repo, skipping .gitignore"
    fi
    
    echo -e "\n${GREEN}Infrastructure ready.${NC}"
}

add_to_gitignore() {
    local entries=(".slop-dictionary.json" ".slop-metrics.json")
    local added=0
    
    # Create .gitignore if not exists
    if [ ! -f "$GITIGNORE_FILE" ]; then
        touch "$GITIGNORE_FILE"
    fi
    
    for entry in "${entries[@]}"; do
        if ! grep -q "^$entry$" "$GITIGNORE_FILE" 2>/dev/null; then
            echo "$entry" >> "$GITIGNORE_FILE"
            echo -e "  ${GREEN}✓${NC} Added $entry to .gitignore"
            ((added++))
        fi
    done
    
    if [ $added -eq 0 ]; then
        echo -e "  ${YELLOW}→${NC} .gitignore already configured"
    fi
}

show_status() {
    echo -e "${GREEN}Slop Infrastructure Status${NC}"
    echo -e "Workspace: $WORKSPACE_ROOT\n"
    
    # Dictionary status
    if [ -f "$DICTIONARY_FILE" ]; then
        local pattern_count=$(jq '.patterns | length' "$DICTIONARY_FILE" 2>/dev/null || echo "0")
        local exception_count=$(jq '.exceptions | length' "$DICTIONARY_FILE" 2>/dev/null || echo "0")
        echo -e "${GREEN}Dictionary:${NC} $DICTIONARY_FILE"
        echo "  Patterns: $pattern_count"
        echo "  Exceptions: $exception_count"
    else
        echo -e "${RED}Dictionary:${NC} Not found"
    fi
    
    echo ""
    
    # Metrics status
    if [ -f "$METRICS_FILE" ]; then
        local docs_analyzed=$(jq '.detection.documents_analyzed' "$METRICS_FILE" 2>/dev/null || echo "0")
        local patterns_found=$(jq '.detection.total_patterns_found' "$METRICS_FILE" 2>/dev/null || echo "0")
        local docs_processed=$(jq '.elimination.documents_processed' "$METRICS_FILE" 2>/dev/null || echo "0")
        local patterns_fixed=$(jq '.elimination.patterns_fixed' "$METRICS_FILE" 2>/dev/null || echo "0")
        local avg_bf=$(jq '.detection.average_slop_score' "$METRICS_FILE" 2>/dev/null || echo "0")
        
        echo -e "${GREEN}Metrics:${NC} $METRICS_FILE"
        echo "  Detection:"
        echo "    Documents analyzed: $docs_analyzed"
        echo "    Patterns found: $patterns_found"
        echo "    Avg slop score: $avg_bf"
        echo "  Elimination:"
        echo "    Documents processed: $docs_processed"
        echo "    Patterns fixed: $patterns_fixed"
    else
        echo -e "${RED}Metrics:${NC} Not found"
    fi
}

reset_metrics() {
    echo -e "${YELLOW}Resetting metrics...${NC}"
    echo "$DEFAULT_METRICS" > "$METRICS_FILE"
    echo -e "${GREEN}✓${NC} Metrics reset to defaults"
}

# Main command handler
case "${1:-}" in
    init)
        init_infrastructure
        ;;
    status)
        show_status
        ;;
    reset)
        reset_metrics
        ;;
    gitignore)
        add_to_gitignore
        ;;
    *)
        echo "Usage: $0 <command> [workspace_root]"
        echo ""
        echo "Commands:"
        echo "  init       Initialize dictionary and metrics files"
        echo "  status     Show current dictionary and metrics summary"
        echo "  reset      Reset metrics (keeps dictionary)"
        echo "  gitignore  Add slop files to .gitignore"
        exit 1
        ;;
esac

