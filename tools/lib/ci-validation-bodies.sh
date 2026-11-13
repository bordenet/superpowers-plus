#!/usr/bin/env bash
# Registered CI bodies. Caller resolves strategy, input context and ownership.
# Each case preserves its original workflow command and exit behavior.
# shellcheck disable=SC2329
ci_validation_body() {
    case "$1" in
        ci:node-tests-toolchain-compatibility-regressions)
            node test/validation-toolchain.test.js
            ;;
        ci:node-tests-ci-boundary-registry-regressions)
            node test/strategy-boundaries.test.js
            ;;
        ci:node-tests-composition-engine-tests)
            node test/composition-engine.test.js
            ;;
        ci:node-tests-compression-safety-gate)
            node test/compression-safety.test.js
            ;;
        ci:node-tests-compression-unit-tests)
            node test/compress.test.js
            ;;
        ci:node-tests-cr-battery-evidence-verifier-tests)
            node test/verify-cr-battery-evidence.test.js
            ;;
        ci:node-tests-ei-move-detector)
            node test/ei-move-detector.test.js
            ;;
        ci:node-tests-frontmatter-parser-tests)
            node test/frontmatter.test.js
            ;;
        ci:node-tests-full-installed-output-parity)
            node test/lite-full-installed.test.js
            ;;
        ci:node-tests-full-oracle-input-parity)
            node test/lite-full-unchanged.test.js
            ;;
        ci:node-tests-hub-anchor-validator)
            node test/hub-anchor-validator.test.js
            ;;
        ci:node-tests-input-closure-regressions)
            node test/validation-inputs.test.js
            ;;
        ci:node-tests-language-scanner-tests)
            node test/language-scanner.test.js
            ;;
        ci:node-tests-lite-manifest-regression-tests)
            node test/lite-manifest.test.js
            ;;
        ci:node-tests-lite-manifest-validation)
            node scripts/validate-lite-manifest.js
            ;;
        ci:node-tests-mcp-smoke-test)
            cd mcp && npm test
            ;;
        ci:node-tests-operative-move-detector)
            node test/operative-move-detector.test.js
            ;;
        ci:node-tests-receipt-producer-regressions)
            node test/validation-receipt.test.js
            ;;
        ci:node-tests-review-hook-install-regressions)
            node test/review-hook-install.test.js
            ;;
        ci:node-tests-review-dispatch-regressions)
            node test/review-strategy.test.js
            ;;
        ci:node-tests-skill-discovery-tests)
            node test/skill-discovery.test.js
            ;;
        ci:node-tests-skill-invocation-smoke)
            node test/skill-invocation-smoke.test.js
            ;;
        ci:node-tests-skill-router-tests)
            node test/skill-router.test.js
            ;;
        ci:node-tests-strategy-boundary-regressions)
            node test/validation-strategy.test.js
            ;;
        ci:node-tests-strategy-policy-regressions)
            node test/strategy-policy.test.js
            ;;
        ci:node-tests-use-skill-cli-tests)
            node test/use-skill-cli.test.js
            ;;
        ci:node-tests-validation-reuse-regression-tests)
            node --test test/ci-validation-reuse.test.js
            ;;
        ci:node-tests-visual-companion-keyed-server)
            node --test test/brainstorm-literal-content.test.js
            ;;
        ci:node-tests-workflow-state-tests)
            node test/workflow-state.test.js
            ;;
        ci:quality-checks-check-version-consistency)
            echo "Checking version consistency..."
            ERRORS=0

            # Get version from install.sh (source of truth)
            INSTALL_VERSION=$(grep '^VERSION=' install.sh | cut -d'"' -f2)
            echo "install.sh version: $INSTALL_VERSION"

            # Check plugin.json
            if [ -f ".claude-plugin/plugin.json" ]; then
              PLUGIN_VERSION=$(python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json'))['version'])")
              if [ "$PLUGIN_VERSION" != "$INSTALL_VERSION" ]; then
                echo "❌ plugin.json version ($PLUGIN_VERSION) differs from install.sh ($INSTALL_VERSION)"
                ERRORS=$((ERRORS + 1))
              else
                echo "✓ plugin.json version matches"
              fi
            fi

            # Check CHANGELOG.md has entry for this version
            if ! grep -q "## \[$INSTALL_VERSION\]" CHANGELOG.md; then
              echo "❌ CHANGELOG.md missing entry for version $INSTALL_VERSION"
              ERRORS=$((ERRORS + 1))
            else
              echo "✓ CHANGELOG.md has entry for $INSTALL_VERSION"
            fi

            if [[ $ERRORS -gt 0 ]]; then
              echo ""
              echo "::warning::Version inconsistency detected. Run version-sync workflow or update manually."
              # Warning only, not blocking - version-sync.yml will fix on merge
            fi
            echo "✓ Version consistency check complete"
            ;;
        ci:quality-checks-dangerous-pattern-scan)
            bash tools/dangerous-pattern-scan.sh
            ;;
        ci:security-scan-dangerous-pattern-scan)
            bash tools/dangerous-pattern-scan.sh
            ;;
        ci:security-scan-ip-disclosure-audit)
            bash test/public-repo-ip-check.test.sh
            ;;
        ci:shell-tests-all-bats-suites-auto-discovered)
            bash tools/ci-bats-discovery.sh --run
            ;;
        ci:shell-tests-bats-policy-lint-no-stale-opt-outs)
            bash tools/ci-bats-discovery.sh --lint
            ;;
        ci:shell-tests-doctor-checks-tests)
            bash tools/tests/test_doctor_checks.sh
            ;;
        ci:shell-tests-full-corpus-fence-scan-all-skills-md)
            mapfile -t MD_FILES < <(find skills -name "*.md")
            bash tools/fence-scan.sh "${MD_FILES[@]}"
            ;;
        ci:shell-tests-harness-skill-size-audit-advisory)
            bash tools/skill-size-audit.sh
            ;;
        ci:shell-tests-skills-md-count-lint)
            ACTUAL=$(find skills/ -name "skill.md" -not -path "*/_adapters/*" | wc -l | tr -d ' ')
            DECLARED=$(grep -o 'SKILL-COUNT: [0-9]*' docs/SKILLS.md | grep -o '[0-9]*')
            if [ -z "$DECLARED" ]; then
              echo "FAIL: <!-- SKILL-COUNT: N --> comment not found in docs/SKILLS.md"
              exit 1
            fi
            if [ "$ACTUAL" != "$DECLARED" ]; then
              echo "FAIL: docs/SKILLS.md declares $DECLARED skills but found $ACTUAL"
              echo "Update the <!-- SKILL-COUNT: --> comment in docs/SKILLS.md to $ACTUAL"
              exit 1
            fi
            echo "PASS: $ACTUAL skills match declared count in docs/SKILLS.md"
            ;;
        ci:shell-tests-todo-archive-tests)
            bash skills/productivity/todo-archive/tests/test_todo_archive.sh
            ;;
        ci:shell-tests-todo-engine-unit-tests)
            python3 tools/tests/test_todo_engine.py -v
            ;;
        ci:shell-tests-todo-lock-tests)
            bash tools/tests/test_todo_lock.sh
            ;;
        *) echo "Unknown registered CI check: $1" >&2; return 2 ;;
    esac
}
