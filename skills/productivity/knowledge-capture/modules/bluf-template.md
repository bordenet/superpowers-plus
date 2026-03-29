# BLUF Article Template

## Required Sections (always include)

```markdown
## Bottom Line
[1-3 sentences: what this is, why it matters, who should read it]

## Audience
[Who should read this. What task/decision they can complete after reading.]

## Scope
- **Covers:** [explicit boundaries]
- **Does not cover:** [explicit exclusions]

## Key Findings
- [Finding 1]
- [Finding 2]
- [Finding 3-5]

## [Domain Section 1 — derived from coverage matrix]
[Content organized by topic area]

## [Domain Section 2]
[Additional content]

## Source
- **Subject Matter Expert:** [Name]
- **Interview Date:** [Date]
- **Reviewed/Approved by SME:** Yes/No
- **Related Pages:** [cross-links to existing wiki pages]
- **Owner:** [who maintains this page]
- **Review Cadence:** [when to revisit]
```

## Conditional Sections (include only if interview produced relevant content)

```markdown
## Terminology
| Term | Definition |
|------|-----------|
| [Term] | [Definition in context of this domain] |

## Failure Modes / Gotchas
- [Failure mode with context and known remediation]

## Trade-offs and Decisions
- [Decision made, alternatives considered, why this choice was made]

## Open Questions
- [Unresolved items with context on why they're open]
```

## Source Notes Appendix (REQUIRED — always include)

```markdown
## Source Notes
Key claims and their provenance:
- "[Claim about X]" — `[sme-stated]`, not independently verified
- "[Claim about Y]" — `[doc-verified]` via [link to wiki page]
- "[Claim about Z]" — `[contested]` — SME stated A, but [doc/code] shows B
```

Provenance tags:
- `[sme-stated]` — stated by SME during interview, taken at face value
- `[doc-verified]` — corroborated by existing documentation
- `[code-verified]` — corroborated by examining actual code/config
- `[inferred]` — derived by agent from multiple SME statements
- `[contested]` — SME statement conflicts with docs/code/other evidence

## Domain Section Derivation

Sections are derived from the coverage matrix, not from a static list:
- **Technical topics:** Components, Architecture, Dependencies, Data Flow
- **Process topics:** Workflow Steps, Inputs/Outputs, Exception Handling
- **Operational topics:** Runbook Steps, Monitoring, Escalation Paths
- **Decision topics:** Context, Options Considered, Decision, Rationale

## Title Guidance

- Title for findability: "[System/Process Name] — [Article Type]"
- Examples: "Telephony Failover — Architecture Reference", "LLM Provider Routing — Runbook"
- Avoid generic titles like "Notes on X" or "About Y"

