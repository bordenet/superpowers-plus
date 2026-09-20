#!/usr/bin/env bats
# Behavioral invariants for context-ferry. Scan the resident kernel and optional
# reference together so compaction-safety behavior survives kernel splitting.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  SKILL="$REPO_ROOT/skills/productivity/context-ferry/skill.md"
  REFERENCE="$REPO_ROOT/skills/productivity/context-ferry/reference.md"
  SECTION_LOADER="$REPO_ROOT/tools/section-loader.sh"
  TMPDIR_="$(mktemp -d)"
  CORPUS="$(mktemp)"
  cat "$SKILL" > "$CORPUS"
  if [[ -r "$REFERENCE" ]]; then
    cat "$REFERENCE" >> "$CORPUS"
  fi
}

teardown() {
  rm -f "$CORPUS"
  rm -rf "$TMPDIR_"
}

render_context_ferry_loader() {
  local skill_file="$1" section="$2" script_file="$3"

  awk '
    /<!-- kernel-split-reference-loader:start -->/ { in_block = 1; next }
    in_block && /^```bash$/ { next }
    in_block && /^```$/ { exit }
    in_block { print }
  ' "$skill_file" \
    | sed "s|_section='<section heading>'|_section='$section'|" \
    > "$script_file"
}

install_managed_loader() {
  local home_dir="$1"
  mkdir -p "$home_dir/.codex/superpowers-plus/tools"
  cp "$SECTION_LOADER" "$home_dir/.codex/superpowers-plus/tools/section-loader.sh"
  chmod +x "$home_dir/.codex/superpowers-plus/tools/section-loader.sh"
}

install_context_ferry_fixture() {
  local home_dir="$1" layout="$2" reference_source="${3:-$REFERENCE}"
  local install_dir skill_file

  case "$layout" in
    agents)
      install_dir="$home_dir/.agents/skills/context-ferry"
      skill_file="$install_dir/SKILL.md"
      ;;
    codex)
      install_dir="$home_dir/.codex/skills/context-ferry"
      skill_file="$install_dir/skill.md"
      ;;
    claude)
      install_dir="$home_dir/.claude/skills/context-ferry"
      skill_file="$install_dir/skill.md"
      ;;
    *)
      printf 'unknown install layout: %s\n' "$layout" >&2
      return 2
      ;;
  esac

  mkdir -p "$install_dir"
  cp "$SKILL" "$skill_file"
  cp "$reference_source" "$install_dir/reference.md"
  install_managed_loader "$home_dir"
  INSTALLED_SKILL="$skill_file"
}

@test "context-ferry uses the abbreviated PreCompact path when a scaffold exists" {
  grep -Eq 'PreCompact.*Abbreviated path|PreCompact.*abbreviated path' "$CORPUS"
  grep -Eq 'Do NOT run the full|do not run the full' "$CORPUS"
  grep -Eq 'file does not exist.*fall back|scaffold.*missing.*full' "$CORPUS"
}

@test "context-ferry updates durable state before summarizing memory" {
  grep -Eq 'Update the execution doc|update.*execution doc' "$CORPUS"
  grep -Eq 'mandatory|MUST' "$CORPUS"
  grep -Fq 'update the most recently modified execution plan' "$SKILL"
  run grep -Fq 'update the newest' "$SKILL"
  [ "$status" -eq 1 ]
  grep -Eq 'Capture each verbatim|capture.*verbatim' "$CORPUS"
  grep -Eq 'Task file is authoritative|task file.*authoritative' "$CORPUS"
}

@test "context-ferry preserves resume-critical output fields" {
  for field in 'Original Goal' 'Pending Questions' 'Pending / Queued Tasks' 'Key Decisions' 'In Progress / Blocked' 'Next 3 Actions' 'Key Files & Diffs'; do
    grep -q "$field" "$CORPUS"
  done
}

@test "context-ferry records fidelity and sensitive-content handling" {
  grep -q 'Fidelity' "$CORPUS"
  grep -Eq 'credentials|API keys|PII' "$CORPUS"
  grep -Eq 'Do not block or skip generation|do not block.*generation' "$CORPUS"
}

@test "context-ferry degrades to a partial or printed ferry instead of losing state" {
  grep -Eq 'Partial ferry is better than no ferry|partial ferry.*no ferry' "$CORPUS"
  grep -Eq 'Write tool unavailable|write tool.*unavailable' "$CORPUS"
  grep -Eq 'print.*ferry prompt|Print.*ferry prompt' "$CORPUS"
}

@test "context-ferry loads the mandatory output template from a source checkout" {
  local script_file="$TMPDIR_/source-loader.sh"
  render_context_ferry_loader "$SKILL" "Output template" "$script_file"

  run env HOME="$TMPDIR_/empty-home" bash -c "cd '$REPO_ROOT' && bash '$script_file'"

  [ "$status" -eq 0 ]
  [[ "$output" == "## Output template"* ]]
  [[ "$output" == *"### Original Goal"* ]]
}

@test "context-ferry loads mandatory fidelity handling from a source checkout" {
  local script_file="$TMPDIR_/source-fidelity-loader.sh"
  render_context_ferry_loader "$SKILL" "Fidelity and sensitive content" "$script_file"

  run env HOME="$TMPDIR_/empty-home" bash -c "cd '$REPO_ROOT' && bash '$script_file'"

  [ "$status" -eq 0 ]
  [[ "$output" == "## Fidelity and sensitive content"* ]]
  [[ "$output" == *"Warning: this session may contain sensitive content."* ]]
  [[ "$output" == *"Do not block or skip generation."* ]]
}

@test "context-ferry executes every supported installed reference layout" {
  local layout install_home consumer script_file

  for layout in claude codex agents; do
    install_home="$TMPDIR_/$layout-home"
    consumer="$TMPDIR_/$layout-consumer"
    mkdir -p "$consumer"
    install_context_ferry_fixture "$install_home" "$layout"
    script_file="$TMPDIR_/$layout-loader.sh"
    render_context_ferry_loader "$INSTALLED_SKILL" "Output template" "$script_file"

    run env HOME="$install_home" bash -c "cd '$consumer' && bash '$script_file'"
    [ "$status" -eq 0 ]
    [[ "$output" == "## Output template"* ]]
    [[ "$output" == *"### Original Goal"* ]]
  done
}

@test "context-ferry installed loading ignores a malicious current-project loader" {
  local install_home="$TMPDIR_/malicious-home"
  local consumer="$TMPDIR_/malicious-consumer"
  local script_file="$TMPDIR_/malicious-loader.sh"
  mkdir -p "$consumer/tools"
  git -C "$consumer" init -q
  install_context_ferry_fixture "$install_home" claude
  cat > "$consumer/tools/section-loader.sh" <<'SH'
#!/usr/bin/env bash
printf 'PROJECT-LOADER-EXECUTED\n'
SH
  chmod +x "$consumer/tools/section-loader.sh"
  render_context_ferry_loader "$INSTALLED_SKILL" "Output template" "$script_file"

  run env HOME="$install_home" bash -c "cd '$consumer' && bash '$script_file'"

  [ "$status" -eq 0 ]
  [[ "$output" == "## Output template"* ]]
  [[ "$output" != *"PROJECT-LOADER-EXECUTED"* ]]
}

@test "context-ferry installed reference wins over a complete malicious current-project tuple" {
  local install_home="$TMPDIR_/complete-tuple-home"
  local consumer="$TMPDIR_/complete-tuple-consumer"
  local project_skill="$consumer/skills/productivity/context-ferry"
  local marker="$TMPDIR_/project-loader-executed"
  local script_file="$TMPDIR_/complete-tuple-loader.sh"
  mkdir -p "$project_skill" "$consumer/tools"
  git -C "$consumer" init -q
  install_context_ferry_fixture "$install_home" claude
  printf '%s\n' '# fake context-ferry skill' > "$project_skill/skill.md"
  cat > "$project_skill/reference.md" <<'MD'
# Fake project reference

## Output template

PROJECT-REFERENCE-SELECTED
MD
  cat > "$consumer/tools/section-loader.sh" <<'SH'
#!/usr/bin/env bash
: > "$PROJECT_LOADER_MARKER"
printf 'PROJECT-LOADER-EXECUTED\n'
SH
  chmod +x "$consumer/tools/section-loader.sh"
  render_context_ferry_loader "$INSTALLED_SKILL" "Output template" "$script_file"

  run env HOME="$install_home" PROJECT_LOADER_MARKER="$marker" \
    bash -c "cd '$consumer' && bash '$script_file'"

  [ "$status" -eq 0 ]
  [[ "$output" == "## Output template"* ]]
  [[ "$output" == *"Generated by context-ferry"* ]]
  [[ "$output" != *"PROJECT-REFERENCE-SELECTED"* ]]
  [[ "$output" != *"PROJECT-LOADER-EXECUTED"* ]]
  [ ! -e "$marker" ]
}

@test "context-ferry canonical Claude reference wins over divergent optional copies" {
  local install_home="$TMPDIR_/divergent-home"
  local consumer="$TMPDIR_/divergent-consumer"
  local stale_agents="$TMPDIR_/stale-agents.md"
  local stale_codex="$TMPDIR_/stale-codex.md"
  local script_file="$TMPDIR_/divergent-loader.sh"
  mkdir -p "$consumer"
  git -C "$consumer" init -q
  sed 's/Generated by context-ferry/STALE-AGENTS/' "$REFERENCE" > "$stale_agents"
  sed 's/Generated by context-ferry/STALE-CODEX/' "$REFERENCE" > "$stale_codex"
  install_context_ferry_fixture "$install_home" agents "$stale_agents"
  install_context_ferry_fixture "$install_home" codex "$stale_codex"
  install_context_ferry_fixture "$install_home" claude "$REFERENCE"
  render_context_ferry_loader "$INSTALLED_SKILL" "Output template" "$script_file"

  run env HOME="$install_home" bash -c "cd '$consumer' && bash '$script_file'"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Generated by context-ferry"* ]]
  [[ "$output" != *"STALE-AGENTS"* ]]
  [[ "$output" != *"STALE-CODEX"* ]]
}

@test "context-ferry installed loading fails without the trusted managed loader" {
  local install_home="$TMPDIR_/missing-loader-home"
  local consumer="$TMPDIR_/missing-loader-consumer"
  local script_file="$TMPDIR_/missing-loader.sh"
  mkdir -p "$consumer"
  install_context_ferry_fixture "$install_home" claude
  rm -f "$install_home/.codex/superpowers-plus/tools/section-loader.sh"
  render_context_ferry_loader "$INSTALLED_SKILL" "Output template" "$script_file"

  run env HOME="$install_home" bash -c "cd '$consumer' && bash '$script_file'"

  [ "$status" -eq 1 ]
  [[ "$output" == *"section-loader missing"* ]]
}

@test "context-ferry installed loading fails on an unknown section" {
  local install_home="$TMPDIR_/missing-section-home"
  local consumer="$TMPDIR_/missing-section-consumer"
  local script_file="$TMPDIR_/missing-section.sh"
  mkdir -p "$consumer"
  install_context_ferry_fixture "$install_home" claude
  render_context_ferry_loader "$INSTALLED_SKILL" "Not a context-ferry section" "$script_file"

  run env HOME="$install_home" bash -c "cd '$consumer' && bash '$script_file'"

  [ "$status" -eq 1 ]
  [[ "$output" == *"section not found: Not a context-ferry section"* ]]
}
