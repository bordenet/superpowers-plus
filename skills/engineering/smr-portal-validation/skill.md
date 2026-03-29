---
name: [portal]-validation
source: superpowers-[company]
description: Use when checking SMR portal health, after CDK deployments, after DNS changes, or when troubleshooting "site down" reports. Triggers on "check portal", "is portal up", "validate demo portal", "portal not working", "check staging/dev site", "post-deploy validation". Smoke tests SMR demo sites (DEV and STAGING) for accessibility and auth.
summary: "Use when: validating SMR portal configuration or data."
triggers: ["check portal", "is portal up", "validate demo portal", "portal not working", "check staging site", "post-deploy validation"]
coordination:
  group: ops
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
anti_triggers: ['deploy', 'build', 'test']
---

# SMR Portal Validation

> **Purpose:** Smoke test SMR demo sites after deployment or DNS changes
> **Last Updated:** 2026-02-27

---

## When to Use

Invoke when:

- After CDK deployment of PortalSiteStack
- After DNS changes to SMR subdomains
- After certificate renewals or ALB updates
- When troubleshooting "site down" reports
- Before merging PRs that affect SMR infrastructure

---

## ⚠️ Credential Security

<EXTREMELY_IMPORTANT>

**NEVER hardcode credentials in skill files or commands shown to user.**

Credentials are stored in: `~/.codex/.env`

Required variables:
```
PORTAL_BASIC_AUTH_USER=<username>
PORTAL_BASIC_AUTH_PASSWORD=<password>
PORTAL_DEV_URL=https://portal-dev.example.net
PORTAL_STAGING_URL=https://portal.example.net
PORTAL_STAGING_ALIAS_URL=https://portal.example.com
```

</EXTREMELY_IMPORTANT>

---

## Validation Steps

### Step 1: Load Credentials

```bash
source ~/.codex/.env
```

### Step 2: Validate DNS Resolution

```bash
# DEV
nslookup portal-dev.example.net

# STAGING (primary)
nslookup portal.example.net

# STAGING (alias)
nslookup portal.example.com
```

**Expected:** All three should resolve to ALB IP addresses (not NXDOMAIN).

### Step 3: Validate HTTPS + Auth

```bash
# DEV
curl -s -o /dev/null -w "%{http_code}" \
  -u "$PORTAL_BASIC_AUTH_USER:$PORTAL_BASIC_AUTH_PASSWORD" \
  "$PORTAL_DEV_URL"

# STAGING (primary)
curl -s -o /dev/null -w "%{http_code}" \
  -u "$PORTAL_BASIC_AUTH_USER:$PORTAL_BASIC_AUTH_PASSWORD" \
  "$PORTAL_STAGING_URL"

# STAGING (alias)
curl -s -o /dev/null -w "%{http_code}" \
  -u "$PORTAL_BASIC_AUTH_USER:$PORTAL_BASIC_AUTH_PASSWORD" \
  "$PORTAL_STAGING_ALIAS_URL"
```

**Expected:** All return `200`.

### Step 4: Validate Certificate

```bash
# Check cert validity
echo | openssl s_client -servername portal.example.com \
  -connect portal.example.com:443 2>/dev/null | \
  openssl x509 -noout -dates
```

---

## Quick Validation Script

```bash
#!/bin/bash
source ~/.codex/.env

ENDPOINTS=(
  "$PORTAL_DEV_URL|DEV"
  "$PORTAL_STAGING_URL|STAGING"
  "$PORTAL_STAGING_ALIAS_URL|STAGING-ALIAS"
)

echo "=== SMR Portal Validation ==="
for entry in "${ENDPOINTS[@]}"; do
  url="${entry%|*}"
  name="${entry#*|}"
  
  # DNS check
  host=$(echo "$url" | sed 's|https://||')
  if nslookup "$host" > /dev/null 2>&1; then
    dns="✅"
  else
    dns="❌ NXDOMAIN"
  fi
  
  # HTTP check
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "$PORTAL_BASIC_AUTH_USER:$PORTAL_BASIC_AUTH_PASSWORD" \
    --connect-timeout 5 "$url")
  
  if [ "$code" = "200" ]; then
    http="✅ $code"
  else
    http="❌ $code"
  fi
  
  echo "[$name] DNS: $dns | HTTP: $http"
done
```

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| NXDOMAIN | Missing Route53 A record | Check hosted zone, redeploy CDK |
| 401 | Wrong credentials | Verify .env matches Secrets Manager |
| 502 | ECS task unhealthy | Check ECS service, task logs |
| Cert error | Missing/expired ACM cert | Check ACM console, redeploy CDK |

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Deploy without validation | Broken portal config | Always validate before deployment |
