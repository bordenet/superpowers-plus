# Verification Procedures

## Employer Legitimacy

**Before ANY pass decision, verify employers are real companies.**

### Step 1: Extract Employers

```
| Company | Duration | Verifiable? |
|---------|----------|-------------|
| [Name]  | X.X yrs  | ✅/❌       |
```

### Step 2: Web Search Each Employer

```bash
web-search "[Company Name] company"
```

| Result | Action |
|--------|--------|
| Website, LinkedIn, news coverage | ✅ Verifiable |
| Publicly traded (NASDAQ, NYSE) | ✅ Verifiable |
| No web presence at all | ❌ Unverifiable — treat as 0 years |
| "DAO", "Collective", "Freelance" | ⚠️ Probe further |

### Step 3: Calculate Verifiable Experience

Only count years at verifiable employers. **HARD GATE: 2+ years at a verifiable product company.**

---

## GitHub Profile Validation

### Step 0: READ the actual URL — DO NOT GUESS from candidate name

| ❌ Wrong | ✅ Correct |
|----------|-----------|
| Guess `github.com/jsmith` from name | Read actual URL from resume |

### Step 1: Check Reachable

```bash
curl -s -o /dev/null -w "%{http_code}" "https://github.com/{username-from-resume}"
```

- `200` → exists, check activity
- `404` → RED FLAG, log fabrication concern

### Step 2: Check Activity

```bash
curl -s "https://api.github.com/users/{username}/repos?sort=updated&per_page=10"
```

| Signal | Good | Concerning |
|--------|------|------------|
| Public repos | 5+ with commits | 0 repos or only forks |
| Recent activity | Last 6 months | No activity 2+ years |
| Profile | Bio, avatar, pinned repos | Default avatar, no bio |

### Step 3: Flag Issues

**RED FLAGS:** 404, 0 repos + no activity, profile < 6 months old
**YELLOW FLAGS:** All forks, no activity 12+ months, empty contribution graph

---

## Level Fit Assessment

**Reference:** [SDE Career Ladder](https://wiki.int.callbox.net/doc/sde-career-ladder-79fARjKXw6)

| Years | Level | Decision |
|-------|-------|----------|
| 0-3 | SDE-I | ❌ HARD FAIL |
| 3-5 | SDE-II | ❌ HARD FAIL |
| 5-8 | Senior | ✅ Target range |
| 8+ | Senior/Principal | ⚠️ May exceed role scope |

### Progression Validation

| Pattern | Signal |
|---------|--------|
| SDE-I for 5+ years | 🚨 Red flag |
| SDE-II for 5+ years | ⚠️ Yellow flag |
| Senior in < 3 years total | ⚠️ Verify scope |
| SDE-I (2-3y) → SDE-II (2-3y) → Senior | ✅ Healthy |
