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
# TARGET-BINDING (R6): for git push / git branch -D commands, a transcript-
# sourced approval additionally requires that this session's most recent,
# SETTLED-AND-ALLOWED prior git push/branch-delete tool_use (if any) targeted
# the same ref (remote+branch, or local branch name for `branch -D`), with
# severity (plain push < force-push < branch-delete) no higher than that
# prior action. This binds approval to the assistant's own structured tool_use
# history, not to parsed human prose -- two earlier designs that tried to
# extract a target ref from conversation text either missed the dominant
# "discussed earlier, approved tersely later" phrasing (proximity-window) or
# collided with ordinary English words that are also common branch names
# ("main", "dev") (keyword enumeration). Neither pitfall applies here because
# nothing here regexes human sentences for a ref.
# PROVENANCE: a prior tool_use only counts if a corresponding tool_result
# shows it actually ran (was allowed) -- a tool_use with no tool_result yet
# (this reliably describes the CURRENT invocation's own just-emitted call,
# and any not-yet-executed sibling in the same batched assistant turn) is
# excluded, and a tool_result whose content contains this same hook's own
# "BLOCKED: RED action" text (a DENIED attempt, never executed) is also
# excluded. Without this, a denied attempt would itself become trusted
# precedent, letting an agent plant a fake "prior" for any target and then
# have an unrelated later approval phrase bind against it -- a
# self-authorization hole (code-review-battery, 2026-07-12).
# AMBIGUOUS TARGETS: bare `git push` (no ref args), a single ambiguous token
# (could be a remote name or a branch name -- git's own grammar is
# context-dependent), the literal ref "HEAD", and any compound command
# (&&, ||, ;, |) whose segments don't all resolve to the identical target
# are never resolved or guessed -- they always fail to match (deny),
# including against an identical-looking prior of the same ambiguous shape.
# This trades convenience (these forms always need a fresh approval, even
# for a genuine repeat) for never silently trusting a resolution that could
# differ across two invocations (e.g. a bare push means a different branch
# once the working tree has since been checked out elsewhere).
# NAMED-TARGET ESCAPE VALVE: when target-binding would otherwise deny (a
# different target, or a severity escalation), a message that contains BOTH
# an approval phrase AND the exact current target ref as a whole word
# (never a ref guessed or extracted from prose -- the ref always comes from
# tool_input.command) is treated as an explicit re-approval of that specific
# target ("approve push to branch-b"). This only ever widens a deny into an
# allow, only for the exact, already-known current target, only within one
# message. Added round 2 (code-review-battery, 2026-07-12) after two
# independent reviewers confirmed the alternative -- no escape valve at all,
# requiring the file-based Method 1 token or a fresh session for any second
# distinct target in a session -- was a real, not just theoretical,
# usability cliff (typical sessions push several different branches, often
# across more than one repo, in one sitting). Residual
# risk: a short/common branch name (e.g. "main") could coincidentally
# co-occur with an approval phrase in the same message without the human
# intending to name that target -- bounded to the already-would-deny path,
# same message only, not the broader "anywhere in the 10-message window"
# surface the earlier, rejected keyword-enumeration design had.
# ACCEPTED RESIDUAL LIMITATIONS (narrower than the pre-R6 gap):
#  1. The very first settled-and-allowed git push/branch-delete this session
#     has no prior to bind against, so it is authorized by any approval
#     phrase in the lookback window regardless of target -- reachable once
#     per session, on the first such action only.
#  2. A second distinct target, without explicit same-message naming (see
#     ESCAPE VALVE above), still requires the file-based Method 1 token or a
#     fresh session -- there is no retry-after-denial shortcut (a denied
#     attempt is deliberately excluded from precedent, see PROVENANCE above).
# Shell-variable-driven target smuggling (e.g. `BR=x; git push origin "$BR"`
# with $BR differing between two invocations that share identical literal
# command text) is NOT detectable by static text analysis and is out of
# scope for this hook -- flagged, not solved.
# ROUND 2 (code-review-battery, 2026-07-12): the first pass at global-option
# tolerance (`git -C <dir> push ...`) was incomplete -- `-c k=v`, `--git-dir`,
# and `--work-tree` (both `=`-attached and space-separated forms) were still
# full RED-gate bypasses (is_red_action never matched, so no approval was
# required at all), and `git branch -f -D <name>` (any flag before the
# delete flag) bypassed both is_red_action and classify() the same way --
# confirmed live to actually delete a branch with zero approval check. Both
# are now fixed: the patterns file and GIT_GLOBAL_OPT_RE tolerate all four
# global-option forms, and the branch-delete check scans all tokens for a
# delete flag in any position rather than anchoring immediately after
# "branch". These two must be kept in lockstep (patterns file vs. this
# script) -- a new global option or flag added to one without the other
# reopens the same bypass class.
# KNOWN OPEN QUESTIONS (round 2, not resolved, not confirmed exploitable):
# the compound-command splitter (&&/||/;/|) is not shell-quote-aware, so a
# quoted argument containing one of those characters (e.g. `git push origin
# main -o "ci.skip; fast"`) mis-splits and the target collapses to
# AMBIGUOUS -- fail-safe (denies rather than falsely allows) but means such
# a push can never be recognized as a legitimate repeat of itself. Separately,
# if Claude Code fires PreToolUse for multiple Bash tool_use blocks in one
# batched assistant turn before any has a tool_result, each could
# independently see zero settled priors and independently qualify for the
# "first action" unscoped-approval path -- letting one approval phrase cover
# N different first-time targets in a single batch, not just one. Neither
# was confirmed exploitable against real Claude Code dispatch behavior;
# flagged for follow-up investigation rather than fixed blind.
# File-based tokens (Method 1, explicit Write-tool grant) are exempt from
# target-binding -- they are already single-use and category-scoped by
# construction; the reuse risk this closes is specific to the reusable,
# phrase-scanned transcript path. NOTE: Method 1's own gating (is anything
# outside this hook verifying the approval file's write was itself
# human-authorized?) is a separate, pre-existing architectural question
# (this hook is only ever invoked for Bash tool calls; the Write tool that
# creates the approval file is not currently gated at all) -- not
# introduced by R6, not fixed here, tracked as follow-up work.
#
# *** FOUNDATIONAL TRUST LIMITATION -- NOT FIXABLE FROM WITHIN THIS SCRIPT ***
# PROVENANCE (and, transitively, target-binding as a whole) verifies
# transcript-entry SHAPE, not AUTHENTICITY: it trusts that assistant
# tool_use / user tool_result JSONL lines were written by Claude Code's own
# tool-execution runtime, never by the same agent's own Bash tool writing
# directly to $TRANSCRIPT (an ordinary file under the user's home
# directory, not protected from the very process this hook exists to
# constrain). Two independent code-review-battery reviewers (Guardian,
# AttackerPersona, round 2, 2026-07-12) confirmed live that an agent can
# append a forged tool_use+tool_result pair claiming an arbitrary git push
# already succeeded, then have any later, genuine-but-unrelated human
# approval phrase bind against that forged "prior" instead of the real one.
# This is NOT specific to R6 or target-binding -- the PRE-EXISTING
# phrase-scan approval mechanism (Method 2, above) shares the identical
# trust assumption: an agent with the same transcript-write access could in
# principle forge a fake human "approve push" message just as easily,
# bypassing the need for genuine human approval entirely, with or without
# target-binding in the picture. Closing this would require either an
# out-of-band, non-agent-writable channel for authorization evidence (a
# platform-level Claude Code capability, not something a shell+python
# PreToolUse hook can construct on its own -- any shared secret or key this
# script could check, the same agent could also read, since this is a
# public repo file the agent itself can open), or abandoning
# transcript-content trust as this hook's authorization model entirely.
# Flagged prominently, not solved -- treat this hook as raising the bar
# against an autonomous-but-not-actively-adversarial agent (accidental
# scope creep, confused retries, stale approvals), not as a hard boundary
# against a deliberately self-subverting one.
#
# *** STRICT-DISABLE GATE -- separate category from push/release ***
# (llm-skill-review adversarial review, 2026-07-17, S0 finding)
# tools/promotion-strict-toggle.sh disable <branch> weakens dev/staging/
# main's required_status_checks.strict flag -- a production branch-
# protection control -- and previously had NO approval gate at all, unlike
# the git push/branch-delete actions above. AGENTS.md documents this as
# needing "its own fresh authorization, never bundled with the promotion
# approval itself". This is why STRICT_DISABLE_PATTERN and
# extract_strict_disable_approval_token() below are a fully separate check
# and approval-extraction path, never merged into is_red_action /
# extract_approval_token / the push/release categories: an agent that
# already has "promote to main" or "approve push" sitting in the 10-message
# lookback window -- which is extremely likely immediately before running
# the promotion-strict-behind-runbook, since that IS the promotion flow --
# would otherwise auto-satisfy a shared gate for free, defeating the entire
# point of gating it. `restore` (the safe, protection-RESTORING direction)
# and `status` are deliberately NOT matched -- only the weakening direction
# requires its own approval.
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
# Fail closed on malformed hook input -- without this, the first `jq` call
# below would itself fail under `set -euo pipefail` (a plain, non-`local`
# command-substitution assignment), aborting the whole script with jq's own
# exit code (5 for invalid JSON) instead of the documented 0/2 contract, and
# before is_red_action or any approval logic ever runs (code-review-battery
# round 2, 2026-07-12). Checking `type == "object"` alone is not sufficient:
# valid-but-wrong-shaped JSON (e.g. `.tool_input` as a scalar string instead
# of an object) passes a bare `jq -e '.'` check, but the very next line's
# `jq -r '.tool_input.command'` then errors with "Cannot index string with
# string" (jq exit 5) -- reproduced live, the exact same undocumented-exit-
# code failure this block exists to prevent (code-review-battery, 2026-07-17,
# Defect Finder). Also validates the specific sub-path this script indexes.
if ! jq -e 'type == "object" and ((.tool_input // {}) | type == "object")' <<<"$INPUT" >/dev/null 2>&1; then
  echo "BLOCKED: malformed PreToolUse hook input (invalid JSON shape) -- failing closed." >&2
  log 2 malformed-input
  exit 2
fi
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
  # `|| true`: under `set -o pipefail`, a non-existent search root makes `find`
  # exit non-zero even though `head -1` succeeds on empty input -- pipefail
  # propagates find's failure through the pipe, and `set -e` would then abort
  # the ENTIRE hook script (fail-open on whatever exit code that produces,
  # since it's neither the documented 0 nor 2) instead of just leaving
  # TRANSCRIPT empty, which the rest of the script already handles safely via
  # `[[ -f "$TRANSCRIPT" ]]` checks (code-review-battery, 2026-07-12).
  TRANSCRIPT="$(find "$HOME/.claude/projects/" -maxdepth 3 -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)" || true
fi

PATTERNS_FILE="${CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE:-$HOME/.config/claude-hooks/red-autonomy-patterns.txt}"

# Portable command normalizer, called exactly once (see NORMALIZED_CMD
# below) and shared by is_red_action() and is_strict_disable_action() so
# newline/backslash-continuation handling never drifts between the two
# gates. Prints the normalized command on success; on any python3 failure
# prints nothing and returns non-zero -- the caller falls back to the raw
# command, never trusts empty output as "nothing to normalize".
normalize_cmd() {
  python3 - "$1" <<'PYEOF' 2>/dev/null
import sys, re
s = sys.argv[1]
s = re.sub(r"\\\n", " ", s)
s = s.replace("\n", " ")
sys.stdout.write(s)
PYEOF
}

# Check if command matches any RED pattern. Takes the ALREADY-NORMALIZED
# command (see NORMALIZED_CMD below) -- normalization happens exactly once,
# shared with is_strict_disable_action, not per-function.
is_red_action() {
  local normalized="$1"
  [[ -s "$PATTERNS_FILE" ]] || return 1
  local TMP_PAT rc=0
  TMP_PAT="$(mktemp)"
  grep -v '^\s*#' "$PATTERNS_FILE" | grep -v '^\s*$' > "$TMP_PAT" || true
  if [[ ! -s "$TMP_PAT" ]]; then
    rm -f "$TMP_PAT"
    return 1
  fi
  printf '%s' "$normalized" | grep -qE -f "$TMP_PAT" 2>/dev/null || rc=$?
  rm -f "$TMP_PAT"
  # rc=2 means grep encountered an error (e.g., malformed pattern in file).
  # Fail closed: treat as a RED action so the approval gate fires rather than
  # silently allowing an unblocked push due to a broken patterns file.
  [[ $rc -eq 2 ]] && return 0
  return $rc
}

# Matches (a) the promotion-strict-toggle.sh wrapper's `disable` subcommand,
# under any invocation prefix (bash/relative/absolute path), and (b) ANY `gh
# api` invocation that references the required_status_checks REST endpoint
# or the requiresStrictStatusChecks GraphQL field, regardless of how the
# boolean payload is encoded. Deliberately does NOT try to also match
# `strict=false`/`strict:false` as a co-requirement -- an earlier version
# did, and code-review-battery (2026-07-17) confirmed live that trivial,
# non-adversarial syntax variance evades a value-anchored match: a quoted
# value (`-F strict='false'`), `--input`/stdin JSON-body indirection (the
# boolean never appears as literal text next to `required_status_checks` at
# all), and the GraphQL field name `requiresStrictStatusChecks` (no `=`, no
# `required_status_checks` substring) each independently bypassed it with
# ZERO gate of any kind (logged as plain `not-red`). Matching on `gh api` +
# endpoint/field-name alone trades a rare false positive (an ad-hoc,
# hand-typed READ of this endpoint via raw `gh api` -- already discouraged
# by the runbook in favor of the wrapper's `status` subcommand) for zero
# false negatives on the actual weakening action. See the STRICT-DISABLE
# GATE header comment above for why this is kept out of the shared patterns
# file / is_red_action entirely.
readonly STRICT_DISABLE_PATTERN='(^|[^A-Za-z0-9_])(bash[[:space:]]+)?([./A-Za-z0-9_-]*/)?promotion-strict-toggle\.sh[[:space:]]+disable([[:space:]]|$)|(^|[^A-Za-z0-9_])gh[[:space:]]+api[[:space:]]+.*(required_status_checks|requiresStrictStatusChecks)'

is_strict_disable_action() {
  local normalized="$1"
  printf '%s' "$normalized" | grep -qE "$STRICT_DISABLE_PATTERN"
}

# Normalize once, shared by both checks below -- performance-analyst review
# (2026-07-17) found this hook forking a python3 process TWICE per Bash tool
# call (once inside each check, on byte-identical input) even for ordinary,
# non-RED commands like `ls`, roughly doubling this hot-path hook's latency
# for zero benefit. Grep matches per physical line by default, so a
# multi-line command is invisible to every pattern below even though the
# BLOCKED message elsewhere already flattens newlines for display
# (code-review-battery round 2, 2026-07-12: confirmed a full RED-gate bypass
# for every category, not just push). A plain `tr '\n' ' '` is not
# sufficient: bash line-continuation (`git \` + newline + `  push origin x`,
# an ordinary idiom bash executes identically to the single-line form)
# leaves a literal backslash character between "git" and "push", still
# breaking the match -- the backslash-newline PAIR must be removed as bash
# itself removes it, not just the newline.
NORMALIZED_CMD="$(normalize_cmd "$CMD")" || {
  NORMALIZED_CMD="$CMD"
  # Falls back to the raw (unnormalized) command -- no worse than the
  # pre-fix behavior for is_red_action, not a new gap there, but now made
  # VISIBLE (guardian review, 2026-07-17: this hook silently degraded
  # multi-line RED-action detection with zero warning, inconsistent with the
  # same-diff fix that added an explicit warning for the identical
  # missing-python3 condition in public-repo-ip-check.sh/commit-msg).
  echo "WARNING: python3 unavailable -- RED/strict-disable detection degraded to single-physical-line matching only (a multi-line or backslash-continued command may not be recognized)." >&2
}

IS_RED=0
if is_red_action "$NORMALIZED_CMD"; then IS_RED=1; fi
IS_STRICT_DISABLE=0
if is_strict_disable_action "$NORMALIZED_CMD"; then IS_STRICT_DISABLE=1; fi

if [[ "$IS_RED" == "0" && "$IS_STRICT_DISABLE" == "0" ]]; then
  log 0 not-red
  exit 0
fi

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

# Handle the strict-disable category fully here, independent of the generic
# push/release flow below, but only exit early when this command has NO
# other RED content -- see the STRICT-DISABLE GATE header comment for why
# these must never share an approval phrase/category (falling through on
# DENY would let a stale "approve push"/"promote to main" silently
# re-authorize this too). On the ALLOW path, though, unconditionally exiting
# here was itself a Critical bypass: is_strict_disable_action/is_red_action
# each match anywhere in the (possibly compound) command string
# independently, so a bundled command like `git push origin
# unapproved-target && tools/promotion-strict-toggle.sh disable main`
# matched BOTH categories, and exiting 0 here the moment strict-disable
# approval was satisfied let the bundled, unapproved, non-target-bound push
# ride along for free -- confirmed live-exploitable by three independent
# code-review-battery reviewers (2026-07-17: Defect Finder, Guardian,
# AttackerPersona), each reproducing it with only a strict-disable token/
# phrase present and zero push/release approval anywhere. Fix: when this
# command is ALSO classified as generic RED (IS_RED==1), strict-disable
# approval only clears ITS OWN portion -- fall through to the existing,
# already-hardened push/branch-delete gate (extract_approval_token +
# check_target_binding) below, which independently requires its own
# approval and correctly reasons about the compound command via its own
# SEPARATOR_RE splitting. This never weakens anything: it only ADDS a
# required gate to commands that used to skip it entirely.
if [[ "$IS_STRICT_DISABLE" == "1" ]]; then
  STRICT_DISABLE_APPROVAL_FILE="$SESSION_ENV_DIR/${SESSION_ID}.strict-disable-approval"

  extract_strict_disable_approval_token() {
    # Method 1: explicit approval file written by Claude via Write tool.
    if [[ -f "$STRICT_DISABLE_APPROVAL_FILE" ]]; then
      local token_text
      token_text="$(tr -cd '[:lower:]-' < "$STRICT_DISABLE_APPROVAL_FILE" | head -c 20)"
      if [[ "$token_text" == "strict-disable" ]]; then
        echo "strict-disable"
        return 0
      fi
    fi

    # Method 2: scan the last 10 non-empty user messages (most recent first)
    # for a dedicated strict-disable approval/revoke phrase. Deliberately
    # does NOT reuse extract_approval_token's push/release phrase list.
    [[ -f "$TRANSCRIPT" ]] || return 0
    python3 - "$TRANSCRIPT" <<'EOF' || true
import sys, json, re

APPROVAL_PHRASES = [
    r'\bapprove\s+strict[\s-]?disable\b',
    r'\bstrict[\s-]?disable\s+approved\b',
    r'\byou\s+may\s+disable\s+strict\b',
]
REVOKE_PHRASES = [
    r'\brevoke\s+strict[\s-]?disable\b',
    r'\bcancel\s+strict[\s-]?disable\b',
    r'\bdo\s+not\s+disable\s+strict\b',
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
            print("strict-disable")
            sys.exit(0)

sys.exit(0)
EOF
  }

  STRICT_DISABLE_TOKEN="$(extract_strict_disable_approval_token)"
  if [[ "$STRICT_DISABLE_TOKEN" != "strict-disable" ]]; then
    {
      echo "BLOCKED: RED action (strict-disable) without explicit approval in current session."
      echo "  command: $(printf '%s' "$CMD" | tr '\n' ' ')"
      echo "  This weakens branch protection on dev/staging/main and requires its OWN approval -- a prior 'approve push' or 'promote to main' does NOT satisfy this gate by design (AGENTS.md: never bundled with the promotion approval itself)."
      echo "  Say 'approve strict-disable' to authorize this action."
    } >&2
    log 2 no-approval-strict-disable
    exit 2
  fi

  # Single-use, mirroring file-based Method 1 tokens for push/release.
  if [[ -f "$STRICT_DISABLE_APPROVAL_FILE" ]]; then
    STRICT_DISABLE_TOKEN_HASH="$(printf '%s:strict-disable' "$SESSION_ID" | _sha256)"
    if [[ -f "$CONSUMED_FILE" ]] && grep -qF "$STRICT_DISABLE_TOKEN_HASH" "$CONSUMED_FILE" 2>/dev/null; then
      {
        echo "BLOCKED: RED action (strict-disable) approval token already consumed in this session."
        echo "  command: $(printf '%s' "$CMD" | tr '\n' ' ')"
        echo "  Request a new approval."
      } >&2
      log 2 token-consumed-strict-disable
      exit 2
    fi
    echo "$STRICT_DISABLE_TOKEN_HASH" >> "$CONSUMED_FILE"
    rm -f "$STRICT_DISABLE_APPROVAL_FILE" 2>/dev/null || true
  fi

  log 0 "approved-strict-disable"
  # Only safe to exit here if this command has no OTHER RED content -- see
  # the block comment above. If IS_RED is also 1 (a compound command bundling
  # a git push/branch-delete alongside the strict-disable trigger), fall
  # through to the generic RED flow below, which independently requires its
  # own approval for that portion.
  if [[ "$IS_RED" == "0" ]]; then
    exit 0
  fi
fi

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
  # `|| true`: under `set -e`, a non-`local` `VAR="$(fn)"` assignment at the
  # call site propagates this function's own exit status -- an uncaught
  # Python exception here (exit 1, not the printed-and-captured "allow"/
  # category text) would otherwise abort the WHOLE hook script with an
  # undocumented, likely fail-open exit code instead of just producing no
  # output, which the caller's case-statement already treats as "no
  # approval found" (code-review-battery, 2026-07-12).
  python3 - "$TRANSCRIPT" <<'EOF' || true
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
            # ("ship" was never added to APPROVAL_PHRASES -- see header
            # comment on why "ship it" was rejected -- so checking for it
            # here was dead code; removed, code-review-battery 2026-07-17.)
            if "push" in phrase or "promote" in phrase:
                print("push:tr")
            else:
                print("release:tr")
            sys.exit(0)

sys.exit(0)
EOF
}

# check_target_binding: for git push / git branch -D commands only (other RED
# categories -- TODO.md writes, etc. -- have no "ref" concept, so they skip
# this and fall through to the phrase-only gate unchanged). Prints "allow" or
# "deny". See the TARGET-BINDING header comment above for the full rationale.
check_target_binding() {
  [[ -f "$TRANSCRIPT" ]] || { echo "allow"; return; }
  # `|| echo "deny"`: an uncaught exception in this script (malformed
  # transcript content, unexpected shape) must fail CLOSED -- print an
  # explicit "deny" rather than relying on empty stdout happening to not
  # equal "allow" (code-review-battery, 2026-07-12: the implicit version of
  # this contract was real but undocumented and untested).
  python3 - "$TRANSCRIPT" "$CMD" <<'EOF2' || echo "deny"
import sys, json, re

transcript_path, current_cmd = sys.argv[1], sys.argv[2]

AMBIGUOUS = '@AMBIGUOUS@'
FORCE_RE = re.compile(r'--force(-with-lease(=\S+)?)?\b|(?<![\w-])-f(?![\w-])')
DELETE_FLAG_RE = re.compile(r'(?<![\w-])-d(?![\w-])')
SEPARATOR_RE = re.compile(r'&&|\|\||[;|]')
# Tolerates common global options between "git" and the subcommand
# (git -C <dir> push ..., git -c k=v push ..., git --git-dir=... push ...,
# git --work-tree=... push ...) so this classifier doesn't diverge from what
# is_red_action's broader pattern already flags as RED. Round 2 fix
# (code-review-battery, 2026-07-12): the original version only handled -C
# and the space-separated forms of --git-dir/--work-tree -- -c and the
# =-attached forms of --git-dir/--work-tree were confirmed live-exploitable
# full bypasses (classify() returned None, so check_target_binding printed
# "allow" unconditionally) until the patterns file was ALSO fixed to match;
# this regex must stay in lockstep with claude-config/red-autonomy-patterns.txt.
GIT_GLOBAL_OPT_RE = re.compile(
    r'\bgit\s+(?:'
    r'-C\s+\S+\s+'
    r'|-c\s+\S+=\S+\s+'
    r'|--git-dir=\S+\s+'
    r'|--git-dir\s+\S+\s+'
    r'|--work-tree=\S+\s+'
    r'|--work-tree\s+\S+\s+'
    r')+'
)

def _classify_single(cmd):
    # Returns (target, severity) for ONE recognized git push / branch-delete
    # command (no shell separators), or None if not a ref-based command.
    # severity: 1=plain push, 2=force push, 3=branch delete. target is
    # either a literal "remote/ref" (or bare local branch name for
    # `branch -D`) string, or the AMBIGUOUS sentinel for any form that
    # can't be safely bound to a specific, stable ref (see header comment).
    cmd = GIT_GLOBAL_OPT_RE.sub('git ', cmd)
    m = re.search(r'\bgit\s+push\b(.*)', cmd)
    if m:
        rest = m.group(1)
        tokens = [t for t in rest.split() if t]
        has_plus_refspec = any(t.startswith('+') and len(t) > 1 for t in tokens)
        severity = 2 if (FORCE_RE.search(rest) or has_plus_refspec) else 1
        non_flag = [t for t in tokens if not t.startswith('-') and not (t.startswith('+') and len(t) > 1)]
        if '--delete' in tokens or DELETE_FLAG_RE.search(rest):
            severity = 3
            target = '/'.join(non_flag) if len(non_flag) == 2 else AMBIGUOUS
        else:
            colon_tok = next((t for t in non_flag if ':' in t), None)
            if colon_tok:
                other = [t for t in non_flag if t != colon_tok]
                remote = other[0] if len(other) == 1 else AMBIGUOUS
                src, _, dst = colon_tok.partition(':')
                if src == '':
                    severity = 3
                    ref = dst if dst else AMBIGUOUS
                else:
                    ref = dst if dst else src
                target = AMBIGUOUS if AMBIGUOUS in (remote, ref) else f"{remote}/{ref}"
            elif len(non_flag) == 2:
                target = f"{non_flag[0]}/{non_flag[1]}"
            else:
                target = AMBIGUOUS
        if target != AMBIGUOUS and target.endswith('/HEAD'):
            target = AMBIGUOUS
        return (target, severity)
    m2 = re.search(r'\bgit\s+branch\b(.*)', cmd)
    if m2:
        # Scan all tokens for a delete flag in ANY position, not just
        # immediately after "branch" -- "git branch -f -D branch-a" bypassed
        # a position-anchored regex entirely (confirmed live-exploitable,
        # code-review-battery round 2, 2026-07-12: real git accepts and
        # executes this, deleting the branch, with zero approval check).
        tokens2 = [t for t in m2.group(1).split() if t]
        if not any(t in ('-D', '-d', '--delete') for t in tokens2):
            return None  # `git branch` without a delete flag isn't RED (list/create/rename)
        non_flag2 = [t for t in tokens2 if not t.startswith('-')]
        target = non_flag2[0] if len(non_flag2) == 1 else AMBIGUOUS
        return (target, 3)
    return None

def classify(cmd):
    # Whitespace-normalized first so multi-line/backslash-continued commands
    # classify identically to their single-line equivalent (the regexes
    # above are not DOTALL and would otherwise stop at the first newline).
    cmd = ' '.join(cmd.split())
    segments = [s.strip() for s in SEPARATOR_RE.split(cmd) if s.strip()]
    if len(segments) <= 1:
        return _classify_single(cmd)
    # Compound command (&&, ||, ;, |): classify every segment. If more than
    # one distinct target appears, or any segment is itself ambiguous, a
    # single-target comparison can no longer safely describe "the" target
    # of this whole command -- treat it as AMBIGUOUS rather than silently
    # comparing against only the first git-push/branch-delete match and
    # letting any additional, smuggled git command ride along unchecked.
    results = [r for r in (_classify_single(s) for s in segments) if r is not None]
    if not results:
        return None
    distinct = {t for t, _ in results if t != AMBIGUOUS}
    max_sev = max(sev for _, sev in results)
    if len(distinct) != 1 or any(t == AMBIGUOUS for t, _ in results):
        return (AMBIGUOUS, max_sev)
    return (next(iter(distinct)), max_sev)

current = classify(current_cmd)
if current is None:
    print("allow")  # not a ref-based git command -- no target to bind against
    sys.exit(0)
current_target, current_severity = current

def _content_list(x):
    return x if isinstance(x, list) else []

def _assistant_content(obj):
    # Two shapes, mirroring the user-message shapes handled in Method 2
    # above: legacy {"role":"assistant","content":...} and current
    # {"type":"assistant","message":{"role":"assistant","content":...}}.
    if obj.get("role") == "assistant":
        return obj.get("content")
    if obj.get("type") == "assistant":
        msg = obj.get("message", {})
        if isinstance(msg, dict) and msg.get("role") == "assistant":
            return msg.get("content")
    return None

def _user_content(obj):
    if obj.get("role") == "user":
        return obj.get("content")
    if obj.get("type") == "user":
        msg = obj.get("message", {})
        if isinstance(msg, dict) and msg.get("role") == "user":
            return msg.get("content")
    return None

def _extract_text(raw):
    if isinstance(raw, list):
        return " ".join(p.get("text", "") for p in raw if isinstance(p, dict))
    return raw if isinstance(raw, str) else ""

def _tool_use_blocks(content):
    out = []
    for p in _content_list(content):
        if isinstance(p, dict) and p.get("type") == "tool_use" and p.get("name") == "Bash":
            inp = p.get("input")
            c = inp.get("command") if isinstance(inp, dict) else None
            tid = p.get("id")
            if isinstance(c, str) and isinstance(tid, str):
                out.append((tid, c))
    return out

def _tool_result_blocks(content):
    out = []
    for p in _content_list(content):
        if isinstance(p, dict) and p.get("type") == "tool_result":
            tid = p.get("tool_use_id")
            text = _extract_text(p.get("content"))
            if isinstance(tid, str):
                out.append((tid, "BLOCKED: RED action" in text))
    return out

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

def _user_texts(path):
    # Re-scan for the named-target escape valve below. Mirrors Method 2's
    # own phrase-matching scan (extract_approval_token, a separate python
    # invocation with no shared state) rather than a shared helper --
    # tracked as follow-up factoring, see header comment.
    texts = []
    with open(path, encoding='utf-8', errors='replace') as f2:
        for line2 in f2:
            line2 = line2.strip()
            if not line2:
                continue
            try:
                obj2 = json.loads(line2)
            except json.JSONDecodeError:
                continue
            uc = _user_content(obj2)
            if uc is not None:
                t = _extract_text(uc)
                if t.strip():
                    texts.append(t)
    return texts

def _named_target_escape_valve(path, target):
    # Narrow fallback, consulted ONLY when target-binding would otherwise
    # deny: does the human's own approval message ALSO name the literal ref
    # this specific command already targets (never a ref guessed from
    # prose -- the ref always comes from tool_input.command, never from
    # text)? Lets a human explicitly re-approve a genuinely new target
    # ("approve push to branch-b") without reopening the rejected "extract
    # any ref from anywhere in prose" design from earlier debate rounds --
    # this only ever widens a deny into an allow for the EXACT current
    # target, only within the same message as the approval phrase itself,
    # and only in the already-would-deny path (never makes an otherwise-
    # allowed action stricter). Residual risk: a short/common branch name
    # (e.g. "main") could coincidentally appear as an ordinary word in the
    # same message as an approval phrase without the human intending to
    # name that specific target -- bounded by requiring BOTH the exact
    # target string AND an approval phrase in the same message, not just
    # proximity anywhere in the 10-message window.
    if target == AMBIGUOUS:
        return False
    candidates = {target}
    if '/' in target:
        candidates.add(target.split('/', 1)[1])
    ref_patterns = [re.compile(r'(?<![\w-])' + re.escape(c) + r'(?![\w-])') for c in candidates]
    for msg in reversed(_user_texts(path)[-10:]):
        msg_lower = msg.lower()
        if any(re.search(p, msg_lower) for p in REVOKE_PHRASES):
            return False  # a more recent revoke invalidates any earlier match
        if any(re.search(p, msg_lower) for p in APPROVAL_PHRASES) and any(pat.search(msg) for pat in ref_patterns):
            return True
    return False

# A prior RED tool_use only counts as binding precedent once we know it was
# actually ALLOWED (see PROVENANCE in the header comment): a tool_use with
# no corresponding tool_result yet is unresolved -- this reliably describes
# THIS invocation's own just-emitted tool_use and any not-yet-executed
# sibling in the same batched assistant turn -- and is excluded; a
# tool_result whose content contains this same hook's own "BLOCKED: RED
# action" text means that attempt was DENIED, never executed, and is also
# excluded.
ordered = []
resolved_ids = set()
denied_ids = set()

with open(transcript_path, encoding='utf-8', errors='replace') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        a_content = _assistant_content(obj)
        if a_content is not None:
            for tid, c in _tool_use_blocks(a_content):
                if classify(c) is not None:
                    ordered.append((tid, c))
            continue
        u_content = _user_content(obj)
        if u_content is not None:
            for tid, denied in _tool_result_blocks(u_content):
                resolved_ids.add(tid)
                if denied:
                    denied_ids.add(tid)

prior_cmds = [c for tid, c in ordered if tid in resolved_ids and tid not in denied_ids]

if not prior_cmds:
    print("allow")  # no settled, allowed, prior ref-based RED action this session
    sys.exit(0)

prior_target, prior_severity = classify(prior_cmds[-1])
if (current_target != AMBIGUOUS and prior_target != AMBIGUOUS
        and current_target == prior_target and current_severity <= prior_severity):
    print("allow")
elif _named_target_escape_valve(transcript_path, current_target):
    print("allow")
else:
    print("deny")
EOF2
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

# Target-binding (R6): only for the reusable, phrase-scanned transcript
# path -- file-based tokens (Method 1) are already single-use and explicit.
if [[ "$TOKEN_SOURCE" == "transcript" ]]; then
  BINDING_VERDICT="$(check_target_binding)"
  if [[ "$BINDING_VERDICT" != "allow" ]]; then
    {
      echo "BLOCKED: RED action approval does not match this command's target/severity."
      echo "  command: $(printf '%s' "$CMD" | tr '\n' ' ')"
      echo "  A prior git push/branch-delete this session targeted a different ref, this action escalates severity (push -> force-push -> delete) beyond what was approved, or the target could not be resolved unambiguously. Repeating the same approval phrase will NOT authorize this -- a denied attempt is never treated as its own precedent. Use the explicit file-based approval token for a new target, or start a fresh session."
    } >&2
    log 2 target-mismatch
    exit 2
  fi
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
