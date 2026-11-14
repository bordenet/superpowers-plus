#!/usr/bin/env python3
"""review-preflight.py -- the mechanical half of code-review-battery triage, as one JSON object.

Usage:
  review-preflight.py [--base REF | --staged] [--mode bug-fix|feature]
  review-preflight.py --list-signals
  review-preflight.py --help

  --base REF       review the branch: diff from merge-base(REF, HEAD) to HEAD
                   (default origin/dev)
  --staged         review the index: diff from HEAD to the staged tree
  --mode M         force bug-fix or feature mode, as code-review-battery's
                   --mode flag does; otherwise detected from the branch name
  --list-signals   print the encoded signal table as JSON and exit

Run it before code-review-battery Phases 0, 0.5 and 1 and read its JSON instead
of applying those tables by hand. The skill's tables stay the spec; this script
is checked against them by tests/tools/review-preflight.bats.

Output keys:
  head, branch, base, mode     what was compared
  worktree_clean               false if tracked files have uncommitted changes
  sentinels                    per sentinel file: state valid, stale, missing,
                               malformed or not-clearing (its verdict does not
                               clear its gate), with the recorded sha and
                               verdict. "carried": true means it names another
                               commit but no file in its scope changed, so the
                               gate still accepts it. Validation is the gates'
                               own bash (tools/lib/review-sentinel.sh,
                               sentinel-scope.sh)
  bugfix_mode                  as tools/run-battery.sh decides it: --mode, else
                               hotfix/ or fix/<prefix>- where the prefixes come
                               from .cr-battery-ticket-prefixes (default
                               PROJ FEAT FIX BUG INFRA SEC QA); see
                               bugfix_mode_reason
  diff                         files with status and line counts, totals,
                               change_class, size_class
  routes                       tools/review.sh route, parsed per review class
  reviewers                    base reviewers for the change class, then each
                               signal row and mandatory rule that fired, with
                               file:line hits; "heuristic": true means a regex
                               can only suggest the row, so confirm it
  dispatch                     whether the combined reviewer runs, and which
                               extra agents the fired rows add
  judgment_required            signal rows no regex can decide; read those
                               rows in the skill
  inline_exemption_eligible    the small-diff inline review exemption, with
                               the reasons for the answer

Exit codes:
  0  JSON printed
  2  usage error, or git could not answer (base ref missing, not a repo)
"""

import json
import os
import re
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TOOLS_ROOT = os.path.dirname(SCRIPT_DIR)
REVIEW_SH = os.path.join(SCRIPT_DIR, "review.sh")
LIB_DIR = os.path.join(SCRIPT_DIR, "lib")

SENTINELS = (".code-review-cleared", ".phr-cleared", ".llm-skill-review-cleared")
# Same default list and file as tools/run-battery.sh's Bug Fix Mode detection.
DEFAULT_TICKET_PREFIXES = ("PROJ", "FEAT", "FIX", "BUG", "INFRA", "SEC", "QA")
DOC_FILE = re.compile(r"\.(md|txt|rst)$")
TEST_FILE = re.compile(r"(^|/)(tests?|__tests__)/|\.bats$|\.test\.[jt]sx?$|(^|/)test_[^/]+\.py$")
CONFIG_FILE = re.compile(r"\.(json|ya?ml|toml|ini|cfg|conf)$|(^|/)\.[^/]+$")
SHELL_SHEBANG = re.compile(r"^#!.*\b(ba|z|k|da)?sh\b")

COMBINED_LENSES = ("Defect Finder", "Guardian", "Standards Enforcer")
INLINE_MAX_LINES = 150
INLINE_MAX_FILES = 3
LARGE_LINES = 500
CHUNK_LINES = 3000

# One entry per row of the "Signal-driven dispatch" table in
# skills/engineering/code-review-battery/skill.md. "row" is a substring of that
# row's first cell; the bats suite fails if a table row matches no entry, so a
# new row in the skill cannot be silently missed here.
#   match: "added"  -> regex over added lines of non-doc files
#          "status" -> rename/delete in the file list
#          "class"  -> the diff's change class
#          "judgment" -> no regex can decide it; reported, never fired
SIGNALS = [
    {"id": "metric-emit", "row": "Metric/counter/event definition",
     "reviewers": ["Defect Finder", "Standards Enforcer"], "match": "added", "heuristic": False,
     "regex": r"\.(emit|inc)\(|\bpublish\(|\bdefineMetric\b|\b(Counter|Gauge|Histogram)\("},
    {"id": "alarm", "row": "Alarm/threshold definition",
     "reviewers": ["Guardian", "Standards Enforcer"], "match": "added", "heuristic": True,
     "regex": r"\b[Aa]larms?\b|\bAlarm\w*\(|\bthreshold\b"},
    {"id": "external-error", "row": "External-dependency call",
     "reviewers": ["Guardian"], "match": "added", "heuristic": True,
     "regex": r"\b429\b|\b50[0-4]\b|\bstatus(Code|_code)?\s*[=!<>]=?\s*\d{3}|rate.?limit"
              r"|\bECONNRESET\b|\bETIMEDOUT\b|Throttl"},
    {"id": "field-reset", "row": "Field set to `null`",
     "reviewers": ["Defect Finder", "Guardian"], "match": "added", "heuristic": False,
     "regex": r"^\s*[\w$]+(\.[\w$]+|\[[^\]]+\])+\s*=\s*(null|None|0|false|False|undefined|nil)\s*;?\s*$"},
    {"id": "public-api", "row": "Public signature / interface",
     "reviewers": ["Design Critic", "Guardian"], "match": "added", "heuristic": False,
     "regex": r"^\s*export\s+(default\s+)?(async\s+)?(class|interface|type|function|const|enum)\b"
              r"|^\s*public\s+[\w<>\[\], ]+\s+\w+\s*\(|\bmodule\.exports\b"},
    {"id": "io-loop", "row": "Loop over I/O",
     "reviewers": ["Performance Analyst"], "match": "added", "heuristic": True,
     "regex": r"\b(SELECT|INSERT|UPDATE|DELETE)\s+\S|\.(query|execute)\(|\bfetch\(|\brequests\.(get|post|put)\("
              r"|\bcurl\s|\bfor\b.*\bawait\b|\bawait\b.*\bfor\b|\bcache\b"},
    {"id": "rename-delete", "row": "File rename/move/delete",
     "reviewers": ["Guardian"], "match": "status", "heuristic": False},
    {"id": "test-only", "row": "Test-only change",
     "reviewers": ["Standards Enforcer", "Defect Finder"], "match": "class", "heuristic": False},
    {"id": "ticket-in-comment", "row": "ticket-tracker reference",
     "reviewers": ["Standards Enforcer"], "match": "added", "heuristic": True,
     "regex": r"^\s*(//|/\*|\*\s).*\b(?!(UTF|ISO|RFC|SHA|HTTP|TLS|SSL|CVE|AES|MD|X)-)[A-Z][A-Z0-9]+-[0-9]+\b"},
    {"id": "security", "row": "Security-class signal",
     "reviewers": ["AttackerPersona"], "match": "added", "heuristic": True,
     "regex": r"\b(secret|password|passwd|api[_-]?key|cookie|session|credential)s?\b"
              r"|\btoken\b|_disabled/|\bmcp\b|\bx-api-key\b"
              r"|[\"'`].*\b(SELECT|FROM|WHERE)\b.*(\$\{|%s|\{\w*\}|\+\s*\w)"},
    {"id": "shell", "row": "Shell-content signal",
     "reviewers": ["ShellRuntimeAuditor"], "match": "added", "heuristic": False,
     "regex": r"^#!|\b(execSync|spawnSync|execFileSync|child_process)\b|\bsubprocess\.(run|call|check_call|check_output|Popen)\b"},
    {"id": "untelemetered-feature", "row": "New user-visible feature",
     "reviewers": ["Standards Enforcer"], "match": "judgment"},
    {"id": "try-catch", "row": "block in the diff",
     "reviewers": ["Defect Finder"], "match": "added", "heuristic": False,
     "regex": r"\btry\s*\{|\}\s*catch\b|^\s*try:\s*$|^\s*except\b"},
    {"id": "caller-removal", "row": "only call site",
     "reviewers": ["Defect Finder"], "match": "judgment"},
    {"id": "sibling-path", "row": "New property added",
     "reviewers": ["Defect Finder", "Guardian"], "match": "judgment"},
]

# "Mandatory activation" bullets under the signal table.
MANDATORY = [
    {"id": "guardian-mandatory", "reviewer": "Guardian",
     "rule": "retry, circuit breaker, rollback, deployment config, feature flag, auth, state machine",
     "regex": r"\bretr(y|ies|ied)\b|\bbackoff\b|circuit.?breaker|\brollback\b|\broll back\b"
              r"|feature.?flag|\bauth[nz]?\b|authenticat|authoriz|state.?machine",
     "path": r"(^|/)\.github/workflows/|(^|/)deploy|Dockerfile$|(^|/)\.env"},
    {"id": "design-critic-mandatory", "reviewer": "Design Critic",
     "rule": "interfaces, public APIs, contracts, message schemas, shared state types",
     "regex": r"^\s*(export\s+)?interface\s+\w|\bschema\b|\bcontract\b",
     "path": None},
]

MAX_HITS = 10


class UsageError(Exception):
    pass


def run(cmd, check=True, **kw):
    """Run cmd, decoding output leniently (diffs may hold non-UTF-8 bytes)."""
    try:
        r = subprocess.run(cmd, capture_output=True, **kw)
    except OSError as e:
        raise UsageError("cannot run %s: %s" % (cmd[0], e))
    r.stdout = r.stdout.decode("utf-8", errors="replace")
    r.stderr = r.stderr.decode("utf-8", errors="replace")
    if check and r.returncode != 0:
        raise UsageError("%s failed: %s" % (" ".join(cmd[:3]), r.stderr.strip() or r.stdout.strip()))
    return r


def git(*args, check=True):
    return run(["git", *args], check=check).stdout


# Pin diff output so user config (diff.noprefix, diff.external, custom
# prefixes, quoted paths) cannot change what the parser sees.
DIFF = ["-c", "core.quotePath=false", "diff", "--no-color", "--no-ext-diff",
        "--src-prefix=a/", "--dst-prefix=b/"]


# --- diff --------------------------------------------------------------------

def diff_range(base, staged):
    if staged:
        return ["--cached", "HEAD"], git("rev-parse", "HEAD").strip()
    if run(["git", "rev-parse", "--verify", "--quiet", base + "^{commit}"], check=False).returncode:
        raise UsageError("base ref %r not found; fetch it or pass --base" % base)
    mb = git("merge-base", base, "HEAD").strip()
    return [mb, "HEAD"], mb


def collect_diff(rng):
    files = {}
    fields = git(*DIFF, "--name-status", "-z", "-M", *rng).split("\0")
    i = 0
    while i < len(fields) and fields[i]:
        status = fields[i][:1]
        if status in ("R", "C"):
            old, path = fields[i + 1], fields[i + 2]
            i += 3
        else:
            old, path = None, fields[i + 1]
            i += 2
        files[path] = {"path": path, "status": status, "added": 0, "removed": 0}
        if status == "R":
            files[path]["renamed_from"] = old
    # numstat -z: "A\tR\tpath\0" or, for a rename, "A\tR\t\0old\0new\0"
    fields = git(*DIFF, "--numstat", "-z", "-M", *rng).split("\0")
    i = 0
    while i < len(fields) and fields[i]:
        a, r, path = fields[i].split("\t", 2)
        if path == "":
            path = fields[i + 2]
            i += 3
        else:
            i += 1
        if path in files:
            files[path]["added"] = int(a) if a != "-" else 0
            files[path]["removed"] = int(r) if r != "-" else 0
            files[path]["binary"] = a == "-"

    added_lines = []  # (path, line_no, text)
    unscanned = []  # header paths that could not be resolved
    removed_count_code = 0
    old_path = new_path = None
    left_old = left_new = 0  # lines still owed by the current hunk
    new_no = 0
    for line in git(*DIFF, "--unified=0", "-M", *rng).split("\n"):
        if left_old > 0 or left_new > 0:
            tag, text = line[:1], line[1:]
            if tag == "+":
                added_lines.append((new_path, new_no, text))
                new_no += 1
                left_new -= 1
            elif tag == "-":
                if old_path and not DOC_FILE.search(old_path):
                    removed_count_code += 1
                left_old -= 1
            elif tag == " ":
                new_no += 1
                left_old -= 1
                left_new -= 1
            continue
        if line.startswith("--- "):
            p = header_path(line[4:])
            old_path = p[2:] if p.startswith("a/") else None
        elif line.startswith("+++ "):
            p = header_path(line[4:])
            new_path = p[2:] if p.startswith("b/") else None
            if new_path is None and p != "/dev/null":
                unscanned.append(p)
        elif line.startswith("@@"):
            m = re.match(r"@@ -\d+(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", line)
            if m:
                left_old = int(m.group(1)) if m.group(1) is not None else 1
                new_no = int(m.group(2))
                left_new = int(m.group(3)) if m.group(3) is not None else 1
    added_lines = [x for x in added_lines if x[0] is not None]
    return list(files.values()), added_lines, removed_count_code, unscanned


C_ESCAPES = {"a": 7, "b": 8, "t": 9, "n": 10, "v": 11, "f": 12, "r": 13,
             '"': 34, "\\": 92}


def header_path(raw):
    """Undo git's C-quoting of a ---/+++ header path ("b/a\\"b.js" -> b/a"b.js).
    core.quotePath=false stops octal escapes for non-ASCII, but quotes, backslashes
    and control characters are still quoted."""
    raw = raw.rstrip("\t")
    if not (len(raw) >= 2 and raw[0] == '"' and raw[-1] == '"'):
        return raw
    body, out, i = raw[1:-1], bytearray(), 0
    while i < len(body):
        c = body[i]
        if c != "\\" or i + 1 >= len(body):
            out += c.encode("utf-8")
            i += 1
        elif body[i + 1] in C_ESCAPES:
            out.append(C_ESCAPES[body[i + 1]])
            i += 2
        elif re.match(r"[0-7]{3}", body[i + 1:i + 4]):
            out.append(int(body[i + 1:i + 4], 8))
            i += 4
        else:
            out += c.encode("utf-8")
            i += 1
    return out.decode("utf-8", errors="replace")


def change_class(paths):
    if not paths:
        return "empty"
    if all(DOC_FILE.search(p) for p in paths):
        return "docs-only"
    if all(TEST_FILE.search(p) for p in paths):
        return "test-only"
    if all(CONFIG_FILE.search(p) for p in paths):
        return "config-only"
    return "code"


def size_class(changed, nfiles):
    if changed == 0 and nfiles == 0:
        return "empty"
    if changed <= INLINE_MAX_LINES and nfiles <= INLINE_MAX_FILES:
        return "small"
    if changed > CHUNK_LINES:
        return "chunk"
    if changed > LARGE_LINES:
        return "large"
    return "medium"


def is_shell_file(path):
    if re.search(r"\.(sh|bash|bats|zsh)$", path):
        return True
    if "." in os.path.basename(path) or not os.path.isfile(path):
        return False
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return bool(SHELL_SHEBANG.match(fh.readline()))
    except OSError:
        return False


def bugfix_mode(root, branch, mode):
    """Mirror tools/run-battery.sh: explicit --mode wins, else the branch name
    against hotfix/ or fix/<allowlisted ticket prefix>-."""
    if mode == "feature":
        return False, "--mode=feature"
    if mode == "bug-fix":
        return True, "--mode=bug-fix"
    prefixes = []
    cfg = os.path.join(root, ".cr-battery-ticket-prefixes")
    if os.path.isfile(cfg):
        with open(cfg, encoding="utf-8", errors="replace", newline="") as fh:
            # Line by line exactly as grep -E '^[A-Z]+$' reads it: "ABC\r" is no match.
            prefixes = [x.rstrip("\n") for x in fh if re.fullmatch(r"[A-Z]+", x.rstrip("\n"))][:50]
    prefixes = prefixes or list(DEFAULT_TICKET_PREFIXES)
    rx = r"^(hotfix/|fix/(%s)-)" % "|".join(prefixes)
    return bool(re.match(rx, branch)), "branch %r against %s" % (branch, rx)


# --- sentinels ---------------------------------------------------------------

# Validates every sentinel with the same bash functions the pre-push gates and
# tools/push-readiness.sh use, and prints one tab-separated line per sentinel:
#   name  state  sha  verdict  carried  detail
SENTINEL_DRIVER = r"""
lib="$1"; head="$2"; shift 2
source "$lib/code-review-sentinel.sh"
source "$lib/review-sentinel.sh"
source "$lib/sentinel-scope.sh"
for s in "$@"; do
  if [[ ! -f "$s" ]]; then printf '%s\tmissing\t\t\t0\t\n' "$s"; continue; fi
  validate_review_sentinel "$s"
  sha="$SENTINEL_SHA" verdict="$SENTINEL_VERDICT"
  if [[ -n "$SENTINEL_ERROR" ]]; then
    printf '%s\tmalformed\t%s\t%s\t0\t%s\n' "$s" "$sha" "$verdict" "$SENTINEL_ERROR"; continue
  fi
  accepted="$(review_sentinel_accepted_verdicts "$s")"
  case " $accepted " in
    *" $verdict "*) ;;
    *) printf '%s\tnot-clearing\t%s\t%s\t0\tverdict does not clear its gate (accepts: %s)\n' \
         "$s" "$sha" "$verdict" "$accepted"; continue ;;
  esac
  if [[ "$sha" == "$head" ]]; then printf '%s\tvalid\t%s\t%s\t0\t\n' "$s" "$sha" "$verdict"; continue; fi
  if sentinel_scope_unchanged "$sha" "$head" "$(sentinel_scope_classifier_for "$s")"; then
    printf '%s\tvalid\t%s\t%s\t1\t\n' "$s" "$sha" "$verdict"
  else
    printf '%s\tstale\t%s\t%s\t0\t%s\n' "$s" "$sha" "$verdict" "$(printf '%s' "$SENTINEL_SCOPE_CHANGED" | tr '\n' ' ')"
  fi
done
"""


def sentinel_states(head, staged):
    env = dict(os.environ, REPO_ROOT=TOOLS_ROOT)
    r = run(["bash", "-c", SENTINEL_DRIVER, "sentinels", LIB_DIR, head, *SENTINELS], env=env)
    out = {}
    for line in r.stdout.splitlines():
        name, state, sha, verdict, carried, detail = line.split("\t", 5)
        entry = {"state": state}
        if sha:
            entry.update(sha=sha, verdict=verdict)
        if carried == "1":
            entry["carried"] = True
        if detail.strip():
            entry["detail"] = detail.strip()
        # A tree: sentinel (run-battery.sh --staged) is promoted by the
        # post-commit hook; until then the gates call it stale. It does cover
        # an index whose tree matches, which is what --staged asks about.
        if staged and state == "stale" and sha.startswith("tree:") \
                and sha[5:] == git("write-tree").strip():
            entry = {"state": "valid", "sha": sha, "verdict": verdict,
                     "detail": "covers the staged tree; the post-commit hook promotes it"}
        out[name] = entry
    missing = [n for n in SENTINELS if n not in out]
    if missing:
        raise UsageError("sentinel check printed nothing for %s" % ", ".join(missing))
    return out


# --- routes ------------------------------------------------------------------

def routes_for(paths):
    if not paths:
        return {"blocks": [], "exit": 0}
    r = run([REVIEW_SH, "route", *paths], check=False)
    blocks, cur = [], None
    for line in r.stdout.splitlines():
        if not line.strip():
            cur = None
            continue
        if line.startswith(("SKILL: ", "EXEMPT: ")) or cur is None:
            cur = {"files": []}
            blocks.append(cur)
        if line.startswith("SKILL: "):
            cur["skill"] = line[7:]
        elif line.startswith("EXEMPT: "):
            cur["exempt"] = line[8:]
        elif line.startswith("RUNNER: "):
            cur["runner"] = line[8:]
        elif line.startswith("SENTINEL: "):
            cur["sentinel"] = line[10:]
        elif line.startswith("  "):
            cur["files"].append(line.strip())
    out = {"blocks": blocks, "exit": r.returncode}
    if r.returncode != 0:
        out["error"] = r.stderr.strip()
    return out


# --- signals -----------------------------------------------------------------

def scan_signals(files, added, cls, changed_lines):
    code_lines = [(p, n, t) for (p, n, t) in added if not DOC_FILE.search(p)]
    fired, judgment = [], []
    for sig in SIGNALS:
        hits = []
        if sig["match"] == "judgment":
            if cls not in ("empty", "docs-only"):
                judgment.append({"id": sig["id"], "row": sig["row"], "reviewers": sig["reviewers"]})
            continue
        if sig["match"] == "added":
            rx = re.compile(sig["regex"])
            hits = ["%s:%d" % (p, n) for (p, n, t) in code_lines if rx.search(t)]
        elif sig["match"] == "status":
            hits = ["%s (%s)" % (f.get("renamed_from", f["path"]), {"R": "renamed", "D": "deleted"}[f["status"]])
                    for f in files if f["status"] in ("R", "D")]
        elif sig["match"] == "class":
            hits = ["all %d changed files are tests" % len(files)] if cls == "test-only" else []
        if sig["id"] == "shell":
            hits = ["%s (shell file)" % f["path"] for f in files
                    if f["status"] != "D" and is_shell_file(f["path"])] + hits
        if sig["id"] == "security":
            hits = ["%s (path)" % f["path"] for f in files if "_disabled/" in f["path"]] + hits
        if sig["id"] == "io-loop" and changed_lines > LARGE_LINES:
            hits = ["%d changed lines (> %d)" % (changed_lines, LARGE_LINES)] + hits
        if hits:
            fired.append({"kind": "signal", "id": sig["id"], "row": sig["row"],
                          "reviewers": sig["reviewers"], "heuristic": sig.get("heuristic", False),
                          "hits": hits[:MAX_HITS], "hit_count": len(hits)})
    mandatory = []
    for rule in MANDATORY:
        rx = re.compile(rule["regex"])
        hits = ["%s:%d" % (p, n) for (p, n, t) in code_lines if rx.search(t)]
        if rule["path"]:
            prx = re.compile(rule["path"])
            hits = ["%s (path)" % f["path"] for f in files if prx.search(f["path"])] + hits
        if hits:
            mandatory.append({"kind": "mandatory", "id": rule["id"], "rule": rule["rule"],
                              "reviewers": [rule["reviewer"]], "heuristic": True,
                              "hits": hits[:MAX_HITS], "hit_count": len(hits)})
    return fired, mandatory, judgment


def base_reviewers(cls):
    if cls == "empty":
        return []
    if cls == "docs-only":
        return [{"kind": "base", "id": "docs-only", "reviewers": ["Standards Enforcer"]}]
    if cls == "config-only":
        return [{"kind": "base", "id": "config-only", "reviewers": ["Guardian"]}]
    return [{"kind": "base", "id": "combined", "reviewers": list(COMBINED_LENSES),
             "note": "one combined reviewer; it must answer the placement question"}]


def dispatch_plan(cls, rows, bugfix):
    combined = cls in ("code", "test-only")
    named = []
    for row in rows:
        for r in row["reviewers"]:
            if r not in named:
                named.append(r)
    extra = [r for r in named if r not in COMBINED_LENSES]
    if bugfix and "BugPath Verifier" not in extra:
        extra.append("BugPath Verifier")
    lenses = [r for r in named if r in COMBINED_LENSES]
    return {"combined_reviewer": combined, "lenses": lenses, "extra_agents": extra}


def inline_exemption(changed, nfiles, bugfix, fired, mandatory, judgment):
    reasons = []
    if changed > INLINE_MAX_LINES:
        reasons.append("%d changed lines > %d" % (changed, INLINE_MAX_LINES))
    if nfiles > INLINE_MAX_FILES:
        reasons.append("%d files > %d" % (nfiles, INLINE_MAX_FILES))
    if bugfix:
        reasons.append("bug-fix branch: BugPath Verifier needs full dispatch")
    for row in fired:
        reasons.append("signal row fired: %s" % row["id"])
    for row in mandatory:
        reasons.append("mandatory activation fired: %s" % row["id"])
    eligible = not reasons
    if eligible:
        reasons.append("<= %d lines, <= %d files, no bug-fix mode, no signal or mandatory row fired"
                       % (INLINE_MAX_LINES, INLINE_MAX_FILES))
        reasons.append("still requires: the reviewing agent wrote or fully re-read this code in this session")
        if judgment:
            reasons.append("still requires: rule out the judgment rows (%s)"
                           % ", ".join(j["id"] for j in judgment))
    return eligible, reasons


# --- main --------------------------------------------------------------------

def preflight(base, staged, mode):
    if run(["git", "rev-parse", "--git-dir"], check=False).returncode:
        raise UsageError("not a git repository")
    root = git("rev-parse", "--show-toplevel").strip()
    os.chdir(root)
    head = git("rev-parse", "HEAD").strip()
    branch = git("branch", "--show-current").strip()
    rng, base_sha = diff_range(base, staged)
    files, added, removed_code, unscanned = collect_diff(rng)
    paths = [f["path"] for f in files]
    total_added = sum(f["added"] for f in files)
    total_removed = sum(f["removed"] for f in files)
    changed = total_added + total_removed
    cls = change_class(paths)
    bugfix, bugfix_reason = bugfix_mode(root, branch, mode)
    fired, mandatory, judgment = scan_signals(files, added, cls, changed)
    if not removed_code:
        judgment = [j for j in judgment if j["id"] != "caller-removal"]
    rows = base_reviewers(cls) + fired + mandatory
    eligible, reasons = inline_exemption(changed, len(files), bugfix, fired, mandatory, judgment)
    if unscanned:
        # Fail closed: lines that were never scanned cannot vouch for "no signal".
        if eligible:
            reasons = []
        eligible = False
        reasons.append("added lines not scanned (unparsed diff header): %s" % ", ".join(unscanned[:5]))
    dirty = run(["git", "diff", "--no-ext-diff", "--quiet"], check=False).returncode or \
        run(["git", "diff", "--no-ext-diff", "--cached", "--quiet"], check=False).returncode
    route_paths = paths + [f["renamed_from"] for f in files if f.get("renamed_from")]
    report = {
        "head": head,
        "branch": branch,
        "mode": "staged" if staged else "branch",
        "base": "HEAD" if staged else base,
        "base_sha": base_sha,
        "worktree_clean": not dirty,
        "sentinels": sentinel_states(head, staged),
        "bugfix_mode": bugfix,
        "bugfix_mode_reason": bugfix_reason,
        "diff": {"files": files, "file_count": len(files), "added": total_added,
                 "removed": total_removed, "changed_lines": changed,
                 "change_class": cls, "size_class": size_class(changed, len(files))},
        "routes": routes_for(route_paths),
        "reviewers": rows,
        "dispatch": dispatch_plan(cls, rows, bugfix),
        "judgment_required": judgment,
        "unscanned_files": unscanned,
        "inline_exemption_eligible": eligible,
        "inline_exemption_reasons": reasons,
    }
    report['strategy'] = review_strategy(root, report)
    return report


def strategy_directory(root):
    from pathlib import Path
    common = Path(git('rev-parse', '--git-common-dir').strip())
    return ((Path(root) / common) if not common.is_absolute() else common).resolve() / 'review-strategy-v1'


def strategy_claim(root, snapshot, name):
    path = strategy_directory(root) / (snapshot + '.' + name + '.json')
    if not path.exists() and not path.is_symlink():
        return None
    if path.is_symlink():
        raise ValueError('review strategy claim must not be a symlink')
    row = json.loads(path.read_text())
    if (not isinstance(row, dict) or row.get('schema') != 1 or
            row.get('snapshot') != snapshot or row.get('class') != name):
        raise ValueError('review strategy claim binding mismatch')
    return row


def native_binding_valid(root, claim, sentinel):
    from pathlib import Path
    import hashlib
    try:
        producer = claim['native_writer']
        expected = {'code': 'run-battery.sh', 'skill': 'run-llm-skill-review.sh', 'design': 'run-phr.sh'}[claim['class']]
        writer = Path(__file__).resolve().parent / expected
        if (producer['script'] != expected or type(producer['exit']) is not int or producer['exit'] != 0 or
                producer['snapshot'] != claim['snapshot'] or
                producer['sha256'] != hashlib.sha256(writer.read_bytes()).hexdigest() or
                type(producer['started']) is not int or type(producer['completed']) is not int or
                not 0 < producer['started'] <= producer['completed']):
            return False
        directory = strategy_directory(root)
        log = directory / producer['log']
        if (log.parent != directory or log.is_symlink() or
                not re.fullmatch(r'native-' + re.escape(claim['class']) + r'-[0-9]+\.log', log.name) or
                hashlib.sha256(log.read_bytes()).hexdigest() != producer['log_sha256']):
            return False
        original = claim['sentinel_record']
        if hashlib.sha256(original.encode()).hexdigest() != claim['sentinel_sha256']:
            return False
        path = Path(root) / sentinel
        if path.is_symlink():
            return False
        current = path.read_text()
        if current == original:
            return True
        # Native post-commit carry changes only SHA; all verdict/score/time
        # fields remain byte-identical and the new commit contains the exact
        # reviewed index tree. This is review reuse, not publication authority.
        old, new = original.rstrip('\n').split('|'), current.rstrip('\n').split('|')
        return (len(old) == len(new) and old[:1] == new[:1] and old[2:] == new[2:] and
                re.fullmatch(r'[a-f0-9]{40}', new[1]) is not None and
                git('rev-parse', new[1] + '^{tree}').strip() == claim['review_tree'])
    except (OSError, ValueError, KeyError, TypeError, IndexError, UsageError):
        return False


_STRATEGY_OBSERVATION = None


def current_review_snapshot(root, report):
    from pathlib import Path
    observation = _STRATEGY_OBSERVATION
    if (not observation or observation['root'] != str(Path(root).resolve()) or
            observation['snapshot'] != report['strategy']['snapshot'] or not observation['fresh']()):
        return None
    return observation['snapshot']


def review_strategy(root, report):
    """Resolve required review classes from native evidence, without dispatch.

    Source, installed review guidance, configuration and behavior environment
    bind the snapshot; HEAD/status messages are not inputs on their own.
    Standalone legacy copies remain readable but explicitly UNENFORCED.
    """
    from pathlib import Path
    import hashlib
    import types
    root = Path(root)
    def load(name, path):
        module = types.ModuleType(name)
        module.__file__ = str(path)
        exec(compile(path.read_bytes(), str(path), 'exec'), module.__dict__)
        return module
    try:
        receipt = load('receipt', root / 'tools/validation-receipt.py')
        strategy = load('strategy', root / 'tools/validation-strategy.py')
    except OSError:
        return {'snapshot': None, 'classes': {}, 'status': 'UNENFORCED',
                'reason': 'missing-native-strategy-helper'}
    snapshotter = load('snapshotter', root / 'tools/review-context-snapshot.py')
    payload, fresh, stats = snapshotter.resolve(receipt, root)
    snapshot = hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()
    global _STRATEGY_OBSERVATION
    _STRATEGY_OBSERVATION = {'root': str(root.resolve()), 'snapshot': snapshot,
                             'fresh': fresh, 'stats': stats}
    classes = {}
    mapping = {'.code-review-cleared': 'code', '.llm-skill-review-cleared': 'skill', '.phr-cleared': 'design'}
    for block in report['routes']['blocks']:
        sentinel = block.get('sentinel')
        if sentinel not in mapping:
            continue
        name = mapping[sentinel]
        state = report['sentinels'][sentinel]['state']
        resolved_state = 'INVALID' if state in ('malformed', 'not-clearing') else 'MISSING'
        try:
            claim = strategy_claim(root, snapshot, name)
            if claim:
                expected = strategy.choose(snapshot, 'review', (name,), 'MISSING')
                if claim.get('decision') != expected:
                    raise ValueError('original review decision is unprovable')
                if claim.get('result') == 'PASS':
                    if (state in ('valid', 'stale') and claim.get('verdict') == report['sentinels'][sentinel].get('verdict')
                            and native_binding_valid(root, claim, sentinel)):
                        resolved_state = 'PASS'
                    else:
                        resolved_state = 'INVALID'
                else:
                    resolved_state = 'RUNNING_UNRESOLVED'
        except (OSError, ValueError, TypeError):
            resolved_state = 'INVALID'
        classes[name] = strategy.choose(snapshot, 'review', (name,), resolved_state,
                                       (name,) if resolved_state == 'PASS' else ())
    return {'snapshot': snapshot, 'classes': classes, 'status': 'RESOLVED'}


def main(argv):
    base, staged, mode, base_given = "origin/dev", False, None, False
    # A GIT_DIR leaked from a hook under a linked worktree would point every
    # git call (and review.sh) at another repo than the sentinels read here.
    for v in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_PREFIX"):
        os.environ.pop(v, None)
    it = iter(argv)
    try:
        for a in it:
            if a in ("-h", "--help"):
                sys.stdout.write(__doc__)
                return 0
            if a == "--list-signals":
                print(json.dumps({"signals": SIGNALS, "mandatory": MANDATORY}, indent=2))
                return 0
            if a == "--staged":
                staged = True
            elif a in ("--base", "--mode"):
                val = next(it, None)
                if not val:
                    raise UsageError("%s needs a value" % a)
                if a == "--base":
                    base, base_given = val, True
                else:
                    mode = val
            elif a.startswith("--base="):
                base, base_given = a.split("=", 1)[1], True
            elif a.startswith("--mode="):
                mode = a.split("=", 1)[1]
            else:
                raise UsageError("unknown argument %r" % a)
        if staged and base_given:
            raise UsageError("--base and --staged are exclusive")
        if mode is not None and mode not in ("bug-fix", "feature"):
            raise UsageError("--mode must be bug-fix or feature")
        print(json.dumps(preflight(base, staged, mode), indent=2))
        return 0
    except UsageError as e:
        print("usage error: %s (see --help)" % e, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
