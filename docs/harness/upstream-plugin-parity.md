# Upstream plugin parity

This page records the P1b parity work needed before the optional
`superpowers@superpowers-marketplace` plugin can be disabled. It documents the
repository changes and the remaining live acceptance test. It does not modify
`~/.claude` or disable the plugin.

The measurements below are a 2026-09-17 snapshot of obra/superpowers v4.0.3 at
`~/.claude/plugins/cache/superpowers-marketplace/superpowers/4.0.3`. On that
date, `claude plugin list` reported the plugin enabled at user scope.

## Skill coverage

All 14 plugin skills have a bundled counterpart in `skills/engineering/` or
`skills/writing/`. The bundled skills include local gates and condensed
v6.3.0-derived behavior; they are not byte-for-byte copies. "Bundled install
name" is the destination selected by `lib/install/skill-naming.sh`.

| Plugin skill | Bundled install name | Plugin `SKILL.md` bytes | Bundled `skill.md` bytes |
|---|---|---:|---:|
| brainstorming | sp-brainstorm | 2,505 | 10,692 |
| dispatching-parallel-agents | dispatching-parallel-agents | 6,104 | 7,615 |
| executing-plans | executing-plans | 2,171 | 3,901 |
| finishing-a-development-branch | sp-finish | 4,250 | 15,800 |
| receiving-code-review | sp-receive | 6,314 | 7,411 |
| requesting-code-review | sp-request | 2,700 | 8,219 |
| subagent-driven-development | subagent-driven-development | 9,809 | 20,872 |
| systematic-debugging | sp-debug | 9,884 | 7,656 |
| test-driven-development | sp-tdd | 9,867 | 6,734 |
| using-git-worktrees | sp-worktree | 5,592 | 6,645 |
| using-superpowers | using-superpowers | 3,798 | 7,016 |
| verification-before-completion | sp-verify | 4,201 | 12,708 |
| writing-plans | sp-write-plan | 3,264 | 8,443 |
| writing-skills | writing-skills | 22,463 | 9,178 |
| **Total** | | **92,922** | **132,890** |

## Plugin-only surface

| Plugin artifact | What it adds | Bundled coverage or known gap |
|---|---|---|
| `agents/code-reviewer.md` (`superpowers:code-reviewer`) | Named reviewer agent for plugin-aware dispatch | The compatibility `code-quality-reviewer-prompt.md` uses the source `requesting-code-review/code-reviewer.md` only when the active loader reports the `spp:` namespace, canonical source template, and resolved source origin and the source reviewer exists. Caller-provided roots never qualify, and missing loader metadata fails closed to installed `sp-request/code-reviewer.md`. It renders and inlines the instructions before generic dispatch and never searches the target project. Active SDD task review uses `task-reviewer-prompt.md`, which already contains its complete spec-and-quality instructions. Doctor check 23 validates both deployed paths and warns on missing or stale Claude copies. |
| `commands/brainstorm.md` and `commands/write-plan.md` | Explicit `/brainstorm` and `/write-plan` commands | `sp-brainstorm`, `sp-write-plan`, and `/sp-plan` cover the workflows under different names. The exact plugin command names are not bundled aliases. |
| `commands/execute-plan.md` | Explicit `/execute-plan` command | The bundled skill is installed as `executing-plans`; `/execute-plan` is not a bundled alias. |
| `hooks/hooks.json` SessionStart hook | Injects the plugin's skill protocol at startup, resume, clear, and compact | The hook emitted 4,306 bytes in the measured snapshot. The bundled `using-superpowers` skill supplies the protocol without this second injection. |

The command-name differences are user-interface gaps, not missing workflow
implementations. P1a preserves typed duplicate aliases as hidden aliases after
its mirror changes are integrated and the installer or mirror is rerun. Any
remaining plugin-only command names must be accepted during AT4 or replaced
with bundled aliases before disabling the plugin.

## Repository regression coverage

Run:

```bash
bash tools/tests/test_doctor_checks.sh
```

The reviewer-dispatch tests exercise these boundaries:

- the controller resolves and inlines reviewer instructions before generic
  dispatch, so the child receives no unresolved path or target-project content;
- the doctor validates the deployed Claude contract and the task-reviewer
  template named by active SDD, requires one semantically affirmative dispatch
  block, and fails closed on direct, indirect, or historical dispatch-negating
  prose anywhere before the affirmative marker;
- the doctor warns on a missing deployed file, a negated or incoherent dispatch
  block, an obsolete named plugin agent, and a stale installed copy;
- `use-skill spp:subagent-driven-development --resource task-reviewer-prompt.md`
  preserves the active source namespace and renders the real sibling prompt
  through the Augment transformation boundary, even when an installed copy
  diverges;
- resource rendering rejects absolute paths, missing files, directories,
  traversal, symlink escape, missing values, and extra arguments. The complete
  seven-case rejection matrix runs independently against both source and
  installed layouts;
- the Augment adapter maps `Subagent (general-purpose):` and
  `Task tool (general-purpose):` to its generic subagent tool;
- obsolete plugin-agent syntax stays visible so the doctor can reject it.

## Integration order

AT4 is an integration test, not a P1b branch-local test. Run it only after the
P1a mirror changes and the P1g journey harness are integrated into the target
branch and installed on the test host. P1g supplies `tools/journey-probe.sh`,
its J1 through J11 fixtures, and the comparison workflow documented in
`docs/JOURNEY_PROBE.md`.

The acceptance sequence is:

1. Install the integrated P1a, P1b, and P1g result while the plugin remains
   enabled.
2. Capture the plugin-enabled listing, SessionStart, hook, command, agent, and
   J1 through J11 baselines.
3. Disable the plugin, reinstall or refresh the bundled artifacts as required,
   and repeat the same measurements.
4. Compare the P1g result files and re-enable the plugin immediately if any AT4
   criterion regresses.

## Disable and rollback

Use the Claude plugin CLI so it validates the plugin identifier:

```bash
claude plugin disable --scope user superpowers@superpowers-marketplace
claude plugin enable --scope user superpowers@superpowers-marketplace
```

The second command is the rollback. Do not edit `~/.claude/settings.json`
directly unless the CLI is unavailable.

## Live acceptance checklist

Disabling the plugin is a separate, machine-level action. Compare before and
after, and re-enable it if any item fails:

- [ ] Listing: the 14 plugin entries are gone and all 14 bundled equivalents
      remain discoverable.
- [ ] Session start: the 4,306-byte plugin injection is gone and the bundled
      `using-superpowers` protocol still loads.
- [ ] Hooks: the plugin SessionStart hook no longer fires and no other workflow
      depended on it.
- [ ] Reviewer dispatch: the named plugin agent is unavailable, generic review
      dispatch still loads the bundled reviewer template, and doctor check 23
      is clean.
- [ ] Commands: `/brainstorm`, `/execute-plan`, and `/write-plan` no longer
      resolve; the operator accepts the bundled names or adds aliases first.
- [ ] Journeys J1 through J11 are equal or better with the plugin disabled,
      measured by the integrated P1g harness and its checked-in fixtures.

Keep the plugin enabled until this complete AT4 sequence passes.
