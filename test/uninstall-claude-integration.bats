#!/usr/bin/env bats

# uninstall.sh must remove what install.sh puts into Claude Code -- and nothing
# the user owns. An end-to-end sandbox test on 2026-09-21 found that all of
# this survived even --purge: 10 hook scripts, their 9 settings.json
# registrations (so "uninstalled" sessions kept running every hook), 55
# mirrored slash commands, _shared/ skill support files, the ~/.codex
# ecosystem marker, and sp-* CLI links left dangling into the purged checkout.
#
# The fixture is a synthetic $HOME, not a real install: install.sh writes the
# machine-global /usr/local/bin, which a test must never touch. The link sweep
# only removes links that resolve into the fixture's own managed directory, so
# real links elsewhere cannot be affected.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    local c="$HOME/.claude" m="$HOME/.codex/superpowers-plus"
    mkdir -p "$c/hooks" "$c/commands" "$c/skills/_shared" "$HOME/.codex/skills/_shared" \
             "$m/tools" "$HOME/.local/bin" "$HOME/.config/claude-hooks"

    # Everything install.sh would have put there.
    local h
    for h in "$REPO_ROOT"/tools/claude-hooks/*.sh; do
        cp "$h" "$c/hooks/"
    done
    printf -- '---\ndescription: "x"\nsource: "claude-commands-mirror"\n---\nbody\n' > "$c/commands/mirrored.md"
    echo shared > "$c/skills/_shared/x.md"
    echo shared > "$HOME/.codex/skills/_shared/x.md"
    echo codex > "$HOME/.codex/.superpowers-ecosystem"
    printf '#!/bin/sh\n' > "$m/tools/sp-update.sh"
    ln -s "$m/tools/sp-update.sh" "$HOME/.local/bin/sp-update"

    # Things the USER owns, which must survive.
    printf '#!/bin/sh\n' > "$c/hooks/users-own-hook.sh"
    printf -- '---\ndescription: "mine"\n---\nmine\n' > "$c/commands/my-own.md"
    printf 'my-term\n' > "$HOME/.config/claude-hooks/internal-terms.txt"
    ln -s /somewhere/else "$HOME/.local/bin/sp-mine"

    # settings.json: one user hook, every shipped hook registered, other keys.
    python3 - "$c/settings.json" "$REPO_ROOT/tools/claude-hooks" <<'PY'
import json, os, sys
path, src = sys.argv[1], sys.argv[2]
ours = [{"type": "command", "command": "$HOME/.claude/hooks/" + n}
        for n in sorted(os.listdir(src)) if n.endswith(".sh")]
data = {"model": "opus", "permissions": {"allow": ["Bash(ls:*)"]},
        "hooks": {"UserPromptSubmit": [{"hooks": [{"type": "command", "command": "/user/own/hook.sh"}]}],
                  "PreToolUse": [{"matcher": "Bash", "hooks": ours}]}}
json.dump(data, open(path, "w"), indent=2)
PY
}

settings_count() {  # $1 = python expression over the list of hook commands
    python3 - "$HOME/.claude/settings.json" "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
cmds = [h["command"] for e in d.get("hooks", {}).values() for g in e for h in g["hooks"]]
print(eval(sys.argv[2]))
PY
}

@test "uninstall: removes shipped hooks and their settings.json registrations" {
    run bash "$REPO_ROOT/uninstall.sh" --yes
    [ "$status" -eq 0 ]
    [ "$(settings_count 'sum(".claude/hooks/" in c for c in cmds)')" = 0 ]
    local shipped
    shipped="$(find "$REPO_ROOT/tools/claude-hooks" -name '*.sh' | head -1)"
    [ ! -e "$HOME/.claude/hooks/$(basename "$shipped")" ]
}

@test "uninstall: keeps the user's own hooks, hook entry and other settings" {
    run bash "$REPO_ROOT/uninstall.sh" --yes
    [ "$status" -eq 0 ]
    [ -f "$HOME/.claude/hooks/users-own-hook.sh" ]
    [ "$(settings_count '"/user/own/hook.sh" in cmds')" = True ]
    run python3 -c "import json;d=json.load(open('$HOME/.claude/settings.json'));print(d['model'], d['permissions']['allow'][0])"
    [ "$output" = "opus Bash(ls:*)" ]
}

@test "uninstall: backs settings.json up before editing it" {
    run bash "$REPO_ROOT/uninstall.sh" --yes
    [ "$status" -eq 0 ]
    compgen -G "$HOME/.claude/settings.json.pre-uninstall.*" >/dev/null
}

@test "uninstall: removes only mirrored commands" {
    run bash "$REPO_ROOT/uninstall.sh" --yes
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.claude/commands/mirrored.md" ]
    [ -f "$HOME/.claude/commands/my-own.md" ]
}

@test "uninstall: removes _shared/ from both skill directories" {
    run bash "$REPO_ROOT/uninstall.sh" --yes
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.claude/skills/_shared" ]
    [ ! -e "$HOME/.codex/skills/_shared" ]
}

@test "uninstall: keeps the user's pattern lists" {
    run bash "$REPO_ROOT/uninstall.sh" --yes
    [ "$status" -eq 0 ]
    [ -f "$HOME/.config/claude-hooks/internal-terms.txt" ]
}

@test "uninstall --dry-run: reports, changes nothing" {
    local before
    before="$(cd "$HOME" && find . | sort | xargs -I{} sh -c 'printf "%s " "{}"; [ -f "{}" ] && cksum < "{}" || echo d')"
    run bash "$REPO_ROOT/uninstall.sh" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Would unregister"* ]]
    [ "$before" = "$(cd "$HOME" && find . | sort | xargs -I{} sh -c 'printf "%s " "{}"; [ -f "{}" ] && cksum < "{}" || echo d')" ]
}

@test "uninstall --purge: removes sp-* links into the checkout, keeps others" {
    run bash "$REPO_ROOT/uninstall.sh" --yes --purge
    [ "$status" -eq 0 ]
    [ ! -L "$HOME/.local/bin/sp-update" ]
    [ -L "$HOME/.local/bin/sp-mine" ]
    [ ! -e "$HOME/.codex/.superpowers-ecosystem" ]
}

# Regression: a function ending in `[[ -d x ]] && log_info` returns 1 when x is
# absent, which aborted uninstall.sh under `set -e`.
@test "uninstall: succeeds when optional Claude directories are absent" {
    rm -rf "$HOME/.config/claude-hooks" "$HOME/.claude/commands" "$HOME/.claude/settings.json"
    run bash "$REPO_ROOT/uninstall.sh" --yes
    [ "$status" -eq 0 ]
}

# Registrations are matched wherever the shipped file appears in the command,
# not only at its end: an entry with arguments or quotes used to survive while
# its hook file was deleted, leaving settings.json pointing at nothing.
@test "uninstall: unregisters every realistic spelling of a shipped hook command" {
    local n
    n="$(basename "$(find "$REPO_ROOT/tools/claude-hooks" -name '*.sh' | sort | head -1)")"
    python3 - "$HOME/.claude/settings.json" "$n" <<'PY'
import json, sys
p, n = sys.argv[1], sys.argv[2]
d = json.load(open(p))
variants = [f"~/.claude/hooks/{n}", "${HOME}/.claude/hooks/" + n, f"/Users/someone/.claude/hooks/{n}",
            f'"$HOME/.claude/hooks/{n}"', f'"$HOME/.claude/hooks/{n}" --strict', f"bash $HOME/.claude/hooks/{n} x"]
d["hooks"]["Stop"] = [{"hooks": [{"type": "command", "command": v} for v in variants]}]
json.dump(d, open(p, "w"))
PY
    run bash "$REPO_ROOT/uninstall.sh" --yes
    [ "$status" -eq 0 ]
    [ "$(settings_count 'sum(".claude/hooks/" in c for c in cmds)')" = 0 ]
    [ "$(settings_count '"/user/own/hook.sh" in cmds')" = True ]
}

# A same-directory hook whose name the repo does not ship is the user's.
@test "uninstall: never unregisters a user hook that merely lives in .claude/hooks" {
    python3 - "$HOME/.claude/settings.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["hooks"]["Stop"] = [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/users-own-hook.sh"}]}]
json.dump(d, open(p, "w"))
PY
    run bash "$REPO_ROOT/uninstall.sh" --yes
    [ "$status" -eq 0 ]
    [ "$(settings_count '"$HOME/.claude/hooks/users-own-hook.sh" in cmds')" = True ]
}

# Regression: with tools/claude-hooks present but empty, shipped_hook_names'
# loop ended on a false `[[ -f ]]` and returned 1, aborting uninstall.sh under
# `set -e` halfway through.
@test "uninstall: does not abort when the shipped-hooks directory is empty" {
    local copy="$BATS_TEST_TMPDIR/repo-copy"
    mkdir -p "$copy/tools/claude-hooks"
    cp "$REPO_ROOT/uninstall.sh" "$copy/"
    run bash "$copy/uninstall.sh" --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed 0 Claude hook script(s)"* ]]
}

@test "uninstall --purge: removes a RELATIVE sp-* link into the checkout" {
    ln -s ../../.codex/superpowers-plus/tools/sp-update.sh "$HOME/.local/bin/sp-rel"
    run bash "$REPO_ROOT/uninstall.sh" --yes --purge
    [ "$status" -eq 0 ]
    [ ! -L "$HOME/.local/bin/sp-rel" ]
    [ -L "$HOME/.local/bin/sp-mine" ]
}
