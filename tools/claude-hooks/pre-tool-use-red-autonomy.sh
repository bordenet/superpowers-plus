#!/usr/bin/env bash
# pre-tool-use-red-autonomy.sh — block RED-band actions without an explicit
# human approval token in the current session transcript.
#
# Item 10 of the Claude Code 12-point guardrails plan.
# RED actions: git push, force push, branch deletion, TODO.md writes, etc.
# Approval phrases (case-insensitive, word-bounded): "approve push",
# "approve release", "release approved", "you may push", "proceed with push",
# "promote to main", "ship it".
# Token is single-use per session; consumed hash stored in session-env file.
# Exit codes: 0 = allow, 2 = block (stderr shown to model as reason).
set -euo pipefail
if [[ "${CLAUDE_HOOKS_BYPASS:-0}" == "1" ]]; then exit 0; fi

LOG="$HOME/.claude/hooks/hook-audit.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "$(date -u +%FT%TZ) red-autonomy exit=$1 reason=$2" >> "$LOG"; }

# Portable SHA256 shim — capability resolved once at script load, not per call.
if command -v sha256sum &>/dev/null; then
  _sha256() { sha256sum | cut -d' ' -f1; }
else
  _sha256() { shasum -a 256 | cut -d' ' -f1; }
fi

INPUT="$(cat)"
CMD="$(jq -r '.tool_input.command // empty' <<<"$INPUT")"
TRANSCRIPT="$(jq -r '.transcript_path // empty' <<<"$INPUT")"
# Sanitize SESSION_ID immediately at intake — it is used in a file path below.
# Characters outside [a-zA-Z0-9_-] are stripped; result capped at 128 chars.
SESSION_ID="$(jq -r '.session_id // empty' <<<"$INPUT" | tr -cd 'a-zA-Z0-9_-' | head -c 128)"

PATTERNS_FILE="${CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE:-$HOME/.config/claude-hooks/red-autonomy-patterns.txt}"

# Check if command matches any RED pattern.
is_red_action() {
  local cmd="$1"
  [[ -s "$PATTERNS_FILE" ]] || return 1
  local TMP_PAT rc=0
  TMP_PAT="$(mktemp)"
  grep -v '^\s*#' "$PATTERNS_FILE" | grep -v '^\s*$' > "$TMP_PAT" || true
  if [[ ! -s "$TMP_PAT" ]]; then
    rm -f "$TMP_PAT"
    return 1
  fi
  echo "$cmd" | grep -qE -f "$TMP_PAT" 2>/dev/null || rc=$?
  rm -f "$TMP_PAT"
  # rc=2 means grep encountered an error (e.g., malformed pattern in file).
  # Fail closed: treat as a RED action so the approval gate fires rather than
  # silently allowing an unblocked push due to a broken patterns file.
  [[ $rc -eq 2 ]] && return 0
  return $rc
}

is_red_action "$CMD" || { log 0 not-red; exit 0; }

# Fail open when session_id is absent — a shared fallback file would permanently
# block all session-less pushes after the first consumed token. An adversarial
# session_id consisting entirely of special characters also sanitizes to empty
# and hits this path; that is acceptable given this hook's threat model (Claude
# autonomy, not external actors controlling hook input).
if [[ -z "$SESSION_ID" ]]; then
  echo "WARNING: no session_id in hook input — RED action allowed without approval check." >&2
  log 0 "no-session-id-fail-open"
  exit 0
fi

# It's a RED action — check for approval token in transcript.
SESSION_ENV_DIR="$HOME/.claude/session-env"
mkdir -p "$SESSION_ENV_DIR"
CONSUMED_FILE="$SESSION_ENV_DIR/${SESSION_ID}.consumed-approvals.txt"

extract_approval_token() {
  # Read the last user message from the JSONL transcript.
  [[ -f "$TRANSCRIPT" ]] || return 0
  python3 - "$TRANSCRIPT" <<'EOF'
import sys, json, re

APPROVAL_PHRASES = [
    r'\bapprove\s+push\b',
    r'\bapprove\s+release\b',
    r'\brelease\s+approved\b',
    r'\byou\s+may\s+push\b',
    r'\bproceed\s+with\s+push\b',
    r'\bpromote\s+to\s+main\b',
    r'\bship\s+it\b',
]

transcript_path = sys.argv[1]
last_user_text = ""
with open(transcript_path, encoding='utf-8', errors='replace') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("role") == "user":
            content = obj.get("content", "")
            if isinstance(content, list):
                parts = [p.get("text", "") for p in content if isinstance(p, dict)]
                last_user_text = " ".join(parts)
            elif isinstance(content, str):
                last_user_text = content

if not last_user_text:
    sys.exit(0)

text_lower = last_user_text.lower()
for phrase in APPROVAL_PHRASES:
    m = re.search(phrase, text_lower)
    if m:
        # Determine category (push vs release).
        if "push" in phrase or "ship" in phrase or "promote" in phrase:
            print("push")
        else:
            print("release")
        sys.exit(0)

sys.exit(0)
EOF
}

TOKEN_CATEGORY="$(extract_approval_token)"
# Constrain to known literals only — unexpected python3 output (deprecation
# warnings, tracebacks) must not be mistaken for an approval token.
case "$TOKEN_CATEGORY" in
  push|release) ;;
  *) TOKEN_CATEGORY="" ;;
esac

if [[ -z "$TOKEN_CATEGORY" ]]; then
  {
    echo "BLOCKED: RED action without explicit approval in current session."
    # Collapse newlines in CMD to prevent injection of fake BLOCKED lines into
    # the model-visible stderr output.
    echo "  command: $(printf '%s' "$CMD" | tr '\n' ' ')"
    echo "  Say 'approve push' or another approval phrase to authorize this action."
  } >&2
  log 2 no-approval
  exit 2
fi

# Check if this token category was already consumed in this session.
# NOTE: check-then-append is not atomic. Claude Code serializes pre-tool-use
# hooks within a session, making concurrent races impossible in practice.
TOKEN_HASH="$(printf '%s:%s' "$SESSION_ID" "$TOKEN_CATEGORY" | _sha256)"
if [[ -f "$CONSUMED_FILE" ]] && grep -qF "$TOKEN_HASH" "$CONSUMED_FILE" 2>/dev/null; then
  {
    echo "BLOCKED: RED action approval token already consumed in this session."
    echo "  command: $(printf '%s' "$CMD" | tr '\n' ' ')"
    echo "  The '$TOKEN_CATEGORY' token was already used. Request a new approval."
  } >&2
  log 2 token-consumed
  exit 2
fi

# First use: consume the token and allow.
echo "$TOKEN_HASH" >> "$CONSUMED_FILE"
log 0 "approved-$TOKEN_CATEGORY"
exit 0
