# TODO Management — Tagging Taxonomy

> Reference material for the `todo-management` skill.
> See `skill.md` for core guidance.

Tags are auto-inferred from keywords in the task description. **Customize for your organization** by adding domain-specific tags.

## Engineering Tags

| Tag | Trigger Keywords |
|-----|------------------|
| `#engineering-frontend` | UI, component, CSS, React, layout, styling |
| `#engineering-backend` | API, database, server, endpoint, migration |
| `#engineering-infra` | deploy, CI, pipeline, Docker, Kubernetes, terraform |
| `#engineering-testing` | test, coverage, unit, integration, QA |
| `#engineering-docs` | documentation, README, wiki, spec, ADR |

## Recruiting Tags

| Tag | Trigger Keywords |
|-----|------------------|
| `#recruiting-sourcer` | source, outreach, LinkedIn, pipeline, candidate search |
| `#recruiting-scheduler` | schedule, calendar, Zoom, interview time, availability |
| `#recruiting-admin` | offer, letter, system, ATS, paperwork |
| `#recruiting-interviewer` | interview, prep, feedback, scorecard, debrief |
| `#recruiting-hr` | comp, compensation, policy, HR, benefits |

## General Tags (auto-inferred from context)

| Tag | Trigger Context |
|-----|-----------------|
| `#team` | Team member names, "team", "direct report" (customize: `#delta-team`, `#your-team`) |
| `#1on1` | "1:1", "one-on-one", "sync with [name]" |
| `#product` | "product", "feature", "roadmap" (customize: `#[product]`, `#your-product`) |
| `#process` | "process", "workflow", "documentation" |

## Plan Tags (effort-scoped)

Use `#plan-<identifier>` to group tasks by effort for parallel work isolation.

| Pattern | Purpose | Example |
|---------|---------|---------|
| `#plan-<identifier>` | Group tasks by effort | `#plan-auth-fix`, `#plan-config-refactor` |
| `#plan` | ⚠️ **Deprecated** | Use `#plan-<identifier>` for effort isolation |

**Identifier derivation:**
- Derive from plan title: "Config Refactor" → `config-refactor`
- Use kebab-case: lowercase, hyphens instead of spaces
- Keep short but descriptive: 2-4 words max
- If ambiguous, ask: "What should I call this effort?"

**Example TODO.md with multiple efforts:**
```markdown
## P1 - Today
- [ ] [20250315-01] Update config schema #plan-config-refactor #engineering
- [ ] [20250315-02] Add validation layer #plan-config-refactor #engineering
- [ ] [20250315-03] Fix auth token refresh #plan-auth-fix #engineering-backend
- [ ] [20250315-04] Add auth retry tests #plan-auth-fix #engineering-testing
```

