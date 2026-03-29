# Phone Screen Prep Skill

A [superpowers skill](../install-augment-superpowers.sh) that generates phone screen notes files with targeted questions based on resume screening concerns.

> **📚 Wiki:** https://wiki.int.callbox.net/doc/superpowers-skills-cASQJAkNFD

---

## 🤖 AI Instructions

<CRITICAL>
**When modifying this skill, you MUST also update the wiki:**
https://wiki.int.callbox.net/doc/superpowers-skills-cASQJAkNFD

Update the "Recruiting Skills" section with any behavioral changes.
</CRITICAL>

---

## 🔗 Cross-References

| Resource | Location | Update When |
|----------|----------|-------------|
| **This skill source** | `skills/phone-screen-prep/skill.md` | Changing skill logic |
| **Phone Screen Template** | `Recruiting/Templates/phone-screen.md` (git-tracked) | Changing interview structure |
| **Phone Screen Guide** | `$RECRUITING_DIR/Sr Eng Phone Screen Guide.md` | Changing questions or flow |
| **Resume Screening Skill** | `skills/resume-screening/` | Changing what concerns to probe |
| **Wiki LLM Prompt** | [wiki.int.callbox.net](https://wiki.int.callbox.net/doc/llm-prompt-LfFH19Gj0y) | Source of truth for criteria |

### Dependency Chain

```
resume-screening skill (identifies concerns)
       │
       ▼ feeds into
phone-screen-prep skill (THIS SKILL — generates prioritized questions)
       │
       ▼ copies and customizes
phone-screen.md (git-tracked template)
       │
       ▼ creates
$RECRUITING_DIR/Phone Screens/FirstName_LastName__YYYY-MM-DD.md (OneDrive, NOT git)
       │
       ▼ interviewer fills, then pastes back for
LLM Synthesis (produces clean debrief summary)
```

---

## Candidate Source Modes

This skill operates in two modes based on how the candidate was sourced:

| Mode | Trigger | What Changes |
|------|---------|--------------|
| **DIRECT-APPLY** (default) | No trigger needed | Full template with comp/fraud sections |
| **RECRUITER-SOURCED** | "from a recruiter", "recruiter-sourced", "agency candidate" | Cleaner sheet, skip comp/verification |

### RECRUITER-SOURCED Mode

When user indicates candidate came from a recruiter/agency:

| Skipped in Phone Screen Sheet | Kept |
|-------------------------------|------|
| Comp Confirmation script | Integrity Policy (MANDATORY) |
| Work authorization check | Technical depth questions |
| Employer/Project Verification section | Four Quadrants assessment |
| Fraud detection questions | AI-detection questions |

**Output adjustments:**

- Header shows: `**Source:** Recruiter ([Name])`
- Comp section becomes one-liner: `**Comp:** Recruiter-confirmed ($XXXk)`
- No `## 🔍 Employer/Project Verification` section
- Extra Q slot for technical depth (comp time freed up)

---

## Quick Start

**Direct-Apply (Paylocity):**

```
1. Screen candidate first: "Screen at $150k cap" + resume
2. Then say: "Prep phone screen for Alex Tang"
3. Agent creates: $RECRUITING_DIR/Phone Screens/Alex_Tang__2026-01-20.md
```

**Recruiter-Sourced:**

```
1. Say: "Prep phone screen for Alex Tang — from recruiter"
2. Agent creates cleaner sheet (no comp script, no verification section)
```

---

## What It Does

1. **Runs resume screening** on the candidate to identify concerns
2. **Copies template** from `Recruiting/Templates/phone-screen.md` (git-tracked)
3. **Creates file** in `$RECRUITING_DIR/Phone Screens/` (OneDrive, NOT git)
4. **Generates prioritized Q1-Q6** based on screening flags:
   - Highest risk concerns first
   - Each question has priority area label and specific question text
   - Q6 is always Culture/Motivation

---

## Invocation

Say one of:
- "Prep phone screen for [First Last]"
- "Create phone screen file for [Name]"
- "Set up interview notes for [Name]"

Include:
- Resume (required — for screening concerns)
- Paylocity URL (optional)
- LinkedIn URL (optional)
- GitHub URL (optional)

---

## Output

Creates a file like:

```markdown
# Phone Screen: Alex Tang

**Date:** 2026-01-20
**Role:** Senior Software Engineer (Team Delta)
...

## ⚠️ Screening Concerns — Targeted Questions

### 1. 🔴 5-Month Tenure at Rocket Lawyer
**Concern:** Left Amazon L6 after 4.5 years, then only 5 months at Rocket Lawyer.

_"You were at Amazon for 4.5 years at L6 — that's senior. Then you went to 
Rocket Lawyer in July 2025 and left in November. Walk me through what happened."_

### 2. 🟡 Backend → Frontend Pivot
**Concern:** Amazon was Java/Python/Go backend. Rocket Lawyer is Next.js/React frontend.

_"Your Amazon role was distributed backend. Your Rocket Lawyer role is UI components. 
What's going on with your career trajectory?"_
...
```

---

## Common Concerns to Probe

| Concern | Sample Question |
|---------|-----------------|
| Short tenure | "What drove the transitions between roles?" |
| Frontend-heavy | "Walk me through a backend system you built from scratch." |
| No IaC | "Have you written Terraform, CDK, CloudFormation?" |
| Weak scale metrics | "What's the highest traffic system you worked on? RPS, latency, DB size?" |
| Consulting/agency | "How many release cycles did you own end-to-end?" |
| Salary mismatch | "Our range is $X base-only, no equity. Does that work?" |
| No real-time | "What experience with WebSockets, audio streaming, low-latency?" |
| No LLM experience | "Have you integrated LLMs into production? Evals, tool calling?" |
| Contractor pattern | "What made you choose contract work vs. full-time?" |

---

## After the Phone Screen

1. Fill in notes during the call
2. Paste completed notes back to Augment
3. Say: "Synthesize these notes"
4. Agent produces clean summary for Paylocity

---

## Files

| File | Purpose |
|------|---------|
| `skill.md` | Skill definition (Augment reads this) |
| `README.md` | Human documentation (you're reading this) |

---

## Version

- 1.2.0 — 2026-02-13: Added RECRUITER-SOURCED vs DIRECT-APPLY candidate source modes
- 1.1.0 — 2026-01-20: Added cross-references and contractor probes
- 1.0.0 — 2026-01-13: Initial release
