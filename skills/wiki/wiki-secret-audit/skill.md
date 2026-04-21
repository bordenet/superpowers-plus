---
name: wiki-secret-audit
source: superpowers-plus
triggers: ["scan wiki for secrets", "audit wiki for credentials", "check for exposed API keys", "wiki security scan", "find leaked tokens in wiki"]
anti_triggers: ["scan code for secrets", "repo security scan", "CVE scan"]
description: Use when scanning wiki pages for exposed secrets, after security incidents, or during periodic security reviews. Detects credentials, API keys, tokens that may have been published before secret detection.
summary: "Use when: auditing wiki for exposed secrets, tokens, or credentials."
composition:
  consumes: [markdown-content]
  produces: [sanitized-content]
  capabilities: [detects-secrets]
  priority: 25
coordination:
  group: wiki
  order: 3
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# wiki-secret-audit

Scan wiki pages for exposed credentials, tokens, and keys. Wrong skill? Code
repos → `repo-security-scan` · Wiki-sourced instruction safety →
`wiki-instruction-guard` · Version claims → `wiki-verify`.

## Procedure

### 1 — Collect scope into `scan.md`

```bash
# Single page:
tools/wiki-read.sh get "$PAGE_ID" | jq -r '.text' > scan.md

# Bulk (search or list): pipe through get to assemble one corpus
tools/wiki-read.sh {search '"password" OR "api key"' --limit 50|list --collection "$UUID" --limit 500} \
  | jq -r '.[].id' | while read id; do
      tools/wiki-read.sh get "$id" | jq -r '"== " + .url + " ==\n" + .text'
    done > scan.md
```

### 2 — Run the pattern scan

```bash
grep -n -E -i '(Server|Data Source)=[^;]*Password=[^;]+|\
(postgres|mysql|mongodb|redis)://[^:]+:[^@]+@|\
password[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9_!@#$%^&*()-]{8,}|\
Bearer[[:space:]]+[A-Za-z0-9_-]{20,}|\
(api[_-]?key|apikey)[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9_-]{20,}|\
-----BEGIN[[:space:]]+(RSA|EC|OPENSSH)?[[:space:]]*PRIVATE[[:space:]]+KEY-----|\
AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{32,}|\
gh[pousr]_[A-Za-z0-9]{30,}|xox[baprs]-[A-Za-z0-9-]{10,}|\
sk_live_[A-Za-z0-9]{20,}' scan.md \
  | grep -v -E '\$\{?[A-Z_]+\}?|process\.env\.|\[REDACTED\]|<YOUR_' \
  | tee findings.txt
```

Exit `0` + empty `findings.txt` → clean. Non-empty → report + remediate.

### 3 — Report + remediate

Report each finding as `<url>:<line>: <pattern> — <preview>`. Then remediate
in this order: (1) redact in wiki via `tools/wiki-write.sh update`;
(2) rotate the upstream credential; (3) audit access logs; (4) notify owner.

## Exclusions (drop from findings)

Env refs (`$VAR`, `${VAR}`, `process.env.VAR`) · placeholders (`[REDACTED]`,
`<YOUR_VALUE>`, `xxx...`) · docs guidance ("password must be 8+ chars").

## High-risk areas (prioritize)

Development setup · environment configuration · architecture docs · runbooks ·
personal notes sections.

## Failure modes

| Failure | Fix |
|---------|-----|
| Obfuscated secrets (base64, url-encoded) | Grep additionally for high-entropy blocks ≥40 chars |
| Page history not scanned | `wiki-read.sh get` returns current only; use adapter's revision tool |
| Custom-format internal token missed | Add org regex to the grep alternation above |
| `wiki-write.sh` exit 1 on redaction | STOP; ask user; do not retry |

Related: `skills/_shared/secret-detection.md`
