---
name: aws-credentials
parent: cari-investigator
description: AWS SSO setup, credential fetching, and database connection reference for Cari investigations.
---

# AWS Access & Credential Fetching

> **Loaded from:** `skill.md` Step 2 → this file for full AWS setup and credential commands.

## 2a: Verify AWS CLI and SSO Access

Before fetching credentials, verify the user has AWS access:

```bash
# Check AWS CLI is installed
which aws || echo "AWS CLI NOT INSTALLED"

# Check profile exists and credentials are valid
aws sts get-caller-identity --profile telephony-prod
```

**If `which aws` fails** → AWS CLI is not installed. Direct user to: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

**If profile check succeeds** → proceed to Step 2b.

**If "profile not found" or "could not find profile"** → the user needs first-time AWS SSO setup. Guide them:

```
The cari-investigator skill requires AWS access to query production databases and CloudWatch logs.

Prerequisites:
1. AWS CLI v2 installed (https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
2. Access to the Callbox AWS accounts (ask your manager if you don't have this)

To set up AWS SSO, run these commands:
```

```bash
# Step 1: Configure the SSO session
aws configure sso-session
#   Session name: telephony
#   SSO start URL: https://d-906715a798.awsapps.com/start/#
#   SSO region: us-east-1
#   SSO registration scopes: sso:account:access

# Step 2: Configure the production profile
aws configure sso
#   SSO session: telephony
#   Account: 055570533261 (production)
#   Role: AWSPowerUserAccess (or whatever role you have)
#   Default region: us-east-1
#   Profile name: telephony-prod

# Step 3: Login (opens browser)
aws sso login --profile telephony-prod
```

Optionally, configure a dev/staging profile too:

```bash
aws configure sso
#   SSO session: telephony
#   Account: 198471628501 (dev/staging)
#   Role: CB_DevAdmin (or your role)
#   Default region: us-east-1
#   Profile name: telephony-dev
```

**If "token has expired" or "SSO session expired"** → the user just needs to re-login:

```bash
aws sso login --profile telephony-prod
```

**To discover available profiles:**

```bash
aws configure list-profiles
```

Common profile names: `cari-prod`, `cari`, `telephony-prod`, `sre-prod`. Use whichever exists on your machine.

**If the user does not have AWS access** → inform them:

```
Cari Investigator requires AWS access to query production databases and CloudWatch logs.
Without AWS access, this skill cannot run. Please contact your manager or DevOps
to request access to the Callbox AWS accounts.
```

## 2b: Fetch Database Credentials

Once AWS access is confirmed, fetch **read-only** credentials from Secrets Manager:

| Environment | AWS CLI Profile | Secret Name | Access Level |
|-------------|----------------|-------------|--------------|
| Production | telephony-prod | cari-readonly-rds-production | SELECT only |
| Dev/Staging | telephony-dev | cari-readonly-rds-dev-staging | SELECT only |

> **⚠️ ALWAYS use the readonly secret.** The admin secrets (`cari-rds-secret-production`, `cari-rds-secret-dev-staging`) should NOT be used by this skill.

### Multiple Databases on Same RDS Instance

Both config and reporting databases share the same RDS host. The secret's `dbname` field connects to the config DB by default. To query the reporting DB, override the database name:

| Database | `dbname` / `PGDATABASE` | Used By |
|----------|------------------------|---------|
| Config | `config-prod` (from secret) | config-service.md |
| Reporting | `reporting-prod` | reporting-service.md, performance-analytics.md |

**Same credentials, same host** — just change the database name in your connection string.

### PowerShell (Windows)

```powershell
# Production
$secretJson = aws secretsmanager get-secret-value `
  --secret-id cari-readonly-rds-production `
  --profile telephony-prod `
  --query "SecretString" `
  --output text | ConvertFrom-Json

# Dev/Staging
# $secretJson = aws secretsmanager get-secret-value `
#   --secret-id cari-readonly-rds-dev-staging `
#   --profile telephony-dev `
#   --query "SecretString" `
#   --output text | ConvertFrom-Json

$env:PGHOST = $secretJson.host
$env:PGPORT = $secretJson.port
$env:PGDATABASE = $secretJson.dbname
$env:PGUSER = $secretJson.username
$env:PGPASSWORD = $secretJson.password
```

### Bash

```bash
# Production
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id cari-readonly-rds-production \
  --profile telephony-prod \
  --query "SecretString" \
  --output text)

# Dev/Staging
# SECRET_JSON=$(aws secretsmanager get-secret-value \
#   --secret-id cari-readonly-rds-dev-staging \
#   --profile telephony-dev \
#   --query "SecretString" \
#   --output text)

DB_HOST=$(echo $SECRET_JSON | jq -r '.host')
DB_PORT=$(echo $SECRET_JSON | jq -r '.port')
DB_USER=$(echo $SECRET_JSON | jq -r '.username')
DB_PASS=$(echo $SECRET_JSON | jq -r '.password')
```

## RDS Proxy Limitation (MCP Postgres Connections)

**⚠️ The MCP `query_postgres` tool may fail with:**
```
Feature not supported: RDS Proxy currently doesn't support the option statement_timeout
```

This affects ALL MCP Postgres connections (`reporting-staging`, `config-staging`, `config-dev`, `reporting-dev`). The MCP connector sets `statement_timeout` which RDS Proxy rejects.

**Workaround:** Use `psql` directly with credentials from AWS Secrets Manager:

```bash
# Fetch creds (see above), then:
PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d reporting-prod -c "SELECT ..."
```

**For reporting DB queries**, override the database name:
- Config DB: use `$DB_NAME` from the secret (default)
- Reporting DB: use `-d reporting-prod` or `-d reporting-dev`

If `psql` is not installed, use `brew install libpq` (macOS) and add to PATH.

If AWS SSO is not configured, see the setup steps above.


### Convenience Function

Copy-paste this into your shell to create a one-liner for Cari Postgres queries:

```bash
cari_psql() {
  local profile="${1:-cari-prod}" db="${2:-reporting-prod}" query="$3"
  local secret_json host port user pass
  secret_json=$(aws secretsmanager get-secret-value --profile "$profile" \
    --secret-id "cari-readonly-rds-production" --query SecretString --output text)
  host=$(echo "$secret_json" | jq -r '.host')
  port=$(echo "$secret_json" | jq -r '.port')
  user=$(echo "$secret_json" | jq -r '.username')
  pass=$(echo "$secret_json" | jq -r '.password')
  PGPASSWORD="$pass" /opt/homebrew/opt/libpq/bin/psql -h "$host" -p "$port" -U "$user" -d "$db" -c "$query"
}

# Usage:
# cari_psql cari-prod reporting-prod "SELECT count(*) FROM calls WHERE lskinid = 72965"
# cari_psql cari-prod config-prod "SELECT * FROM scheduler_configs LIMIT 1"
```
