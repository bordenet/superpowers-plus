# Test-pruning record: 2026-09-17

The durable inventory at [`test-inventory.tsv`](test-inventory.tsv) maps all
101 retained runnable tests to their normal runner and coverage, and records
all 38 artifacts deleted in this unit. `test/test-inventory.test.js` fails when
a live test is missing, duplicated, stale, or lacks either field. It also makes
manual-only and CI-excluded suites explicit instead of treating them as run.

| Removed artifact | Reason |
|---|---|
| `tools/tests/test_tool_help.sh` | No runner executed it, and its shallow `--help` string checks duplicated direct tool tests. |
| `exercises/forked-debugging/` | Self-described experiment stub with no code, test, or documentation consumers. |
| `exercises/multi-agent-skills/` | Unexecuted fixture-only experiment with no consumers. |
| `test/golden-compression/*.golden.txt` | Exact whole-document output coverage was removed. Direct transformation checks in `test/compress.test.js`, safety checks in `test/compression-safety.test.js`, and reviewed operative assertions remain, but they are narrower and are not described as equivalent snapshot coverage. |
| Compression-snapshot fast-forward registration | No generated compression snapshot remains to reproduce. The 2026-08-28 incident regressions still classify any file reintroduced under the retired path as code. |

The wiki instruction guard's known-bad, known-good, and prose corpus was not
executed by CI. It now runs in the security job. Both the skill and corpus test
use `references/blocklist-patterns.json`; the old divergent Python pattern copy
is gone. The same suite rejects malformed required fields and 143 representative
contract mutations, including every category verdict, CAT7's
`NON_OVERRIDABLE` verdict, code case sensitivity, and prose case/verdict
semantics. Pattern matching and warning-category selection continue to read the
canonical JSON rather than a test-owned pattern or behavior copy.

`test/skill-invocation-fixtures.json` is now a reviewed literal oracle. The
trigger refresher cannot derive expectations from live compression output,
cannot overwrite reviewed assertions, and rejects zero operative assertions.

Every artifact changed or deleted here has a mechanical review route.
`exercises/**/*.md` is PHR-owned, executable fixtures and policy route to the
code-review battery, and the wiki skill routes to LLM skill review.

Preserved incident-linked guards include the pre-commit and pre-push tests for
the retired compression-snapshot path. EI and operative baselines remain
unchanged except for `wiki-instruction-guard`'s `code_fences` floor changing
from 1 to 0: the removed fence was the malformed wrapper around the divergent
prose-pattern copy, not an executable procedure. The detector generator was
run and its broader stale-baseline resync was rejected; no unrelated baseline
row changed. The three existing CI exclusions in `tests/ci-bats-policy.txt`
also remain; the inventory records them as exclusions rather than claiming CI
coverage.
