---
name: repo-security-scan
source: superpowers-plus
augment_menu: true
triggers: ["/sp-scan", "security scan", "scan for secrets", "scan for vulnerabilities", "audit repo security", "check for hardcoded keys", "check for insecure code", "security review", "scan repos", "find secrets in code", "credential scan", "security audit"]
anti_triggers: ["review for correctness", "scan for performance issues", "check for bugs", "general code review", "pr review for style", "language audit for profanity"]
description: "Use when asked to audit a git repository for security issues, check for secrets or credentials in code, scan for dependency vulnerabilities, or review a repo's security posture. Use instead of writing ad-hoc scanning scripts. Covers Python, Node.js, Go, Rust, and shell projects."
summary: "Use when: auditing repo for security vulnerabilities, secrets, or misconfigurations."
coordination:
  group: security
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [code-changes, repo-context]
  produces: [security-report]
  capabilities: [scans-secrets, detects-vulnerabilities]
  priority: 25
---

# repo-security-scan

> **Purpose:** Systematic security scan of any git repository across four categories.
> **Last Updated:** 2026-08-15
>
> **Wrong skill?** Public repo IP leakage → `public-repo-ip-audit`. Wiki secrets → `wiki-secret-audit`. Dependency upgrades → `security-upgrade`.

## Approach

Run a comprehensive security scan on a git repo without creating ad-hoc scripts. This skill orchestrates four scan categories using tools already available on the system.

**Key principle:** Use existing tools and skills — never create custom scanning scripts in `/tmp/` or anywhere else.

## When to Use

- Asked to "scan a repo for security issues"
- Asked to "find secrets" or "check for vulnerabilities"
- Before releasing or open-sourcing a project
- Monthly/quarterly security hygiene checks
- After onboarding a new repo

## Scan Process

### Phase 0: Stack Detection

Identify the repo's stack by checking for manifest files:

| File | Stack | Audit Tool |
|------|-------|------------|
| `package.json` | Node.js | `npm audit` |
| `requirements.txt` / `pyproject.toml` | Python | `pip-audit` |
| `go.mod` | Go | `govulncheck` |
| `Cargo.toml` | Rust | `cargo audit` |
| `pubspec.yaml` | Flutter/Dart | `flutter pub outdated` |

```bash
# Auto-detect — run from repo root
for f in package.json requirements.txt pyproject.toml go.mod Cargo.toml pubspec.yaml; do
  [ -f "$f" ] && echo "DETECTED: $f"
done
```

### Phase 1: Secrets & Credentials

Use a **documented subset** of patterns from `skills/_shared/secret-detection.md` (high-confidence tokens + hardcoded assignment forms below — not the full shared checklist). Scan tracked files only (not untracked):

```bash
# High-confidence token patterns in tracked files
TOKEN_RE='(sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|AKIA[A-Z0-9]{16}|xox[bpsar]-[a-zA-Z0-9-]+|glpat-[a-zA-Z0-9-]+)'
ASSIGN_RE='(api[_-]?key|secret[_-]?key|password|private[_-]?key)\s*[:=]\s*["'"'"'][^"'"'"']{8,}'

git ls-files -z | xargs -0 grep -lnE "$TOKEN_RE" \
  2>/dev/null | grep -v 'node_modules\|\.git\|venv'

# Hardcoded secret assignments (filter out test files and examples)
git ls-files -z | xargs -0 grep -lnE "$ASSIGN_RE" \
  2>/dev/null | grep -v 'node_modules\|\.git\|venv\|test\|spec\|\.example\|\.sample\|\.md$'

# Committed .env files
git ls-files | grep -iE '\.env$|\.env\.[^e]'

# Private key files
git ls-files | grep -iE '\.(pem|key|p12|pfx|jks)$'
```

**False positive filtering:** Matches in test files, `.example` files, and documentation are expected. Review each match to determine if it's a real secret or a placeholder.

**Required — git history (commit-then-delete leaks):** HEAD-only greps miss secrets that were committed and later removed. Always run a history scan before claiming the secrets phase is clean. The history `-G` set MUST cover the same token + assignment classes as HEAD (not tokens alone).

```bash
# Prefer gitleaks when installed (full history; do not truncate output)
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks detect --source . --log-opts="--all" --no-banner
else
  # Portable fallback: same TOKEN_RE + ASSIGN_RE as HEAD (set above).
  # Do NOT pipe through head/truncation — a capped stream is an incomplete
  # scan. If the repo is too large for interactive review, install gitleaks
  # or stop and report INCOMPLETE rather than claiming clean.
  set -o pipefail
  HISTORY_RE="(${TOKEN_RE}|${ASSIGN_RE})"
  if ! git log -p --all -G "$HISTORY_RE" --pretty=format:'=== %H %s ==='; then
    echo "INCOMPLETE: history scan failed; do not claim secrets phase clean" >&2
    exit 1
  fi
fi
```

Treat history hits as real findings: rotate the credential, document the commit(s), and do not claim a clean secrets scan until history is clean or each hit has an explicit accepted-risk note. History rewrite (filter-branch / BFGs) is advisory and separate from detection. **Never treat a truncated or failed history scan as clean.**

### Phase 2: Dependency Vulnerabilities

**When upgrading dependencies:** use `superpowers:security-upgrade` for discovery → scan → upgrade → validate → commit/push. It is the upgrade path after CVE findings — not a hard prerequisite for a scan-only run.

Quick scan commands (from security-upgrade; safe for scan-only):

```bash
# npm (built-in, no install needed)
npm audit --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('metadata',{}).get('vulnerabilities',{}))" 2>/dev/null

# Python (install: pip install pip-audit)
pip-audit -r requirements.txt 2>&1

# Go (install: go install golang.org/x/vuln/cmd/govulncheck@latest)
govulncheck ./... 2>&1

# Rust (install: cargo install cargo-audit)
cargo audit 2>&1
```

**If scanning only (not upgrading):** Run the quick scan commands above. If CVEs are found and you need to upgrade, switch to the full `security-upgrade` skill workflow. Do not load `security-upgrade` solely to list CVEs.

### Phase 3: Insecure Code Patterns

Scan tracked source files for dangerous patterns:

```bash
# Dangerous function calls (Python, JS, Shell)
git ls-files -z '*.py' '*.js' '*.ts' '*.sh' 2>/dev/null | xargs -0 grep -nE \
  '(eval\(|exec\(|pickle\.loads|subprocess\.call.*shell=True|os\.system\(|yaml\.load\([^,]*\)$|innerHTML\s*=|document\.write\(|child_process\.exec\()' \
  2>/dev/null | grep -v 'node_modules\|venv\|__pycache__'

# SQL injection risks (string interpolation in queries)
git ls-files -z '*.py' '*.js' '*.ts' 2>/dev/null | xargs -0 grep -nE \
  '(f".*SELECT|f".*INSERT|f".*UPDATE|f".*DELETE|\.format\(.*SELECT|query\(.*\+)' \
  2>/dev/null | grep -v 'node_modules\|venv\|test'
```

**Triage:** Not every match is exploitable. `innerHTML` in a static site with no user input is low-risk. `eval()` in a test helper may be acceptable. Document the finding and assess context.

### Phase 4: Misconfiguration

```bash
# Missing .gitignore entries (check for common sensitive patterns)
if [ -f .gitignore ]; then
  for pattern in ".env" "*.pem" "*.key" ".DS_Store"; do
    grep -qF "$pattern" .gitignore || echo "MISSING: $pattern not in .gitignore"
  done
else
  echo "WARNING: No .gitignore file exists"
fi

# Stack-specific .gitignore checks
[ -f package.json ] && ! grep -q "node_modules" .gitignore 2>/dev/null && echo "MISSING: node_modules"
[ -f requirements.txt ] && ! grep -q "__pycache__" .gitignore 2>/dev/null && echo "MISSING: __pycache__"
[ -f requirements.txt ] && ! grep -q "venv" .gitignore 2>/dev/null && echo "MISSING: venv"

# Debug mode in production configs
git ls-files -z 2>/dev/null | xargs -0 grep -lnE \
  '(DEBUG\s*=\s*True|debug:\s*true|"debug":\s*true)' \
  2>/dev/null | grep -v 'test\|spec\|\.md$'
```

## Fix Workflow

For each finding:

1. **Secrets found** → Remove the secret, rotate it, add pattern to `.gitignore`
2. **Dependency CVEs** → Use `superpowers:security-upgrade` workflow (scan → upgrade → validate → commit)
3. **Insecure patterns** → Fix the code, apply TDD where applicable
4. **Misconfiguration** → Add missing entries, disable debug mode

**Commit each fix individually** with descriptive messages:

```python
fix(security): remove hardcoded API key from config.ts
fix(security): add .env to .gitignore
fix(security): upgrade flask 3.1.2→3.1.3 (CVE-2026-27205)
fix(security): replace eval() with JSON.parse() in parser.js
```

## Verification

After all fixes, **re-run the full scan (Phases 0–4), including the Phase 1 history step**, to confirm zero remaining issues on **both HEAD and git history** (or every remaining history hit has a dated accepted-risk note). A HEAD-only re-grep is not a full scan. Use `superpowers:verification-before-completion` — evidence before assertions.

## Rules

- **Never write custom scanning scripts.** The inline commands above ARE the automation.
- **Run all four phases.** Don't skip because "this repo probably doesn't have X."
- **Always include Phase 1 history.** Commit-then-delete secrets are still leaks.
- **Triage each match.** Don't dismiss all as false positives without reviewing context.
- **Re-run full scan after fixes** to confirm zero remaining issues on HEAD and history.
- **Multi-repo:** Process each repo sequentially through all four phases.

## Companion Skills

- `security-upgrade` — load when Phase 2 finds CVEs that need upgrading (not a scan-only prerequisite)
- `public-repo-ip-audit` — IP/license leakage (different from secrets)
- `wiki-secret-audit` — wiki-side secret scanning
- `verification-before-completion` — evidence before "clean" assertions

## Failure Modes and Recovery

| Failure | Fix |
|---------|-----|
| Scanner tool not installed (gitleaks, npm audit) | Install or use the Phase 1 uncapped `git log -p` / audit-tool fallbacks; never truncate |
| False positive on test fixtures with dummy secrets | Maintain allowlist of known test fixtures per repo |
| History scan too large for interactive review | Install gitleaks and re-run; if still blocked, stop and report INCOMPLETE — do not claim clean |
| History scan command fails / incomplete | Treat as failed secrets phase; do not assert zero remaining issues |
| Dependency vuln has no fix available | Document as accepted risk with justification and review date |
