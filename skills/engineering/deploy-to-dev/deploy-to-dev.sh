#!/usr/bin/env bash
set -euo pipefail

# Description: Deploy a CARI service branch to the Dev environment via Azure Pipelines.
#              Queues a manual pipeline run on the branch, monitors until the Dev stage
#              completes, and optionally verifies ECS health.
#
# Usage: deploy-to-dev.sh <service> <branch-or-pr>
#        deploy-to-dev.sh telephony-service fix/DELTA-1142
#        deploy-to-dev.sh telephony-service PR:25419
#
# Prerequisites: az CLI authenticated (az login / az devops configure)

readonly PROJECT="CARI Phone Assist"
readonly POLL_INTERVAL=30
readonly MAX_WAIT=900  # 15 minutes

# --- Color output (if terminal) ---
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; BLUE=''; NC=''
fi

info()  { echo -e "${BLUE}▸${NC} $*"; }
ok()    { echo -e "${GREEN}✅${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠️${NC}  $*"; }
fail()  { echo -e "${RED}❌${NC} $*" >&2; exit 1; }

# --- Usage ---
usage() {
  cat <<'EOF'
Usage: deploy-to-dev.sh <service> <branch-or-pr>

Arguments:
  service       Service name matching an Azure Pipeline (e.g. telephony-service, agent-api)
  branch-or-pr  Git branch name, OR "PR:<number>" to resolve from a pull request

Examples:
  deploy-to-dev.sh telephony-service fix/DELTA-1142-third-way
  deploy-to-dev.sh telephony-service PR:25419
  deploy-to-dev.sh agent-api feature/new-endpoint

Prerequisites:
  - az CLI installed and authenticated (run: az login)
  - Azure DevOps defaults configured (run: az devops configure --defaults project="CARI Phone Assist")
EOF
  exit 1
}

[[ ${#} -ge 2 ]] || usage

readonly SERVICE="$1"
readonly BRANCH_INPUT="$2"

# --- Step 1: Check az CLI auth ---
info "Checking Azure DevOps authentication..."
if ! az account show &>/dev/null; then
  fail "Not authenticated. Run: az login"
fi

# --- Step 2: Resolve pipeline ID from service name ---
info "Looking up pipeline for '${SERVICE}'..."
local_pipeline_id=""
local_pipeline_id=$(az pipelines list --project "$PROJECT" --name "$SERVICE" --query "[0].id" -o tsv 2>/dev/null) || true

if [[ -z "$local_pipeline_id" ]]; then
  echo ""
  warn "No pipeline found named '${SERVICE}'. Available pipelines:"
  az pipelines list --project "$PROJECT" --query "[].name" -o tsv 2>/dev/null | sed 's/^/    /'
  echo ""
  fail "Pipeline '${SERVICE}' not found."
fi
readonly PIPELINE_ID="$local_pipeline_id"
ok "Pipeline: ${SERVICE} (ID: ${PIPELINE_ID})"

# --- Step 3: Resolve branch name ---
local_branch=""
if [[ "$BRANCH_INPUT" == PR:* ]]; then
  local_pr_id="${BRANCH_INPUT#PR:}"
  info "Resolving branch from PR #${local_pr_id}..."
  local_branch=$(az repos pr show --id "$local_pr_id" --project "$PROJECT" --query "sourceRefName" -o tsv 2>/dev/null) || true
  if [[ -z "$local_branch" ]]; then
    fail "Could not resolve PR #${local_pr_id}. Check the PR number and try again."
  fi
  # Strip refs/heads/ prefix
  local_branch="${local_branch#refs/heads/}"
  ok "PR #${local_pr_id} → branch: ${local_branch}"
else
  local_branch="$BRANCH_INPUT"
fi
readonly BRANCH="$local_branch"

# --- Step 4: Verify PR approval gate ---
# Required reviewers — matched by stable ADO identity ID (not email, which can change)
readonly REQUIRED_REVIEWER_IDS=(
  "7fa4220c-6614-6628-9991-54c7d1f85e40:Thomas Smith"
  "7a5b2fd1-9491-6e66-b721-97413f508310:Junyi Sim"
)

info "Checking for active PR on branch '${BRANCH}' targeting 'main' in repo '${SERVICE}'..."

# Find active PR for this branch, constrained by repository AND target branch
local_pr_json=""
if ! local_pr_json=$(az repos pr list \
  --project "$PROJECT" \
  --repository "$SERVICE" \
  --source-branch "$BRANCH" \
  --target-branch main \
  --status active \
  --query "[0]" \
  -o json 2>&1); then
  fail "Failed to query PRs. Check 'az' authentication and project access. Error: ${local_pr_json}"
fi

if [[ -z "$local_pr_json" || "$local_pr_json" == "null" ]]; then
  fail "No active PR found for branch '${BRANCH}' targeting 'main' in repo '${SERVICE}'. Create a PR before deploying."
fi

# Parse all PR fields in a single python3 call — fail explicitly if parsing breaks
local_pr_parsed=""
if ! local_pr_parsed=$(echo "$local_pr_json" | python3 -c "
import sys, json
pr = json.load(sys.stdin)
print(pr['pullRequestId'])
print(pr['isDraft'])
print(pr['mergeStatus'])
reviewers = pr.get('reviewers', [])
for r in reviewers:
    print(f\"REVIEWER:{r.get('id','')}:{r.get('vote',0)}:{r.get('displayName','')}\")
" 2>&1); then
  fail "Failed to parse PR response: ${local_pr_parsed}"
fi

local_pr_id_check=""
local_pr_id_check=$(echo "$local_pr_parsed" | sed -n '1p')
local_is_draft=""
local_is_draft=$(echo "$local_pr_parsed" | sed -n '2p')
local_merge_status=""
local_merge_status=$(echo "$local_pr_parsed" | sed -n '3p')

if [[ "$local_is_draft" == "True" ]]; then
  fail "PR #${local_pr_id_check} is a draft. Mark as ready for review before deploying."
fi

# mergeStatus: REST API returns int (3=succeeded), CLI may return string ("succeeded")
# Accept both forms
case "$local_merge_status" in
  3|succeeded)
    ok "PR #${local_pr_id_check} found (active, not draft, mergeable)" ;;
  conflicts|2)
    fail "PR #${local_pr_id_check} has merge conflicts. Rebase on main before deploying." ;;
  rejectedByPolicy)
    fail "PR #${local_pr_id_check} rejected by branch policy. Resolve policy requirements before deploying." ;;
  failure|4)
    fail "PR #${local_pr_id_check} merge check failed. Investigate before deploying." ;;
  *)
    fail "PR #${local_pr_id_check} has unexpected mergeStatus='${local_merge_status}'. Cannot verify mergeability." ;;
esac

# Check required reviewer approvals by stable ADO identity ID
# Reviewers were already parsed above as "REVIEWER:{id}:{vote}:{name}" lines
info "Verifying required reviewer approvals..."
local_reviewer_lines=""
local_reviewer_lines=$(echo "$local_pr_parsed" | grep "^REVIEWER:" || true)

local_all_approved=true
for required in "${REQUIRED_REVIEWER_IDS[@]}"; do
  local_rid="${required%%:*}"
  local_name="${required##*:}"
  # Search for this reviewer ID in the pre-parsed lines (grep won't abort — || true above)
  local_match=""
  local_match=$(echo "$local_reviewer_lines" | grep "REVIEWER:${local_rid}:" || true)

  if [[ -z "$local_match" ]]; then
    echo -e "  ${RED}❌${NC} ${local_name}: NOT A REVIEWER on PR #${local_pr_id_check}"
    local_all_approved=false
  else
    local_vote=""
    local_vote=$(echo "$local_match" | head -1 | cut -d: -f3)
    if [[ "$local_vote" == "10" ]]; then
      echo -e "  ${GREEN}✅${NC} ${local_name}: Approved"
    else
      echo -e "  ${RED}❌${NC} ${local_name}: vote=${local_vote} (need 10=Approved)"
      local_all_approved=false
    fi
  fi
done

if [[ "$local_all_approved" != "true" ]]; then
  echo ""
  fail "PR #${local_pr_id_check} missing required approvals. Both Thomas Smith AND Junyi Sim must approve (vote=10) before deploying to Dev."
fi

ok "All required reviewers approved PR #${local_pr_id_check}"
echo ""

# --- Step 5: Queue the pipeline run ---
info "Queuing pipeline run on branch '${BRANCH}'..."
local_run_id=""
local_run_id=$(az pipelines run \
  --id "$PIPELINE_ID" \
  --branch "$BRANCH" \
  --project "$PROJECT" \
  --query "id" -o tsv 2>/dev/null) || true

if [[ -z "$local_run_id" ]]; then
  fail "Failed to queue pipeline. Check that branch '${BRANCH}' exists."
fi
readonly RUN_ID="$local_run_id"
ok "Pipeline run #${RUN_ID} queued"

# --- Step 6: Monitor until completion ---
info "Monitoring run #${RUN_ID} (polling every ${POLL_INTERVAL}s, timeout ${MAX_WAIT}s)..."
local_elapsed=0
local_status="notStarted"
local_result=""

while [[ "$local_status" != "completed" && "$local_status" != "canceled" ]]; do
  if (( local_elapsed >= MAX_WAIT )); then
    warn "Timeout after ${MAX_WAIT}s. Run #${RUN_ID} still in progress."
    warn "Check manually: az pipelines runs show --id ${RUN_ID} --project '${PROJECT}'"
    exit 2
  fi
  sleep "$POLL_INTERVAL"
  local_elapsed=$((local_elapsed + POLL_INTERVAL))

  local_output=""
  local_output=$(az pipelines runs show --id "$RUN_ID" --project "$PROJECT" \
    --query "{status:status, result:result}" -o tsv 2>/dev/null) || true
  local_status=$(echo "$local_output" | awk '{print $1}')
  local_result=$(echo "$local_output" | awk '{print $2}')
  printf "  %s  status=%s result=%s\n" "$(date +%H:%M:%S)" "$local_status" "${local_result:-pending}"
done

# --- Step 7: Check Dev stage result ---
info "Checking stage results..."
local_dev_result=""
local_dev_result=$(az devops invoke \
  --area build --resource timeline \
  --route-parameters project="$PROJECT" buildId="$RUN_ID" \
  --query "records[?type=='Stage' && contains(name, 'Development')].result | [0]" \
  -o tsv 2>/dev/null) || true

local_build_result=""
local_build_result=$(az devops invoke \
  --area build --resource timeline \
  --route-parameters project="$PROJECT" buildId="$RUN_ID" \
  --query "records[?type=='Stage' && contains(name, 'Build')].result | [0]" \
  -o tsv 2>/dev/null) || true

echo ""
echo "━━━ Pipeline Run #${RUN_ID} Results ━━━"

if [[ "$local_build_result" != "succeeded" ]]; then
  fail "Build stage: ${local_build_result:-unknown}. Fix build errors before deploying."
fi
ok "Build: succeeded"

if [[ "$local_dev_result" == "succeeded" ]]; then
  ok "Deploy to Dev: succeeded"
  echo ""
  ok "Branch '${BRANCH}' is now deployed to Dev."
  echo "   Service: ${SERVICE}"
  echo "   Run:     #${RUN_ID}"
  echo "   Time:    ${local_elapsed}s"
elif [[ -z "$local_dev_result" || "$local_dev_result" == "None" ]]; then
  warn "Deploy to Dev stage not found in timeline. The pipeline may not have a Dev deployment stage."
  exit 2
else
  fail "Deploy to Dev: ${local_dev_result}. Check pipeline logs for details."
fi
