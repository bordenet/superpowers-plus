# Output Formats Module

> **Load when:** Generating final screening report
> **Purpose:** Consistent output structure for candidate tracking

## Core Principle

**BOTTOM LINE UP FRONT.** Decision first. Questions second. Evidence last.

---

## Standard Report Format

```markdown
# [Candidate Name]

## HIRE | NO HIRE | PROBE

---

## Phone Screen Questions

1. "[Most critical flag — phrase as direct question]"
2. "[Second critical flag]"
3. "[Third flag if needed]"
4. "[Fourth flag if needed]"

---

## Loop Questions (First Interviewer)

1. "[Question validating startup readiness / scrappy execution]"
2. "[Question validating growth mindset / learning new domains]"
3. "[Question validating leadership / mentorship]"

---

## Rationale

[2-3 sentences explaining decision. Key strengths + flags. AFTER questions because questions are action items.]

---

## Supporting Evidence

**Experience:** [X years] — [Company trajectory]
**Education:** [Degree, school]
**Salary:** $[X]k [✓ in range / ✗ over cap]
**GitHub:** [URL or N/A]

| Screening Answer | Matches Resume? |
|------------------|-----------------|
| [Key claim] | ✓/✗ [Which bullet] |
| [Key claim] | ✓/✗ [Which bullet] |

**AI Slop:** [None detected / Detected — explain]

---

## Flags

| Flag | Severity | Covered By |
|------|----------|------------|
| [Specific concern] | Red/Yellow/Low | Phone Q# |
| [Specific concern] | Red/Yellow/Low | Phone Q# |
```

---

## Flag Severity Guide

| Severity | Meaning | Action |
|----------|---------|--------|
| **Red** | Fabrication, title inflation, disqualifying | Must resolve before proceeding |
| **Yellow** | Ambiguous, needs clarification | Phone screen resolves |
| **Low** | Minor gap, fungible engineer can close | Note but don't over-weight |

---

## Output Rules

### Rule 1: ONE CANDIDATE PER REPORT

Never mention other candidates:
- ❌ "Unlike the previous candidate..."
- ❌ "Similar to other fraud cases..."
- ✅ Report ONLY on candidate being evaluated

### Rule 2: NO PREAMBLE

Start with report immediately:
- ❌ "I've completed the investigation. Here's what I found..."
- ❌ "Let me summarize..."
- ✅ `# [Candidate Name]`

### Rule 3: CONVICTION DISCLOSURE

Per legal requirements: "Conviction of a crime will not be an absolute bar to employment."
- Do NOT auto-reject on criminal history
- Note factually if disclosed
- Do NOT speculate about undisclosed

---

## Simplified Format (Agency Candidates)

For recruiter-sourced candidates, use abbreviated format:

```markdown
## Supporting Evidence

**Experience:** [X years] — [Company trajectory]
**Education:** [Degree, school]
**GitHub:** [URL or N/A]
**LinkedIn:** [URL] ✅ Verified

**AI Slop:** [None detected / Detected — explain]
```

**Omit:**
- Salary line (agency handles comp)
- Screening Answer cross-reference table (no Paylocity form)

---

## Verdict Definitions

| Verdict | Meaning |
|---------|---------|
| **HIRE** | Strong candidate, proceed to phone screen |
| **NO HIRE** | Does not meet bar, stop |
| **PROBE** | Ambiguous signals, phone screen to resolve specific questions |

---

## Context Management

- **ALWAYS use fresh chat** for each candidate
- One candidate per session
- Prevents context contamination
