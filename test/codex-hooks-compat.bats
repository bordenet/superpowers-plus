#!/usr/bin/env bats

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd -P)"
    SANDBOX="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
    export HOME="$SANDBOX/home with spaces" CODEX_HOME
    CODEX_HOME="$HOME/.codex"
    export CODEX_SKILLS_DIR="$CODEX_HOME/skills"
    PROJECT="$SANDBOX/project with spaces"
    mkdir -p "$PROJECT/.ai-guidance" "$HOME/.augment/rules" \
        "$HOME/.claude/hooks" "$CODEX_HOME/hooks" "$CODEX_SKILLS_DIR/fixture-handler"
    git init -q "$PROJECT"
    printf 'Fixture invariants.\n' > "$PROJECT/.ai-guidance/invariants.md"
    printf 'Fixture rules.\n' > "$HOME/.augment/rules/core.md"
    cat > "$CODEX_SKILLS_DIR/fixture-handler/skill.md" <<'SKILL'
---
name: fixture-handler
description: Handle fixture requests
triggers: [fixture-handler]
---
Handle fixture requests.
SKILL
    for name in session-start-rules-integrity.sh user-prompt-submit-skill-router.sh; do
        cp "$ROOT/tools/claude-hooks/$name" "$HOME/.claude/hooks/$name"
        cp "$ROOT/tools/claude-hooks/$name" "$CODEX_HOME/hooks/$name"
    done
    SESSION_INPUT="$(printf '{"hook_event_name":"SessionStart","session_id":"fixture","cwd":"%s","source":"startup","permission_mode":"default"}' "$PROJECT")"
    PROMPT_INPUT="$(printf '{"hook_event_name":"UserPromptSubmit","session_id":"fixture","cwd":"%s","prompt":"fixture-handler","turn_id":"fixture-turn","permission_mode":"default"}' "$PROJECT")"
}

@test "Codex SessionStart returns native JSON context when guidance exists" {
    run "$CODEX_HOME/hooks/session-start-rules-integrity.sh" <<< "$SESSION_INPUT"
    [ "$status" -eq 0 ]
    python3 -c 'import json,sys; d=json.loads(sys.argv[1])["hookSpecificOutput"]; assert d["hookEventName"]=="SessionStart"; assert "rules-file integrity OK" in d["additionalContext"]; assert ".ai-guidance/invariants.md" in d["additionalContext"]' "$output"
}

@test "Claude SessionStart retains its plain-text context" {
    run "$HOME/.claude/hooks/session-start-rules-integrity.sh" <<< "$SESSION_INPUT"
    [ "$status" -eq 0 ]
    [[ "$output" == "[claude-hooks/SessionStart] rules-file integrity OK; invariants at $PROJECT/.ai-guidance/invariants.md" ]]
}

@test "Codex prompt router returns a native JSON advisory" {
    run "$CODEX_HOME/hooks/user-prompt-submit-skill-router.sh" <<< "$PROMPT_INPUT"
    [ "$status" -eq 0 ]
    python3 -c 'import json,sys; d=json.loads(sys.argv[1])["hookSpecificOutput"]; assert d["hookEventName"]=="UserPromptSubmit"; assert "fixture-handler" in d["additionalContext"]' "$output"
}

@test "Codex router leaves Claude cache and metrics untouched" {
    printf '{"version":999,"entries":[]}\n' > "$HOME/.claude/hooks/skill-router-cache.json"
    printf 'Claude metrics sentinel.\n' > "$HOME/.claude/hooks/skill-router-metrics.jsonl"
    cp "$HOME/.claude/hooks/skill-router-cache.json" "$SANDBOX/cache-before"
    cp "$HOME/.claude/hooks/skill-router-metrics.jsonl" "$SANDBOX/metrics-before"
    run "$CODEX_HOME/hooks/user-prompt-submit-skill-router.sh" <<< "$PROMPT_INPUT"
    [ "$status" -eq 0 ]
    cmp "$SANDBOX/cache-before" "$HOME/.claude/hooks/skill-router-cache.json"
    cmp "$SANDBOX/metrics-before" "$HOME/.claude/hooks/skill-router-metrics.jsonl"
    [ -s "$CODEX_HOME/hooks/skill-router-cache.json" ]
    [ -s "$CODEX_HOME/hooks/skill-router-metrics.jsonl" ]
}

@test "installer refreshes only the two registered Codex copies without changing registration" {
    python3 - "$HOME" <<'JSON'
import json,sys,pathlib
h=pathlib.Path(sys.argv[1]); hooks={}
for event,name in [('SessionStart','session-start-rules-integrity.sh'),('UserPromptSubmit','user-prompt-submit-skill-router.sh')]:
    hooks[event]=[{'hooks':[{'type':'command','command':"'"+str(h/'.codex/hooks'/name)+"'"}]}]
hooks['Stop']=[{'hooks':[{'type':'command','command':'echo unrelated'}]}]
(h/'.codex/hooks.json').write_text(json.dumps({'hooks':hooks})+'\n')
JSON
    cp "$CODEX_HOME/hooks.json" "$SANDBOX/registration-before"
    printf 'stale\n' > "$CODEX_HOME/hooks/session-start-rules-integrity.sh"
    printf 'stale\n' > "$CODEX_HOME/hooks/user-prompt-submit-skill-router.sh"
    run bash "$ROOT/setup/install-claude-guardrails.sh"
    [ "$status" -eq 0 ]
    cmp "$SANDBOX/registration-before" "$CODEX_HOME/hooks.json"
    for name in session-start-rules-integrity.sh user-prompt-submit-skill-router.sh; do
        cmp "$ROOT/tools/claude-hooks/$name" "$CODEX_HOME/hooks/$name"
        [ -x "$CODEX_HOME/hooks/$name" ]
    done
}

@test "installer leaves an unregistered Codex copy alone" {
    printf 'unmanaged\n' > "$CODEX_HOME/hooks/session-start-rules-integrity.sh"
    run bash "$ROOT/setup/install-claude-guardrails.sh"
    [ "$status" -eq 0 ]
    [ "$(cat "$CODEX_HOME/hooks/session-start-rules-integrity.sh")" = unmanaged ]
}
