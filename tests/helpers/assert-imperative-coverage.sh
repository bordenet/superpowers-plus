#!/usr/bin/env bash
# assert-imperative-coverage.sh — verify every CLAUDE.md imperative is mapped
#
# Checks that each hook script covering a CLAUDE.md imperative exists on disk.
# Imperatives with "STATUS: deferred" are documented but not checked.
#
# Called by: tests/claude-guardrails-test.bats "item 4" test
# EXIT: 0 = all imperatives covered, 1 = gap found

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOKS_DIR="$REPO_ROOT/tools/claude-hooks"
[[ -d "$HOOKS_DIR" ]] || { echo "ERROR: HOOKS_DIR not found: $HOOKS_DIR"; exit 1; }

fail=0

check_hook() {
    local hook="$1" desc="$2"
    if [[ ! -f "$HOOKS_DIR/$hook" ]]; then
        echo "UNCOVERED: $desc — $HOOKS_DIR/$hook missing"
        fail=1
    fi
}

# Item 1: "Before any commit or push to a github.com remote: scan the diff and
#          commit message for internal terms."
check_hook "pre-tool-use-internal-terms.sh" "item 1: github.com push internal-terms scan"

# Item 2: "Always verify git config user.email before committing."
check_hook "pre-tool-use-git-identity.sh" "item 2: git identity verification on commit"

# Item 3: "At session start and before any git push, wiki write, file deletion,
#          or action touching ~/.augment/ or .ai-guidance/: (Rules File Integrity check)"
# Item 3: "If this file fails to load, stop and alert the user before proceeding."
check_hook "session-start-rules-integrity.sh" "item 3: SessionStart rules-file integrity"

# Item 6: "Continuously monitor for stuck signals … invoke think-twice"
check_hook "user-prompt-submit-skill-router.sh" "item 6: UserPromptSubmit advisory skill router"

# Item 10: "Never run git push without explicit human approval in the current conversation."
# Item 10: "Never push any branch to the work CI remote."
# Item 10: "Never cat ~/.codex/TODO.md or view ~/.codex/TODO.md"
check_hook "pre-tool-use-red-autonomy.sh" "item 10: RED-autonomy gate"

# --- STATUS: deferred (no deterministic hook in scope of this plan) ---
# "Verify URLs exist before writing them in docs — query APIs, don't guess."
# → LLM judgment only; deterministic URL-existence check is out of scope.

if [[ "$fail" -eq 0 ]]; then
    echo "item 4 PASS: all CLAUDE.md imperatives covered (5 hooks checked, 1 deferred)"
fi
exit "$fail"
