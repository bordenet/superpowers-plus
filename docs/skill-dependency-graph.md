# Skill Dependency Graph

> **Auto-generated** by `tools/generate-skill-dag.js`
> **Last updated:** 2026-03-25

This document visualizes the coordination relationships between skills in superpowers-plus.

## Diagram

```mermaid
graph TD
  subgraph engineering["Engineering"]
    feature_development["feature-development"]
  end

  subgraph debugging["Debugging"]
    investigation_state["investigation-state"]
  end

  subgraph commit-gates["Commit Gates"]
    pre_commit_gate["pre-commit-gate"]
    enforce_style_guide["enforce-style-guide"]
    progressive_code_review_gate["progressive-code-review-gate"]
    professional_language_audit["professional-language-audit"]
    public_repo_ip_audit["public-repo-ip-audit"]
  end

  subgraph completion-gate["Completion Gate"]
    exhaustive_audit_validation["exhaustive-audit-validation"]
    verification_before_completion["verification-before-completion"]
  end

  subgraph stuck-escalation["Stuck Escalation"]
    think_twice["think-twice"]
    perplexity_research["perplexity-research"]
  end

  subgraph thinking["Thinking"]
    thinking_orchestrator["thinking-orchestrator"]
  end

  subgraph wiki-pipeline["Wiki Pipeline"]
    wiki_orchestrator["wiki-orchestrator"]
    wiki_content_coherence["wiki-content-coherence"]
  end

  feature_development -->|enables| requirements_validation
  feature_development -->|enables| design_triad
  feature_development -->|enables| todo_management
  feature_development ==>|escalates to| thinking_orchestrator
  investigation_state -->|enables| think_twice
  investigation_state ==>|escalates to| thinking_orchestrator
  pre_commit_gate -->|enables| enforce_style_guide
  enforce_style_guide -->|then| progressive_code_review_gate
  progressive_code_review_gate -->|enables| professional_language_audit
  exhaustive_audit_validation -->|enables| verification_before_completion
  think_twice ==>|escalates to| perplexity_research
  thinking_orchestrator -->|enables| adversarial_search
  thinking_orchestrator -->|enables| think_twice
  thinking_orchestrator -->|enables| verification_before_completion
  thinking_orchestrator -->|enables| exhaustive_audit_validation
  thinking_orchestrator -->|enables| completeness_check
  thinking_orchestrator -->|enables| investigation_state
  thinking_orchestrator -->|enables| feature_development
  professional_language_audit -->|then| public_repo_ip_audit
  wiki_orchestrator -->|then| wiki_content_coherence
  wiki_content_coherence -->|enables| link_verification
  wiki_content_coherence ==>|escalates to| wiki_orchestrator
  wiki_orchestrator -->|enables| link_verification
```

## Coordination Groups

| Group | Skills | Purpose |
|-------|--------|---------|
| Engineering | `feature-development` | Coordinated skill group |
| Debugging | `investigation-state` | Coordinated skill group |
| Commit Gates | `pre-commit-gate`, `enforce-style-guide`, `progressive-code-review-gate`, `professional-language-audit`, `public-repo-ip-audit` | Quality checks before git commit |
| Completion Gate | `exhaustive-audit-validation`, `verification-before-completion` | Verification and TODO maintenance before claiming done |
| Stuck Escalation | `think-twice`, `perplexity-research` | Getting unstuck when blocked |
| Thinking | `thinking-orchestrator` | Metacognition and thinking orchestration |
| Wiki Pipeline | `wiki-orchestrator`, `wiki-content-coherence` | Wiki authoring quality pipeline |

## Legend

| Edge Type | Meaning |
|-----------|---------|
| `-->` solid | "enables" — this skill unlocks the next |
| `-.->` dashed | "requires" — must run before |
| `==>` thick | "escalates to" — fallback if insufficient |
| `[internal]` | Not user-invocable; called by other skills |

## Namespaced Triggers

Skills now support namespaced triggers (`domain:action`) for disambiguation:

| Domain | Example Triggers |
|--------|------------------|
| `commit:` | `commit:pre-check`, `commit:style`, `commit:language`, `commit:ip-audit` |
| `wiki:` | `wiki:create`, `wiki:update`, `wiki:edit-internal`, `wiki:verify-links` |
| `stuck:` | `stuck:reasoning`, `stuck:research`, `stuck:knowledge` |

## Regenerating This Document

```bash
node tools/generate-skill-dag.js
```
