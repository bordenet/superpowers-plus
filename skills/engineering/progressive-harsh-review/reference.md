## Anti-Patterns

| Anti-Pattern | Detection | Correction |
|--------------|-----------|------------|
| Soft review | No score <7 given | Recalibrate with known-bad example |
| Same feedback loop | Same comment 3 iterations | Escalate to structural fix |
| Style over substance | All comments are formatting | Check logic, edge cases, error handling first |
| Perfection paralysis | 3+ rounds, no convergence | Hard limit: 3 rounds then **escalate to human** — do NOT ship |
| Missing context | Review without reading full file | Load surrounding context first |
