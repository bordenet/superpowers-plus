# Codebase Recon — Lens Search Patterns

Full grep commands and checklists for each of the 8 recon lenses referenced from `skill.md` Phase 2. Run each lens in order; record findings in the Phase 3 master table.

## Lens Search Patterns

### Lens 1: Authentication & Authorization

**Goal:** Find every entry point and verify auth enforcement.

```bash
# Find public HTTP handlers (adapt to your framework)
grep -rn 'router\.\(get\|post\|put\|delete\)\|app\.get\|@route\|@api_view' --include="*.ts" --include="*.js" --include="*.py" REPO_PATH

# For each endpoint file, check for auth middleware
grep -n 'auth\|middleware\|require.*login\|is_authenticated\|verifyToken\|session\.' FILE

# Check if any routes are mounted without an auth guard
grep -rn 'use(router)\|use(apiRouter)' REPO_PATH | grep -v auth
```

**Checklist:**
- [ ] Every public endpoint verifies the caller's identity
- [ ] Every endpoint scopes data to the caller's account (no cross-tenant access)
- [ ] Auth middleware is applied at the mount point, not just at individual handlers
- [ ] No route is reachable without passing through auth

### Lens 2: Security — Injection & Secrets

```bash
# SQL injection risk (raw string interpolation)
grep -rn 'query.*\${.*}\|query.*+.*req\.\|execute.*\`.*\`' --include="*.ts" --include="*.js" REPO_PATH

# Hardcoded secrets
grep -rn 'api.key\s*=\s*["'"'"']\|password\s*=\s*["'"'"']\|secret\s*=\s*["'"'"']' REPO_PATH

# Debug/dump endpoints (should not be reachable in production)
grep -rn 'debug\|dump\|inspect\|trace' --include="*.ts" --include="*.js" REPO_PATH | grep -v test | grep -v '^\s*//'
```

**Checklist:**
- [ ] All DB queries use parameterized statements / ORM binding
- [ ] No secrets or API keys hardcoded in source
- [ ] No debug dump endpoints reachable in production

### Lens 3: Feature Gating & Entitlement

```bash
# Find feature flag checks
grep -rn 'featureFlag\|isEnabled\|hasPermission\|planTier\|getFeature' REPO_PATH

# Find data rendered to UI — verify gate wraps it
grep -rn 'res\.json\|res\.send\|return response' REPO_PATH | head -30
```

**Checklist:**
- [ ] All premium/gated features are wrapped in a flag check
- [ ] Flag check happens server-side, not only in the UI
- [ ] Missing flag = access DENIED, not access GRANTED

### Lens 4: Data Flow

```bash
# Trace from DB to response
grep -rn 'SELECT\|findAll\|findOne\|prisma\.' REPO_PATH | head -20
grep -rn 'axios\.\|fetch(\|httpClient\.' REPO_PATH | head -20
```

**Checklist:**
- [ ] Data is transformed / sanitized before leaving the server
- [ ] No raw DB rows sent directly to client
- [ ] Outbound HTTP calls have error handling

### Lens 5: Error Handling & Fail Mode

```bash
# Empty catch blocks
grep -rn 'catch\s*(' REPO_PATH | grep -v '//' | head -20

# Swallowed errors (catch with only console.log)
grep -A2 'catch' FILE | grep -v 'throw\|return\|reject\|error'
```

**Checklist:**
- [ ] No empty catch blocks
- [ ] Errors are logged AND propagated (not swallowed)
- [ ] Auth/gate failures return 401/403, not 200+empty

### Lens 6: Test Coverage

```bash
# Find test files for the feature area
find REPO_PATH -name "*test*" -o -name "*spec*" | grep -i 'KEYWORD'

# Check if key paths are covered
grep -rn 'it(\|test(\|describe(' TEST_FILE | grep -i 'KEYWORD'
```

**Checklist:**
- [ ] Happy path covered
- [ ] Auth failure covered (unauthenticated / wrong tenant)
- [ ] Error cases covered

### Lens 7: Cross-Repo Consistency

```bash
# Same business logic across repos
for REPO in REPO_A REPO_B REPO_C; do
    echo "=== $REPO ==="; grep -rn 'KEYWORD' "$REPO" | head -5
done
```

**Checklist:**
- [ ] Same gating logic in all repos (no one repo weaker)
- [ ] No copy-paste drift (same fix applied everywhere if common)

### Lens 8: Git Blame & Change History

```bash
# Who last modified the suspicious file
git log --follow -p -- FILE | head -60
git blame FILE | grep 'KEYWORD'

# Recent changes to the feature area
git log --all --oneline --diff-filter=M -- 'PATTERN' | head -20
```

**Checklist:**
- [ ] Every high-severity finding: who introduced it and when?
- [ ] Any recent change that could be the regression trigger?
- [ ] Is this pattern repeated in the same author's other commits?
