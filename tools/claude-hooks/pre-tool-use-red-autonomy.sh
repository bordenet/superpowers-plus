#!/usr/bin/env bash
# pre-tool-use-red-autonomy.sh — block RED-band actions without an explicit
# human approval token in the current session transcript.
#
# Item 10 of the Claude Code 12-point guardrails plan.
# RED actions: git push, force push, branch deletion, TODO.md writes, etc.
# Approval phrases (case-insensitive, word-bounded): "approve push",
# "approve release", "release approved", "you may push", "proceed with push",
# "promote to main". ("ship it" was considered and rejected -- too generic a
# casual affirmation, could trigger from an unrelated remark within the
# 10-message window.) Revoke phrases ("revoke push", "cancel push",
# "do not push", "stop pushing") in a more recent message win over an earlier
# approval. File-based tokens are single-use; transcript-based tokens are
# reusable (phrase persists in transcript). Consumed hashes stored in
# ~/.claude/consumed/.
# Transcript scan checks the last 10 non-empty user messages (most recent
# first, not just the single last one -- a real approval can otherwise scroll
# out of view behind a burst of tool-result/notification messages), across 3
# message shapes: legacy {"role":"user",...}, current {"type":"user",
# "message":{"role":"user",...}}, and mid-turn queued commands
# {"type":"attachment","attachment":{"type":"queued_command",...}} -- the last
# covers approval phrases typed while Claude is still working, which the other
# two shapes never see.
# KNOWN, ACCEPTED LIMITATION: the approval token is not scoped to the specific
# RED command it was granted for -- any approval phrase found in the lookback
# window satisfies ANY RED action, including one never discussed. This
# predates the multi-message lookback; it widens the window this can be
# misapplied across, but does not introduce the gap. See the "R5" test in
# tests/claude-guardrails-test.bats for the documented, tested contract.
# Real per-action/branch scoping is tracked as future work, not fixed here.
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
SESSION_ID="$(jq -r '.session_id // empty' <<<"$INPUT" | tr -cd 'a-zA-Z0-9_-' | cut -c1-128)"
# Fallback: transcript_path removed from Claude Code hook payload in newer versions.
# If absent, locate the transcript by session_id under ~/.claude/projects/.
if [[ -z "$TRANSCRIPT" && -n "$SESSION_ID" ]]; then
  # SESSION_ID is sanitized to [a-zA-Z0-9_-] so path traversal via -name is impossible.
  # UUID session IDs make same-name collisions near-zero; head -1 handles the rare edge case.
  TRANSCRIPT="$(find "$HOME/.claude/projects/" -maxdepth 3 -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)"
fi

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
# SESSION_ENV_DIR: approval files (push-approval) live here — classifier-sensitive path.
# CONSUMED_DIR: consumed-token records live here — writable by the hook without classifier.
SESSION_ENV_DIR="$HOME/.claude/session-env"
CONSUMED_DIR="$HOME/.claude/consumed"
mkdir -p "$SESSION_ENV_DIR" "$CONSUMED_DIR"
CONSUMED_FILE="$CONSUMED_DIR/${SESSION_ID}.consumed-approvals.txt"

extract_approval_token() {
  # Method 1: explicit approval file written by Claude via Write tool.
  # Format: single line containing the token category (push|release).
  # This avoids the transcript-timing race condition entirely.
  local APPROVAL_FILE="$SESSION_ENV_DIR/${SESSION_ID}.push-approval"
  if [[ -f "$APPROVAL_FILE" ]]; then
    local token_text; token_text="$(tr -cd '[:lower:]' < "$APPROVAL_FILE" | head -c 10)"
    case "$token_text" in push|release) echo "$token_text"; return 0 ;; esac
  fi

  # Method 2: scan the last 10 non-empty user messages (most recent first) for
  # an approval or revoke phrase. A single-last-message check is too narrow --
  # a real approval phrase can scroll out if a burst of tool-result/notification
  # messages lands right after it; scanning 10 gives it room to survive that.
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
]

REVOKE_PHRASES = [
    r'\brevoke\s+push\b',
    r'\bcancel\s+push\b',
    r'\bdo\s+not\s+push\b',
    r'\bstop\s+pushing\b',
]

transcript_path = sys.argv[1]
recent_user_messages = []

def extract_text(content):
    if isinstance(content, list):
        return " ".join(p.get("text","") for p in content if isinstance(p,dict))
    return content if isinstance(content, str) else ""

with open(transcript_path, encoding='utf-8', errors='replace') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        t = ""
        # Support three transcript shapes:
        # Legacy: {"role":"user","content":...}
        # Current: {"type":"user","message":{"role":"user","content":...}}
        # Mid-turn queued command: {"type":"attachment","attachment":
        #   {"type":"queued_command","prompt":"...","origin":{"kind":"human"}}}
        # -- messages sent while Claude is still working on a turn are queued
        # and surfaced in this third shape, invisible to the first two checks.
        # Confirmed via a real session transcript where "approve push" sent
        # mid-turn never satisfied this scan, but the identical phrase sent
        # moments later as a fresh standalone message did. Gated on
        # origin.kind == "human" so only user-authored queued commands count.
        if obj.get("role") == "user":
            t = extract_text(obj.get("content", ""))
        elif obj.get("type") == "user":
            msg = obj.get("message", {})
            if isinstance(msg, dict) and msg.get("role") == "user":
                t = extract_text(msg.get("content", ""))
        elif obj.get("type") == "attachment":
            att = obj.get("attachment", {})
            if isinstance(att, dict) and att.get("type") == "queued_command":
                origin = att.get("origin", {})
                if isinstance(origin, dict) and origin.get("kind") == "human":
                    p = att.get("prompt", "")
                    if isinstance(p, str):
                        t = p
        if t.strip():
            recent_user_messages.append(t)

if not recent_user_messages:
    sys.exit(0)

for msg in reversed(recent_user_messages[-10:]):
    msg_lower = msg.lower()
    for phrase in REVOKE_PHRASES:
        if re.search(phrase, msg_lower):
            sys.exit(0)
    for phrase in APPROVAL_PHRASES:
        if re.search(phrase, msg_lower):
            # Determine category (push vs release); suffix ":tr" marks transcript origin.
            if "push" in phrase or "ship" in phrase or "promote" in phrase:
                print("push:tr")
            else:
                print("release:tr")
            sys.exit(0)

sys.exit(0)
EOF
}

TOKEN_CATEGORY_RAW="$(extract_approval_token)"
# Constrain to known literals only. ":tr" suffix marks transcript-sourced tokens;
# bare "push"/"release" are from the file-based approval mechanism.
TOKEN_SOURCE="file"
case "$TOKEN_CATEGORY_RAW" in
  push)             TOKEN_CATEGORY="push" ;;
  release)          TOKEN_CATEGORY="release" ;;
  push:tr)          TOKEN_CATEGORY="push";    TOKEN_SOURCE="transcript" ;;
  release:tr)       TOKEN_CATEGORY="release"; TOKEN_SOURCE="transcript" ;;
  *)                TOKEN_CATEGORY="" ;;
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

# File-based tokens are single-use: check and update consumed hash.
# Transcript-based tokens are reusable (the phrase persists in the transcript).
if [[ "$TOKEN_SOURCE" == "file" ]]; then
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
  echo "$TOKEN_HASH" >> "$CONSUMED_FILE"
  # Remove file-based approval token (it is single-use by design).
  rm -f "$SESSION_ENV_DIR/${SESSION_ID}.push-approval" 2>/dev/null || true
fi

log 0 "approved-${TOKEN_CATEGORY}(${TOKEN_SOURCE})"
exit 0
