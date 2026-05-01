#!/usr/bin/env bash
# subagent-stop-claims-evidence.sh — Item 8. SubagentStop claims-evidence hook.
# Reads the sub-agent's last assistant message from transcript_path and checks
# whether result claims (done, fixed, passing, etc.) are paired with concrete
# evidence (code block, exit code, test summary). Advisory only — always exits 0.
#
# Item 8 of the Claude Code 12-point guardrails plan.
# Exit codes: 0 always.
set -euo pipefail
if [[ "${CLAUDE_HOOKS_BYPASS:-0}" == "1" ]]; then exit 0; fi
trap 'exit 0' ERR

INPUT="$(cat)"

TRANSCRIPT="$(printf '%s' "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('transcript_path', ''))
" 2>/dev/null | tr -d '\n' || true)"

[[ -z "$TRANSCRIPT" ]] && exit 0
[[ -f "$TRANSCRIPT" ]] || exit 0

python3 - "$TRANSCRIPT" <<'PYEOF'
import sys, json, re, collections

transcript_path = sys.argv[1]
TAIL = 500  # read only the last 500 lines — sufficient for any realistic final message
try:
    with open(transcript_path, encoding='utf-8', errors='replace') as f:
        lines = collections.deque(
            (ln.strip() for ln in f if ln.strip()), maxlen=TAIL
        )
except OSError as exc:
    print(f"claims-evidence: could not read transcript ({exc})")
    sys.exit(0)

# Find the last assistant message content.
last_content = ''
for line in lines:
    try:
        obj = json.loads(line)
    except json.JSONDecodeError:
        continue
    # Support both legacy {role, content} and current {type, message} formats.
    role = obj.get('role', '')
    content = obj.get('content', '')
    if not role and obj.get('type') == 'assistant':
        msg = obj.get('message', {}) or {}
        role = msg.get('role', '')
        content = msg.get('content', '')
    if role == 'assistant':
        if isinstance(content, list):
            last_content = ' '.join(
                p.get('text', '') for p in content if isinstance(p, dict)
            )
        elif isinstance(content, str):
            last_content = content

if not last_content:
    sys.exit(0)

CLAIMS_RE = re.compile(
    r'\b(done|fixed|passing|verified|works|complete|all\s+green)\b',
    re.IGNORECASE,
)
EVIDENCE_RE = re.compile(
    r'```|exit\s+\d+|exit\s+code[:\s]+\d+|\d+\s+tests?\s+passed|^ok\s+\d+',
    re.IGNORECASE | re.MULTILINE,
)

content_lines = last_content.split('\n')
evidence_line_nos = {
    i for i, ln in enumerate(content_lines) if EVIDENCE_RE.search(ln.lstrip())
}

unpaired = []
seen = set()
for m in CLAIMS_RE.finditer(last_content):
    claim = m.group(0).lower().replace(' ', '_')
    if claim in seen:
        continue
    line_no = last_content[: m.start()].count('\n')
    if not any(abs(e - line_no) <= 10 for e in evidence_line_nos):
        seen.add(claim)
        unpaired.append(m.group(0).lower())

if unpaired:
    print(f"unpaired claims: {', '.join(unpaired)}")
else:
    print('all claims paired with evidence')
PYEOF
