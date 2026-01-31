---
name: security-upgrade
description: Use when you need to scan project dependencies for CVEs, upgrade vulnerable packages, validate that everything still compiles and passes tests, then commit and push the fixes - works with npm, Go, Python, Rust, and Flutter projects
---

# Security Dependency Upgrade Workflow

> **Last Updated:** 2026-01-31

## Overview

This skill provides a systematic workflow for security dependency auditing and upgrading. Use it to scan for CVEs, upgrade vulnerable packages, validate changes, and commit fixes.

**Supported package managers:** npm, Go modules, pip, Cargo, Flutter/pub

## When to Use

- Monthly security audits of dependencies
- Before major releases to ensure clean security posture
- When dependabot or security alerts notify you of vulnerabilities
- After onboarding a new project to assess security debt
- CI/CD integration for automated security gates

---

## Phase 1: Discovery

Identify what package managers are in use:

```bash
# Find all dependency manifests
find . -name "package.json" -not -path "*/node_modules/*" -exec dirname {} \;
find . -name "go.mod" -exec dirname {} \;
find . -name "pubspec.yaml" -exec dirname {} \;
find . -name "requirements.txt" -exec dirname {} \;
find . -name "Cargo.toml" -exec dirname {} \;
```

---

## Phase 2: Security Scanning

### npm Dependencies
```bash
npm audit --json

# For monorepos
find . -name "package.json" -not -path "*/node_modules/*" \
  -exec sh -c 'echo "=== $(dirname {}) ===" && cd $(dirname {}) && npm audit' \;
```

### Go Dependencies
```bash
# Install if needed
go install golang.org/x/vuln/cmd/govulncheck@latest

# Scan
~/go/bin/govulncheck .

# Verbose with fix recommendations
~/go/bin/govulncheck -show verbose .
```

### Python Dependencies
```bash
pip install pip-audit
pip-audit
pip-audit -r requirements.txt
```

### Rust Dependencies
```bash
cargo install cargo-audit
cargo audit
```

### Flutter/Dart Dependencies
```bash
flutter pub outdated
```

---

## Phase 3: Upgrade Dependencies

### Go Modules
```bash
go get <package>@<fixed-version>
go mod tidy
```

### npm
```bash
npm audit fix
npm audit fix --force  # Breaking changes - use with caution
```

### Python
```bash
pip install --upgrade <package>
pip freeze > requirements.txt
```

### Rust
```bash
cargo update <package>
```

---

## Phase 4: Validation

### Compile Verification
```bash
# Go
go build -o /dev/null .

# npm
npm run build

# Rust
cargo build

# Flutter
flutter build web --release
```

### Run Tests
```bash
# Go
go test ./...

# npm
npm test

# Rust
cargo test

# Flutter
flutter test
```

### Security Re-scan
Re-run the appropriate scanner. Expected: "No vulnerabilities found."

---

## Phase 5: Commit & Push

**Only proceed if ALL validation tests pass.**

```bash
git add -A

git commit -m "security: upgrade dependencies to fix CVEs

<Package> <old-version> → <new-version> (CVE-XXXX-XXXXX)
- Brief description of vulnerability fixed

Validation: All tests passing"

git push origin main
```

---

## Critical Reminders

1. **Always run full validation suite** before committing
2. **Document all CVE numbers** in commit message
3. **Test compilation** of all affected modules
4. **Re-scan for vulnerabilities** after upgrades to verify fixes
5. **Never bypass security updates** - all CVEs must be addressed

## ⛔ NEVER Do These Things

- **NEVER skip, disable, or bypass tests** to make upgrades pass
- **NEVER use `--force` flags** without explicit user approval
- **NEVER delete or comment out failing tests** to hide breakage
- **NEVER use `|| true` to suppress test failures**
- **NEVER commit with failing tests** - fix the code or rollback the upgrade

If tests fail after an upgrade, the correct response is:
1. Investigate why the test fails
2. Fix the code to work with the new dependency version
3. OR rollback to the previous dependency version
4. OR ask the user for guidance

---

## Expected Outcomes

- ✅ Zero known security vulnerabilities in dependencies
- ✅ All modules compile without errors
- ✅ All tests pass
- ✅ Changes committed and pushed

---

## Troubleshooting

**If govulncheck panics:**
- Run on individual directories instead of entire codebase
- Exclude template directories with Go files in node_modules

**If validation fails:**
- Do NOT commit or push
- Fix issues before proceeding
- Re-run validation suite

**If breaking changes introduced:**
- Review package changelogs
- Update code to accommodate API changes
- Consider gradual rollout for major version bumps

