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
  local heredoc_indented=0  # 1 = <<- (tab-stripping); 0 = << (column-0 required)
  local trimmed  # declared at function scope; used inside the heredoc-tracking block
  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Track heredoc boundaries.
    # Closing detection: POSIX 2.7.4 says <<- strips ONLY leading tabs from the
    # closing delimiter; << requires the delimiter at column 0 (no stripping).
    # Strip accordingly: tabs-only for <<-, nothing for <<.
    if [[ -n "$in_heredoc" ]]; then
      if [[ "$heredoc_indented" -eq 1 ]]; then
        # <<-: strip leading tabs only.  ${line%%[^$'\t']*} yields the leading
        # tab sequence; removing it leaves the delimiter candidate.
        trimmed="${line#"${line%%[^$'\t']*}"}"
      else
        # <<: delimiter must start at column 0 -- no stripping.
        trimmed="$line"
      fi
      # Use [[:blank:]]* (tab+space) rather than [[:space:]]* to avoid matching
      # CR or other vertical whitespace that a shell would never accept as a
      # terminator, preventing false-positive heredoc closes.
      [[ "$trimmed" =~ ^${in_heredoc}[[:blank:]]*$ ]] && { in_heredoc=""; heredoc_indented=0; }
      continue
    fi
    # Opening detection: one regex captures <<- (group 1='-') and << (group 1='')
    # plus optional quote wrapping and the delimiter word (group 4).
    # Using [[ =~ ]] with BASH_REMATCH avoids forking echo|grep and echo|sed.
    if [[ "$line" =~ "<<"(-?)([[:space:]]*)([\"']?)([A-Za-z_][A-Za-z0-9_]*)([\"']?) ]]; then
      in_heredoc="${BASH_REMATCH[4]}"
      [[ "${BASH_REMATCH[1]}" == "-" ]] && heredoc_indented=1 || heredoc_indented=0
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
  local heredoc_indented=0  # 1 = <<- (tab-stripping); 0 = << (column-0 required)
  local trimmed  # declared at function scope; used inside the heredoc-tracking block
  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Track heredoc boundaries (same logic as check_unguarded_rm_rf above).
    if [[ -n "$in_heredoc" ]]; then
      if [[ "$heredoc_indented" -eq 1 ]]; then
        trimmed="${line#"${line%%[^$'\t']*}"}"
      else
        trimmed="$line"
      fi
      [[ "$trimmed" =~ ^${in_heredoc}[[:blank:]]*$ ]] && { in_heredoc=""; heredoc_indented=0; }
      continue
    fi
    if [[ "$line" =~ "<<"(-?)([[:space:]]*)([\"']?)([A-Za-z_][A-Za-z0-9_]*)([\"']?) ]]; then
      in_heredoc="${BASH_REMATCH[4]}"
      [[ "${BASH_REMATCH[1]}" == "-" ]] && heredoc_indented=1 || heredoc_indented=0
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
