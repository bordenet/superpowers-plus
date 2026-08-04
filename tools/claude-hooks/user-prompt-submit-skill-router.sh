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
    # matching was removed. Applied ONLY to description tokens, NEVER to
    # name tokens -- applying this to skill names was tried and found to
    # be a real, measured regression: it strips the defining word from a
    # skill's own name (update-superpowers loses "update", superpowers-help
    # loses "help", test-driven-development loses "test"), breaking exact
    # matches on prompts that literally name the skill. A skill's own name
    # containing a generic verb (e.g. code-review-respond) may still
    # surface on a prompt containing that verb -- an accepted, narrower
    # residual than the regression this avoids.
    GENERIC_VERBS = {'fix','help','review','check','update','run','add','edit',
                      'write','make','get','show','find','list','create','build',
                      'test','start','stop','read','view','open','close'}

    def is_generic_verb(word):
        # Stem-aware: an inflection of a generic verb ("reviewer",
        # "reviewed") must also be excluded, or the suppression above is
        # trivially defeated by morphology (confirmed empirically:
        # "review" was stopped but "reviewer" was not, and "reviewer"
        # still fuzzy-matched "review" at scoring time). Restricted to
        # this set specifically (not STOP) since these are all real verbs
        # where the inflections are unambiguous -- unlike short function
        # words, where the same suffixes collide with unrelated words.
        if word in GENERIC_VERBS:
            return True
        for suf in ('ing', 'ers', 'ions', 'ors', 'ies', 'es', 'ed', 'er', 'or', 'ly', 's'):
            if word.endswith(suf) and word[:-len(suf)] in GENERIC_VERBS:
                return True
        return False

    tokens = set()
    for word in re.findall(r"[a-z]{3,}", name.lower()):
        if word not in STOP:
            tokens.add(word)
    for word in re.findall(r"[a-z]{3,}", desc_for_tokens.lower()):
        if word not in STOP and not is_generic_verb(word):
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
    prompt_lower = sys.argv[3].lower()

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
        if re.search(r'\b' + re.escape(name_lc) + r'\b', prompt_lower):
            name_score = 3 * idf(name_lc)
        else:
            name_score = 0
            name_flat = name_lc.replace('-', '')
            for pw in prompt_word_set:
                if len(pw) >= 4 and stems_match(name_flat, pw.replace('-', '')):
                    name_score = 2 * idf(name_lc)
                    break
        # Each DISTINCT prompt word contributes to the token score at most
        # once (exact match preferred; a stem match only counts a prompt
        # word not already covered by an exact match on some other token).
        # Without this cap, morphological variants of the same skill token
        # (e.g. multiple tokens all stem-matching the single prompt word
        # "call") could each add their own contribution independently.
        tokens = entry.get('tokens', [])
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
    # Distinct exit code: an unexpected scoring-logic error is now
    # observable in the metrics record instead of looking identical to a
    # clean "no match" result.
    sys.exit(4)
SCORE_PY
  SCORE_OUTPUT="$(python3 "$SCORE_PY_FILE" "$CACHE_FILE" "$MAX_HINTS" "$PROMPT" 2>/dev/null)"
  SCORE_EXIT=$?
  rm -f "$SCORE_PY_FILE"
else
  # mktemp itself failed (e.g. unwritable/full TMPDIR) -- no hints this
  # invocation, but still record it distinctly rather than looking like a
  # clean no-match result.
  SCORE_OUTPUT=""
  SCORE_EXIT=4
fi

if [[ -n "$SCORE_OUTPUT" ]]; then
    printf '%s\n' "$SCORE_OUTPUT"
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
{
    python3 -c "
import json, sys, time
rebuilt_flag = sys.argv[1]
score_exit = sys.argv[2]
lines = sys.argv[3].split(chr(10)) if len(sys.argv) > 3 else []
hints = [l.split('Likely match: ',1)[1].split(' — ')[0] for l in lines if 'Likely match:' in l]
status = {'0': 'ok', '3': 'cache_unreadable', '4': 'scoring_error'}.get(score_exit, 'unknown_exit_' + score_exit)
print(json.dumps({'ts': time.time(), 'rebuilt': rebuilt_flag == '1', 'status': status, 'hints': hints}))
" "$rebuild_needed" "$SCORE_EXIT" "$SCORE_OUTPUT" >> "$METRICS_FILE"
} 2>/dev/null || true

exit 0
