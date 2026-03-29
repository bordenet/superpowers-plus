# State File Format

## Location
`~/.codex/knowledge-capture/<topic-slug>-<YYYY-MM-DD>.md`

Legacy location (checked on resume for backward compat): `~/.codex/expert-capture/`

Topic slug: lowercase, hyphens only, no special characters. Example: `telephony-failover-2026-03-25.md`

## Template

```markdown
# knowledge-capture state: <topic>
- **Phase:** scoping
- **Mode:** create|update|companion
- **Source:** interview|conversation
- **Topic:** <topic>
- **Audience:** <not yet>
- **Intent:** <not yet>
- **Scope in:** <not yet>
- **Scope out:** <not yet>
- **Existing page ID:** none
- **Existing page URL:** none
- **Draft path:** not yet
- **Publish URL:** not yet
- **Review round:** 0

## Coverage Matrix
| Area | Priority | Status |
|------|----------|--------|
| Purpose / audience | P0 | open |
| System boundaries / components | P0 | open |
| Workflows / processes | P0 | open |
| Dependencies (upstream/downstream) | P1 | open |
| Decisions made and trade-offs (WHY) | P1 | open |
| Failure modes / troubleshooting / gotchas | P1 | open |
| Concrete examples / scenarios | P1 | open |
| Terminology / glossary | P2 | open |
| Known exceptions / edge cases | P2 | open |
| Open questions / uncertainties | P2 | open |

## Interview Log (append-only)

## Unresolved Contradictions
- none

## Review Findings
```

## Rules

1. **Create on Phase 1 start.** Initialize from this template.
2. **Phase field:** Update to current phase on each transition.
3. **Coverage Matrix:** Update status after each interview answer: `open` → `partial` → `covered` or `na`.
4. **Interview Log:** APPEND ONLY. Never edit or delete previous entries. Two entry formats:
   ```
   ### Q<N>: <question>
   **A:** <answer summary>
   **Provenance:** [sme-stated|doc-verified|code-verified|inferred|contested]
   **Coverage:** <area name>
   ```
   For reactive mode (Phase 1.5 harvest), use `H<N>` prefix:
   ```
   ### H<N>: [harvested from conversation]
   **A:** <extracted content>
   **Provenance:** [sme-stated]  ← direct user statement from conversation
   **Coverage:** <area name>

   ### H<N>: [harvested from conversation]
   **A:** <synthesized content>
   **Provenance:** [inferred]  ← agent synthesis of multiple user statements
   **Coverage:** <area name>
   ```
5. **Contradictions:** Append when found. Mark resolved when resolved.
6. **Review Findings:** Append per round with severity and resolution status.
7. **Draft path:** Set when draft is saved to local file.
8. **Publish URL:** Set after successful publish. Set to "pending" if Outline unavailable.

## TODO Pointer

When state file is created, write a single line to `$TODO_FILE_PATH`:
```
- [ ] knowledge-capture: <topic> — Phase <N> in progress. State: ~/.codex/knowledge-capture/<file>.md
```
Update phase on each transition. Mark `[x]` when publish completes.

## On Resume

1. List all `.md` files in `~/.codex/knowledge-capture/` (exclude `drafts/` and `archive/` subdirectories)
2. Also check `~/.codex/expert-capture/` for legacy state files (backward compat)
3. Present to user with topic, current phase, and source mode (interview/conversation)
4. Ask: "Resume from Phase <N>, or abandon?"
5. On resume: read state, continue from current phase
6. On abandon: archive state file (move to `~/.codex/knowledge-capture/archive/`)

