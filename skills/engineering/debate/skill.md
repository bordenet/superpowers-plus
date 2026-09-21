---
name: debate
source: superpowers-plus
augment_menu: true
triggers:
  - /sp-debate
  - three design options
  - compare design approaches
  - design comparison matrix
  - evaluate design alternatives
  - red team the design
  - harsh design review
  - generate design options
  - design triad
  - design options with adversarial review
  - design decision needed
  - choosing implementation approach
anti_triggers:
  - implement this design
  - code review
  - already decided on the approach
  - continue implementing
  - just writing tests
description: "Compare significant design approaches before implementation: generate three real options, use a compact matrix and separated hostile review, test edge cases, and converge in two to three rounds. Not for brainstorming, implementation, or code review."
summary: "Use when choosing among design approaches before implementation. Skip when the design is already decided."
coordination:
  group: thinking
  order: 1
  requires: []
  enables: []
  escalates_to: ["thinking-orchestrator"]
  internal: false
composition:
  consumes: [challenge, goal]
  produces: [design-options, decision-record]
  capabilities: [evaluates-options, generates-designs]
  priority: 5
---

## Reference index

Load only the sections required by the process. Preflight, comparison, and hostile review are mandatory; the remaining sections are on demand.

| Need | Read this reference section |
|---|---|
| Before every debate | Preflight routing |
| Mandatory before building the matrix | Comparison protocol |
| Before adversarial review | Hostile review protocol |
| When an output example is needed | Output and example |
| When choosing a neighboring workflow | Companion skills |


# Design Triad

> **Wrong skill?** Idea exploration -> `brainstorming`. Requirements validation -> `requirements-validation`. Implementation planning -> `plan-and-execute`.

**Announce at start:** "I'm using the **debate** skill to evaluate design options."

## When to use

Use before committing to a non-trivial architecture, data model, integration, or other significant design choice. Also use when the user asks for design alternatives or a comparison.

Do not use after implementation has begun, for bug fixing, or for initial idea exploration.

## Mandatory process

1. **Preflight.** Load `Preflight routing` before every debate. Choose a route within 30 seconds; unresolved high-stakes inputs go to the user.
2. **Generate.** Produce a minimum three genuinely distinct, implementable options. Include status quo or a time-boxed spike as a real comparison anchor. If only one option emerges, invoke `think-twice`.
3. **Compare.** Load `Comparison protocol` before building the matrix. Use all six criteria, no more than five words per cell. Recommend in two or three sentences. A recommendation is not completion.
4. **Review.** Author and reviewer must be separate. Load `Hostile review protocol`; use one separated reviewer for reversible work and at least two for irreversible or high-blast-radius work. Do NOT invoke `progressive-harsh-review` or `quantitative-decision-gate` as the reviewer because both can route back to debate.
5. **Probe edge cases.** List no more than ten failure modes, boundaries, tests, or defensive integration points surfaced by review.
6. **Iterate.** Run `review -> fix -> verify the fix in the artifact -> re-review`. Complete a minimum two full review rounds and no more than three. Exit only when a round finds no new material issue. If three rounds completed without convergence, escalate to `thinking-orchestrator` with the unresolved findings rather than continuing to iterate. Do NOT continue beyond 3 rounds.

## Hard gates

- Three options must be genuinely different, not superficial variations or two straw men around a preferred answer.
- A separated reviewer must test the chosen option and the integrity of the option set.
- Verify fixes landed: every claimed resolution must be visible in the updated artifact.
- Keep each review answer to one sentence and each later round delta-only.
- Never claim convergence after the initial review.

## Failure Modes

| Failure | Fix |
|---------|-----|
| Only one option ever generated | Invoke `think-twice`; never proceed with fewer than three genuinely distinct options |
| Reviewer is the same pass/agent as the author | Dispatch a fresh sub-agent, or make an explicit role switch that discards the author's reasoning and starts fresh from the artifact text |
| Three rounds completed without convergence | Escalate to `thinking-orchestrator` with the unresolved findings — do not keep iterating past round 3 |
| A rejected option is a straw man, not one a competent engineer would propose | Replace it once and rerun comparison; the next review becomes round one |
| A claimed fix was never verified in the updated artifact | Re-read the artifact directly — a fix summary is not evidence the fix landed |
| Convergence claimed after only one review round | Never claim convergence after the initial review; a minimum of two full rounds is a hard gate, not a suggestion |

## Rationalizations to reject

| Excuse | Required response |
|---|---|
| There is only one way | Invoke `think-twice`. |
| Other options are obviously wrong | Explain the loss in the matrix. |
| This is too simple | Test the assumptions anyway. |
| Review found nothing | Answer every hostile-review question. |
| There is no time | Compare now to avoid rework. |
| The recommendation is done | Complete review, edge cases, and iteration. |
| I reviewed my own design | Separate author and reviewer. |
| I documented the resolution | Verify it landed in the artifact. |

## Output

Return a compact inline decision record containing: decision and rationale; options considered; rejected options and reasons; edge-case catalog; review findings and resolutions; open risks. Write under `docs/superpowers/specs/` only when explicitly requested.

## Reference loading

Load only the named section. `Preflight routing` is mandatory before Step 1, `Comparison protocol` before Step 3, and `Hostile review protocol` before Step 4. Load the output example only when needed. When an installed copy is found (any of `.claude`/`.codex`/`.agents`), loading requires the separately-provisioned `~/.codex/superpowers-plus` checkout -- an install missing that shared dependency gets a loud `section-loader missing` failure, not silent wrong content.

<!-- kernel-split-reference-loader:start -->
```bash
_ks_ref=""
_ks_loader=""
for _candidate in \
  "$HOME/.claude/skills/sp-debate/reference.md" \
  "$HOME/.codex/skills/sp-debate/reference.md" \
  "$HOME/.agents/skills/sp-debate/reference.md"
do
  if [ -r "$_candidate" ]; then _ks_ref="$_candidate"; break; fi
done
if [ -n "$_ks_ref" ]; then
  _ks_loader="$HOME/.codex/superpowers-plus/tools/section-loader.sh"
else
  _project_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  _source_dir="$_project_root/skills/engineering/debate"
  if [ -n "$_project_root" ] && [ -r "$_source_dir/skill.md" ] && \
     [ -r "$_source_dir/reference.md" ] && \
     [ -r "$_project_root/tools/section-loader.sh" ]; then
    _ks_ref="$_source_dir/reference.md"
    _ks_loader="$_project_root/tools/section-loader.sh"
  fi
fi
[ -r "$_ks_ref" ] || { printf 'reference missing\n' >&2; exit 1; }
[ -r "$_ks_loader" ] || { printf 'section-loader missing\n' >&2; exit 1; }
# Replace <section heading> below with one of the exact strings from
# the Reference index table above before running.
_section='<section heading>'
bash "$_ks_loader" "$_ks_ref" "$_section" \
  || { printf 'section not found: %s\n' "$_section" >&2; exit 1; }
```
<!-- kernel-split-reference-loader:end -->
