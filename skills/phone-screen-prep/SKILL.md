---
name: phone-screen-prep
description: "Prepare phone screen notes file from template with targeted questions based on screening concerns."
---

# Phone Screen Prep

> **📋 Screening criteria source:** https://wiki.int.callbox.net/doc/llm-prompt-LfFH19Gj0y
>
> **⚠️ Check for updates daily.** Targeted questions are derived from the canonical screening prompt.

---

## 🔗 Cross-References

| Resource | Location | Update When |
|----------|----------|-------------|
| **Phone Screen Template** | `a.People/Recruiting/Phone Screen Notes/_TEMPLATE.md` | Changing interview structure |
| **Phone Screen Guide** | `a.People/Recruiting/Sr Eng Phone Screen Guide.md` | Changing questions or flow |
| **Resume Screening Skill** | `superpowers-skills/resume-screening/skill.md` | Changing what concerns to probe |
| **Completed Phone Screens** | `a.People/Recruiting/Phone Screen Notes/DONE/` | Reference for examples |
| **Wiki LLM Prompt** | [wiki.int.callbox.net](https://wiki.int.callbox.net/doc/llm-prompt-LfFH19Gj0y) | Source of truth for criteria |

### Dependency Chain

```
resume-screening skill (identifies concerns)
       │
       ▼ feeds into
phone-screen-prep skill (THIS FILE — generates targeted questions)
       │
       ▼ copies and customizes
_TEMPLATE.md (master template)
       │
       ▼ creates
Phone Screen Notes/FirstName_LastName__YYYY-MM-DD.md
       │
       ▼ interviewer fills, then pastes back for
LLM Synthesis (produces clean debrief summary)
```

---

## Overview

Creates a phone screen notes file for a candidate, including **targeted questions based on screening concerns** identified from their resume evaluation.

## Invocation

User says one of:
- "Prep phone screen for [First Last]"
- "Create phone screen file for [Name]"
- "Set up interview notes for [Name]"

Include:
- Paylocity URL
- Resume PDF path (for screening concerns)
- LinkedIn URL (optional)
- GitHub URL (optional)

## Workflow

1. **Run resume screening** on the candidate's resume to identify concerns
2. **Copy template** from: `a.People/Recruiting/Phone Screen Notes/_TEMPLATE.md`
3. **Create new file**: `a.People/Recruiting/Phone Screen Notes/FirstName_LastName__YYYY-MM-DD.md`
4. **Replace placeholders**:
   - `[CANDIDATE NAME]` → Candidate's full name
   - `[YYYY-MM-DD]` → Today's date
   - `[Paylocity]()` → `[Paylocity](url)` if provided
   - `[GitHub]()` → `[GitHub](url)` if provided
   - `[LinkedIn]()` → `[LinkedIn](url)` if provided
   - Salary expectation from screening
5. **Add "Screening Concerns — Targeted Questions" section** with:
   - Each concern from the resume screening
   - 1-2 specific questions to probe that concern
   - Placed before the "Why CallBox?" section

## Targeted Questions Format

```markdown
## ⚠️ Screening Concerns — Targeted Questions

Based on resume screening, probe these specific gaps:

### 1. [Concern Area]
**Concern:** [What the screening identified]

_"[Specific question to probe this]"_

_"[Follow-up question if needed]"_
```

## Common Concerns to Probe

| Concern | Sample Questions |
|---------|------------------|
| Frontend-heavy | "Walk me through a backend system you built from scratch — data model, scaling, failure handling." |
| No IaC | "Have you written Terraform, CDK, CloudFormation? Walk me through a module you built." |
| Weak scale metrics | "What's the highest traffic system you worked on? Give me RPS, latency targets, database size." |
| Consulting/agency | "How many release cycles did you own end-to-end at [company]?" |
| Short tenure | "What drove the transitions between roles?" |
| Salary mismatch | "Our range is $X base-only, no equity. Does that work for you?" |
| No real-time | "What experience do you have with WebSockets, audio streaming, or low-latency pipelines?" |
| No LLM experience | "Have you integrated LLMs into production systems? Prompt engineering, evals, tool calling?" |

## NOT Concerns (Do Not Flag)

| Pattern | Why It's Normal |
|---------|-----------------|
| Empty/recent GitHub for big-company engineers | Google, Meta, Amazon, etc. use internal monorepos. Engineers often only create public repos when job hunting or after layoff. This is expected behavior, not a red flag. |
| No public OSS contributions | Many companies have strict IP policies. Lack of public OSS ≠ lack of coding ability. |
| GitHub created recently | Common post-layoff or pre-job-search. Ask for context if curious, but don't treat as suspicious. |

## File Naming Convention

`FirstName_LastName__YYYY-MM-DD.md`

Examples:
- `Daniel_Lee__2026-01-12.md`
- `Shoaib_Beil__2026-01-13.md`

## Template Location

`a.People/Recruiting/Phone Screen Notes/_TEMPLATE.md`

## Output

1. Confirm file created with full path
2. List the targeted questions added
3. Remind user to fill in notes during the call
4. After call, user pastes filled notes and agent synthesizes using LLM prompt at bottom of template

