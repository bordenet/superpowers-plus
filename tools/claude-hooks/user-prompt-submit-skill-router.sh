#!/usr/bin/env bash
# user-prompt-submit-skill-router.sh — advisory skill router for UserPromptSubmit.
# Item 6 of the Claude Code 12-point guardrails plan.
# Reads the prompt text from stdin JSON, scores installed skills by name/description
# substring match, and emits up to 3 advisory hints to stdout.
# NEVER blocks (always exits 0). The LLM retains final judgment.
set -euo pipefail
if [[ "${CLAUDE_HOOKS_BYPASS:-0}" == "1" ]]; then exit 0; fi

VERBOSE=0

show_help() {
    cat <<EOF
Usage: ${0##*/} [options] < hook-stdin-json

Advisory UserPromptSubmit skill router (item 6, Claude Code guardrails).
Reads a UserPromptSubmit hook JSON payload from stdin, scores installed
skills by name/description match, and prints up to 3 advisory hints.
Always exits 0 (never blocks). The LLM retains final judgment.

Input (stdin JSON):
  {"hook_event_name":"UserPromptSubmit","prompt":"...","cwd":"..."}

Output (stdout, one line per match):
  [skill-router] Likely match: <name> — <description>

Options:
  -v, --verbose   Log cache rebuild and scoring details to stderr
  -h, --help      Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)    show_help; exit 0 ;;
        -v|--verbose) VERBOSE=1; shift ;;
        *) echo "Unknown option: $1" >&2; show_help >&2; exit 1 ;;
    esac
done

SKILLS_DIR="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
CACHE_FILE="${CLAUDE_SKILL_ROUTER_CACHE:-$HOME/.claude/hooks/skill-router-cache.json}"
MAX_HINTS=3

INPUT="$(head -c 65536)"
PROMPT="$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    obj = json.load(sys.stdin)
    print(obj.get('prompt', ''))
except Exception:
    sys.exit(0)
")"

[[ -z "$PROMPT" ]] && exit 0
# Cap prompt to 4096 chars before scoring — prevents excessive scoring time on huge inputs.
PROMPT="${PROMPT:0:4096}"

# Rebuild cache if absent or any skill.md is newer.
rebuild_needed=0
if [[ ! -f "$CACHE_FILE" ]]; then
    rebuild_needed=1
else
    while IFS= read -r -d '' skill_file; do
        if [[ "$skill_file" -nt "$CACHE_FILE" ]]; then
            rebuild_needed=1
            break
        fi
    done < <(find "$SKILLS_DIR" -maxdepth 2 -name "skill.md" -print0 2>/dev/null)
fi

if [[ $rebuild_needed -eq 1 ]]; then
    [[ "$VERBOSE" -eq 1 ]] && echo "[skill-router] rebuilding cache from $SKILLS_DIR" >&2 || true
    mkdir -p "$(dirname "$CACHE_FILE")"
    python3 - "$SKILLS_DIR" "$CACHE_FILE" <<'REBUILD_PY'
import sys, json, os, re

skills_dir = sys.argv[1]
cache_path = sys.argv[2]
entries = []

for skill_name in os.listdir(skills_dir):
    skill_file = os.path.join(skills_dir, skill_name, 'skill.md')
    if not os.path.isfile(skill_file):
        continue
    try:
        with open(skill_file, encoding='utf-8', errors='replace') as f:
            content = f.read()
    except OSError:
        continue

    fm_match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
    name = skill_name
    desc = ''
    if fm_match:
        fm = fm_match.group(1)
        nm = re.search(r'^name:\s*(.+)', fm, re.MULTILINE)
        dm = re.search(r'^description:\s*(.+)', fm, re.MULTILINE)
        if nm:
            name = nm.group(1).strip().strip('"\'')
        if dm:
            desc = dm.group(1).strip().strip('"\'')

    STOP = {'the','and','for','with','any','this','that','are','you','its',
            'use','when','will','not','but','can','how','from','all','has',
            'have','your','our','their','been','was','were','into','only',
            'also','one','two','via','per','over','each','must','than','as',
            'on','in','of','to','a','an','at','be','is','it','or','if','by'}
    tokens = set()
    for word in re.findall(r"[a-z]{3,}", (name + ' ' + desc).lower()):
        if word not in STOP:
            tokens.add(word)

    entries.append({'name': name, 'description': desc[:120], 'tokens': sorted(tokens)})

with open(cache_path, 'w', encoding='utf-8') as f:
    json.dump(entries, f)
REBUILD_PY
fi

# Score skills against the prompt and emit advisory hints.
python3 - "$CACHE_FILE" "$MAX_HINTS" "$PROMPT" <<'SCORE_PY'
import sys, json, re

cache_path = sys.argv[1]
max_hints = int(sys.argv[2])
prompt_lower = sys.argv[3].lower()

try:
    with open(cache_path, encoding='utf-8') as f:
        entries = json.load(f)
except Exception:
    sys.exit(0)

# Prompt words (4+ chars) for prefix matching.
prompt_words = re.findall(r"[a-z]{4,}", prompt_lower)

scored = []
for entry in entries:
    score = 0
    name_lc = entry['name'].lower()
    # Name is an exact substring of prompt, or any prompt word is a prefix of the name.
    if name_lc in prompt_lower:
        score += 3
    elif any(name_lc.startswith(pw) and len(pw) >= 4 for pw in prompt_words):
        score += 2
    for tok in entry.get('tokens', []):
        if tok in prompt_lower:
            score += 1
        elif any(tok.startswith(pw) and len(pw) >= 4 for pw in prompt_words):
            score += 1
    if score > 0:
        scored.append((score, entry['name'], entry['description']))

scored.sort(key=lambda x: -x[0])
for _, name, desc in scored[:max_hints]:
    desc_str = f" — {desc}" if desc else ""
    print(f"[skill-router] Likely match: {name}{desc_str}")
SCORE_PY

exit 0
