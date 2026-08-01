#!/usr/bin/env bash
# user-prompt-submit-skill-router.sh — advisory skill router for UserPromptSubmit.
# Item 6 of the Claude Code 12-point guardrails plan.
# Reads the prompt text from stdin JSON, scores installed skills by
# word-boundary token match (normalized by vocabulary size, IDF-weighted,
# one contribution per distinct prompt word) with an anti_triggers hard
# veto, and emits up to 3 deduplicated advisory hints.
# NEVER blocks (always exits 0). The LLM retains final judgment.
set -uo pipefail
if [[ "${CLAUDE_HOOKS_BYPASS:-0}" == "1" ]]; then exit 0; fi
# CLAUDE_HOOKS_BYPASS=1 is also the rollback path if this scoring change
# needs to be disabled without a redeploy.

VERBOSE=0

show_help() {
    cat <<EOF
Usage: ${0##*/} [options] < hook-stdin-json

Advisory UserPromptSubmit skill router (item 6, Claude Code guardrails).
Reads a UserPromptSubmit hook JSON payload from stdin, scores installed
skills by word-boundary token match against name/description (with an
anti_triggers hard veto), and prints up to 3 deduplicated advisory hints.
Always exits 0 (never blocks). The LLM retains final judgment.
Set CLAUDE_HOOKS_BYPASS=1 to disable entirely without a redeploy.

Input (stdin JSON):
  {"hook_event_name":"UserPromptSubmit","prompt":"...","cwd":"..."}

Output (stdout, one line per match):
  [skill-router] Likely match: <name> — <description>

A one-line JSON record per invocation is appended to
\$CLAUDE_SKILL_ROUTER_METRICS (default \$HOME/.claude/hooks/skill-router-metrics.jsonl)
for production observability: timestamp, whether the cache rebuilt, and
the hint names emitted. This file is local-only and never synced/committed.

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

HOME="${HOME:-/tmp}"
SKILLS_DIR="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
CACHE_FILE="${CLAUDE_SKILL_ROUTER_CACHE:-$HOME/.claude/hooks/skill-router-cache.json}"
METRICS_FILE="${CLAUDE_SKILL_ROUTER_METRICS:-$HOME/.claude/hooks/skill-router-metrics.jsonl}"
MAX_HINTS=3

# 'set -e' is intentionally NOT used: this hook fires on every prompt in
# every session and must never let a failing/crashing python3 propagate a
# non-zero exit. Every python3 invocation below is guarded with '|| true'.
# 'set -u' IS used; $HOME is defaulted above so it cannot trip it.

INPUT="$(head -c 65536)"
PROMPT="$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    obj = json.load(sys.stdin)
    print(obj.get('prompt', ''))
except Exception:
    sys.exit(0)
" 2>/dev/null)" || true

[[ -z "$PROMPT" ]] && exit 0
# Cap prompt to 4096 chars before scoring — prevents excessive scoring time on huge inputs.
PROMPT="${PROMPT:0:4096}"

# Rebuild cache if absent, empty/corrupt, wrong-shape, or any skill.md is newer.
rebuild_needed=0
if [[ ! -s "$CACHE_FILE" ]]; then
    # -s (not -f): also catches a zero-byte cache file (e.g. pre-created by
    # a caller, or truncated by a crash) that would otherwise be treated as
    # fresh and silently produce zero hints forever until a skill.md changes.
    rebuild_needed=1
elif ! python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if isinstance(d, dict) and 'entries' in d and 'doc_freq' in d else 1)
" "$CACHE_FILE" >/dev/null 2>&1; then
    # Shape check, not just JSON-syntax validity: a pre-migration cache is a
    # bare JSON list, which is syntactically valid but has no 'entries' key.
    # Without this check that old cache silently produces zero hints forever
    # (confirmed on a real installed cache during review) -- the mtime sweep
    # below can never fire because nothing rewrites the cache to trigger it.
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
    python3 - "$SKILLS_DIR" "$CACHE_FILE" <<'REBUILD_PY' 2>/dev/null || true
import sys, json, os, re

skills_dir = sys.argv[1]
cache_path = sys.argv[2]
entries = []

def atomic_write(path, obj):
    tmp_path = f"{path}.tmp.{os.getpid()}"
    try:
        with open(tmp_path, 'w', encoding='utf-8') as f:
            json.dump(obj, f)
        os.replace(tmp_path, path)  # atomic on POSIX -- safe under concurrent sessions
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise

def parse_array_field(field_name, fm_text):
    """Parse triggers/anti_triggers in the 3 forms lib/frontmatter.js documents:
    1. Inline:        field: ["a", "b"]
    2. Bracket-multiline (rare in practice; treated as inline after joining)
    3. YAML list:     field:\n  - a\n  - b
    Best-effort: malformed/unrecognized forms yield an empty list, never an error.
    """
    values = []
    lines = fm_text.split('\n')
    for i, line in enumerate(lines):
        m = re.match(rf'^{field_name}:\s*\[(.*)$', line)
        if m:
            # Join forward until a closing bracket is found (handles bracket-multiline).
            joined = m.group(1)
            j = i
            while ']' not in joined and j + 1 < len(lines):
                j += 1
                joined += ' ' + lines[j]
            joined = joined.split(']')[0]
            for item in re.findall(r'"([^"]*)"|\'([^\']*)\'', joined):
                val = item[0] or item[1]
                if val:
                    values.append(val)
            # Unquoted inline items (e.g. "[foo, bar]") -- fall back only if
            # no quoted items were found, so we don't mix both parses.
            if not values and joined.strip():
                for part in joined.split(','):
                    part = part.strip().strip('"\'')
                    if part:
                        values.append(part)
            return values
        m = re.match(rf'^{field_name}:\s*$', line)
        if m:
            for j in range(i + 1, len(lines)):
                item_m = re.match(r'^\s+-\s+(.+)$', lines[j])
                if item_m:
                    raw = item_m.group(1).strip()
                    # Strip a trailing '# comment' before stripping quotes, so
                    # the comment doesn't get trapped inside the value (e.g.
                    # '"foo"   # note' must not become 'foo"   # note').
                    raw = re.sub(r'\s+#.*$', '', raw)
                    values.append(raw.strip().strip('"\''))
                    continue
                if lines[j].strip() == '':
                    continue
                break
            return values
    return values

def parse_internal_flag(fm_text):
    """Return True if frontmatter's coordination.internal is true.
    Internal skills are dispatched by other skills, not directly invocable,
    and should not be recommended as advisory hints to the end user.
    """
    m = re.search(r'^coordination:\s*$', fm_text, re.MULTILINE)
    if not m:
        return False
    start = m.end()
    block_lines = fm_text[start:].split('\n')
    for line in block_lines:
        if line.strip() == '':
            continue
        if not line.startswith((' ', '\t')):
            break  # dedented past the coordination: block
        im = re.match(r'^\s+internal:\s*(true|false)\s*$', line)
        if im:
            return im.group(1) == 'true'
    return False

try:
    skill_names = os.listdir(skills_dir)
except OSError:
    atomic_write(cache_path, {'entries': [], 'doc_freq': {}, 'n_docs': 0})
    sys.exit(0)

for skill_name in skill_names:
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
    anti_triggers = []
    if fm_match:
        fm = fm_match.group(1)
        if parse_internal_flag(fm):
            continue  # not directly invocable -- never surface as an advisory hint
        nm = re.search(r'^name:\s*(.+)', fm, re.MULTILINE)
        dm = re.search(r'^description:\s*(.+)', fm, re.MULTILINE)
        if nm:
            name = nm.group(1).strip().strip('"\'')
        if dm:
            desc = dm.group(1).strip().strip('"\'')
            if desc in ('>', '>-', '|', '|-'):
                # YAML folded/literal-block scalar indicator with no inline
                # text -- the real description is on following lines, which
                # this single-line regex doesn't capture. Treat as empty
                # rather than harvest the punctuation as a "description".
                desc = ''
        anti_triggers = [a.lower() for a in parse_array_field('anti_triggers', fm) if a]

    # Strip exclusion-clause prose ("NOT for X", "not intended for X", "skip when X")
    # before tokenizing -- otherwise a skill's own disambiguation prose (e.g.
    # "NOT for multi-call search or aggregation") gets harvested as if it were a
    # positive-match token, penalizing authors who write careful exclusions.
    desc_for_tokens = re.split(
        r'(?i)\bNOT\s+(?:for|intended\s+for)\b|\bskip\s+when\b',
        desc, maxsplit=1,
    )[0]

    STOP = {'the','and','for','with','any','this','that','are','you','its',
            'use','when','will','not','but','can','how','from','all','has',
            'have','your','our','their','been','was','were','into','only',
            'also','one','two','via','per','over','each','must','than','as',
            'on','in','of','to','a','an','at','be','is','it','or','if','by',
            # Interrogatives/function words: rare in declarative skill
            # descriptions but common in (often question-shaped) prompts, so
            # IDF alone inflates their weight for the wrong reason -- rarity
            # from genre mismatch, not topical specificity (confirmed
            # empirically during review).
            'where','what','why','who','whom','whose','which','does','did',
            'do','doing','then','these','those','there'}
    tokens = set()
    for word in re.findall(r"[a-z]{3,}", (name + ' ' + desc_for_tokens).lower()):
        if word not in STOP:
            tokens.add(word)

    entries.append({
        'name': name,
        'description': desc[:120],
        'tokens': sorted(tokens),
        'anti_triggers': anti_triggers,
    })

# Document frequency per token, across DISTINCT skill names (not raw entry
# count) -- an alias pair sharing one canonical name must not double-count
# that name's vocabulary as if it were two independent skills discussing
# the same topic, which would understate its rarity.
seen_for_df = {}
for entry in entries:
    seen_for_df.setdefault(entry['name'], entry)
doc_freq = {}
for entry in seen_for_df.values():
    for tok in entry['tokens']:
        doc_freq[tok] = doc_freq.get(tok, 0) + 1

atomic_write(cache_path, {'entries': entries, 'doc_freq': doc_freq, 'n_docs': len(seen_for_df)})
REBUILD_PY
fi

# Score skills against the prompt and emit advisory hints.
SCORE_OUTPUT="$(python3 - "$CACHE_FILE" "$MAX_HINTS" "$PROMPT" <<'SCORE_PY' 2>/dev/null
import sys, json, re, math

try:
    cache_path = sys.argv[1]
    max_hints = int(sys.argv[2])
    prompt_lower = sys.argv[3].lower()

    try:
        with open(cache_path, encoding='utf-8') as f:
            cache = json.load(f)
        entries = cache['entries']
        doc_freq = cache['doc_freq']
        n_docs = max(1, cache['n_docs'])
    except Exception:
        sys.exit(0)

    # Whole-word prompt tokens (3+ chars, matches the cache's own token floor)
    # and a 4+ char subset for fuzzy prefix/stem matching.
    prompt_words_all = re.findall(r"[a-z]{3,}", prompt_lower)
    prompt_word_set = set(prompt_words_all)
    prompt_words4 = {w for w in prompt_word_set if len(w) >= 4}

    def veto(entry):
        for phrase in entry.get('anti_triggers', []):
            # \b requires a preceding/following word character, so it never
            # matches at a phrase edge that starts/ends with punctuation
            # (e.g. "/sp-graded-review") -- confirmed empirically to silently
            # disable every slash-command anti_trigger. Apply \b only on the
            # sides that are actually word characters.
            left = r'\b' if phrase[:1].isalnum() else ''
            right = r'\b' if phrase[-1:].isalnum() else ''
            if re.search(left + re.escape(phrase) + right, prompt_lower):
                return True
        return False

    def idf(tok):
        # Smoothed IDF: a token in every skill's vocabulary contributes ~0,
        # a token unique to 1-2 skills contributes several times more than
        # a generic one. Confirmed empirically necessary: word-boundary
        # matching and sqrt normalization alone were not sufficient to
        # suppress common-word false positives at this corpus size.
        df = doc_freq.get(tok, 1)
        return math.log((n_docs + 1) / (df + 1)) + 1

    scored = []
    for entry in entries:
        if veto(entry):
            continue

        # Only an exact whole-name-phrase match earns the strong name bonus.
        # A prefix-of-first-hyphen-segment bonus (e.g. "scope" prefixing
        # "scope-tripwire") was removed: name components already feed the
        # token score below, and the prefix heuristic alone false-matched
        # on any prompt containing a skill's first hyphen-segment as a
        # generic word (confirmed empirically).
        name_lc = entry['name'].lower()
        name_score = 3 * idf(name_lc) if re.search(r'\b' + re.escape(name_lc) + r'\b', prompt_lower) else 0

        # Each DISTINCT prompt word contributes to the token score at most
        # once. Without this, morphological variants of the same skill
        # token (e.g. "call"/"caller"/"callid"/"callguid" all fuzzy-matching
        # the single prompt word "call") each add their own contribution
        # independently, letting one real word in the prompt masquerade as
        # several pieces of evidence -- confirmed empirically as the
        # dominant remaining cause of false positives after IDF weighting
        # alone (a skill can still win on a single incidental word match
        # stacked across its own morphological family).
        tokens = entry.get('tokens', [])
        covered = set()
        token_score = 0.0
        for tok in tokens:
            if tok in prompt_word_set:
                token_score += idf(tok)
                covered.add(tok)
        fuzzy_best = {}
        for tok in tokens:
            if tok in covered or len(tok) < 4:
                continue
            for pw in prompt_words4:
                if pw in covered:
                    continue
                if tok.startswith(pw) or pw.startswith(tok):
                    val = idf(tok)
                    if pw not in fuzzy_best or val > fuzzy_best[pw][0]:
                        fuzzy_best[pw] = (val, tok)
        for _pw, (val, _tok) in fuzzy_best.items():
            token_score += 0.5 * val

        # Still normalize by vocabulary size (sqrt) on top of IDF weighting --
        # a skill with a much larger description has more distinct prompt
        # words available to match than a terse one.
        norm_token_score = token_score / (len(tokens) ** 0.5) if tokens else 0
        total = name_score + norm_token_score
        if total > 0:
            scored.append((total, entry['name'], entry['description']))

    scored.sort(key=lambda x: -x[0])

    seen_names = set()
    hints = []
    for _, name, desc in scored:
        if name in seen_names:
            continue
        seen_names.add(name)
        hints.append((name, desc))
        if len(hints) >= max_hints:
            break

    for name, desc in hints:
        desc_str = f" — {desc}" if desc else ""
        print(f"[skill-router] Likely match: {name}{desc_str}")
except Exception:
    pass
SCORE_PY
)" || true

if [[ -n "$SCORE_OUTPUT" ]]; then
    printf '%s\n' "$SCORE_OUTPUT"
fi

# Production observability: one JSONL record per invocation, local-only,
# never synced or committed. This is the signal that was missing entirely
# before this change -- without it, a recall regression in production is
# invisible until someone notices by hand (as happened here).
{
    python3 -c "
import json, sys, time
rebuilt_flag = sys.argv[1]
lines = sys.argv[2].split(chr(10)) if len(sys.argv) > 2 else []
hints = [l.split('Likely match: ',1)[1].split(' — ')[0] for l in lines if 'Likely match:' in l]
print(json.dumps({'ts': time.time(), 'rebuilt': rebuilt_flag == '1', 'hints': hints}))
" "$rebuild_needed" "$SCORE_OUTPUT" >> "$METRICS_FILE"
} 2>/dev/null || true

exit 0
