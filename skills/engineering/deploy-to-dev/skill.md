---
name: deploy-to-dev
source: superpowers-[product]
triggers: ["deploy to dev", "push to dev", "deploy PR to dev", "deploy branch to dev", "push changes to dev", "deploy to development", "get this on dev", "push this to dev environment"]
anti_triggers: ["deploy to staging", "deploy to production", "deploy to prod", "merge to main", "merge PR"]
description: Deploy a [PRODUCT] service branch or PR to the Dev environment without merging. Uses Azure Pipelines manual trigger to build, push Docker image, and update ECS. No Docker or AWS credentials required locally — only az CLI.
summary: "Use when: deploying a branch or PR to the Dev environment without merging to main."
coordination:
  group: [product]
  order: 1
  requires: []
  enables: ['[warm-transfer]-tester']
  escalates_to: []
  internal: false
---

# Deploy to Dev

## When to Use

- Deploy a [PRODUCT] branch or PR to Dev without merging to `main`
- Smoke-test a feature or verify a fix in the shared Dev environment
- User says "deploy to dev," "push to dev," or "get this on dev"
- NOT for: staging/production deploys, merging PRs, CI/CD pipeline config

Deploy any [PRODUCT] service branch to the Dev environment in ~8-10 minutes. No Docker, no AWS credentials, no PowerShell required. Just `az` CLI.

## How It Works

The script queues a **manual** Azure Pipeline run on the target branch. Because the trigger is `manual` (not `PullRequest`), the pipeline's Dev deployment stage executes — building the Docker image in the pipeline agent, pushing to ECR, and updating the ECS service.

**Staging will fail** with a branch protection error. This is expected and harmless — the Dev deployment completes independently.

## Prerequisites

1. **az CLI installed** — `brew install azure-cli` (macOS) or `curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash` (Linux)
2. **az CLI authenticated** — `az login` (browser SSO flow)
3. **Azure DevOps defaults set** — `az devops configure --defaults project="[PRODUCT] Phone Assist" organization=https://dev.azure.com/[Company]`

To verify: `az pipelines list --project "[PRODUCT] Phone Assist" --output table` should show pipelines.

## Usage

```bash
# Deploy a branch
bash /path/to/deploy-to-dev.sh [telephony-service] fix/DELTA-1142-third-way

# Deploy from a PR number (resolves branch automatically)
bash /path/to/deploy-to-dev.sh [telephony-service] PR:25419

# Deploy another service
bash /path/to/deploy-to-dev.sh agent-api feature/new-endpoint
```

The script will:
1. ✅ Verify `az` authentication
2. ✅ Resolve the pipeline ID from the service name
3. ✅ Resolve the branch from a PR number (if `PR:` prefix used)
4. 🔒 **Verify PR approval gate** — active PR, not draft, no merge conflicts, both Thomas Smith AND Junyi Sim approved (vote=10)
5. ✅ Queue the pipeline run
6. ✅ Monitor progress (polls every 30s, 15-min timeout)
7. ✅ Report Dev deployment result (ignores Staging/Prod failures)

## 🔴 Pre-Flight Gate (NON-NEGOTIABLE)

**Before deploying ANYTHING to Dev, ALL of the following must be true:**

### 1. Active PR exists
The branch must have an **active, non-draft PR** targeting `main`. No PR = no deploy.

### 2. Required reviewers have approved
Both of these reviewers must have voted **Approved (vote = 10)** on the PR:

| Reviewer | Email | ADO ID |
|----------|-------|--------|
| **Thomas Smith** | `REDACTED@[company].com` | `7fa4220c-6614-6628-9991-54c7d1f85e40` |
| **Junyi Sim** | `REDACTED@[company].com` | `7a5b2fd1-9491-6e66-b721-97413f508310` |

- `vote = 0` (no vote) → ❌ BLOCKED
- `vote = 5` (approved with suggestions) → ❌ BLOCKED — must be full approval
- `vote = 10` (approved) → ✅ PASS
- `vote = -5` (waiting for author) → ❌ BLOCKED
- `vote = -10` (rejected) → ❌ BLOCKED

### 3. Branch is mergeable (no conflicts)
The PR must have a successful merge status — no merge conflicts. Note: this only verifies mergeability, not that the branch is fully up-to-date with main. If merge conflicts exist, the developer must rebase or merge main into the branch first.

Merge status values (REST API returns int, CLI may return string):
- `3` / `succeeded` → ✅ PASS
- `2` / `conflicts` → ❌ BLOCKED
- `rejectedByPolicy` → ❌ BLOCKED
- `failure` / `4` → ❌ BLOCKED

### 4. Human said "deploy to dev" in THIS conversation
The agent must have explicit human approval in the current conversation. Prior sessions don't count.

### Verification procedure (for agents)

Before running `deploy-to-dev.sh`, the agent MUST:

1. Call `repo_list_pull_requests_by_repo_or_project_azure-devops` with `repositoryId`, `sourceRefName=refs/heads/<branch>`, and `targetRefName=refs/heads/main` to find the active PR for the exact branch in the correct repo
2. Call `repo_get_pull_request_by_id_azure-devops` to check:
   - `status = 1` (active)
   - `isDraft = false`
   - `mergeStatus = 3` or `succeeded` (mergeable, no conflicts)
3. Check `reviewers` array for BOTH Thomas Smith (ID: `7fa4220c-...`) and Junyi Sim (ID: `7a5b2fd1-...`) with `vote = 10` — match by ID, not email
4. If ANY check fails → **DO NOT DEPLOY**. Tell the user exactly what's missing.

### Gate failure messages

| Check | Failure message |
|-------|----------------|
| No PR | "Branch `{branch}` has no active PR. Create a PR targeting main before deploying." |
| Missing reviewer | "PR #{id} is missing approval from {name}. Both Thomas Smith and Junyi Sim must approve." |
| Vote not approved | "PR #{id}: {name} has not approved (current vote: {vote}). Approval (vote=10) required." |
| Merge conflict | "PR #{id} has merge conflicts. Rebase on main before deploying." |
| Draft PR | "PR #{id} is a draft. Mark as ready for review before deploying." |

## For Agents

When a user says "deploy to dev" or "push this to dev":

1. **Identify the service** — which repo are we working with? ([telephony-service], agent-api, config-service, etc.)
2. **Identify the branch or PR** — what code should be deployed?
3. **Run the pre-flight gate** — verify PR exists, both reviewers approved, no merge conflicts (see above)
4. **Only if ALL checks pass**, run the script:

```bash
bash ~/.codex/skills/deploy-to-dev/deploy-to-dev.sh <service-name> <branch-or-PR:number>
```

5. **Report the result** to the user with the pipeline run number.

> **Incident (2026-03-27):** An agent pushed 4 branches to ADO without PR approvals, triggering 2 pipeline runs that deployed unsanctioned code to Dev through 3/5 stages. This pre-flight gate exists to prevent recurrence.

## Supported Services

Any service with an Azure Pipeline in the [PRODUCT] Phone Assist project:

| Service | Pipeline |
|---------|----------|
| [telephony-service] | [telephony-service] |
| agent-api | agent-api |
| config-service | config-service |
| reporting-service | reporting-service |
| integration-platform | integration-platform |
| call-processing | call-processing |

## Troubleshooting

| Error | Fix |
|-------|-----|
| "Not authenticated" | Run `az login` |
| "No pipeline found" | Check service name matches a pipeline. Run `az pipelines list --project "[PRODUCT] Phone Assist"` |
| "Could not resolve PR" | Check the PR number exists and is active |
| "Build stage failed" | Fix build errors in the branch first (lint, tests, compilation) |
| "Deploy to Dev failed" | Check pipeline logs: `az pipelines runs show --id <RUN_ID> --project "[PRODUCT] Phone Assist"` |
| Timeout (15 min) | Pipeline may be queued behind other runs. Check Azure DevOps web UI. |

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Wrong branch deployed | Unexpected behavior | Verify branch name and ADO pipeline |
| Stale build cache | Old code despite deploy | Force clean build |
