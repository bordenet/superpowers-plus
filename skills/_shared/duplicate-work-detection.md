# Duplicate Work Detection

> **Purpose:** Detect and handle overlapping investigation branches to prevent wasted effort.
> **Used by:** `debug-conductor` (Phase 4 evidence validation), multi-agent synthesis layers.

## Detection Strategy

### Level 1: Structural Overlap (Fast, Cheap)

Compare evidence item fields across branches:

```markdown
For each pair of branches (A, B):
  overlap_score = |evidence_sources(A) ∩ evidence_sources(B)| / |evidence_sources(A) ∪ evidence_sources(B)|
```

| Score | Action |
|-------|--------|
| > 0.7 | **Merge branches** — investigating the same thing |
| 0.4–0.7 | **Flag for review** — may have legitimate overlap |
| < 0.4 | **No action** — sufficiently distinct |

### Level 2: Hypothesis Overlap (Medium Cost)

Compare branch hypotheses by key terms:

1. Extract key entities from each hypothesis (service names, error types, config keys)
2. Compute entity overlap: shared entities / total unique entities
3. If overlap > 0.6 AND same verdict direction → likely duplicate

### Level 3: Evidence Conclusion Overlap (Higher Cost)

Compare branch verdicts and supporting evidence conclusions:

1. If two branches reach the same verdict with the same supporting evidence → duplicate
2. If two branches reach opposite verdicts about the same hypothesis → valuable divergence (keep both)

## Merge Protocol

When branches are flagged as duplicates:

1. **Keep the branch with higher confidence** as primary
2. **Merge unique evidence** from the secondary branch into the primary
3. **Record the merge** in the incident packet: which branches merged, why, what evidence was added
4. **Kill the secondary branch** (stops consuming budget)

## Integration Points

### In debug-conductor (Phase 4)

```python
After receiving evidence from branch N:
  For each existing branch M (M ≠ N):
    score = structural_overlap(M.evidence, N.evidence)
    If score > 0.7:
      merge(keep=higher_confidence, absorb=lower_confidence)
      log merge decision to incident packet
```

### In multi-agent synthesis layers

```text
Before synthesis:
  Group branch outputs by structural similarity
  Within each group: merge duplicates, keep strongest
  Pass deduplicated groups to synthesizer
```

## Honest Limitation

Structural overlap (Jaccard on source names) is naive. Two branches investigating "replication lag" and "cache staleness" may use completely different evidence sources but be investigating the same root cause from different angles. **Semantic duplicate detection requires embedding-based comparison, which is deferred to Wave 4+.** For now, structural overlap is a conservative floor — it catches obvious duplicates but misses subtle ones.
