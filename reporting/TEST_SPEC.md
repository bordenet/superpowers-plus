# Test Specification: Reporting Superpower

> **Status:** Draft
> **Last Updated:** 2026-01-31
> **PRD:** [PRD.md](./PRD.md)
> **Design:** [DESIGN.md](./DESIGN.md)

## Test Categories

1. **Unit Tests** — Individual component behavior
2. **Integration Tests** — Component interactions
3. **End-to-End Tests** — Full workflow validation
4. **Edge Cases** — Error handling and recovery

---

## Unit Tests

### UT-1: Outcome Schema Validation

| ID | Test Case | Input | Expected |
|----|-----------|-------|----------|
| UT-1.1 | Valid outcome | `{skill_name, timestamp, outcome, outcome_reason}` | Accepted |
| UT-1.2 | Missing skill_name | `{timestamp, outcome, outcome_reason}` | Rejected with error |
| UT-1.3 | Missing timestamp | `{skill_name, outcome, outcome_reason}` | Auto-generate timestamp |
| UT-1.4 | Invalid outcome enum | `{..., outcome: "MAYBE"}` | Rejected with error |
| UT-1.5 | Empty outcome_reason | `{..., outcome_reason: ""}` | Rejected with error |
| UT-1.6 | Valid with metadata | `{..., metadata: {tool: "ask"}}` | Accepted |
| UT-1.7 | Invalid metadata type | `{..., metadata: "string"}` | Rejected with error |

### UT-2: Pending Queue Operations

| ID | Test Case | Input | Expected |
|----|-----------|-------|----------|
| UT-2.1 | Append to empty queue | First outcome | pending.jsonl created |
| UT-2.2 | Append to existing queue | Second outcome | Appended as new line |
| UT-2.3 | Read queue | N outcomes | Returns array of N objects |
| UT-2.4 | Truncate queue | After sync | pending.jsonl empty |
| UT-2.5 | Concurrent appends | Two outcomes simultaneously | Both recorded |

### UT-3: Aggregation Logic

| ID | Test Case | Input | Expected |
|----|-----------|-------|----------|
| UT-3.1 | First outcome for skill | SUCCESS | total=1, successful=1, rate=1.0 |
| UT-3.2 | Second outcome SUCCESS | SUCCESS | total=2, successful=2, rate=1.0 |
| UT-3.3 | Third outcome FAILURE | FAILURE | total=3, successful=2, rate=0.667 |
| UT-3.4 | PARTIAL counts as success | PARTIAL | successful incremented |
| UT-3.5 | Multiple skills | 2 skills | Separate entries in skills object |
| UT-3.6 | Last invocation updated | New outcome | last_invocation = new timestamp |

### UT-4: Sync Threshold

| ID | Test Case | Input | Expected |
|----|-----------|-------|----------|
| UT-4.1 | Below threshold | 19 pending | No sync triggered |
| UT-4.2 | At threshold | 20 pending | Sync triggered |
| UT-4.3 | Above threshold | 25 pending | Sync triggered |
| UT-4.4 | Custom threshold | threshold=10, 10 pending | Sync triggered |

---

## Integration Tests

### IT-1: Skill Reports Outcome

| ID | Test Case | Steps | Expected |
|----|-----------|-------|----------|
| IT-1.1 | perplexity-research reports SUCCESS | 1. Invoke perplexity-research<br>2. Evaluate as SUCCESS<br>3. Check pending.jsonl | Outcome recorded |
| IT-1.2 | detecting-ai-slop reports SUCCESS | 1. Analyze document<br>2. Report outcome<br>3. Check pending.jsonl | Outcome recorded |
| IT-1.3 | Multiple skills report | 1. perplexity reports<br>2. detecting reports<br>3. Check aggregated | Both skills tracked |

### IT-2: Stats Summary

| ID | Test Case | Steps | Expected |
|----|-----------|-------|----------|
| IT-2.1 | Empty stats | 1. Fresh install<br>2. Request summary | "No stats recorded yet" |
| IT-2.2 | Single skill stats | 1. Report 5 outcomes<br>2. Request summary | Shows skill with 5 invocations |
| IT-2.3 | Multiple skill stats | 1. Report for 3 skills<br>2. Request summary | Shows all 3 skills sorted |

### IT-3: GitHub Sync

| ID | Test Case | Steps | Expected |
|----|-----------|-------|----------|
| IT-3.1 | Manual sync | 1. Report 5 outcomes<br>2. Run sync push | stats/aggregated.json committed |
| IT-3.2 | Auto sync at threshold | 1. Report 20 outcomes | Sync triggered automatically |
| IT-3.3 | Pull on new machine | 1. Clone repo<br>2. Run sync pull | Local stats populated |

---

## End-to-End Tests

### E2E-1: Full Workflow

**Scenario:** User uses perplexity-research, outcome is tracked and synced.

**Steps:**
1. User encounters error, triggers perplexity-research
2. Perplexity returns helpful information
3. User applies fix, evaluates as SUCCESS
4. Reporting superpower records outcome
5. After 20 reports, sync to GitHub
6. On another machine, pull stats
7. Verify stats match

**Expected:** Stats consistent across machines.

### E2E-2: Migration from Legacy Stats

**Scenario:** Migrate existing perplexity-stats.json to new format.

**Steps:**
1. Existing ~/.codex/perplexity-stats.json has 42 invocations
2. Run migration script
3. Verify aggregated.json shows 42 invocations
4. Verify perplexity-research uses new reporting

**Expected:** No data loss during migration.

---

## Edge Cases

### EC-1: Error Recovery

| ID | Test Case | Scenario | Expected |
|----|-----------|----------|----------|
| EC-1.1 | Corrupted pending.jsonl | Invalid JSON on line 5 | Skip line, log warning |
| EC-1.2 | Corrupted aggregated.json | Invalid JSON | Rebuild from pending.jsonl |
| EC-1.3 | Missing stats directory | ~/.codex/skill-stats/ deleted | Recreate on next report |
| EC-1.4 | GitHub push fails | Network error | Queue for retry, warn user |
| EC-1.5 | Merge conflict | Two machines sync simultaneously | Last Write Wins |

### EC-2: Boundary Conditions

| ID | Test Case | Scenario | Expected |
|----|-----------|----------|----------|
| EC-2.1 | Very long outcome_reason | 10,000 character reason | Truncate to 500 chars |
| EC-2.2 | Unicode in metadata | Emoji in query_summary | Preserved correctly |
| EC-2.3 | Rapid-fire reports | 100 reports in 1 second | All recorded, single sync |
| EC-2.4 | Zero success rate | 10 FAILURE outcomes | success_rate = 0.0 |

---

## Validation Checklist

Before marking implementation complete:

- [ ] All UT tests pass
- [ ] All IT tests pass
- [ ] E2E-1 workflow validated manually
- [ ] E2E-2 migration tested with real data
- [ ] EC-1 error recovery tested
- [ ] EC-2 boundary conditions tested
- [ ] perplexity-research migrated successfully
- [ ] Stats visible on second machine after sync
- [ ] No regression in skill functionality

