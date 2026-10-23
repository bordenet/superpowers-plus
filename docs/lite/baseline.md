# Lite baseline and Full oracle

Measured on 2026-10-23 at `45186ef62e2ac91f8ec173d92d36b5058380eff2`, the permanent Full oracle and this slice's freshly fetched `origin/dev` base. This baseline documents existing behavior; it introduces no Light installation behavior.

## Units and boundaries

Listing metadata means the UTF-8 byte length of parsed `name` concatenated with parsed `description`, without separators or host framing. It is not a tokenizer measurement or a native host prompt total. Counts below describe separate source and installed boundaries; do not add the rows into a whole-prompt total. Native host totals remain unverified.

| Boundary | Entries | Metadata bytes |
|---|---:|---:|
| All source skills | 125 | 32,778 |
| Source skills already manual-only | 100 | 25,433 |
| Remaining source Claude listing projection | 25 | 7,345 |
| Installed shared root (`~/.agents/skills`), all sources | 103 | 30,609 |
| This suite within the installed shared root | 58 | 17,285 |
| Eight selected core skills, source metadata | 8 | 2,390 |

The shared-root inventory includes root-level directory symlinks as well as physical packages. Its metadata total does not apply Claude's manual-only filter. Source flags project the Claude listing; discovery of skills by Augment and Codex still needs host probes.

The source and installed always-on rule file each measure 4,887 bytes. Running the source adapter's bootstrap against the installed skill store in an empty scratch HOME produced 1,020 stdout bytes and zero stderr bytes. The source and installed adapter files have matching SHA-256 hashes. That capture excludes pre-existing workflow state and is separate from host-injected instructions and listings.

## Core measurement and Light forecast

| Source core skill | Name plus description bytes |
|---|---:|
| branch-sync-gate | 258 |
| merge-authorization-gate | 321 |
| push-authorization-gate | 365 |
| superpowers-doctor | 525 |
| systematic-debugging | 111 |
| unified-commit-gate | 267 |
| using-superpowers | 176 |
| verification-before-completion | 367 |
| **Total** | **2,390** |

The Light listing forecast remains **2,790 bytes**: 2,390 measured core bytes plus an assumed 200 bytes for each of two future helper entries, `sp-catalog` and `sp-load`. Those helpers do not exist at this base. Their allowance and host visibility remain assumptions. The intended host-proven targets are at most 3,000 bytes for the suite's Claude listing and at most 4,000 bytes for its shared-root listing; this baseline does not establish either result.

## Existing reductions on dev

These changes are ancestors of the pinned base and are already included in the baseline:

- `ec6f52427b19f64fdbb2ed4d95387ea24886657a` merged the existing diet work, including kernel/reference splits, router changes and cost tooling.
- `ce9b957026b0eb487e5ad75f3f77def451eec458` made micro-harsh-review, experimental-self-prompting and autonomous-chain-controller manual-only.
- `3568201a1c412065649abab8eb65565610b3a4c7` excluded independently synced skills from the governed Claude host budget while reporting them separately.
- `4295bc74` disabled the presence-only pre-commit review-sentinel check. Review gates remain separate from measurement.

The 25,433 bytes already suppressed across 100 source entries are existing behavior, not future Light savings. Kernel/reference changes already on dev are likewise part of the starting point.

## Measurement method

Run all tools with a fresh scratch HOME and scratch TMPDIR. Real installer tests belong in a disposable source clone, never a live installation or the working checkout used for the docs commit.

1. Run `python3 tools/resident-cost-report.py --repo --repo-root <pinned-source> --json`. At this base it reports 125 scanned skills, 25 automatic and 100 manual entries, 7,345 listing bytes, and zero parse failures.
2. Send a JSON array of source skill paths to `node tools/frontmatter-batch.js`; aggregate decoded names and descriptions separately for all, manual-only and core entries. For the installed shared root, include registered root-level symlink packages and aggregate suite membership by the parsed `source` field. The reader is bounded to 64 KiB of frontmatter per file.
3. Capture `node superpowers-augment.js bootstrap` stdout and stderr with `PERSONAL_SKILLS_DIR` and `SUPERPOWERS_SKILLS_DIR` pointing to the installed store read-only, `SPP_SOURCE_DIR` pointing to the pinned source, and `WORKFLOW_STATE_FILE` pointing into scratch HOME. Measure the captured bytes; do not count the generated index file as bootstrap stdout.

Source metadata and installed metadata have different inventories. These commands measure those inventories; they do not replace a native host probe.

## Validation at the base

Tools: Bash 5.3.20, Node 26.12.1, Python 3.15.0, ShellCheck 0.11.0, Bats 1.14.0 and GNU parallel 20260922 on macOS. All local runs used scratch HOME; the full suite ran in a disposable source clone with scratch TMPDIR. A Git discovery ceiling prevents non-repository fixtures from finding the enclosing checkout. Local mock servers require loopback-listener permission.

| Check at the pinned base | Exit | Result |
|---|---:|---|
| Three required measurement tools | 0 each | Baseline figures reproduced |
| Root shell syntax with Bash 5 | 0 | Passed |
| Full `tools/test-all.sh`, corrected environment | 1 | Four inherited failures in `tests/` |
| One serial rerun of those four cases | 1 | All four reproduced |
| Bash 3.2 installer invocation | 1 | Expected refusal: installer requires Bash 4+ |

The full runner passed its `shellcheck -x`, static review, all 997 `test/` cases, Node/shell harness group and working-tree guard. Its `tests/` group reported these four failures at the unchanged base:

- `tests/compat-help-test.bats:33`: the TODO self-test expects an existing TODO file; fresh HOME has none.
- `tests/harness/artifact-budgets.bats:74`: the smoke test requires three Claude host measurements unavailable in fresh HOME. The required P0 repository report and frontmatter/bootstrap measurements succeeded separately.
- `tests/skip-augment-test.bats:30` and `:37`: the assertions expect target paths in `--check` output; the installer exits 0 and prints prerequisites without those paths.

A separate literal root-only ShellCheck invocation without `-x` exited 1 with SC1091 and SC2034 diagnostics; the full runner's source-following lint passed. The first sandboxed full-suite attempt also exited 1, with fixture-discovery and localhost-listener failures; those did not recur in the corrected run. No product or test changes were made to clear failures. This is a recorded red local baseline, not an all-green claim.

At the same SHA, the dev **push** workflows [Harsh Review](https://github.com/bordenet/superpowers-plus/actions/runs/37502609227) and [Tests](https://github.com/bordenet/superpowers-plus/actions/runs/37502609269) both completed successfully. Their four jobs were Quality Checks, Security Scan, Node.js Tests and Shell Tests, all successful when queried on 2026-10-23. These are push-event results for the pinned SHA, not a claim about branch-protection configuration.

## Oracle boundary

Future Full comparisons use permanent oracle `45186ef62e2ac91f8ec173d92d36b5058380eff2`. Deployed Full skill files and companions, commands, rules, slash listings and bootstrap output must remain byte-identical to that oracle. This docs-only slice changes none of those inputs. It records the baseline; it does not add the future deployment comparison harness or claim a host-level Full comparison has run.
