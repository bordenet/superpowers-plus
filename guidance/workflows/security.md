# Security Workflow

> **Priority**: CRITICAL - IP protection and vulnerability management  
> **Source**: codebase-reviewer, scripts Agents.md, security-upgrade skill

## 🔒 Pre-Commit Hooks - NEVER BYPASS

Pre-commit hooks exist to protect intellectual property. **NEVER disable or bypass them.**

```bash
# ❌ NEVER DO THIS
git commit --no-verify

# ✅ ALWAYS DO THIS
git commit  # Let hooks run
```

## Security Scanning Tools

| Language | Tool | Command |
|----------|------|---------|
| Node.js | npm audit | `npm audit --json` |
| Go | govulncheck | `govulncheck ./...` |
| Python | pip-audit | `pip-audit -r requirements.txt` |

## Security Upgrade Workflow

1. **Discovery** - Identify projects with dependencies
2. **Scan** - Run security scanners
3. **Upgrade** - Fix vulnerabilities
4. **Validate** - Compile, test, verify
5. **Re-scan** - Confirm fixes
6. **Commit** - Push with green CI

## CVE Response Priority

| Severity | Response Time |
|----------|---------------|
| Critical | Immediate |
| High | Same day |
| Moderate | Within week |
| Low | Next release |

## Secret Management

- NEVER commit secrets to git
- Use environment variables for API keys
- Store secrets in secure credential managers
- Use `.env.local` files (gitignored)
- Prompt for secrets interactively in setup scripts

## Related Skills

For comprehensive security workflows:
- `superpowers-plus/skills/security-upgrade/`

