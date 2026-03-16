# Mode 2: From Recorded Patterns

Synthesize skills from patterns recorded in the learning state.

---

## How Patterns Are Recorded

The `skill-effectiveness` skill records patterns via:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js record-pattern "description" potential-skill-name
```

Patterns are stored in `~/.codex/.learning-state.json`:

```json
{
  "pattern_observations": [
    {
      "pattern": "When reviewing PRs, always check for console.log statements",
      "potential_skill": "console-log-detector",
      "frequency": 5,
      "status": "observed",
      "first_seen": "2026-03-01T...",
      "last_seen": "2026-03-15T..."
    }
  ]
}
```

---

## Finding Synthesis Candidates

### Step 1: Check Learning State

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js learning-report
```

Look for **"Emerging Patterns"** section — patterns with frequency ≥ 3.

### Step 2: Evaluate Candidates

For each candidate, assess:

| Criteria | Question |
|----------|----------|
| **Frequency** | Has it occurred 3+ times? |
| **Specificity** | Is it concrete enough to codify? |
| **Reusability** | Will it apply beyond current context? |
| **Gap** | Is there already a skill for this? |

### Step 3: Propose to User

Present candidates ranked by frequency:

```
## Skill Synthesis Candidates

| Pattern | Frequency | Suggested Name |
|---------|-----------|----------------|
| "Always run lint before commit" | 7 | pre-commit-lint |
| "Check for API key exposure in diffs" | 5 | secret-diff-check |
| "Verify test coverage after changes" | 3 | coverage-gate |

Would you like me to generate a skill for any of these?
```

---

## Synthesis Process

### Step 1: Extract from Pattern

The pattern description contains the "what" — extract:
- **Trigger conditions** — When does this pattern apply?
- **Actions** — What does the pattern involve doing?
- **Outcome** — What's the goal?

### Step 2: Expand with Context

Patterns are terse. Ask clarifying questions:
- What tools are involved?
- What does success look like?
- Should this be a gate (blocking) or advisory?

### Step 3: Generate Draft

Use the pattern as the seed, expand into full skill structure.

---

## Example

**Pattern in learning-state:**
```json
{
  "pattern": "Before pushing, verify no hardcoded URLs to staging/dev environments",
  "potential_skill": "env-url-checker",
  "frequency": 4
}
```

**Synthesized skill:**

```yaml
---
name: env-url-checker
source: superpowers-plus
triggers: ["check for hardcoded URLs", "env URL audit", "staging URL check", "before push URL scan"]
description: Use before pushing to verify no hardcoded staging/dev URLs. Prevents accidental exposure of internal environments.
---

# Environment URL Checker

> **Purpose:** Catch hardcoded staging/dev URLs before they reach production
> **Origin:** Synthesized from pattern observation (frequency: 4)

## When to Use

- Before `git push` to remote
- During code review
- After refactoring configuration

## Process

### Step 1: Scan for URL Patterns

Look for:
- `staging.`, `dev.`, `test.` subdomains
- `localhost`, `127.0.0.1` references
- Non-production port numbers (3000, 8080, etc.)

### Step 2: Classify Findings

| Finding | Severity |
|---------|----------|
| Hardcoded staging URL in code | 🔴 Critical |
| Localhost in config file | 🟡 Warning |
| Dev URL in comments | 🟢 Info |

### Step 3: Remediate

Replace hardcoded URLs with environment variables or config references.
```

---

## Marking Patterns as Synthesized

After generating a skill from a pattern:

```javascript
// In learning-state.js, pattern status becomes:
{
  "status": "synthesized",
  "synthesized_to": "env-url-checker",
  "synthesized_at": "2026-03-16T..."
}
```

This prevents re-proposing the same pattern.
