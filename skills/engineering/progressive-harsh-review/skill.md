---
name: progressive-harsh-review
source: superpowers-plus
augment_menu: true
triggers:
  - /sp-phr
  - /sp-redteam
  - harsh review
  - progressive review
  - red team this
  - review this harshly
  - hostile review
  - critic review
  - find what's wrong
  - score this work
  - ready to present plan
  - ready to present design
  - ready to present spec
  - before pushing design docs
aliases: [PHR, harsh-review]
anti_triggers:
  - code review
  - PR review
  - review someone's PR
  - design review inside debate
  - quick feedback
description: "Adversarial review for plans, specs, and other non-code deliverables. Three independent personas score correctness, simplicity, verifiability, blind spots, and operational risk. Route code to code-review-battery and skill files to llm-skill-review."
summary: "Use before presenting a non-code deliverable. Route code and skill files to their dedicated review gates."
coordination:
  group: quality
  order: 2
  requires: []
  enables: ["think-twice", "debate"]
  escalates_to: []
  internal: false
composition:
  consumes: [design-options, phased-plan, markdown-content]
  produces: [review-feedback]
  capabilities: [reviews-design, gates-quality]
  priority: 30
---

## Reference index

| Need | Reference section |
|---|---|
| Repository sets a score floor | Project-min override |
| Final report needs a template | Scoring output format |
| Review behavior looks weak | Anti-Patterns |
| A neighboring workflow is needed | Companion skills |


# Progressive Harsh Review

> **Mechanical routing:** Run `tools/review.sh route <path> [<path> ...]` first. Obey its result; stop on error or an unclassified artifact.
>
> **Wrong skill?** Code -> `code-review-battery`; skills/tooling -> `llm-skill-review`; design comparison -> `debate`.

**Announce at start:** "I'm using the **progressive-harsh-review** skill to red-team this work."

## When to use

Use before presenting non-code work or on a hostile-review request. Exclude code, skills, brainstorming, and design-option selection.

## Persona dimension table

Each persona reads independently. Send only its row, the common dimension questions, and artifact/repository access.

| Persona | Start point | C | S | V | B | OR |
|---|---|---:|---:|---:|---:|---:|
| JuniorDevNitpicker | Line-by-line prose | 35 | 25 | 15 | 20 | 5 |
| SeniorArchCritic | Promises vs. evidence | 25 | 15 | 25 | 15 | 20 |
| OpsRealist | Failures and state changes | 25 | 10 | 10 | 25 | 30 |

Dimensions: **Correctness** (holds?), **Simplicity** (needless complexity?), **Verifiability** (checkable?), **Blind Spots** (omissions?), **Operational Risk** (adverse failures?). Each row totals 100.

For user-visible functionality, missing named metrics and trace/span strategy caps OpsRealist's Operational Risk at 4; cite the omission.

## Review process

1. **Fresh-reader check.** Flag local paths, undefined identifiers, process commentary, and inaccessible references. Remove this author noise before shipping; do not lower scores for it alone.
2. **Independent review.** Author != Reviewer. Dispatch all personas from artifact paths with only their row, five questions, and repository access. Persona reviewers must not invoke PHR, debate, code-review-battery, or other reviewers; each returns one scorecard. Remediate only after aggregation.
3. **Score.** Score each dimension 1-10 with the persona's weights, then take the equal-weight average of the three weighted scores.
4. **Apply veto.** Correctness or Operational Risk <=4 is a hard veto only with a specific defect. Unrecoverable failures must affect Operational Risk, not Blind Spots alone.
5. **Verdict.** Use the table. A repository floor raises the PASS bar only; load `Project-min override`.
6. **Remediate.** Fix and verify every material finding. After round one, review the delta. REJECT requires root-cause analysis and full re-review.
7. **Check correlation.** Any flag below or unsupported clean sweep requires a new persona starting point.
8. **Converge.** Require the active floor, no veto/flag, and no new material issues. Escalate after 3 rounds without convergence; never auto-ship.

## Verdicts

| Weighted mean | Verdict | Action |
|---:|---|---|
| >=8 | PASS | Ship after all gates clear |
| 7 to <8 | PASS_WITH_FIXES | Fix and rescore changed areas |
| <7 | REJECT | Root-cause, remediate, full re-review |
| Any with veto | REJECT | Clear the cited defect, full re-review |

PASS_WITH_FIXES never clears the gate. Limit the entire remediation cycle to 3 review rounds.

## Correlated-failure checks

- `CORRELATED EVIDENCE`: shared evidence; one persona restarts from its lens.
- `ECHO REASONING`: materially identical reasoning; require an independent restatement.
- Clean sweep: each persona shows evidence from its distinct start point or re-examines.

## Sentinel after PASS

Only PASS clears the gate. Run PHR AFTER `git commit` once the floor is met with no veto or correlation flag:

```bash
tools/run-phr.sh --verdict PASS --min-score "<weighted-mean>"
```

The sentinel binds to HEAD. Commit, amend, or rebase requires fresh review unless promotion is tree-identical.

## Reference loading

Load only the needed section: a repository score floor, detailed failure recovery, or the report template.

<!-- kernel-split-reference-loader:start -->
```bash
_project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
_ks_ref=""
for _candidate in \
  "$HOME/.agents/skills/sp-phr/reference.md" \
  "$HOME/.codex/skills/sp-phr/reference.md" \
  "$HOME/.claude/skills/sp-phr/reference.md"
do
  [ -r "$_candidate" ] || continue
  if [ -n "$_ks_ref" ] && ! cmp -s "$_ks_ref" "$_candidate"; then
    printf 'installed references diverge: %s\n' "$_candidate" >&2
    exit 1
  fi
  [ -n "$_ks_ref" ] || _ks_ref="$_candidate"
done
_ks_loader="$HOME/.codex/superpowers-plus/tools/section-loader.sh"
if [ -z "$_ks_ref" ]; then
  _ks_ref="$_project_root/skills/engineering/progressive-harsh-review/reference.md"
  [ -r "$_ks_loader" ] || _ks_loader="$_project_root/tools/section-loader.sh"
fi
[ -r "$_ks_ref" ] || { printf 'reference missing\n' >&2; exit 1; }
[ -r "$_ks_loader" ] || { printf 'section loader missing\n' >&2; exit 1; }
_section='<section heading>'
bash "$_ks_loader" "$_ks_ref" "$_section" \
  || { printf 'section not found: %s\n' "$_section" >&2; exit 1; }
```
<!-- kernel-split-reference-loader:end -->

## Failure Modes

| Failure | Fix |
|---------|-----|
| Self-reviewed in same thinking pass | Use sub-agent (preferred) — in-process role switch with no context isolation is significantly less reliable; if used, explicitly discard the author's reasoning and start fresh from the artifact text |
| All personas gave same feedback | Each persona must name ≥1 plausible failure mode unique to their lens, or cite a specific property of the change explaining why none exists (generic dismissal = rubber-stamp) — identical findings means the lenses aren't distinct |
| Score inflated to avoid re-work | Findings with concrete issues MUST score ≤7 on that dimension |
| Remediation skipped after REJECT | REJECT means start over. No "fix one thing and call it done" |
| Only reviewed happy path | OpsRealist must consider failure, rollback, 3am scenarios, and OE telemetry for new behavior |
| Round N mean lower than Round N-1 | Remediation introduced new issues — flag REGRESSION, root-cause before Round N+1 |
| No output summary before presenting | Always emit PHR SUMMARY block (rounds, mean, verdict, project-min, vetoes) |
| Shipped at round 3 without convergence | 3 rounds = escalate to human with blocker list — never auto-ship |
| Unrecoverable finding scored only on Blind Spots | Must ALSO score Operational Risk to be veto-eligible — Blind Spots alone bypasses the veto gate |
| Skipped sentinel write after PASS | Pre-push Gate 5 refuses the push with "PHR sentinel missing." Run `tools/run-phr.sh --verdict PASS --min-score <N>` and retry. |
