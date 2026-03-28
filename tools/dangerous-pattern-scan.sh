#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: dangerous-pattern-scan.sh
# PURPOSE: Scan staged shell scripts for dangerous patterns before commit.
#          Part of the pre-commit-gate skill family.
# USAGE:   ./dangerous-pattern-scan.sh [--all]
#          Default: scans only staged .sh files (git diff --cached)
#          --all:   scans all .sh files in the repo
# EXIT:    0 = clean, 1 = dangerous patterns found
# VERSION: 1.0.0
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Bash Guard ---
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. Run with: bash $0" >&2
    exit 1
fi

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat << 'HELP'
dangerous-pattern-scan.sh — Scan shell scripts for dangerous patterns

USAGE
  ./tools/dangerous-pattern-scan.sh [--all]

OPTIONS
  --all    Scan all .sh files in the repo (default: staged files only)
  --help   Show this help message

DESCRIPTION
  Scans for destructive commands (rm -rf ~/, force pushes, etc.) in staged
  shell scripts as a pre-commit safety gate. Exit 0 = clean, 1 = found.
HELP
  exit 0
fi

MODE="staged"
[[ "${1:-}" == "--all" ]] && MODE="all"

# --- Collect files to scan ---
declare -a FILES=()
if [[ "$MODE" == "staged" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && FILES+=("$f")
  done < <(git diff --cached --name-only --diff-filter=ACM -- '*.sh' 2>/dev/null)
else
  while IFS= read -r f; do
    [[ -n "$f" ]] && FILES+=("$f")
  done < <(find . -name "*.sh" -not -path './.git/*' -type f 2>/dev/null)
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "[dangerous-pattern-scan] No .sh files to scan."
  exit 0
fi

echo "[dangerous-pattern-scan] Scanning ${#FILES[@]} file(s)..."

FOUND=0
WARNINGS=0

# --- Pattern functions ---

check_unguarded_rm_rf() {
  local file="$1"
  local line_num=0
  local in_heredoc=""
  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Track heredoc boundaries
    if [[ -n "$in_heredoc" ]]; then
      [[ "$line" =~ ^${in_heredoc}[[:space:]]*$ ]] && in_heredoc=""
      continue
    fi
    if echo "$line" | grep -qE '<<[-]?\s*'\''?([A-Z_]+)'\''?'; then
      in_heredoc=$(echo "$line" | sed -E "s/.*<<-?\s*'?([A-Z_]+)'?.*/\1/")
      continue
    fi

    # Skip comments and documentation
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*echo ]] && continue
    [[ "$line" =~ ^[[:space:]]*printf ]] && continue

    # Match rm -rf or rm -fr (with any flag combos)
    if echo "$line" | grep -qE 'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)'; then
      # Check if ALL variables use :? guard
      if echo "$line" | grep -qE '\$[A-Za-z_]' && ! echo "$line" | grep -qE '\$\{[A-Za-z_]+:\?'; then
        # Has a variable but no :? guard — check if it's a hardcoded safe path
        if echo "$line" | grep -qE 'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)\s+~/'; then
          # Hardcoded ~ path like rm -rf ~/.codex/something — warn but don't block
          echo "  ⚠️  $file:$line_num: rm -rf with hardcoded ~ path (review manually)"
          echo "      $line"
          WARNINGS=$((WARNINGS + 1))
          continue
        fi
        echo "  ❌ $file:$line_num: UNGUARDED rm -rf with variable expansion"
        echo "      $line"
        echo "      FIX: Use \${VAR:?} instead of \$VAR to prevent empty-variable disasters"
        FOUND=$((FOUND + 1))
      fi
    fi
  done < "$file"
}

check_dangerous_commands() {
  local file="$1"
  local line_num=0
  local in_heredoc=""
  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Track heredoc boundaries
    if [[ -n "$in_heredoc" ]]; then
      [[ "$line" =~ ^${in_heredoc}[[:space:]]*$ ]] && in_heredoc=""
      continue
    fi
    if echo "$line" | grep -qE '<<[-]?\s*'\''?([A-Z_]+)'\''?'; then
      in_heredoc=$(echo "$line" | sed -E "s/.*<<-?\s*'?([A-Z_]+)'?.*/\1/")
      continue
    fi

    # Skip comments
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*echo ]] && continue
    [[ "$line" =~ ^[[:space:]]*printf ]] && continue

    # chmod 777
    if echo "$line" | grep -qE 'chmod\s+777'; then
      echo "  ❌ $file:$line_num: chmod 777 (world-writable)"
      echo "      $line"
      FOUND=$((FOUND + 1))
    fi

    # curl/wget piped to shell
    if echo "$line" | grep -qE '(curl|wget)\s.*\|\s*(bash|sh|zsh)'; then
      echo "  ❌ $file:$line_num: Piping download to shell (curl|bash)"
      echo "      $line"
      FOUND=$((FOUND + 1))
    fi

    # dd targeting disk devices
    if echo "$line" | grep -qE 'dd\s+if=.*of=/dev/'; then
      echo "  ❌ $file:$line_num: dd writing to block device"
      echo "      $line"
      FOUND=$((FOUND + 1))
    fi

    # mkfs (format filesystem)
    if echo "$line" | grep -qE 'mkfs[.\s]'; then
      echo "  ❌ $file:$line_num: mkfs (filesystem format)"
      echo "      $line"
      FOUND=$((FOUND + 1))
    fi

    # force push without --force-with-lease
    if echo "$line" | grep -qE 'git\s+push\s+.*--force[^-]' && ! echo "$line" | grep -qE 'force-with-lease|force-if-includes'; then
      echo "  ⚠️  $file:$line_num: git push --force (use --force-with-lease instead)"
      echo "      $line"
      WARNINGS=$((WARNINGS + 1))
    fi
  done < "$file"
}

# --- Run scans ---
for file in "${FILES[@]}"; do
  [[ ! -f "$file" ]] && continue
  check_unguarded_rm_rf "$file"
  check_dangerous_commands "$file"
done

# --- Report ---
echo ""
if [[ $FOUND -gt 0 ]]; then
  echo "[dangerous-pattern-scan] ❌ BLOCKED: $FOUND dangerous pattern(s) found. Fix before committing."
  [[ $WARNINGS -gt 0 ]] && echo "[dangerous-pattern-scan] ⚠️  Plus $WARNINGS warning(s) (non-blocking)."
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo "[dangerous-pattern-scan] ⚠️  $WARNINGS warning(s) found (non-blocking). Review recommended."
  exit 0
else
  echo "[dangerous-pattern-scan] ✅ Clean — no dangerous patterns found."
  exit 0
fi
