#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: setup/install-claude-guardrails.sh
# PURPOSE: Install Claude Code lifecycle hooks (items 1-10) and merge the
#          hooks block into ~/.claude/settings.json. Standalone installer —
#          not sourced. Invoked by install.sh main() after install_skills.
#
# USAGE:
#   bash setup/install-claude-guardrails.sh           # install
#   bash setup/install-claude-guardrails.sh --check   # dry-run / verify only
#   bash setup/install-claude-guardrails.sh --help
#
# KILL SWITCH: Set SUPERPOWERS_CLAUDE_GUARDRAILS=0 to exit without writing
#   anything to ~/.claude/ (bake-period default, see PR-0 .env.example).
#
# EXIT: 0 = success or kill-switch; 1 = hard error
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P 2>/dev/null)" || REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_SRC="$REPO_ROOT/tools/claude-hooks"
CLAUDE_HOOKS_DIR="$HOME/.claude/hooks"
CLAUDE_CONFIG_DIR="$HOME/.config/claude-hooks"
SETTINGS_JSON="$HOME/.claude/settings.json"
SPEC_JSON="$REPO_ROOT/claude-config/settings-hooks-spec.json"
LOG_PREFIX="[install-claude-guardrails]"
CHECK_ONLY=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log_info()  { echo "$LOG_PREFIX $*"; }
log_warn()  { echo "$LOG_PREFIX WARN: $*" >&2; }
log_error() { echo "$LOG_PREFIX ERROR: $*" >&2; }

# ---------------------------------------------------------------------------
# --help / --check
# ---------------------------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --help|-h)
      cat <<'HELP'
install-claude-guardrails.sh — install Claude Code hooks from superpowers-plus

USAGE
  bash setup/install-claude-guardrails.sh          # install/upgrade
  bash setup/install-claude-guardrails.sh --check  # verify installed state only
  bash setup/install-claude-guardrails.sh --help   # this help

KILL SWITCH
  SUPERPOWERS_CLAUDE_GUARDRAILS=0 bash setup/install-claude-guardrails.sh
    → exits 0 without writing anything (default during bake period)

ENV VARS (all optional)
  SUPERPOWERS_CLAUDE_GUARDRAILS  0=skip (default), 1=install
  CLAUDE_HOOKS_BYPASS            1=skip all hooks for one invocation (runtime)
HELP
      exit 0
      ;;
    --check) CHECK_ONLY=1 ;;
  esac
done

# ---------------------------------------------------------------------------
# P3 kill switch (default 0 = OFF during bake period)
# ---------------------------------------------------------------------------
_kill_switch_check() {
  if [[ "${SUPERPOWERS_CLAUDE_GUARDRAILS:-0}" == "0" ]]; then
    log_info "Kill switch ON (SUPERPOWERS_CLAUDE_GUARDRAILS=0). Skipping install."
    log_info "To enable: SUPERPOWERS_CLAUDE_GUARDRAILS=1 bash $0"
    exit 0
  fi
}

# ---------------------------------------------------------------------------
# Bypass clause gate — every shipped hook must declare the escape hatch
# ---------------------------------------------------------------------------
_verify_bypass_clause() {
  local h missing=0
  for h in "$HOOKS_SRC"/*.sh; do
    [[ -f "$h" ]] || continue
    if ! grep -q 'CLAUDE_HOOKS_BYPASS' "$h"; then
      log_error "Hook missing bypass clause: $h"
      missing=1
    fi
  done
  [[ $missing -eq 0 ]] || { log_error "Fix hooks above, then re-run."; exit 1; }
}

# ---------------------------------------------------------------------------
# CLI version detect (floor 2.1.116)
# ---------------------------------------------------------------------------
SKIP_SETTINGS_MERGE=0
_check_cli_version() {
  local claude_bin floor ver
  claude_bin="$(command -v claude || true)"
  floor="2.1.116"
  if [[ -z "$claude_bin" ]]; then
    log_warn "claude CLI not found — installing hook scripts only (skipping settings.json merge)"
    SKIP_SETTINGS_MERGE=1; return 0
  fi
  ver="$("$claude_bin" --version 2>/dev/null | grep -oE '[0-9]+([.][0-9]+){2}' | head -1 || true)"
  if [[ -z "$ver" ]]; then
    log_warn "Could not parse claude --version — skipping settings.json merge"
    SKIP_SETTINGS_MERGE=1; return 0
  fi
  if [[ "$(printf '%s\n%s\n' "$floor" "$ver" | sort -V | head -1)" != "$floor" ]]; then
    log_warn "Claude Code CLI v$ver < $floor (hooks unverified) — skipping settings.json merge"
    SKIP_SETTINGS_MERGE=1
  fi
}

# ---------------------------------------------------------------------------
# Copy hook scripts
# ---------------------------------------------------------------------------
_install_hook_scripts() {
  local h count=0
  mkdir -p "$CLAUDE_HOOKS_DIR"
  for h in "$HOOKS_SRC"/*.sh; do
    [[ -f "$h" ]] || continue
    install -m 0755 "$h" "$CLAUDE_HOOKS_DIR/$(basename "$h")"
    count=$((count + 1))
  done
  log_info "Hooks installed: $count script(s) → $CLAUDE_HOOKS_DIR"
}

# ---------------------------------------------------------------------------
# Copy pattern files (preserve user edits if file differs from template)
# ---------------------------------------------------------------------------
_install_patterns() {
  local src dest
  mkdir -p "$CLAUDE_CONFIG_DIR"
  for src in "$REPO_ROOT/claude-config"/*.txt; do
    [[ -f "$src" ]] || continue
    dest="$CLAUDE_CONFIG_DIR/$(basename "$src")"
    if [[ -f "$dest" ]] && ! diff -q "$src" "$dest" >/dev/null 2>&1; then
      log_warn "$(basename "$dest") differs from template — keeping existing; template at $src"
    else
      install -m 0644 "$src" "$dest"
    fi
  done
}

# ---------------------------------------------------------------------------
# Idempotent merge of hooks block into ~/.claude/settings.json
# ---------------------------------------------------------------------------
_merge_settings() {
  [[ $SKIP_SETTINGS_MERGE -eq 1 ]] && { log_warn "Skipping settings.json merge (see above)."; return 0; }
  [[ -f "$SPEC_JSON" ]] || { log_warn "settings-hooks-spec.json not found — skipping merge"; return 0; }
  mkdir -p "$HOME/.claude/backups"
  [[ -f "$SETTINGS_JSON" ]] || echo '{}' > "$SETTINGS_JSON"
  cp "$SETTINGS_JSON" "$HOME/.claude/backups/settings.json.$(date -u +%Y%m%dT%H%M%SZ)"
  python3 - "$SETTINGS_JSON" "$SPEC_JSON" <<'PY' || { log_error "settings.json merge failed"; return 1; }
import json, sys, os
target_path, spec_path = sys.argv[1], sys.argv[2]
with open(target_path) as f: target = json.load(f)
with open(spec_path)   as f: spec   = json.load(f)
target.setdefault('hooks', {})
for event, want_blocks in spec.get('hooks', {}).items():
    have_blocks = target['hooks'].setdefault(event, [])
    for w in want_blocks:
        match = next((b for b in have_blocks if b.get('matcher') == w.get('matcher')), None)
        if match is None:
            have_blocks.append(w)
            continue
        existing_cmds = {h.get('command') for h in match.get('hooks', [])}
        for h in w.get('hooks', []):
            if h.get('command') not in existing_cmds:
                match.setdefault('hooks', []).append(h)
# Merge non-hooks scalar settings from spec.
# Numeric: take max (never lower a value the user has raised).
# Other types: setdefault (don't overwrite user's existing value).
for key, val in spec.items():
    if key.startswith('_') or key == 'hooks':
        continue
    if isinstance(val, (int, float)) and isinstance(target.get(key), (int, float)):
        target[key] = max(target[key], val)
    else:
        target.setdefault(key, val)
tmp = target_path + '.tmp'
with open(tmp, 'w') as f: json.dump(target, f, indent=2, sort_keys=True)
os.replace(tmp, target_path)
print(f"merged: events={len(target.get('hooks', {}))}", flush=True)
PY
  python3 -c "import json; json.load(open('$SETTINGS_JSON'))" \
    || { log_error "settings.json is invalid JSON after merge"; return 1; }
  log_info "settings.json merged (hooks events: $(python3 -c "import json; d=json.load(open('$SETTINGS_JSON')); print(len(d.get('hooks', {})))"))"
}

# ---------------------------------------------------------------------------
# Verify installed state
# ---------------------------------------------------------------------------
_check_state() {
  local ok=0
  log_info "--- Check mode ---"
  if [[ -d "$CLAUDE_HOOKS_DIR" ]]; then log_info "Hooks dir: OK"; else log_warn "Hooks dir missing: $CLAUDE_HOOKS_DIR"; ok=1; fi
  if [[ -d "$CLAUDE_CONFIG_DIR" ]]; then log_info "Config dir: OK"; else log_warn "Config dir missing: $CLAUDE_CONFIG_DIR"; ok=1; fi
  if [[ -f "$SETTINGS_JSON" ]]; then log_info "settings.json: OK"; else log_warn "settings.json missing"; ok=1; fi
  return $ok
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  [[ $CHECK_ONLY -eq 1 ]] && { _check_state; exit $?; }
  _kill_switch_check
  _verify_bypass_clause
  _check_cli_version
  _install_hook_scripts
  _install_patterns
  _merge_settings
  log_info "Done. Run with --check to verify installed state."
}

main "$@"
