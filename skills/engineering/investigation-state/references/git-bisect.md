# Investigation State — Regression Hunting via Git Bisect

> Reference material for the `investigation-state` skill.
> See `skill.md` for core guidance.

Use git bisect when an investigation identifies a regression — something that used to work but no longer does — and you need to find the exact commit that introduced the bug.

---

## When to Use

- A feature or behavior worked before and now doesn't
- You can identify a "known good" commit/tag/date and a "known bad" one
- The regression is reproducible with a specific test or check
- Manual code review hasn't identified the culprit

## When NOT to Use

- The bug has always existed (not a regression)
- The codebase has fewer than ~20 commits between good and bad
- The reproduction requires external state (database, API) that differs between commits

---

## The Process

### Step 1: Establish Boundaries

Identify the good and bad commits:

```bash
# Find the last known good state
git log --oneline --since="2026-03-01" --until="2026-03-15"

# Or use a tag
git tag -l 'v*'
```

Log these as evidence:

```json
{
  "source": "git:bisect",
  "finding": "Good: v2.2.0 (abc1234). Bad: HEAD (def5678). Starting bisect.",
  "timestamp": "2026-03-23T15:00:00Z"
}
```

### Step 2: Start Bisect

```bash
git bisect start
git bisect bad HEAD
git bisect good v2.2.0
```

Git will check out a commit halfway between good and bad.

### Step 3: Test Each Commit

For each commit git checks out:

1. **Run the reproduction test** — whatever demonstrates the bug
2. **Mark the result:**

   ```bash
   git bisect good  # if the bug is NOT present
   git bisect bad   # if the bug IS present
   ```

3. **Repeat** until git identifies the first bad commit

### Step 4: Automated Bisect (Preferred)

If you have a script that exits 0 for good and non-zero for bad:

```bash
git bisect start HEAD v2.2.0
git bisect run ./test-regression.sh
```

This runs automatically without manual intervention.

### Step 5: Record the Result

When bisect completes:

```bash
# Git will output something like:
# abc1234 is the first bad commit
# Author: ...
# Date: ...
# commit message

# View the changes in that commit
git show abc1234

# End bisect
git bisect reset
```

Log the finding:

```json
{
  "source": "git:bisect",
  "finding": "First bad commit: abc1234 'Refactor config loading' by developer@example.com on 2026-03-10. Changed config parser to skip empty values.",
  "timestamp": "2026-03-23T15:30:00Z"
}
```

---

## Bisect with Untestable Commits

Some commits may not compile or may be irrelevant:

```bash
git bisect skip  # Skip the current commit
```

Use this when:

- The commit doesn't compile
- The commit is a merge commit with no functional changes
- The feature under test doesn't exist yet at this commit

---

## Integration with Investigation State

1. **Before bisect:** Create a hypothesis: "Regression introduced between [good] and [bad]"
2. **During bisect:** Log each step as evidence with source `git:bisect`
3. **After bisect:** Update hypothesis verdict to `confirmed` with the culprit commit
4. **Next step:** Examine the commit diff to understand the root cause
5. **Update investigation:** Add the fix approach to `nextSteps`

---

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Wrong "good" boundary — bug existed earlier | Verify the good commit actually passes the test before starting |
| Flaky test gives wrong good/bad marks | Use a deterministic reproduction, not an intermittent one |
| Forgot `git bisect reset` | Always reset when done — otherwise you're on a detached HEAD |
| Bisect across merge commits | Use `git bisect skip` on merge commits, or use `--first-parent` |
