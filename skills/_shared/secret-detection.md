# Secret Detection Module

> **Security Incident 2026-02-24:** SQL Server credentials (`your-productuser`/password) were published to wiki.
> This module defines secret detection patterns and procedures to prevent recurrence.

## 🛑 HIGH-CONFIDENCE PATTERNS (Always Block)

These patterns have very low false-positive rates and should ALWAYS trigger a block:

| Pattern | Example | Severity |
|---------|---------|----------|
| SQL Connection String | `Server=...;Password=xyz` | 🔴 HIGH |
| Database URL with Credentials | `postgres://user:pass@host` | 🔴 HIGH |
| Password Assignment | `password: mySecret123` or `PASSWORD=xyz` | 🔴 HIGH |
| Bearer Token | `Bearer eyJhbGc...` | 🔴 HIGH |
| API Key Assignment | `api_key=sk_live_...` | 🔴 HIGH |
| Private Key Block | `-----BEGIN RSA PRIVATE KEY-----` | 🔴 HIGH |
| AWS Access Key | `AKIA...` (20 chars) | 🔴 HIGH |
| Outline Token | `ol_api_...` | 🔴 HIGH |
| Issue Tracker Token | `[tracker-token]` | 🔴 HIGH |
| OpenAI Key | `sk-...` (32+ chars) | 🔴 HIGH |
| GitHub Token | `ghp_...`, `gho_...`, `ghu_...` | 🔴 HIGH |
| Slack Token | `xoxb-...`, `xoxp-...` | 🔴 HIGH |
| Stripe Key | `sk_live_...` | 🔴 HIGH |

---

## ✅ ALLOWLIST PATTERNS (Do Not Block)

These patterns indicate the value is a placeholder or environment variable reference:

| Pattern | Example | Why Allowlisted |
|---------|---------|-----------------|
| Shell variable | `$PASSWORD` or `${DB_PASSWORD}` | Reference, not value |
| Python env | `os.environ["PASSWORD"]` | Reference, not value |
| Node.js env | `process.env.PASSWORD` | Reference, not value |
| Redacted marker | `[REDACTED: SQL password]` | Explicit placeholder |
| Placeholder syntax | `<YOUR_PASSWORD_HERE>` | Template marker |
| Generic placeholder | `your-api-key-here` | Documentation example |

---

## 📋 SECRET SCAN CHECKLIST

<EXTREMELY_IMPORTANT>

**Before pushing ANY wiki content, perform this secret scan:**

### Step 1: Visual Scan

Search your content for these keywords (case-insensitive):
- `password`, `pwd`, `passwd`
- `secret`, `credential`, `token`
- `api_key`, `apikey`, `api-key`
- `private_key`, `privatekey`
- `connection_string`, `connectionstring`

### Step 2: Pattern Check

For each match, ask:
1. **Is this a real value?** → 🛑 STOP — remove or redact
2. **Is this an env variable reference?** → ✅ OK (e.g., `$DB_PASSWORD`)
3. **Is this a placeholder?** → ✅ OK (e.g., `[REDACTED]`, `<YOUR_VALUE>`)
4. **Is this documentation about secrets?** → ✅ OK (e.g., "passwords must be 8+ chars")

### Step 3: If Secret Detected

1. **DO NOT** push the content
2. **Remove or redact** the secret value
3. Use one of these safe alternatives:
   - Environment variable: `${DATABASE_PASSWORD}`
   - Redacted marker: `[REDACTED: SQL Server password]`
   - Placeholder: `<YOUR_API_KEY_HERE>`
4. Re-scan and verify no secrets remain

</EXTREMELY_IMPORTANT>

---

## 🔒 MCP Server Hard Block (P0)

The Outline MCP server (v5.9.0+) has a built-in secret scanner that:
- Blocks `createDocument`, `updateDocument`, `pushDocument` if secrets are detected
- Returns a detailed error message with line numbers and pattern names
- Cannot be bypassed — content with secrets WILL NOT be published

This is the **last line of defense**. The checklist above should catch secrets BEFORE hitting this block.

---

## 🔧 Remediation Examples

**Original (contains secret):**
```
Server=mydb.database.windows.net;User Id=admin;Password=j69KZhsk_6935Bayn2W0ZZmA
```

**Fixed (environment variable):**
```
Server=mydb.database.windows.net;User Id=${DB_USER};Password=${DB_PASSWORD}
```

**Fixed (redacted):**
```
Server=mydb.database.windows.net;User Id=admin;Password=[REDACTED: production SQL password]
```

---

## 📚 Related

- **MCP Server Implementation:** `mcp-servers/outline/src/utils/secretScanner.ts`
- **Unit Tests:** `mcp-servers/outline/test/secretScanner.test.ts`
- **Incident Wiki Page:** `/doc/example-incident-page-xyz789` (credentials since removed)

