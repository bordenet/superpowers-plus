#!/usr/bin/env bash
# pre-tool-use-git-identity.sh — block git commit/push with wrong git identity.
#
# Item 2 of the Claude Code 12-point guardrails plan.
# Identity resolution: walk CWD upward to first AGENTS.md, parse the Email
# column from the identity table, compare against git config user.email.
# Exit codes: 0 = allow, 2 = block (stderr shown to model as reason).
set -euo pipefail
if [[ "${CLAUDE_HOOKS_BYPASS:-0}" == "1" ]]; then exit 0; fi

LOG="$HOME/.claude/hooks/hook-audit.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "$(date -u +%FT%TZ) git-identity exit=$1 reason=$2" >> "$LOG"; }

INPUT="$(cat)"
TOOL="$(jq -r '.tool_name // empty' <<<"$INPUT")"
[[ "$TOOL" != "Bash" ]] && { log 0 not-bash; exit 0; }
CMD="$(jq -r '.tool_input.command // empty' <<<"$INPUT")"
[[ "$CMD" =~ (^|[^A-Za-z0-9_])git[[:space:]]+(commit|push)([[:space:]]|$) ]] || { log 0 not-commit-or-push; exit 0; }
CWD="$(jq -r '.cwd // empty' <<<"$INPUT")"
ACTUAL="$(git -C "$CWD" config user.email 2>/dev/null || echo '')"
URL="$(git -C "$CWD" remote get-url origin 2>/dev/null || echo '')"

# resolve_expected_identity: walk CWD upward for AGENTS.md, parse Email column.
# Prints expected email or empty string if resolution fails (allowing the push).
resolve_expected_identity() {
  local cwd="$1" url="$2"
  python3 - "$cwd" "$url" <<'EOF'
import sys, os, re

cwd = sys.argv[1]
url = sys.argv[2]
workspace_root = os.path.expanduser("~/git")

# Walk upward from cwd, stop at workspace root.
path = cwd
agents_file = None
while True:
    candidate = os.path.join(path, "AGENTS.md")
    if os.path.isfile(candidate):
        agents_file = candidate
        break
    parent = os.path.dirname(path)
    if parent == path or path == workspace_root:
        # Try workspace root itself
        candidate = os.path.join(workspace_root, "AGENTS.md")
        if os.path.isfile(candidate):
            agents_file = candidate
        break
    path = parent

if not agents_file:
    sys.exit(0)  # No AGENTS.md found: allow

with open(agents_file) as f:
    content = f.read()

# Find first table whose header row contains both "Email" (and "Git" or "Context")
lines = content.splitlines()
header_idx = None
for i, line in enumerate(lines):
    if "|" in line and "email" in line.lower() and ("git" in line.lower() or "context" in line.lower()):
        header_idx = i
        break

if header_idx is None:
    sys.exit(0)  # No identity table found: allow

# Parse rows (skip separator line after header)
rows = []
for line in lines[header_idx + 2:]:
    if not line.strip().startswith("|"):
        break
    cells = [c.strip().strip("`") for c in line.strip().strip("|").split("|")]
    if len(cells) >= 2:
        rows.append(cells)

# Determine if this is a github.com push (personal) or work push.
is_github = "github.com" in url
for row in rows:
    # Check first cell (context) for github.com pattern
    ctx = row[0].lower()
    if is_github and "github.com" in ctx:
        # Find Email column (index varies; find by header position)
        headers = [c.strip().lower() for c in lines[header_idx].strip().strip("|").split("|")]
        email_col = next((i for i, h in enumerate(headers) if "email" in h), 1)
        if email_col < len(row):
            print(row[email_col].strip())
            sys.exit(0)
    elif not is_github and ("work" in ctx or "callbox" in ctx or "azure" in ctx or "gitlab" in ctx):
        headers = [c.strip().lower() for c in lines[header_idx].strip().strip("|").split("|")]
        email_col = next((i for i, h in enumerate(headers) if "email" in h), 1)
        if email_col < len(row):
            val = row[email_col].strip()
            # Skip placeholder rows ("see repo AGENTS.md" etc.)
            if "@" in val:
                print(val)
                sys.exit(0)

sys.exit(0)  # No matching row: allow
EOF
}

EXPECTED="$(resolve_expected_identity "$CWD" "$URL")"

if [[ -n "$EXPECTED" && "$ACTUAL" != "$EXPECTED" ]]; then
  {
    echo "BLOCKED: git identity mismatch in $CWD"
    echo "  expected: $EXPECTED  (per nearest AGENTS.md, repo URL: $URL)"
    echo "  actual:   $ACTUAL"
    echo "  fix:      git config user.email '$EXPECTED'"
  } >&2
  log 2 mismatch
  exit 2
fi
log 0 ok
exit 0
