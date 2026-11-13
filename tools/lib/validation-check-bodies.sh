#!/usr/bin/env bash
# Internal registered bodies. Only the outer Python producer owns receipts/lock.
# Usage: source this library; validation_check_body <shellcheck|harsh|router>
run_shellcheck() {
    if ! command -v shellcheck >/dev/null 2>&1; then
        echo "❌ shellcheck is required for registered lint coverage" >&2
        return 127
    fi
    # Match the scope used by tools/harsh-review.sh: every tracked .sh plus
    # extensionless hooks under tools/. Exclude vendored / generated paths.
    local files
    files=$(git ls-files '*.sh' tools/pre-commit tools/pre-push tools/commit-msg 2>/dev/null | sort -u)
    [[ -z "$files" ]] && { echo "no shell files tracked"; return 0; }
    # shellcheck disable=SC2086  # word-splitting intentional
    shellcheck -x $files
}

validation_check_body() {
    local check="$1"
    shift
    case "$check" in
        shellcheck) run_shellcheck ;;
        harsh) bash "$SCRIPT_DIR/lib/harsh-review-body.sh" --registered-body "$@" ;;
        router) node "$REPO_ROOT/test/skill-router.test.js" ;;
        native:pre-commit-static) bash "$SCRIPT_DIR/lib/pre-commit-static-body.sh" ;;
        native:commit-default) bats "$REPO_ROOT/tests/" ;;
        ci:*)
            # shellcheck source=tools/lib/ci-validation-bodies.sh
            source "$SCRIPT_DIR/lib/ci-validation-bodies.sh"
            ci_validation_body "$check"
            ;;
        node:*) node "$REPO_ROOT/test/${check#node:}" ;;
        shell:*) bash "$REPO_ROOT/test/${check#shell:}" ;;
        *) echo "Unknown registered validation check: $check" >&2; return 2 ;;
    esac
}
