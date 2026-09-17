#!/usr/bin/env bash
# user-prompt-submit-skill-router.sh — advisory skill router for UserPromptSubmit.
# Item 6 of the Claude Code 12-point guardrails plan.
# Reads the prompt text from stdin JSON, scores installed skills by
# word-boundary token match (normalized by vocabulary size, IDF-weighted,
# one contribution per distinct prompt word), bounded positive-trigger
# phrase weight, and an anti_triggers hard veto. Emits up to
# CLAUDE_SKILL_ROUTER_MAX_HINTS (default 1)
# deduplicated advisory hints, each gated on CLAUDE_SKILL_ROUTER_MIN_SCORE
# (default 0.55) so a low-confidence match emits no hint at all. diet.md
# P1c: 607 logged prompts, 94% got a hint (up to the old default of 3),
# 113 distinct skills were suggested, and the most-suggested skills were
# almost never actually invoked -- multiple low-confidence hints per
# prompt were mostly noise, not signal.
# NEVER blocks (always exits 0). The LLM retains final judgment.
set -uo pipefail
if [[ "${CLAUDE_HOOKS_BYPASS:-0}" == "1" ]]; then exit 0; fi
# Router telemetry includes bounded matched terms from the published skill
# vocabulary, never arbitrary prompt tokens. Keep newly-created cache and
# metrics files private to the current OS account.
umask 077
# CLAUDE_HOOKS_BYPASS=1 is also the rollback path if this scoring change
# needs to be disabled without a redeploy.

VERBOSE=0

show_help() {
    cat <<EOF
Usage: ${0##*/} [options] < hook-stdin-json

Advisory UserPromptSubmit skill router (item 6, Claude Code guardrails).
Reads a UserPromptSubmit hook JSON payload from stdin, scores installed
skills by word-boundary token match against name/description (with bounded
positive-trigger phrase weight and an anti_triggers hard veto), and prints
up to CLAUDE_SKILL_ROUTER_MAX_HINTS
(default 1) deduplicated advisory hints, each gated on
CLAUDE_SKILL_ROUTER_MIN_SCORE (default 0.55) -- a top score below the
floor emits no hint at all.
Always exits 0 (never blocks). The LLM retains final judgment.
Set CLAUDE_HOOKS_BYPASS=1 to disable entirely without a redeploy.

Input (stdin JSON):
  {"hook_event_name":"UserPromptSubmit","prompt":"...","cwd":"...","session_id":"..."}

Output (stdout, one line per match):
  [skill-router] Likely match: <name> — <description>

Environment:
  CLAUDE_SKILL_ROUTER_MAX_HINTS   Max hints emitted (default 1; must be a
                                  whole number from 1 to 3, else falls
                                  back to 1).
  CLAUDE_SKILL_ROUTER_MIN_SCORE   Confidence floor (default 0.55; must be
                                  a finite number from 0 to 10, else falls
                                  back to the default). See the MIN_SCORE
                                  comment in this script for how the
                                  default was calibrated.

A one-line JSON record per invocation is appended to
\$CLAUDE_SKILL_ROUTER_METRICS (default \$HOME/.claude/hooks/skill-router-metrics.jsonl)
for production observability: timestamp, whether the cache rebuilt, status,
the hint names emitted, session_id (if the hook payload had one),
prompt_sha256 (a hash, NEVER the prompt text), the top-scoring skill
("suggested", or null), its score and the runner-up's score (or null),
up to 5 matched_terms that contributed to the top skill, and the
threshold/max_hints in effect for this invocation. This file is
local-only and never synced/committed.

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

# Cache schema/logic version -- bumped whenever the SKIP logic (which
# skills get cached at all) or the cache's shape changes, independent of
# any skill.md mtime. Without this, a cache built under old skip logic
# would keep silently serving stale entries (e.g. a newly-added
# disable-model-invocation skill would still be advisory-hinted) until
# some unrelated skill.md file happened to change and triggered the mtime
# sweep below. Version 3 adds name-token provenance and bounded published
# aliases used by the precision analyzer; old caches cannot safely infer
# either field. Version 4 adds bounded published positive-trigger phrases
# used by the scorer plus a privacy-safe source-inventory count/digest; a
# version 3 cache would silently omit that evidence, while an early version 4
# cache without the inventory is rejected by the shape/currentness check.
CACHE_SCHEMA_VERSION=4

# MAX_HINTS: default 1 (was 3). Evidence (diet.md P1c, 607 logged
# prompts): 94% of prompts got a hint (up to the old default of 3), 113
# distinct skills were suggested, and the most-suggested skills were
# almost never actually invoked -- multiple hints per prompt were mostly
# noise, not signal. The override is bounded to 1..3: three preserves the
# previous maximum for controlled comparison, while any malformed or larger
# value falls back to one rather than flooding the context or risking a crash
# on every prompt (this hook must never fail the "always exits 0" contract).
MAX_HINTS="${CLAUDE_SKILL_ROUTER_MAX_HINTS:-1}"
case "$MAX_HINTS" in
    1|2|3) ;;
    *) MAX_HINTS=1 ;;
esac

# MIN_SCORE: a confidence floor below which NO hint is emitted at all,
# even if MAX_HINTS would otherwise allow one. Default 0.55, calibrated
# against a versioned 12-skill fixture and the installed 118-skill corpus.
# Raw TF-IDF is corpus-sensitive: one rare incidental token scored 1.278 in
# the installed corpus. The scorer therefore discounts a description-only
# match with one lexical signal to 35%, putting that observed false positive
# at 0.447. The weakest retained two-signal inflection fixture scores 0.695.
# The 0.55 floor sits between those measured bounds. Exact full-name matches
# and non-generic name segments are strong intent evidence. Generic name
# segments may add weight after independent intent qualifies, but never count
# as qualifying evidence themselves. One bounded published positive-trigger
# phrase may also contribute without stacking. The regression fixture is in
# tests/claude-guardrails-test.bats.
# The operator range is deliberately bounded: very large digit strings become
# infinity in Python, suppress every hint, and are not valid JSON numbers.
# Invalid, non-finite, or out-of-range overrides fall back to the default.
MIN_SCORE="${CLAUDE_SKILL_ROUTER_MIN_SCORE:-0.55}"
if ! [[ "$MIN_SCORE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
   ! LC_ALL=C awk -v score="$MIN_SCORE" 'BEGIN { exit !(score >= 0 && score <= 10) }'; then
    MIN_SCORE=0.55
fi

# 'set -e' is intentionally NOT used: this hook fires on every prompt in
# every session and must never let a failing/crashing python3 propagate a
# non-zero exit. The rebuild and prompt-extraction invocations are guarded
# with '|| true'; the scoring invocation deliberately is NOT (its exit
# code is captured as SCORE_EXIT below, to distinguish a scoring error
# from a genuine no-match in the metrics record) -- it is still safe
# without '|| true' because 'set -e' is off, so a non-zero exit there
# does not abort the script either. 'set -u' IS used; $HOME is defaulted
# above so it cannot trip it.

INPUT="$(head -c 65536)"
PROMPT="$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    obj = json.load(sys.stdin)
    value = obj.get('prompt', '')
    if isinstance(value, str):
        sys.stdout.write(value)
except Exception:
    sys.exit(0)
" 2>/dev/null)" || true

[[ -z "$PROMPT" ]] && exit 0
# Cap prompt to 4096 chars before scoring — prevents excessive scoring time on huge inputs.
PROMPT="${PROMPT:0:4096}"

# session_id: best-effort, for tools/router-precision.py to later join a
# hint against the transcript that followed it. Absent on older Claude
# Code versions or non-interactive callers -- recorded as null, not an
# error (see 'Older records without session_id are counted for rates
# only' in tools/router-precision.py).
SESSION_ID="$(printf '%s' "$INPUT" | python3 -c "
import sys, json, re
try:
    obj = json.load(sys.stdin)
    value = obj.get('session_id')
    if isinstance(value, str) and len(value) <= 128 and re.fullmatch(r'[A-Za-z0-9_.-]+', value):
        print(value)
except Exception:
    sys.exit(0)
" 2>/dev/null)" || true

# prompt_sha256: a hash of the prompt for metrics, NEVER the prompt text
# itself -- fed via stdin (not argv) so the raw prompt never even appears
# in this process's own command line while hashing it.
PROMPT_SHA256="$(printf '%s' "$PROMPT" | python3 -c "
import sys, hashlib
print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())
" 2>/dev/null)" || true

# Hash only the sorted names of immediate skill directories that currently
# contain skill.md. The cache stores the count and digest, never those names or
# paths. This catches deletion and rename, which a surviving-file mtime sweep
# cannot detect. os.fsencode gives a stable byte ordering even for non-ASCII
# filesystem names and remains compatible with macOS Python 3.9.
SOURCE_INVENTORY="$(python3 -c "
import hashlib, json, os, sys

try:
    names = sorted(
        os.fsencode(name)
        for name in os.listdir(sys.argv[1])
        if os.path.isfile(os.path.join(sys.argv[1], name, 'skill.md'))
    )
except OSError:
    names = []

digest = hashlib.sha256(b'\\0'.join(names)).hexdigest()
json.dump({'count': len(names), 'sha256': digest}, sys.stdout,
          allow_nan=False, separators=(',', ':'), sort_keys=True)
" "$SKILLS_DIR" 2>/dev/null)" || true

# Rebuild cache if absent, empty/corrupt, wrong-shape, source inventory changed,
# or any surviving skill.md is newer.
rebuild_needed=0
if [[ ! -s "$CACHE_FILE" ]]; then
    # -s (not -f): also catches a zero-byte cache file (e.g. pre-created by
    # a caller, or truncated by a crash) that would otherwise be treated as
    # fresh and silently produce zero hints forever until a skill.md changes.
    rebuild_needed=1
elif ! python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
current_inventory = json.loads(sys.argv[2])
valid = (
    isinstance(d, dict)
    and 'entries' in d
    and 'doc_freq' in d
    and d.get('version') == $CACHE_SCHEMA_VERSION
    and d.get('source_inventory') == current_inventory
)
sys.exit(0 if valid else 1)
" "$CACHE_FILE" "$SOURCE_INVENTORY" >/dev/null 2>&1; then
    # Shape check, not just JSON-syntax validity: a pre-migration cache is a
    # bare JSON list, which is syntactically valid but has no 'entries' key.
    # Without this check that old cache silently produces zero hints forever
    # (confirmed on a real installed cache during review) -- the mtime sweep
    # below can never fire because nothing rewrites the cache to trigger it.
    # The 'version' check is the same guard applied to the SKIP LOGIC: a
    # cache built under an older CACHE_SCHEMA_VERSION (e.g. before the
    # disable-model-invocation skip existed) must not be trusted just
    # because no skill.md happens to be newer than it -- the logic that
    # decided what to include changed, not necessarily the inputs.
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
    python3 - "$SKILLS_DIR" "$CACHE_FILE" "$CACHE_SCHEMA_VERSION" <<'REBUILD_PY' 2>/dev/null || true
import hashlib, json, os, re, sys

skills_dir = sys.argv[1]
cache_path = sys.argv[2]
cache_schema_version = int(sys.argv[3])
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

def parse_disable_model_invocation_flag(fm_text):
    """Return True if the frontmatter's top-level disable-model-invocation
    is true. Distinct from coordination.internal (dispatched by other
    skills, never surfaced) -- this is the author-facing manual-only flag:
    a skill invoked only by its explicit /name, never by the model on its
    own initiative and never advisory-hinted here either, for the same
    reason coordination.internal is excluded.
    """
    m = re.search(r'^disable-model-invocation:\s*(true|false)\s*$', fm_text, re.MULTILINE)
    if not m:
        return False
    return m.group(1) == 'true'

try:
    skill_names = os.listdir(skills_dir)
except OSError:
    skill_names = []

source_names = sorted(
    os.fsencode(skill_name)
    for skill_name in skill_names
    if os.path.isfile(os.path.join(skills_dir, skill_name, 'skill.md'))
)
source_inventory = {
    'count': len(source_names),
    'sha256': hashlib.sha256(b'\0'.join(source_names)).hexdigest(),
}

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
    explicit_aliases = []
    positive_triggers = []
    if fm_match:
        fm = fm_match.group(1)
        if parse_internal_flag(fm) or parse_disable_model_invocation_flag(fm):
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
        all_triggers = [
            value.lower().strip()
            for value in parse_array_field('triggers', fm)
            if value
        ]
        anti_triggers = [a.lower() for a in parse_array_field('anti_triggers', fm) if a]
        slash_triggers = [
            value
            for value in all_triggers
            if value.startswith('/')
        ]
        # Only bounded, multi-word, non-command phrases are eligible for a
        # positive-trigger score. Single generic words are too broad, slash
        # commands are explicit aliases, and multiple matching phrases never
        # stack at scoring time.
        positive_triggers = [
            value
            for value in all_triggers
            if not value.startswith('/')
            and len(value) <= 160
            and len(re.findall(r'[a-z0-9]+', value)) >= 2
        ][:16]
        named_aliases = [
            '/' + value.lower().lstrip('/')
            for value in parse_array_field('aliases', fm)
            if value
        ]
        explicit_aliases = slash_triggers + named_aliases

    # Strip exclusion-clause prose ("NOT for X", "not intended for X", "skip when X")
    # before tokenizing -- otherwise a skill's own disambiguation prose (e.g.
    # "NOT for multi-call search or aggregation") gets harvested as if it were a
    # positive-match token, penalizing authors who write careful exclusions.
    desc_for_tokens = re.split(
        r'(?i)\bNOT\s+(?:for|intended\s+for)\b|\bskip\s+when\b',
        desc, maxsplit=1,
    )[0]

    # Function words / interrogatives: exact match only, applied to BOTH
    # name and description. Never stem-matched -- stemming this set was
    # tried and found to produce real false positives on unrelated words
    # that happen to end the same way ("notes" stemming back to "not",
    # "whys" -- the "5 Whys" root-cause technique -- stemming back to
    # "why"), confirmed empirically against the real corpus.
    STOP = {'the','and','for','with','any','this','that','are','you','its',
            'use','when','will','not','but','can','how','from','all','has',
            'have','your','our','their','been','was','were','into','only',
            'also','one','two','via','per','over','each','must','than','as',
            'on','in','of','to','a','an','at','be','is','it','or','if','by',
            'where','what','why','who','whom','whose','which','does','did',
            'do','doing','then','these','those','there'}

    # Generic imperative verbs (backported from a sibling internal
    # project's own curated "too generic to be a useful trigger" word
    # list, a static trigger-quality lint's own stopword tier, per this
    # repo's reciprocal-value convention): common in both prompts and
    # skill DESCRIPTIONS ("review", "check", "run", "make", ...), so they
    # were still producing exact-match false positives even after fuzzy
    # matching was removed. They are removed from description vocabulary but
    # retained in name_tokens so a literal full skill name still works. Their
    # provenance is also recorded in generic_name_tokens so they may add
    # weight only after independent intent qualifies the skill.
    GENERIC_VERBS = {'fix','help','review','check','update','run','add','edit',
                      'write','make','get','show','find','list','create','build',
                      'test','debug','start','stop','read','view','open','close'}

    MORPH_SUFFIXES = ('ing', 'ers', 'ions', 'ors', 'ies', 'es', 'ed', 'er', 'or', 'ly', 's')

    def stems_match(a, b):
        """Match the scorer's exact, suffix-bounded morphology rules."""
        if a == b:
            return True
        short, long_ = (a, b) if len(a) < len(b) else (b, a)
        if long_.startswith(short) and long_[len(short):] in MORPH_SUFFIXES:
            return True
        if short and long_.startswith(short + short[-1]):
            rest = long_[len(short) + 1:]
            if rest in ('ing', 'ed'):
                return True
        return False

    def is_generic_verb(word):
        # Stem-aware: an inflection of a generic verb ("reviewer",
        # "reviewed", "debugging") must receive the same classification as
        # its base. Restricted to this set specifically (not STOP) since these
        # are real verbs where the supported inflections are unambiguous.
        return any(stems_match(word, verb) for verb in GENERIC_VERBS)

    name_tokens = set()
    for word in re.findall(r"[a-z]{3,}", name.lower()):
        if word not in STOP:
            name_tokens.add(word)
    tokens = set(name_tokens)
    for word in re.findall(r"[a-z]{3,}", desc_for_tokens.lower()):
        if word not in STOP and not is_generic_verb(word):
            tokens.add(word)

    entries.append({
        'name': name,
        'description': desc[:120],
        'tokens': sorted(tokens),
        'name_tokens': sorted(name_tokens),
        'generic_name_tokens': sorted(word for word in name_tokens if is_generic_verb(word)),
        'anti_triggers': anti_triggers,
        'positive_triggers': sorted(set(positive_triggers)),
        # Published skill metadata only; bounded again before telemetry write.
        'explicit_aliases': sorted(set(['/' + name.lower()] + explicit_aliases))[:16],
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

atomic_write(cache_path, {
    'entries': entries,
    'doc_freq': doc_freq,
    'n_docs': len(seen_for_df),
    'source_inventory': source_inventory,
    'version': cache_schema_version,
})
REBUILD_PY
fi

# Score skills against the prompt and emit advisory hints.
# Write the scorer to a temp file rather than piping a heredoc directly
# into a command substitution: bash 3.2 (macOS's default /bin/bash, still
# the interpreter for engineers without Homebrew bash ahead on PATH) hits
# a RUNTIME word-splitting error on
# `SCORE_OUTPUT="$(python3 - ... <<'SCORE_PY' ... SCORE_PY)"` -- `bash -n`
# exits 0 on this form, so it is not a parse-time failure -- dying with a
# "bad substitution: no closing ')'" error that aborts this scoring step
# specifically (confirmed empirically: the cache-rebuild heredoc above is
# a separate, unwrapped heredoc and still completes fine under
# /bin/bash; only the scorer's output capture dies). This form (heredoc
# into a plain file, unrelated command substitution around a file
# argument) has no such ambiguity on any bash version.
SCORE_PY_FILE="$(mktemp -t skill-router-score.XXXXXX.py 2>/dev/null)"
trap 'rm -f "$SCORE_PY_FILE"' EXIT
if [ -n "$SCORE_PY_FILE" ]; then
  cat > "$SCORE_PY_FILE" <<'SCORE_PY'
import sys, json, re, math

try:
    cache_path = sys.argv[1]
    max_hints = int(sys.argv[2])
    min_score = float(sys.argv[3])
    prompt_lower = sys.stdin.read().lower()

    try:
        with open(cache_path, encoding='utf-8') as f:
            cache = json.load(f)
        entries = cache['entries']
        doc_freq = cache['doc_freq']
        n_docs = max(1, cache['n_docs'])
    except Exception:
        # Distinct exit code (not 0): a metrics-logging record can then tell
        # "cache unreadable even right after a rebuild attempt" apart from
        # "scored cleanly, genuinely no match" -- both used to look
        # identical (empty output, exit 0), which is exactly the failure
        # class this hook's own history includes (a stale-format cache that
        # "silently produced zero hints forever").
        sys.exit(3)

    # Whole-word prompt tokens (3+ chars, matches the cache's own token floor).
    prompt_words_all = re.findall(r"[a-z]{3,}", prompt_lower)
    prompt_word_set = set(prompt_words_all)

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

    def positive_trigger_match(entry):
        """Return one bounded phrase boost from published metadata."""
        best_score = 0.0
        best_phrase = None

        def trigger_root(word):
            # Trigger-only normalization for a narrow reversed two-word form,
            # e.g. published "test failure" matching prompt "failing test".
            # This does not broaden general lexical stemming or longer trigger
            # phrases such as "debug across services".
            if word.endswith('ing') and len(word) > 5:
                root = word[:-3]
                if len(root) > 2 and root[-1:] == root[-2:-1]:
                    root = root[:-1]
                return root
            if word.endswith('ure') and len(word) > 5:
                return word[:-3]
            return word

        for phrase in entry.get('positive_triggers', []):
            words = re.findall(r'[a-z0-9]+', phrase.lower())
            if len(words) < 2:
                continue
            # Match the declared words contiguously and in order, allowing
            # punctuation/whitespace between them but no intervening words.
            pattern = r'\b' + r'\W+'.join(re.escape(word) for word in words) + r'\b'
            if re.search(pattern, prompt_lower):
                score = min(2.25, 0.75 * len(words))
            elif len(words) == 2:
                expected = [trigger_root(words[1]), trigger_root(words[0])]
                score = 0.0
                for left, right in zip(prompt_words_all, prompt_words_all[1:]):
                    if [trigger_root(left), trigger_root(right)] == expected:
                        score = 1.25
                        break
                if score == 0:
                    continue
            else:
                continue
            if score > best_score:
                best_score = score
                best_phrase = phrase
        return best_score, best_phrase

    def idf(tok):
        # Smoothed IDF: a token in every skill's vocabulary contributes ~0,
        # a token unique to 1-2 skills contributes several times more than
        # a generic one. Confirmed empirically necessary: word-boundary
        # matching and sqrt normalization alone were not sufficient to
        # suppress common-word false positives at this corpus size.
        df = doc_freq.get(tok, 1)
        return math.log((n_docs + 1) / (df + 1)) + 1

    # Suffix-restricted stemming: two words are related only if the longer
    # equals the shorter plus one recognized inflectional suffix -- not any
    # arbitrary shared prefix. Blanket prefix matching (tok.startswith(pw))
    # was the recurring, empirically-confirmed root cause of false positives
    # across two remediation passes ("call" prefix-matching "callout", an
    # unrelated word -- "blast-radius callout" has nothing to do with phone
    # calls). But removing fuzzy matching entirely cost a real true positive
    # ("brainstorm" no longer matching "brainstorming"). This is the
    # narrower middle ground: genuine inflections still match, unrelated
    # words that happen to share a prefix do not.
    SUFFIXES = ('ing', 'ers', 'ions', 'ors', 'ies', 'es', 'ed', 'er', 'or', 'ly', 's')

    def stems_match(a, b):
        if a == b:
            return True
        short, long_ = (a, b) if len(a) < len(b) else (b, a)
        if long_.startswith(short):
            if long_[len(short):] in SUFFIXES:
                return True
        # Consonant-doubling before -ing/-ed (e.g. "debug"+"ging"=
        # "debugging", "run"+"ning"="running") -- without this, common
        # verb forms that double their final consonant never matched
        # their base at all (confirmed empirically: "debug" scored zero
        # for prompts containing only "debugging", losing the
        # systematic-debugging skill entirely).
        if short and long_.startswith(short + short[-1]):
            rest = long_[len(short) + 1:]
            if rest in ('ing', 'ed'):
                return True
        return False

    scored = []
    for entry in entries:
        if veto(entry):
            continue

        # Name bonus: an exact whole-name-phrase match earns the strong
        # bonus (3x idf). A prompt word that only STEMS to the name (e.g.
        # "brainstorm" for the "brainstorming" skill) earns a reduced but
        # still substantial bonus (2x idf) -- this is a much stronger
        # signal than an incidental description-token match, since the
        # prompt is naming the skill itself, not just sharing vocabulary
        # with its description. Without this, a skill whose description
        # happens to literally contain the prompt's exact word (e.g.
        # another skill's description literally says "brainstorm" as one
        # step in a longer process) can outscore the skill the prompt is
        # actually naming, since a literal description match and a
        # name-stem match otherwise looked identical in weight (confirmed
        # empirically: "help me brainstorm a new feature" ranked the
        # brainstorming skill below others whose description merely
        # mentioned "brainstorm" in passing, until this name-stem bonus
        # was added). A prefix-of-first-hyphen-segment bonus (e.g. "scope"
        # prefixing "scope-tripwire") was tried and removed: it
        # false-matched on any prompt containing a skill's first
        # hyphen-segment as a generic word.
        name_lc = entry['name'].lower()
        # name_match_terms come only from the published skill name. Never
        # retain the arbitrary prompt spelling in telemetry.
        name_match_terms = []
        if re.search(r'\b' + re.escape(name_lc) + r'\b', prompt_lower):
            name_score = 3 * idf(name_lc)
            name_match_terms = re.findall(r'[a-z0-9]+', name_lc)
        else:
            name_score = 0
            name_flat = name_lc.replace('-', '')
            for pw in prompt_word_set:
                if len(pw) >= 4 and stems_match(name_flat, pw.replace('-', '')):
                    name_score = 2 * idf(name_lc)
                    name_match_terms = re.findall(r'[a-z0-9]+', name_lc)
                    break
        # Each DISTINCT prompt word contributes to the token score at most
        # once (exact match preferred; a stem match only counts a prompt
        # word not already covered by an exact match on some other token).
        # Without this cap, morphological variants of the same skill token
        # (e.g. multiple tokens all stem-matching the single prompt word
        # "call") could each add their own contribution independently.
        tokens = entry.get('tokens', [])
        name_tokens = set(entry.get('name_tokens', []))
        generic_name_tokens = set(entry.get('generic_name_tokens', []))
        covered = set()
        token_score = 0.0
        for tok in tokens:
            if tok in prompt_word_set:
                token_score += idf(tok)
                covered.add(tok)
        stem_best = {}
        for tok in tokens:
            if tok in covered or len(tok) < 4:
                continue
            for pw in prompt_word_set:
                if pw in covered or len(pw) < 4:
                    continue
                if stems_match(tok, pw):
                    val = idf(tok)
                    if pw not in stem_best or val > stem_best[pw][0]:
                        stem_best[pw] = (val, tok)
        for _pw, (val, _tok) in stem_best.items():
            token_score += 0.5 * val

        # Still normalize by vocabulary size (sqrt) on top of IDF weighting --
        # a skill with a much larger description has more distinct prompt
        # words available to match than a terse one.
        norm_token_score = token_score / (len(tokens) ** 0.5) if tokens else 0
        matched_skill_tokens = set(covered)
        matched_skill_tokens.update(tok for _val, tok in stem_best.values())
        qualified_skill_tokens = matched_skill_tokens - generic_name_tokens
        qualified_evidence_count = len(qualified_skill_tokens)
        matched_non_generic_name_tokens = qualified_skill_tokens & name_tokens
        trigger_score, matched_trigger = positive_trigger_match(entry)
        raw_total = name_score + norm_token_score + trigger_score
        # A single description-token overlap is not enough intent evidence.
        # Discount it before applying MIN_SCORE so corpus-wide IDF cannot turn
        # one rare incidental word into a high-confidence hint. Generic name
        # segments never qualify on their own or increase the qualified-signal
        # count. Once non-generic evidence independently qualifies the skill,
        # their matched weight remains part of raw_total. Two distinct
        # non-generic signals, a non-generic name signal, an exact full-name
        # match, or one bounded published trigger phrase retains full score.
        if (
            name_score == 0
            and trigger_score == 0
            and qualified_evidence_count == 0
        ):
            total = 0.0
        elif (
            name_score == 0
            and trigger_score == 0
            and qualified_evidence_count == 1
            and not matched_non_generic_name_tokens
        ):
            total = raw_total * 0.35
        else:
            # A non-generic segment of the skill's own name is stronger than
            # an incidental description token. Canonical J1 combines "debug"
            # with non-generic failure/test evidence; bare "debug" is generic-
            # only and must remain unrouted.
            total = raw_total
        if total > 0:
            # matched_terms: up to 5 terms from the published SKILL vocabulary
            # that matched, highest-contribution first. For stem matches this
            # deliberately records the skill-side token, not the arbitrary
            # prompt spelling. Metrics-only; does not affect routing.
            contrib = {}
            for t in name_match_terms:
                contrib[t] = max(contrib.get(t, 0.0), idf(name_lc) * 10)
            for t in covered:
                contrib[t] = max(contrib.get(t, 0.0), idf(t))
            for _pw, (val, tok) in stem_best.items():
                contrib[tok] = max(contrib.get(tok, 0.0), 0.5 * val)
            if matched_trigger:
                contrib[matched_trigger] = max(
                    contrib.get(matched_trigger, 0.0), trigger_score
                )
            matched_terms = [
                term[:64]
                for term in sorted(contrib, key=lambda t: (-contrib[t], t))[:5]
            ]
            scored.append((
                total,
                entry['name'],
                entry['description'],
                matched_terms,
                entry.get('explicit_aliases', []),
            ))

    scored.sort(key=lambda x: -x[0])

    # Dedup by name (first/highest-scoring occurrence wins), unconditionally
    # -- not just when building `hints` below. The raw top score / runner-up
    # recorded in the ##META## line must reflect genuinely distinct skills,
    # not two directory aliases of the same skill both scoring near the top.
    seen_names = set()
    ranked = []
    for item in scored:
        _total, name, _desc, _terms, _aliases = item
        if name in seen_names:
            continue
        seen_names.add(name)
        ranked.append(item)

    top_score = ranked[0][0] if ranked else None
    runner_up_score = ranked[1][0] if len(ranked) > 1 else None
    top_terms = ranked[0][3] if ranked else []
    top_explicit_aliases = ranked[0][4] if ranked else []

    # MIN_SCORE gate: `ranked` is sorted descending, so the first entry
    # below the floor means every entry after it is too -- emit no hint at
    # all for a low-confidence top match, rather than only suppressing the
    # marginal 2nd/3rd hint (diet.md P1c: top-suggested skills were almost
    # never actually invoked).
    hints = []
    suggested = None
    for total, name, desc, _terms, _aliases in ranked:
        if total < min_score:
            break
        hints.append((name, desc))
        if suggested is None:
            suggested = name
        if len(hints) >= max_hints:
            break

    for name, desc in hints:
        desc_str = f" — {desc}" if desc else ""
        print(f"[skill-router] Likely match: {name}{desc_str}")

    # Trailing metadata line for the metrics record only -- the outer shell
    # strips any '##META##'-prefixed line before printing real hook output,
    # so this never reaches the user/LLM. Always emitted on the non-exception
    # path (even with zero candidates), so 'score'/'runner_up' stay available
    # for floor recalibration independent of whether a hint was emitted.
    meta = {
        'suggested': suggested,
        'score': round(top_score, 3) if top_score is not None else None,
        'runner_up': round(runner_up_score, 3) if runner_up_score is not None else None,
        'matched_terms': top_terms,
        'explicit_aliases': top_explicit_aliases,
    }
    print("##META##" + json.dumps(meta))
except Exception:
    # Distinct exit code: an unexpected scoring-logic error is now
    # observable in the metrics record instead of looking identical to a
    # clean "no match" result.
    sys.exit(4)
SCORE_PY
  # Feed the prompt on stdin so it never appears in the scorer process's
  # command-line arguments or in telemetry.
  SCORE_OUTPUT="$(printf '%s' "$PROMPT" | python3 "$SCORE_PY_FILE" "$CACHE_FILE" "$MAX_HINTS" "$MIN_SCORE" 2>/dev/null)"
  SCORE_EXIT=$?
  rm -f "$SCORE_PY_FILE"
else
  # mktemp itself failed (e.g. unwritable/full TMPDIR) -- no hints this
  # invocation, but still record it distinctly rather than looking like a
  # clean no-match result.
  SCORE_OUTPUT=""
  SCORE_EXIT=4
fi

# The scorer's stdout may contain a trailing '##META##<json>' line (score,
# runner_up, matched_terms -- observability only). Strip it before printing
# real hook output: only the "[skill-router] Likely match: ..." lines are
# meant for the user/LLM. The unfiltered $SCORE_OUTPUT (meta line included)
# is still passed to the metrics step below.
HINT_LINES="$(printf '%s\n' "$SCORE_OUTPUT" | grep -v '^##META##' || true)"

if [[ -n "$HINT_LINES" ]]; then
    printf '%s\n' "$HINT_LINES"
fi

# Production observability: one JSONL record per invocation, local-only,
# never synced or committed (test suites must override
# CLAUDE_SKILL_ROUTER_METRICS to a scratch path -- a prior version of this
# hook lacked that override entirely and the CI-registered test suite
# silently appended fixture records into this real production file).
# 'status' distinguishes a genuine no-match (ok, empty hints) from a
# cache-load failure (3) or a scoring-logic error (4) -- both used to be
# indistinguishable empty-output/exit-0 records, which is exactly the
# failure class this telemetry exists to catch.
# The prompt text itself is NEVER passed to this step -- only PROMPT_SHA256
# (already just a hex digest computed above) and SESSION_ID/MIN_SCORE/
# MAX_HINTS, none of which can reconstruct the prompt.
mkdir -p "$(dirname "$METRICS_FILE")" 2>/dev/null || true
python3 -c "
import json, math, os, stat, sys, time

rebuilt_flag = sys.argv[1]
score_exit = sys.argv[2]
raw = sys.argv[3] if len(sys.argv) > 3 else ''
session_id = sys.argv[4] if len(sys.argv) > 4 else ''
prompt_sha256 = sys.argv[5] if len(sys.argv) > 5 else ''
threshold_arg = sys.argv[6] if len(sys.argv) > 6 else ''
max_hints_arg = sys.argv[7] if len(sys.argv) > 7 else ''
metrics_path = sys.argv[8] if len(sys.argv) > 8 else ''

lines = raw.split(chr(10))
hints = [l.split('Likely match: ', 1)[1].split(' — ')[0] for l in lines if 'Likely match:' in l]

meta = {}
for l in lines:
    if l.startswith('##META##'):
        try:
            meta = json.loads(l[len('##META##'):])
        except Exception:
            meta = {}
        break

def to_float(s):
    try:
        value = float(s)
        return value if math.isfinite(value) else None
    except Exception:
        return None

def to_int(s):
    try:
        return int(s)
    except Exception:
        return None

def finite_number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return value if math.isfinite(value) else None

status = {'0': 'ok', '3': 'cache_unreadable', '4': 'scoring_error'}.get(score_exit, 'unknown_exit_' + score_exit)
explicit_aliases = []
for value in meta.get('explicit_aliases') or []:
    if isinstance(value, str) and len(value) <= 160 and value.startswith('/'):
        explicit_aliases.append(value)
    if len(explicit_aliases) >= 16:
        break

record = {
    'ts': time.time(),
    'rebuilt': rebuilt_flag == '1',
    'status': status,
    'hints': hints,
    'session_id': session_id or None,
    'prompt_sha256': prompt_sha256 or None,
    'suggested': meta.get('suggested'),
    'score': finite_number(meta.get('score')),
    'runner_up': finite_number(meta.get('runner_up')),
    'matched_terms': meta.get('matched_terms') or [],
    'explicit_aliases': explicit_aliases,
    'threshold': to_float(threshold_arg),
    'max_hints': to_int(max_hints_arg),
}
payload = (json.dumps(record, allow_nan=False, separators=(',', ':')) + chr(10)).encode('utf-8')
no_follow = getattr(os, 'O_NOFOLLOW', None)
if no_follow is None or not metrics_path:
    raise OSError('safe no-follow telemetry open is unavailable')
flags = os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_NONBLOCK | no_follow
descriptor = os.open(metrics_path, flags, 0o600)
try:
    if not stat.S_ISREG(os.fstat(descriptor).st_mode):
        raise OSError('telemetry target is not a regular file')
    os.fchmod(descriptor, 0o600)
    if os.write(descriptor, payload) != len(payload):
        raise OSError('short telemetry write')
finally:
    os.close(descriptor)
" "$rebuild_needed" "$SCORE_EXIT" "$SCORE_OUTPUT" "$SESSION_ID" "$PROMPT_SHA256" "$MIN_SCORE" "$MAX_HINTS" "$METRICS_FILE" 2>/dev/null || true

exit 0
