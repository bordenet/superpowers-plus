# Deterministic Verification (Phase 2.5)

Runs after all reviewers return (Phase 2) and before aggregation (Phase 3). Parses each finding's structured fields and runs deterministic checks.

## Structured Finding Schema

Every reviewer must output findings in this format:

### Finding F\<n\>
- **file**: \<path\> (or "N/A")
- **line**: \<number\> (or "N/A")
- **symbol**: \<name\> (omit if not applicable)
- **severity**: Critical / Important / Minor
- **confidence**: High (>80%) / Possible (60–80%)
- **scope**: isolated / systemic
- **issue**: \<what is wrong — 1–2 sentences\>
- **why**: \<why it matters\>
- **fix**: \<how to fix\>

## Parsing Rules

1. Each finding starts with `### Finding F<n>` — heading signals boundary
2. Single-line fields: everything after `: ` on the same line
3. Multiline fields (issue, why, fix, evidence): all lines until next `- **` prefix or `### Finding`
4. `instances` block: indented `- file:line` entries until next field or heading
5. If a finding cannot be parsed (no heading, missing required fields): tag `[UNSTRUCTURED]`

## Verification Checks

### Check 1: File Existence

```bash
test -f "<referenced_file>"
```

Fail → `[UNVERIFIED: file not found]`

### Check 2: Line Validity

```bash
total=$(wc -l < "<referenced_file>")
# Compare: referenced line ≤ total
```

Fail → `[UNVERIFIED: line out of range]`

### Check 3: Symbol Existence

```bash
grep -n '<claimed_symbol>' "<referenced_file>" --binary-files=without-match
```

Zero hits → `[UNVERIFIED: symbol not found in file]`

### Check 4: Reserved

Reserved for future incremental addition after measuring false-negative rate.

## Verification Output

Each finding gets one tag:

- `[VERIFIED]` — file, line, and symbol confirmed
- `[UNVERIFIED: <reason>]` — at least one check failed
- `[UNSTRUCTURED]` — could not parse structured fields

Unverified and unstructured findings are **not dropped**. They move to an appendix in the aggregated report.

## Edge Cases

- **timeout unavailable**: Run checks without timeout (Checks 1–3 are <100ms each)
- **Binary files**: Use `grep --binary-files=without-match`
- **0 parseable findings**: Tag entire output as `[UNSTRUCTURED]`, pass through
- **N/A line or symbol**: Skip the corresponding check; tag `[VERIFIED]` if other checks pass
