# Technical Consultation Request

## Role

You are a senior software engineer and technical consultant. You are being
asked to provide a fresh perspective on a problem that another engineer has
been working on and is currently blocked. You have NO prior context —
everything you need is in this brief.

## Problem Statement

{{PROBLEM_STATEMENT}}

## Technical Context

- **Language/Framework:** {{LANGUAGE_FRAMEWORK}}
- **Environment:** {{ENVIRONMENT}}
- **Key Dependencies:** {{KEY_DEPENDENCIES}}
- **Architecture Notes:** {{ARCHITECTURE_NOTES}}

## What Has Been Tried

{{APPROACHES_TRIED}}

## Current Error/Blocker

{{ERROR_BLOCKER}}

```
{{ERROR_OUTPUT}}
```

## Relevant Code

```{{LANGUAGE}}
{{CODE_EXCERPT}}
```

## Constraints

{{CONSTRAINTS}}

## What I Need

{{SPECIFIC_ASK}}

## Research Guidance

Before answering, consider searching the web for:
- Recent issues/discussions related to {{SEARCH_TOPIC_1}}
- Alternative approaches to {{SEARCH_TOPIC_2}}
- Known bugs or breaking changes in {{SEARCH_TOPIC_3}}

Provide your recommendation with reasoning, code examples where helpful,
and any caveats or trade-offs.

---

## Template Usage Notes

When filling this template, the agent MUST:

1. **Problem Statement** — 2-4 sentences, plain English, what we're trying to accomplish
2. **Technical Context** — Be specific about versions (e.g., "Node.js 20.x, TypeScript 5.3")
3. **What Has Been Tried** — Numbered list with outcomes:
   ```
   1. [Approach] → [Result/Why it failed]
   2. [Approach] → [Result/Why it failed]
   ```
4. **Error/Blocker** — Exact error messages, not paraphrased
5. **Relevant Code** — Minimal reproducible snippet, NOT entire files
6. **Constraints** — Non-obvious limitations (perf, compat, library restrictions)
7. **What I Need** — Specific ask: "suggest alternative", "explain why X", "recommend pattern for Y"
8. **Research Guidance** — Fill in specific search topics relevant to the problem

## Quality Criteria

The filled prompt MUST:
- Be fully self-contained (any engineer could pick it up cold)
- Include concrete error messages / output (not vague descriptions)
- Separate facts from speculation
- Include what was tried AND why it failed
- Be under 2000 tokens (forces distillation)
- Explicitly encourage the consultant to search the web

