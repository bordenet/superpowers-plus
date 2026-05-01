# Skill Reference

Complete list of skills in superpowers-plus. Auto-trigger skills fire based on context; explicit skills are invoked manually.

## Engineering

| Skill | Description |
|-------|-------------|
| `blast-radius-check` | Search for ALL usages before modifying existing code. Prevents breaking unrelated consumers. |
| `brainstorming` | Explores user intent, requirements, and design before implementation. Fires before creative work. |
| `code-review-battery` | Dispatches 5 parallel specialist reviewers instead of one shallow pass. Slash command: `/sp-cr-battery [min-score]` (optional 1.0–10.0 quality threshold, default 7.0). `/sp-deepreview` is a legacy synonym. |
| `cognitive-complexity-refactoring` | Refactors functions flagged by Biome for excessive cognitive complexity. |
| `debug-conductor` | PREVIEW. Conductor-led bounded investigation for complex distributed incidents. |
| `debate` | Generates 3+ decision options, builds comparison matrix, red-teams the winner. |
| `evidence-adjudicator` | Synthesizes evidence from investigator branches into a root cause verdict. |
| `feature-development` | Full lifecycle orchestrator: brainstorm, debate, plan, TDD, review, verify. |
| `field-rename-verification` | Traces READ, STORE, PASS paths when renaming fields or changing API contracts. |
| `finishing-a-development-branch` | Guides completion of development work when implementation is done: mandates code review, presents merge/PR/cleanup options. |
| `git-branch-conventions` | Enforces semantic prefix naming on branch creation. |
| `implementation-tracker` | Maintains a living progress document across multi-session implementations. |
| `infra-config-investigator` | Diagnoses infrastructure, configuration, and deployment failures. |
| `investigation-state` | Persists debugging context (hypotheses, evidence) across sessions. |
| `llm-behavior-investigator` | Diagnoses LLM/prompt behavior issues: tool selection, prompt regressions, parsing failures. |
| `micro-harsh-review` | Per-batch adversarial review for code changes. 3 personas, 5 dimensions. Score <8 = reject. |
| `output-verification` | Hard gate before describing generated output. Prevents confabulation. |
| `pre-commit-gate` | Gate 1 of the commit chain: lint, typecheck, test. Deep-dive skill; invoke via `/sp-precommit` or through `unified-commit-gate`. |
| `unified-commit-gate` | Entry point for the full commit gate chain (`/sp-commit`). Runs all 5 gates in sequence; escalates to individual gate skills for deep-dive. Push mode adds sentinel check and proof-of-output requirement. |
| `progressive-code-review-gate` | Mandatory progressive review loop via sub-agent before commit/push. |
| `progressive-harsh-review` | Multi-persona adversarial review for non-code deliverables. Score <7 = reject. |
| `providing-code-review` | Engineering rigor gate for reviewing PRs. |
| `receiving-code-review` | Technical rigor when receiving feedback. No performative agreement. |
| `requesting-code-review` | Dispatches the code-review-battery before presenting code changes to a human. Skips if valid sentinel exists. |
| `reproduction-experiment-investigator` | Tests hypotheses through controlled reproduction attempts. |
| `requirements-validation` | Tests requirements for falsifiability, measurability, and independence. |
| `state-consistency-investigator` | Diagnoses state consistency failures: replication lag, cache staleness, event ordering. |
| `subagent-driven-development` | Executes implementation plans with independent parallel tasks. |
| `systematic-debugging` | Root-cause-first investigation: reproduce, hypothesize, isolate, fix. |
| `test-driven-development` | Write tests before implementation code. |
| `timeline-trace-investigator` | Reconstructs incident timelines from traces, logs, deployments, and metrics. |
| `verification-before-completion` | Evidence before assertions. Runs verification commands before claiming done. |

## Productivity

| Skill | Description |
|-------|-------------|
| `adversarial-search` | Forces search for the WRONG thing to prevent confirmation bias. |
| `autonomous-chain-controller` | Auto-detects required skill chain and executes with quality gates between steps. |
| `code-review-respond` | Acts as the reviewer agent for file protocol handoff. |
| `inter-agent-review-protocol` | Sends work to a separate reviewer agent via the `request.md` → `response.md` file protocol. |
| `domain-design` | Designs new skill families from scratch: research, brainstorm, review, prioritize, document. |
| `enforce-style-guide` | Checks shebang, error handling, help flags, line limits, ShellCheck compliance. |
| `fallback-planning` | Generates machine-agnostic fallback TODOs for top risks in an implementation plan. |
| `golden-agents` | Initializes or upgrades AI guidance (AGENTS.md) for git repos. |
| `innovation` | Produces a single high-conviction innovation answer for the project. |
| `plan-and-execute` | Challenge, plan, stress-test, phased execution with retrospectives between phases. |
| `quantitative-decision-gate` | Forces decision matrix evaluation before escalating questions to the user. |
| `skill-authoring` | Creates new skills from descriptions, patterns, or codebase analysis. |
| `superpowers-help` | Dynamically enumerates all installed skills at runtime. |
| `think-twice` | Detects stuck loops, dispatches fresh sub-agent with zero shared context. |
| `thinking-orchestrator` | Routes to correct thinking skill by context. |
| `todo-archive` | Low-level archive engine for completed TODO.md tasks. |
| `todo-guardian` | Auto-extracts TODOs from outputs, detects stale items, blocks completion if open TODOs exist. |
| `todo-management` | Task capture, tracking, triage, history queries, multi-step plan execution. |
| `update-superpowers` | Updates superpowers-plus to latest, reruns install cascade, verifies with doctor. |

## Writing

| Skill | Description |
|-------|-------------|
| `detecting-ai-slop` | Scores text 0-100 for machine-generated patterns across 4 dimensions. |
| `eliminating-ai-slop` | Rewrites prose to remove AI patterns. Interactive or automatic mode. |
| `markdown-table-discipline` | Best practices for table construction. Prevents noise, redundancy, accessibility issues. |
| `plan-quality-gates` | Prevents fabricated timelines, ensures dependency ordering, requires exit criteria. |
| `professional-language-audit` | Hard gate scanning for profanity before publishing documentation. |
| `readme-authoring` | Enforces README best practices, slop detection, quickstart-first structure. |
| `writing-skills` | Reviews skill files for prose quality and markdown formatting. |

## Wiki

| Skill | Description |
|-------|-------------|
| `link-verification` | Verifies all links before writing. Hard gate in wiki-orchestrator pipeline. |
| `wiki-markdown-structure-gate` | Blocks malformed wiki markdown structures before publish: tables, fences, callouts, heading hierarchy, escaped link artifacts, missing TOC on `toc_behavior=manual` pages with 4+ H2/H3 headings. |
| `wiki-content-coherence` | Detects duplicated sections, obsolete content, structural defects. |
| `wiki-debunker` | Verifies factual claims against git history, tickets, transcripts, and PRs. |
| `wiki-orchestrator` | Orchestrates bulk documentation projects with quality pipeline. |
| `wiki-refactor` | 7-phase pipeline for full wiki refactoring with scope caps and drift detection. |
| `wiki-secret-audit` | Scans wiki pages for exposed secrets, API keys, and tokens. |
| `wiki-verify` | Verifies codebase claims in wiki pages and updates stale content. |

## Observability

| Skill | Description |
|-------|-------------|
| `completeness-check` | Detects incomplete work from crashes, context exhaustion, or distractions. |
| `evolution-loop` | Scans failures for recurring patterns, generates skill updates, tracks metrics. |
| `exhaustive-audit-validation` | Enforces exhaustive scope enumeration and item-by-item tracking for bulk edits. |
| `failure-autopsy` | Post-mortem analyzer: 5-Why root cause, pattern detection, preventive actions. |
| `holistic-repo-verification` | Verifies ALL repository health aspects: CI, Pages, custom workflows. |
| `measurement-integrity` | Forces cross-validation and confidence qualification before reporting metrics. |
| `skill-health-check` | Structural lint for skill files: validates YAML, line counts, coordination metadata. |
| `superpowers-doctor` | 29-check diagnostic across all installed skills. Modeled after `brew doctor`. |

## Issue Tracking

| Skill | Description |
|-------|-------------|
| `issue-authoring` | Enforces formatting standards, required fields, label validation, duplicate checking. |
| `issue-comment-debunker` | Prevents fabricated investigation summaries in ticket comments. |
| `issue-editing` | Fetch-before-edit workflow to prevent stale updates and concurrent modifications. |
| `issue-link-verification` | Verifies all URLs before posting to issue descriptions or comments. |
| `issue-verify` | Verifies issue identifiers exist and validates cross-references. |

## Security

| Skill | Description |
|-------|-------------|
| `public-repo-ip-audit` | Audits public repos for proprietary IP before commit/push. |
| `repo-security-scan` | Scans for secrets, dependency vulnerabilities, and security posture. |
| `security-upgrade` | Scans dependencies for CVEs, upgrades, validates, commits. |
| `wiki-instruction-guard` | Blocks destructive operations extracted from wiki pages. |

## Research

| Skill | Description |
|-------|-------------|
| `expert-interviewer` | Structured interviewing to produce written artifacts from domain knowledge. |
| `incorporating-research` | Merges external research into documents. Strips artifacts, preserves voice. |
| `perplexity-research` | Escalates to Perplexity MCP when stuck after 2+ failed attempts. |

## Experimental

| Skill | Description |
|-------|-------------|
| `experimental-self-prompting` | PREVIEW. Context-free prompts before code analysis. Not production-ready. |
