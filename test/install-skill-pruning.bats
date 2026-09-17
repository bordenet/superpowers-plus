#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

RETIRED_HELPERS=(
  timeline-trace-investigator
  llm-behavior-investigator
  state-consistency-investigator
  infra-config-investigator
  reproduction-experiment-investigator
  evidence-adjudicator
)

setup() {
  CODEX_DIR="$BATS_TEST_TMPDIR/codex"
  SKILLS_DIR="$CODEX_DIR/skills"
  CLAUDE_SKILLS_DIR="$BATS_TEST_TMPDIR/claude-skills"
  AUGMENT_MENU_DIR="$BATS_TEST_TMPDIR/agents-skills"
  SCRIPT_DIR="$REPO_ROOT"
  VERBOSE=false
  export CODEX_DIR SKILLS_DIR CLAUDE_SKILLS_DIR AUGMENT_MENU_DIR SCRIPT_DIR VERBOSE

  # deploy.sh is function-only and expects the installer logging helpers.
  log_verbose() { :; }
  log_warn() { :; }
  log_success() { :; }
  log_info() { :; }
  error_exit() { echo "error_exit: $*" >&2; return 1; }
  create_dir() { mkdir -p "$1"; }

  # shellcheck disable=SC1090
  source "$REPO_ROOT/lib/install/deploy.sh"
}

seed_retired_helpers() {
  local target_dir="$1" helper
  mkdir -p "$target_dir"
  for helper in "${RETIRED_HELPERS[@]}"; do
    mkdir -p "$target_dir/$helper"
    printf -- '---\nname: %s\nsource: superpowers-plus\n---\n' "$helper" \
      > "$target_dir/$helper/skill.md"
  done
}

assert_retired_helpers_absent() {
  local target_dir="$1" helper
  for helper in "${RETIRED_HELPERS[@]}"; do
    [ ! -e "$target_dir/$helper" ]
  done
}

@test "manifest pruning removes all retired debug helper install directories" {
  local target_dir="$BATS_TEST_TMPDIR/manifest-target"
  local manifest="$BATS_TEST_TMPDIR/skills.manifest"
  seed_retired_helpers "$target_dir"
  printf '%s\n' "${RETIRED_HELPERS[@]}" > "$manifest"

  prune_stale_managed_skills "$target_dir" "$manifest" debug-conductor

  assert_retired_helpers_absent "$target_dir"
}

@test "fallback pruning removes retired helpers without a manifest" {
  local target_dir="$BATS_TEST_TMPDIR/fallback-target"
  seed_retired_helpers "$target_dir"
  mkdir -p "$target_dir/third-party-skill"
  printf -- '---\nname: third-party-skill\nsource: third-party\n---\n' \
    > "$target_dir/third-party-skill/skill.md"

  prune_stale_managed_skills \
    "$target_dir" "$BATS_TEST_TMPDIR/missing.manifest" debug-conductor

  assert_retired_helpers_absent "$target_dir"
  [ -d "$target_dir/third-party-skill" ]
}

@test "installer prunes both Codex and Claude skill destinations" {
  local deploy_script="$REPO_ROOT/lib/install/deploy.sh"

  grep -Fq 'prune_stale_managed_skills "$SKILLS_DIR"' "$deploy_script"
  grep -Fq 'prune_stale_managed_skills "$CLAUDE_SKILLS_DIR"' "$deploy_script"
}

@test "update path redeploys through install.sh so pruning runs" {
  grep -Fq 'bash "$managed_dir/install.sh" "${install_args[@]}"' \
    "$REPO_ROOT/tools/sp-update.sh"
}
