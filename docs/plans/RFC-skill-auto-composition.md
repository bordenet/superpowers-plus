# RFC: Skill Auto-Composition Engine

**Status:** Implemented
**Author:** Matt Bordenet
**Date:** 2026-03-16
**Version:** 1.0

---

## 1. Problem Statement

### Current State

Skills are coordinated via manual `coordination:` blocks in YAML frontmatter:

```yaml
coordination:
  group: wiki-pipeline
  order: 1
  requires: []
  enables: [link-verification, wiki-editing]
```

### Limitations

| Problem | Impact |
|---------|--------|
| **Manual maintenance** | Every new skill needs hand-authored coordination blocks |
| **Static pipelines** | Same chain runs regardless of context (public repo vs. internal wiki) |
| **Implicit knowledge** | Why does link-verification come before wiki-editing? You must read docs |
| **Brittle ordering** | Adding a skill mid-pipeline requires updating multiple files |
| **No composability** | Skills can't dynamically combine based on task requirements |

### The Gap

We know WHAT each skill does, but not WHAT it needs or WHAT it produces. This prevents automatic pipeline construction.

---

## 2. Proposed Solution

Extend skill frontmatter with **capability declarations**:

- **`produces`** — What artifacts/states this skill creates
- **`consumes`** — What artifacts/states this skill requires as input
- **`capabilities`** — What verification/transformation this skill performs

The router builds pipelines by **matching producers to consumers** — like Unix pipes, but for AI skills.

### Core Insight

```
wiki-authoring PRODUCES markdown-content
link-verification CONSUMES markdown-content, PRODUCES verified-links
wiki-editing CONSUMES verified-links, PRODUCES published-page
```

Pipeline emerges automatically: `authoring → verification → editing`

---

## 3. Schema Design

### New Frontmatter Fields

```yaml
composition:
  produces: [<artifact>, ...]      # What this skill outputs
  consumes: [<artifact>, ...]      # What this skill requires
  capabilities: [<capability>, ...]  # What transformations it applies
  priority: <number>                # Tie-breaker when multiple skills match (lower = earlier)
  optional: <boolean>               # Can be skipped if inputs unavailable (default: false)
```

### Artifact Taxonomy (Initial)

| Artifact | Description |
|----------|-------------|
| `markdown-content` | Raw markdown text |
| `verified-links` | Content with all URLs validated |
| `verified-facts` | Content with claims fact-checked |
| `sanitized-content` | Content with secrets/PII removed |
| `quality-prose` | Content with AI slop eliminated |
| `published-page` | Content written to wiki platform |
| `user-intent` | Parsed user request |

### Capability Taxonomy (Initial)

| Capability | Description |
|------------|-------------|
| `validates-links` | Checks URLs resolve |
| `validates-facts` | Checks claims against sources |
| `detects-secrets` | Scans for credentials |
| `eliminates-slop` | Rewrites machine-like prose |
| `publishes-wiki` | Writes to wiki platform |
| `generates-content` | Creates new content |

---

## 4. Concrete Examples: Wiki Skills

### wiki-orchestrator

```yaml
name: wiki-orchestrator
composition:
  consumes: [user-intent]
  produces: [pipeline-plan]
  capabilities: [orchestrates-pipeline]
  priority: 0
```

### wiki-authoring

```yaml
name: wiki-authoring
composition:
  consumes: [user-intent]
  produces: [markdown-content]
  capabilities: [generates-content]
  priority: 10
```

### link-verification

```yaml
name: link-verification
composition:
  consumes: [markdown-content]
  produces: [verified-links]
  capabilities: [validates-links]
  priority: 20
```

### wiki-secret-audit

```yaml
name: wiki-secret-audit
composition:
  consumes: [markdown-content]
  produces: [sanitized-content]
  capabilities: [detects-secrets]
  priority: 25
```

### wiki-debunker

```yaml
name: wiki-debunker
composition:
  consumes: [markdown-content]
  produces: [verified-facts]
  capabilities: [validates-facts]
  priority: 30
  optional: true
```

### eliminating-ai-slop

```yaml
name: eliminating-ai-slop
composition:
  consumes: [markdown-content]
  produces: [quality-prose]
  capabilities: [eliminates-slop]
  priority: 35
```

### wiki-editing

```yaml
name: wiki-editing
composition:
  consumes: [verified-links, sanitized-content]
  produces: [published-page]
  capabilities: [publishes-wiki]
  priority: 100
  requires_all: true  # Needs ALL consumed artifacts, not just one
```

---

## 5. Router Algorithm

### Pseudocode

```javascript
function buildPipeline(targetCapability, availableArtifacts = ['user-intent']) {
  const pipeline = [];
  const produced = new Set(availableArtifacts);
  const visited = new Set();

  // Find skill that produces the target capability
  const targetSkill = findSkillWithCapability(targetCapability);
  if (!targetSkill) return null;

  // Recursively resolve dependencies
  function resolve(skill) {
    if (visited.has(skill.name)) return; // Prevent cycles
    visited.add(skill.name);

    // Check if all consumed artifacts are available
    const missing = skill.consumes.filter(a => !produced.has(a));

    // For each missing artifact, find a producer and resolve it first
    for (const artifact of missing) {
      const producer = findSkillThatProduces(artifact);
      if (producer) {
        resolve(producer); // Recursive: resolve producer's dependencies first
      }
    }

    // Add this skill to pipeline
    pipeline.push(skill);

    // Mark its outputs as available
    skill.produces.forEach(a => produced.add(a));
  }

  resolve(targetSkill);

  // Sort by priority for stable ordering
  return pipeline.sort((a, b) => a.priority - b.priority);
}
```

### Key Properties

| Property | Behavior |
|----------|----------|
| **Dependency resolution** | Skills added only when their inputs are satisfied |
| **Cycle detection** | Visited set prevents infinite loops |
| **Priority ordering** | Lower priority = earlier in pipeline |
| **Optional skills** | Skipped if inputs unavailable and `optional: true` |

---

## 6. Example Workflow

**User says:** "Create a wiki page about our authentication API"

### Step 1: Intent Detection

Router detects target: `publishes-wiki` capability needed.

### Step 2: Dependency Resolution

```
wiki-editing CONSUMES [verified-links, sanitized-content]
  ├── link-verification CONSUMES [markdown-content] PRODUCES [verified-links]
  │     └── wiki-authoring CONSUMES [user-intent] PRODUCES [markdown-content]
  └── wiki-secret-audit CONSUMES [markdown-content] PRODUCES [sanitized-content]
        └── (markdown-content already produced by wiki-authoring)
```

### Step 3: Pipeline Construction

After topological sort by priority:

| Order | Skill | Priority | Consumes | Produces |
|-------|-------|----------|----------|----------|
| 1 | wiki-authoring | 10 | user-intent | markdown-content |
| 2 | link-verification | 20 | markdown-content | verified-links |
| 3 | wiki-secret-audit | 25 | markdown-content | sanitized-content |
| 4 | wiki-editing | 100 | verified-links, sanitized-content | published-page |

### Step 4: Execution

Router invokes skills in order, passing artifacts between them.

---

## 7. Migration Path

### Coexistence Strategy

| Scenario | Behavior |
|----------|----------|
| Skill has `coordination:` only | Use explicit ordering (legacy mode) |
| Skill has `composition:` only | Use auto-composition |
| Skill has both | `coordination:` overrides auto-composition for that group |
| Mixed pipeline | Explicit skills anchor the chain, auto-composition fills gaps |

### Migration Steps

1. **Phase 1:** Add `composition:` to wiki skills (keep `coordination:`)
2. **Phase 2:** Validate auto-composed pipelines match manual ones
3. **Phase 3:** Remove `coordination:` blocks from migrated skills
4. **Phase 4:** Deprecate `coordination:` for new skills

### Backward Compatibility

Existing skills without `composition:` continue to work. The router falls back to:
1. Explicit `coordination:` groups
2. Trigger-based invocation (current behavior)

---

## 8. Risks & Mitigations

### Risk 1: Composition Explosion

**Problem:** Multiple skills produce `markdown-content` — which one to choose?

**Mitigation:**
- Priority field breaks ties (lower = preferred)
- Capability specificity: `generates-wiki-content` vs. `generates-content`
- Context hints: repo type, recent files, user history

### Risk 2: Debugging Complexity

**Problem:** "Why did skill X run before skill Y?"

**Mitigation:**
- `--explain` flag shows composition reasoning
- Log artifact flow: `[link-verification] consumed markdown-content from wiki-authoring`
- Visualize pipeline as Mermaid diagram before execution

### Risk 3: Circular Dependencies

**Problem:** A consumes B, B consumes A

**Mitigation:**
- Visited set in resolver (see algorithm)
- Validation at skill install time: reject cycles
- Clear error: "Circular dependency: A → B → A"

### Risk 4: Missing Producers

**Problem:** Skill needs `verified-facts` but no skill produces it

**Mitigation:**
- If `optional: true`, skip the consumer
- If required, fail fast with clear message: "No skill produces verified-facts"
- Suggest: "Install wiki-debunker to enable fact verification"

---

## 9. Success Criteria

### Prototype (Week 1) ✅ COMPLETE

- [x] `composition:` fields added to 6 wiki/writing skills
- [x] `buildPipeline()` function in skill-router.js
- [x] `explainPipeline()` shows proposed pipeline without executing
- [x] Auto-composed wiki pipeline matches expected order exactly

### MVP (Sprint 1)

- [ ] 15+ skills have `composition:` fields
- [ ] Router handles optional skills correctly
- [ ] Pipeline visualization in Mermaid format
- [ ] No regression in existing skill behavior

### Full Release

- [ ] All skills migrated to `composition:` (coordination: deprecated)
- [ ] Context-aware producer selection (repo type hints)
- [ ] Observability: log artifact flow for debugging
- [ ] Documentation: artifact taxonomy, capability taxonomy

---

## 10. Open Questions

1. **Should artifacts be typed?** (e.g., `markdown-content:wiki` vs `markdown-content:readme`)
2. **How do we handle skills that modify in-place?** (consumes X, produces X')
3. **Can users override auto-composition?** (`--skip link-verification`)
4. **Should pipelines be cached?** (same task = same pipeline)

---

## Appendix: Full Schema Reference

```yaml
composition:
  # What this skill creates (required for producers)
  produces:
    - artifact-name

  # What this skill needs as input (required for consumers)
  consumes:
    - artifact-name

  # What transformations this skill performs (for discovery)
  capabilities:
    - capability-name

  # Execution order tie-breaker (lower = earlier, default: 50)
  priority: 50

  # Can be skipped if inputs unavailable (default: false)
  optional: false

  # Requires ALL consumed artifacts vs. ANY (default: false = ANY)
  requires_all: false

  # Context hints for producer selection
  context:
    repo_types: [typescript, wiki-heavy]
    file_patterns: ["*.md", "docs/**"]
```
