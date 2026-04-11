#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# lib/install/deploy.sh
# PURPOSE: Skill, adapter, rule, and template deployment to platform-specific
#          directories (~/.codex/skills/, ~/.claude/skills/, ~/.agents/skills/).
# SOURCED BY: install.sh — do not run directly.
# GLOBALS READ: SCRIPT_DIR, SKILLS_DIR, CLAUDE_SKILLS_DIR, AUGMENT_MENU_DIR,
#               CODEX_DIR, FORCE, VERBOSE
# REQUIRES: lib/install/logging.sh
# -----------------------------------------------------------------------------

# Resolve the upstream source directory for a skill with `overrides:` metadata.
# Input: the overrides value (e.g., "superpowers/test-driven-development")
# Output: prints the upstream skill directory path, or empty if not found
_resolve_upstream_dir() {
    local override_val="$1"
    # Parse "source/skill-name" format
    local source_name
    source_name="${override_val%%/*}"
    local upstream_skill
    upstream_skill="${override_val##*/}"

    local upstream_dir=""
    case "$source_name" in
        superpowers)
            # obra/superpowers: flat structure at ~/.codex/superpowers/skills/
            upstream_dir="${SUPERPOWERS_DIR}/skills/${upstream_skill}"
            ;;
        *)
            # Other sources (superpowers-plus, overlay repos, etc.)
            # Search the source repo's skills/ tree for the skill name
            local src_repo="${CODEX_DIR}/${source_name}"
            if [[ -d "$src_repo/skills" ]]; then
                upstream_dir=$(find "$src_repo/skills" -maxdepth 2 -name "$upstream_skill" -type d 2>/dev/null | head -1)
            fi
            ;;
    esac

    if [[ -n "$upstream_dir" && -d "$upstream_dir" ]]; then
        echo "$upstream_dir"
    fi
}

# Install a single skill to all platform-specific paths.
# When a skill declares `overrides:`, stage the upstream companion files first
# (reference docs, scripts, prompts), then overlay the override's skill.md on
# top. This ensures companion files from the upstream source survive the override.
install_skill() {
    local skill_dir="$1"
    local skill_name
    skill_name=$(basename "$skill_dir")

    log_verbose "Installing skill: $skill_name"

    # Check if SKILL.md or skill.md exists
    if [[ ! -f "$skill_dir/SKILL.md" ]] && [[ ! -f "$skill_dir/skill.md" ]]; then
        log_warn "Skipping $skill_name: No SKILL.md or skill.md found"
        return 1
    fi

    # Detect override mode: parse overrides: value from frontmatter
    local override_val=""
    local skill_file=""
    [[ -f "$skill_dir/skill.md" ]] && skill_file="$skill_dir/skill.md"
    [[ -f "$skill_dir/SKILL.md" ]] && skill_file="$skill_dir/SKILL.md"
    if [[ -n "$skill_file" ]]; then
        override_val=$(grep '^overrides:' "$skill_file" 2>/dev/null \
            | head -1 | sed 's/^overrides:[[:space:]]*//' | tr -d '"' | tr -d "'") || true
    fi

    # Resolve upstream source directory if override is declared
    local upstream_dir=""
    if [[ -n "$override_val" ]]; then
        upstream_dir=$(_resolve_upstream_dir "$override_val")
        if [[ -n "$upstream_dir" ]]; then
            log_verbose "  Override: staging upstream companions from $upstream_dir"
        else
            log_verbose "  Override: upstream '$override_val' not found, clean install only"
        fi
    fi

    for target_dir in "$SKILLS_DIR" "$CLAUDE_SKILLS_DIR"; do
        mkdir -p "$target_dir"
        local dest="$target_dir/$skill_name"

        # Always start with a clean destination
        if [[ -d "$dest" ]]; then
            rm -rf "${dest:?}" || \
                error_exit "Failed to remove existing skill: $skill_name"
        fi
        mkdir -p "$dest"

        # Stage 1: If override, copy upstream companion files first
        if [[ -n "$upstream_dir" ]]; then
            # Copy all upstream files EXCEPT the main skill file (SKILL.md/skill.md)
            local f
            while IFS= read -r -d '' f; do
                local base
                base=$(basename "$f")
                # Skip the main skill file — the override replaces it
                [[ "$base" == "SKILL.md" || "$base" == "skill.md" ]] && continue
                cp "$f" "$dest/" || \
                    error_exit "Failed to stage upstream file $base for skill: $skill_name"
            done < <(find "$upstream_dir" -maxdepth 1 -type f -print0 2>/dev/null)

            # Copy upstream subdirectories (scripts/, references/, etc.)
            local d
            while IFS= read -r -d '' d; do
                cp -R "$d" "$dest/" || \
                    error_exit "Failed to stage upstream dir $(basename "$d") for skill: $skill_name"
            done < <(find "$upstream_dir" -maxdepth 1 -type d -not -path "$upstream_dir" -print0 2>/dev/null)
        fi

        # Stage 2: Copy all override files on top (skill.md + any extras)
        while IFS= read -r -d '' f; do
            cp "$f" "$dest/" || \
                error_exit "Failed to install $(basename "$f") for skill: $skill_name"
        done < <(find "$skill_dir" -maxdepth 1 -type f -print0 2>/dev/null)

        # Copy override subdirectories on top
        while IFS= read -r -d '' d; do
            cp -R "$d" "$dest/" || \
                error_exit "Failed to install dir $(basename "$d") for skill: $skill_name"
        done < <(find "$skill_dir" -maxdepth 1 -type d -not -path "$skill_dir" -print0 2>/dev/null)
    done

    log_success "Installed: $skill_name"
    return 0
}

# Install the superpowers-augment adapter
install_adapter() {
    log_info "Installing superpowers-augment adapter..."

    local adapter_src="$SCRIPT_DIR/superpowers-augment.js"
    local adapter_dest_dir="${CODEX_DIR}/superpowers-augment"
    local adapter_dest="${adapter_dest_dir}/superpowers-augment.js"
    local lib_src="$SCRIPT_DIR/lib"
    local lib_dest="${adapter_dest_dir}/lib"

    if [[ ! -f "$adapter_src" ]]; then
        log_warn "Adapter source not found: $adapter_src"
        return 1
    fi

    create_dir "$adapter_dest_dir"

    if [[ -f "$adapter_dest" ]] && cmp -s "$adapter_src" "$adapter_dest"; then
        log_verbose "Adapter already up to date"
    else
        cp "$adapter_src" "$adapter_dest" || error_exit "Failed to copy adapter to $adapter_dest"
        log_success "Adapter installed: $adapter_dest"
    fi

    if [[ -d "$lib_src" ]]; then
        rm -rf "${lib_dest:?}" 2>/dev/null
        cp -r "$lib_src" "$lib_dest" || error_exit "Failed to copy lib/ to $lib_dest"
        log_verbose "Installed lib/ directory"
    fi
}

sync_managed_checkout() {
    local managed_dir="${CODEX_DIR}/superpowers-plus"
    [[ -d "$managed_dir/.git" ]] || return 0  # No managed checkout — nothing to do

    # If install is running from the managed checkout itself, skip (already current)
    local managed_real
    local script_real
    managed_real=$(cd "$managed_dir" && pwd -P)
    script_real=$(cd "$SCRIPT_DIR" && pwd -P)
    if [[ "$managed_real" == "$script_real" ]]; then
        log_verbose "Running from managed checkout — skip sync"
        return 0
    fi

    log_info "Syncing managed checkout at $managed_dir..."

    # Try fast-forward pull from origin
    local timeout_cmd=""
    command -v timeout &>/dev/null && timeout_cmd="timeout 15"
    command -v gtimeout &>/dev/null && timeout_cmd="gtimeout 15"

    if $timeout_cmd git -C "$managed_dir" fetch origin --quiet 2>/dev/null; then
        if git -C "$managed_dir" merge-base --is-ancestor HEAD origin/main 2>/dev/null; then
            if git -C "$managed_dir" pull --ff-only origin main --quiet 2>/dev/null; then
                log_success "Managed checkout synced to origin/main"
            else
                log_warn "Could not fast-forward managed checkout (local changes?)"
            fi
        else
            # HEAD is not behind/equal to origin/main. Two sub-cases:
            # - Local is ahead (origin/main IS ancestor of HEAD): skip without resetting
            # - True divergence (neither is ancestor): history rewrite/force-push → auto-reset
            if git -C "$managed_dir" merge-base --is-ancestor origin/main HEAD 2>/dev/null; then
                log_warn "Managed checkout is ahead of origin/main — skipping sync (use --force to reset)"
            else
                log_warn "Managed checkout history has diverged from origin/main — auto-resetting"
                if git -C "$managed_dir" reset --hard origin/main --quiet 2>/dev/null && \
                   git -C "$managed_dir" clean -fd --quiet 2>/dev/null; then
                    log_success "Managed checkout recovered: reset to origin/main"
                else
                    log_warn "Auto-reset failed — run: cd $managed_dir && git reset --hard origin/main"
                fi
            fi
        fi
    else
        log_warn "Could not fetch origin for managed checkout (network issue?)"
    fi
}

register_source_repo() {
    local env_file="${HOME}/.codex/.env"
    local var_name="SPP_SOURCE_DIR"
    local source_path="$SCRIPT_DIR"

    create_dir "${HOME}/.codex"
    [[ -f "$env_file" ]] || touch "$env_file"

    # Use single quotes to prevent shell expansion of special characters
    # ($, ", \, spaces) when the .env file is later sourced.
    local new_line="${var_name}='${source_path//\'/\'\\\'\'}'"

    if grep -q "^${var_name}=" "$env_file" 2>/dev/null; then
        # Remove old line and append new (avoids sed delimiter/escaping issues)
        grep -v "^${var_name}=" "$env_file" > "${env_file}.tmp" || true
        mv "${env_file}.tmp" "$env_file"
    fi
    # Ensure file ends with a newline before appending
    if [[ -s "$env_file" ]] && [[ "$(tail -c 1 "$env_file" | wc -l)" -eq 0 ]]; then
        echo "" >> "$env_file"
    fi
    echo "$new_line" >> "$env_file"

    log_verbose "Registered source repo: $var_name=$source_path"
}

get_install_state_dir() {
    local state_dir="${CODEX_DIR}/superpowers-plus/install-state"
    mkdir -p "$state_dir"
    printf '%s\n' "$state_dir"
}

skill_manifest_path() {
    local state_dir
    state_dir=$(get_install_state_dir)
    printf '%s\n' "${state_dir}/skills.manifest"
}

managed_skill_source_matches() {
    local skill_dir="$1"
    local skill_file=""

    [[ -f "$skill_dir/skill.md" ]] && skill_file="$skill_dir/skill.md"
    [[ -z "$skill_file" && -f "$skill_dir/SKILL.md" ]] && skill_file="$skill_dir/SKILL.md"
    [[ -z "$skill_file" ]] && return 1

    grep -q '^source: superpowers-plus$' "$skill_file" 2>/dev/null
}

prune_stale_managed_skills() {
    local target_dir="$1"
    local manifest="$2"
    shift 2
    local current_skill_names=("$@")
    declare -A current_skill_map=()
    local skill_name
    for skill_name in "${current_skill_names[@]}"; do
        [[ -n "$skill_name" ]] && current_skill_map["$skill_name"]=1
    done

    if [[ -f "$manifest" ]]; then
        while IFS= read -r stale_skill; do
            [[ -z "$stale_skill" ]] && continue
            if [[ -z "${current_skill_map[$stale_skill]:-}" ]] && [[ -d "$target_dir/$stale_skill" ]]; then
                rm -rf "${target_dir:?}/$stale_skill" || log_warn "Failed to remove stale skill: $stale_skill"
                log_verbose "Removed stale skill: $stale_skill"
            fi
        done < "$manifest"
        return
    fi

    for installed_dir in "$target_dir"/*/; do
        [[ -d "$installed_dir" ]] || continue
        skill_name=$(basename "$installed_dir")
        if [[ -z "${current_skill_map[$skill_name]:-}" ]] && managed_skill_source_matches "$installed_dir"; then
            rm -rf "${installed_dir:?}" || log_warn "Failed to remove stale managed skill: $skill_name"
            log_verbose "Removed stale managed skill (source fallback): $skill_name"
        fi
    done
}

# Install tools from tools/ directory (todo-preflight.sh, todo-lock.sh, etc.)
install_tools() {
    log_info "Installing tools from superpowers-plus..."

    local tools_src="$SCRIPT_DIR/tools"
    if [[ ! -d "$tools_src" ]]; then
        log_verbose "No tools directory found, skipping"
        return
    fi

    local tools_dest="${CODEX_DIR}/superpowers-plus/tools"
    local state_dir
    state_dir=$(get_install_state_dir)
    local manifest="${state_dir}/tools.manifest"
    create_dir "$tools_dest"

    local count=0
    declare -A current_tools=()
    for tool in "$tools_src"/*; do
        [[ ! -f "$tool" ]] && continue
        local basename
        basename=$(basename "$tool")
        current_tools["$basename"]=1
    done

    if [[ -f "$manifest" ]]; then
        while IFS= read -r stale_tool; do
            [[ -z "$stale_tool" ]] && continue
            if [[ -z "${current_tools[$stale_tool]:-}" ]] && [[ -e "$tools_dest/$stale_tool" ]]; then
                rm -f "$tools_dest/$stale_tool" || log_warn "Failed to remove stale tool: $stale_tool"
                log_verbose "Removed stale tool: $stale_tool"
            fi
        done < "$manifest"
    fi

    for tool in "$tools_src"/*; do
        [[ ! -f "$tool" ]] && continue
        local basename
        basename=$(basename "$tool")
        local dest="${tools_dest}/${basename}"

        if [[ -f "$dest" ]] && cmp -s "$tool" "$dest"; then
            log_verbose "Tool already up to date: $basename"
        else
            cp "$tool" "$dest" || { log_warn "Failed to copy $basename"; continue; }
            log_verbose "Installed tool: $basename"
        fi
        # Always ensure execute bits (repairs broken perms even if content unchanged)
        if [[ "$basename" == *.sh ]] || [[ "$basename" == "pre-commit" ]] || [[ "$basename" == "pre-push" ]]; then
            chmod +x "$dest" 2>/dev/null || log_verbose "chmod +x skipped for $basename (NTFS mount?)"
        fi
        count=$((count + 1))
    done

    if [[ ${#current_tools[@]} -gt 0 ]]; then
        printf '%s\n' "${!current_tools[@]}" | sort > "$manifest"
    else
        : > "$manifest"
    fi

    log_success "Installed $count tools to $tools_dest"
}

# _cli_bin_dir_in_profiles <dir>
# Returns 0 if dir is referenced as a PATH token in a known POSIX shell profile,
# 1 if it is absent from all of them.
#
# Profiles checked: ~/.bash_profile, ~/.bash_login, ~/.bashrc,
#                   ~/.zshrc, ~/.zprofile, ~/.profile
# Not checked: fish (config.fish), nushell — those use different PATH syntax.
#
# Matching rules:
#   - Comment lines (leading #) are ignored.
#   - Only lines that persistently assign/append to PATH are considered.
#     Per-command env assignments (PATH=... command, no export) are excluded.
#   - The directory is matched as a token. Quotes are treated as optional wrappers
#     around real delimiters (=, :, }) — not as delimiters themselves. This prevents
#     "PATH="$PATH"TARGET" from matching while "PATH="TARGET"" still does.
#   - Both the absolute path and common $HOME/..., ${HOME}/..., ~/... shorthands
#     are matched to avoid false negatives when the profile uses a variable form.
#   - Trailing slash is normalised: ~/bin/ and ~/bin are treated as equivalent.
#   - Matching is restricted to the PATH= value token; trailing commands or
#     comments on the same line are not scanned, preventing false positives
#     like: export PATH="$PATH"; echo "/target/dir"
#   - Known limitation: per-command env exclusion uses a heuristic; shell control
#     operators (&&, ||) and semicolon-joined forms are preserved as persistent.
_cli_bin_dir_in_profiles() {
    local dir="${1%/}"   # strip trailing slash for consistent matching
    local profiles=(
        "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.bashrc"
        "$HOME/.zshrc"        "$HOME/.zprofile"   "$HOME/.profile"
    )

    # Escape ERE metacharacters in path fragments so unusual-but-valid characters
    # (dots, plus signs, brackets, etc.) don't cause false negatives or positives.
    # Uses explicit per-character substitutions for BSD/GNU sed portability —
    # the [] character-class form ([][...]) is rejected by macOS BSD sed.
    _esc_ere() { printf '%s' "$1" | sed \
        -e 's/\./\\./g' -e 's/\[/\\[/g' -e 's/\]/\\]/g' \
        -e 's/+/\\+/g'  -e 's/\*/\\*/g' -e 's/?/\\?/g'  \
        -e 's/(/\\(/g'  -e 's/)/\\)/g'  -e 's/{/\\{/g'  \
        -e 's/}/\\}/g'  -e 's/\^/\\^/g' -e 's/|/\\|/g'; }
    local esc_dir
    esc_dir=$(_esc_ere "$dir")

    # Build regex variants for $HOME-relative shorthand forms found in profiles.
    # Three forms are common, but they have different quoting semantics:
    #   $HOME/...    — expands in double-quoted or unquoted context only
    #   ${HOME}/...  — expands in double-quoted or unquoted context only
    #   ~/...        — tilde expands ONLY when unquoted; double-quoted tilde is literal
    #
    # home_pats: matched with double-quote-aware boundaries (pre_dq/post_dq).
    # tilde_pats: matched with strictly-unquoted boundaries (pre_uq/post_uq).
    #
    # SC2016: single-quote prefix is intentional — we want literal \$HOME in
    # the grep -E regex, not the expanded value of $HOME.
    local -a home_pats=() tilde_pats=()
    if [[ "$dir" == "$HOME/"* ]]; then
        local rel="${dir#"$HOME/"}"
        local esc_rel
        esc_rel=$(_esc_ere "$rel")
        # SC2016: single-quote prefix is intentional — literal \$HOME in the grep -E regex.
        # SC2088: tilde in double quotes is intentional — building a regex for profile matching.
        # shellcheck disable=SC2016,SC2088
        home_pats+=(
            '\$HOME/'"$esc_rel"          # matches $HOME/.local/bin
            '\$\{HOME\}/'"$esc_rel"      # matches ${HOME}/.local/bin
        )
        # shellcheck disable=SC2088
        tilde_pats+=(
            "~/$esc_rel"                 # matches ~/.local/bin (unquoted only)
        )
    fi

    # Token boundaries — three variants:
    # pre / post:     allow optional ' or " wrapper (for absolute paths, which are
    #                 literal regardless of quoting).
    # pre_dq/post_dq: allow optional " only — NOT '. $HOME/$var do not expand in
    #                 single quotes, so PATH='$HOME/.local/bin' must be NOT_FOUND.
    # pre_uq/post_uq: no optional quote at all. Tilde does not expand inside double
    #                 quotes in bash or zsh, so PATH="~/.local/bin" must be NOT_FOUND.
    # } is included in pre* so ${PATH:+$PATH:}TARGET is correctly matched.
    local pre='(^|[=:}])["'"'"']?'
    local post='["'"'"']?([:;#]|[[:space:]]|$)'
    local pre_dq='(^|[=:}])"?'
    local post_dq='"?([:;#]|[[:space:]]|$)'
    local pre_uq='(^|[=:}])'
    local post_uq='([:;#]|[[:space:]]|$)'

    local p pat path_lines
    for p in "${profiles[@]}"; do
        [[ -f "$p" ]] || continue
        # Strip comment lines; keep only lines that persistently assign/append
        # to PATH itself. Anchored to exclude MANPATH, MY_PATH, LD_LIBRARY_PATH.
        path_lines=$(grep -v '^[[:space:]]*#' "$p" 2>/dev/null \
            | grep -E '^[[:space:]]*(export[[:space:]]+)?PATH(\+)?=') || true
        [[ -n "$path_lines" ]] || continue
        # Exclude per-command env assignments: PATH=<value> <command> (no export).
        # Positive allowlist: keep bare PATH= lines only when the suffix is a shell
        # operator (&&, ||, ;) or comment (#) or EOL. Anything else after whitespace
        # is a per-command temp env.
        # [^[:space:];]* stops at ; so PATH=val; export FOO is NOT wrongly excluded.
        path_lines=$(printf '%s\n' "$path_lines" \
            | grep -vE '^[[:space:]]*PATH[+]?=[^[:space:];]*[[:space:]]+[^&|;#[:space:]]') || true
        [[ -n "$path_lines" ]] || continue

        # Restrict matching to the PATH= value only — strip any trailing command or
        # comment so "export PATH=$PATH; echo TARGET" is not falsely matched.
        # [^;[:space:]]* captures the value (quoted or unquoted) up to the first
        # space or semicolon; everything after is a trailing command/comment.
        local value_lines
        value_lines=$(printf '%s\n' "$path_lines" \
            | sed -E 's/^([[:space:]]*(export[[:space:]]+)?PATH[+]?=[^;[:space:]]*)[[:space:];].*/\1/')

        # Check absolute path form; /? accepts optional trailing slash in the profile
        if printf '%s\n' "$value_lines" | grep -qE "${pre}${esc_dir}/?${post}"; then
            return 0
        fi
        # Check $HOME/${HOME} shorthand forms: double-quote OK, single-quote NOT OK.
        for pat in "${home_pats[@]}"; do
            if printf '%s\n' "$value_lines" | grep -qE "${pre_dq}${pat}/?${post_dq}"; then
                return 0
            fi
        done
        # Check ~/... tilde shorthand: must be completely unquoted.
        # Tilde does not expand inside double quotes in bash or zsh, so
        # PATH="$PATH:~/.local/bin" leaves a literal ~/... on PATH.
        # Strategy: replace each double-quoted span with a non-delimiter sentinel
        # (__QS__) so that ~/... inside "..." is gone, but adjacent unquoted tokens
        # retain their boundaries correctly. Using empty replacement would merge
        # surrounding text and create phantom delimiter boundaries — e.g.
        # PATH="${PATH:+$PATH:}"~/ → PATH=~/ (false FOUND). With __QS__ it becomes
        # PATH=__QS__~/ where __QS__ is not in [=:}], so pre_uq never matches.
        if [[ ${#tilde_pats[@]} -gt 0 ]]; then
            local tilde_value_lines
            tilde_value_lines=$(printf '%s\n' "$value_lines" | sed -E 's/"[^"]*"/__QS__/g')
            for pat in "${tilde_pats[@]}"; do
                if printf '%s\n' "$tilde_value_lines" | grep -qE "${pre_uq}${pat}/?${post_uq}"; then
                    return 0
                fi
            done
        fi
    done
    return 1
}

# Install CLI commands — symlink all tools/sp-*.sh to PATH as sp-*
install_cli_commands() {
    local tools_dest="${CODEX_DIR}/superpowers-plus/tools"

    # Find all sp-*.sh files in the installed tools directory
    local sp_scripts=()
    while IFS= read -r -d '' f; do
        sp_scripts+=("$f")
    done < <(find "$tools_dest" -maxdepth 1 -name 'sp-*.sh' -type f -print0 2>/dev/null)

    [[ ${#sp_scripts[@]} -gt 0 ]] || return 0

    # Find a writable bin directory — prefer one that is already on PATH.
    # Normalize trailing slashes before comparing: PATH=$HOME/bin/:... should
    # match candidate $HOME/bin just as well as an exact $HOME/bin entry.
    local bin_dir="" candidate norm_candidate norm_seg seg
    for candidate in /usr/local/bin "$HOME/.local/bin" "$HOME/bin"; do
        if [[ -d "$candidate" ]] && [[ -w "$candidate" ]]; then
            # Prefer directories that are already on PATH (slash-normalized)
            norm_candidate="${candidate%/}"
            local on_path=0
            local IFS_saved="$IFS"; IFS=":"
            for seg in $PATH; do
                norm_seg="${seg%/}"
                if [[ "$norm_seg" == "$norm_candidate" ]]; then
                    on_path=1; break
                fi
            done
            IFS="$IFS_saved"
            if [[ "$on_path" -eq 1 ]]; then
                bin_dir="$candidate"
                break
            fi
            # Remember first writable candidate even if not on PATH (fallback)
            [[ -z "$bin_dir" ]] && bin_dir="$candidate"
        fi
    done

    # Try creating ~/.local/bin if nothing else works
    if [[ -z "$bin_dir" ]]; then
        bin_dir="$HOME/.local/bin"
        mkdir -p "$bin_dir" 2>/dev/null || {
            log_warn "Cannot create $bin_dir — sp-* commands won't be on PATH"
            return 0
        }
    fi

    # Verify bin_dir is referenced in at least one POSIX shell profile.
    # Scanning profiles (not $PATH) catches cross-shell gaps — e.g., installing
    # from zsh when an AI agent runs bash with no ~/.bash_profile.
    # Fish/nushell configs are not checked (different PATH syntax).
    if ! _cli_bin_dir_in_profiles "$bin_dir"; then
        log_warn "sp-* commands installed to $bin_dir but that path was not found"
        log_warn "in any POSIX shell profile (~/.bash_profile, ~/.bashrc, ~/.zshrc, etc.)."
        log_warn "Commands may be invisible in some shells. Add to each relevant profile:"
        log_warn "  export PATH=\"${bin_dir}:\$PATH\""
    fi

    local installed=0
    for script in "${sp_scripts[@]}"; do
        local basename
        basename=$(basename "$script")
        # sp-update.sh → sp-update, sp-doctor.sh → sp-doctor
        local cmd_name="${basename%.sh}"
        local link="$bin_dir/$cmd_name"

        # Create or update symlink
        if [[ -L "$link" ]]; then
            local existing
            existing=$(readlink "$link" 2>/dev/null || true)
            if [[ "$existing" == "$script" ]]; then
                log_verbose "$cmd_name symlink already correct"
                installed=$((installed + 1))
                continue
            fi
            rm -f "$link"
        elif [[ -e "$link" ]]; then
            log_warn "$cmd_name exists at $link but is not a symlink — skipping"
            continue
        fi

        if ln -s "$script" "$link" 2>/dev/null; then
            installed=$((installed + 1))
        else
            log_warn "Failed to symlink $cmd_name to $bin_dir"
        fi
    done

    if [[ $installed -gt 0 ]]; then
        log_success "CLI commands installed: $installed sp-* command(s) in $bin_dir"
    fi
}

# Curated skills exported to Augment IDE's native slash menu (~/.agents/skills/).
# These appear in the Augment "/" command palette when set to "Manual" mode.
# Keep this list small — only high-frequency, user-facing skills belong here.
AUGMENT_MENU_SKILLS=(
    brainstorming
    systematic-debugging
    think-twice
    plan-and-execute
    debate
    progressive-harsh-review
    perplexity-research
    detecting-ai-slop
    eliminating-ai-slop
    todo-management
    pre-commit-gate
    pre-push-quality-gate
    superpowers-help
    providing-code-review
    code-review-battery
    requesting-code-review
    receiving-code-review
    verification-before-completion
    test-driven-development
    blast-radius-check
    repo-security-scan
    finishing-a-development-branch
    update-superpowers
    superpowers-doctor
    failure-autopsy
    innovation
    holistic-repo-verification
    enforce-style-guide
)

# Export curated skills to ~/.agents/skills/ for Augment IDE slash menu discovery.
# Copies the skill directory and renames skill.md → SKILL.md (Augment convention).
# Called from install_skills() after main deployment completes.
# Extract the first /sp-* trigger from a skill.md file.
# Handles both inline YAML array: triggers: ["/sp-foo", ...]
# and block list format:  triggers:\n  - /sp-foo
_extract_sp_trigger() {
    local skill_file="$1"
    local t
    # Inline array: triggers: ["/sp-foo", ...]
    t=$(grep "^triggers:" "$skill_file" 2>/dev/null | grep -o '"/sp-[^"]*"' | head -1 | tr -d '"')
    [[ -n "$t" ]] && echo "$t" && return
    # Block list: - /sp-foo
    t=$(grep -m1 '^ *- /sp-' "$skill_file" 2>/dev/null | sed 's/^ *- //')
    echo "$t"
}

export_augment_menu_skills() {
    [[ -z "${AUGMENT_MENU_DIR:-}" ]] && return 0

    log_info "Exporting curated skills to Augment slash menu..."
    mkdir -p "$AUGMENT_MENU_DIR"

    local exported=0
    local missing=0

    # Track exported sp-* dir names for pruning
    declare -A exported_names=()

    for skill_name in "${AUGMENT_MENU_SKILLS[@]}"; do
        # Find the installed skill in the primary deployment target
        local source_dir="$SKILLS_DIR/$skill_name"
        if [[ ! -d "$source_dir" ]]; then
            log_warn "  Curated skill not found: $skill_name (expected in $SKILLS_DIR)"
            missing=$((missing + 1))
            continue
        fi

        # Derive slash-command directory name from first /sp-* trigger.
        # Augment IDE uses the directory name as the slash command (/sp-foo).
        local sp_trigger dest_name
        sp_trigger=$(_extract_sp_trigger "$source_dir/skill.md")
        dest_name="${sp_trigger#/}"       # strip leading /
        dest_name="${dest_name:-$skill_name}"  # fallback: use skill name
        exported_names["$dest_name"]=1

        local dest="$AUGMENT_MENU_DIR/$dest_name"
        rm -rf "${dest:?}" 2>/dev/null || true
        mkdir -p "$dest"

        # Copy all files from the installed skill
        local f
        while IFS= read -r -d '' f; do
            cp "$f" "$dest/" || log_warn "Failed to copy $(basename "$f") for $skill_name"
        done < <(find "$source_dir" -maxdepth 1 -type f -print0 2>/dev/null)

        # Copy subdirectories
        local d
        while IFS= read -r -d '' d; do
            cp -R "$d" "$dest/" || log_warn "Failed to copy dir $(basename "$d") for $skill_name"
        done < <(find "$source_dir" -maxdepth 1 -type d -not -path "$source_dir" -print0 2>/dev/null)

        # Augment convention: SKILL.md (uppercase). Two-step rename needed on
        # case-insensitive filesystems (macOS APFS) where mv skill.md SKILL.md is a no-op.
        if [[ -f "$dest/skill.md" ]]; then
            mv "$dest/skill.md" "$dest/_skill_tmp.md"
            mv "$dest/_skill_tmp.md" "$dest/SKILL.md"
        fi

        # Update name: field so Augment shows the sp-* label in the slash menu.
        if [[ -n "$sp_trigger" ]] && [[ "$dest_name" != "$skill_name" ]]; then
            sed -i '' "s/^name: .*/name: $dest_name/" "$dest/SKILL.md" 2>/dev/null || true
        fi

        exported=$((exported + 1))
        log_verbose "  Exported: $skill_name → /$dest_name"
    done

    # Prune skills removed from the curated list (including old non-sp-* dirs).
    for installed_dir in "$AUGMENT_MENU_DIR"/*/; do
        [[ -d "$installed_dir" ]] || continue
        local dir_name
        dir_name=$(basename "$installed_dir")
        if [[ -z "${exported_names[$dir_name]:-}" ]]; then
            # Only prune if it looks like a superpowers-managed skill
            if grep -q '^source: superpowers-plus$' "$installed_dir/SKILL.md" 2>/dev/null || \
               grep -q '^source: superpowers-plus$' "$installed_dir/skill.md" 2>/dev/null; then
                rm -rf "${installed_dir:?}"
                log_verbose "  Pruned stale Augment menu skill: $dir_name"
            fi
        fi
    done

    local expected="${#AUGMENT_MENU_SKILLS[@]}"
    if [[ $missing -gt 0 ]]; then
        log_warn "Augment slash menu: $missing/$expected curated skill(s) missing — slash commands may be incomplete"
    fi
    if [[ $exported -gt 0 ]]; then
        log_success "Exported $exported/$expected skill(s) to Augment slash menu ($AUGMENT_MENU_DIR)"
    fi
}


# Install all skills from this repository (supports domain-based structure)
install_skills() {
    log_info "Installing skills from superpowers-plus..."

    if [[ ! -d "$SCRIPT_DIR/skills" ]]; then
        error_exit "Skills directory not found: $SCRIPT_DIR/skills"
    fi
    if [[ ! -r "$SCRIPT_DIR/skills" ]]; then
        error_exit "Skills directory not readable: $SCRIPT_DIR/skills (check permissions)"
    fi

    create_dir "$SKILLS_DIR"
    create_dir "$CLAUDE_SKILLS_DIR"
    local manifest
    manifest=$(skill_manifest_path)
    local installed=0
    local skipped=0
    local current_skill_names=()

    for domain_or_skill in "$SCRIPT_DIR/skills/"*/; do
        [[ ! -d "$domain_or_skill" ]] && continue
        local dir_name
        dir_name=$(basename "$domain_or_skill")

        [[ "$dir_name" == _* ]] && continue  # Skip _shared, _archive, _adapters, etc.

        if [[ -f "$domain_or_skill/skill.md" ]] || [[ -f "$domain_or_skill/SKILL.md" ]]; then
            current_skill_names+=("$(basename "$domain_or_skill")")
        else
            for skill_dir in "$domain_or_skill"*/; do
                [[ ! -d "$skill_dir" ]] && continue
                if [[ -f "$skill_dir/skill.md" ]] || [[ -f "$skill_dir/SKILL.md" ]]; then
                    current_skill_names+=("$(basename "$skill_dir")")
                fi
            done
        fi
    done

    prune_stale_managed_skills "$SKILLS_DIR" "$manifest" "${current_skill_names[@]}"
    prune_stale_managed_skills "$CLAUDE_SKILLS_DIR" "$manifest" "${current_skill_names[@]}"

    for domain_or_skill in "$SCRIPT_DIR/skills/"*/; do
        [[ ! -d "$domain_or_skill" ]] && continue
        local dir_name
        dir_name=$(basename "$domain_or_skill")

        [[ "$dir_name" == _* ]] && continue  # Skip _shared, _archive, _adapters, etc.

        if [[ -f "$domain_or_skill/skill.md" ]] || [[ -f "$domain_or_skill/SKILL.md" ]]; then
            if install_skill "$domain_or_skill"; then
                installed=$((installed + 1))
            else
                skipped=$((skipped + 1))
            fi
        else
            for skill_dir in "$domain_or_skill"*/; do
                [[ ! -d "$skill_dir" ]] && continue
                local nested_name
                nested_name=$(basename "$skill_dir")
                [[ "$nested_name" == _* ]] && continue  # Skip _adapters in domain dirs
                if [[ -f "$skill_dir/skill.md" ]] || [[ -f "$skill_dir/SKILL.md" ]]; then
                    if install_skill "$skill_dir"; then
                        installed=$((installed + 1))
                    else
                        skipped=$((skipped + 1))
                    fi
                fi
            done
        fi
    done

    # Deploy _shared/ support directory (not a skill, but referenced by skills)
    if [[ -d "$SCRIPT_DIR/skills/_shared" ]]; then
        for target_dir in "$SKILLS_DIR" "$CLAUDE_SKILLS_DIR"; do
            [[ -z "$target_dir" || ! -d "$target_dir" ]] && continue
            local shared_dest="$target_dir/_shared"
            rm -rf "${shared_dest:?}" 2>/dev/null || true
            cp -R "$SCRIPT_DIR/skills/_shared" "$shared_dest"
        done
        log_verbose "Deployed _shared/ support directory"
    fi

    if [[ $installed -eq 0 ]]; then
        log_warn "No skills were installed"
    else
        log_success "Installed $installed skill(s)"
    fi

    if [[ $skipped -gt 0 ]] && [[ "$VERBOSE" == "true" ]]; then
        log_verbose "Skipped $skipped item(s)"
    fi

    if [[ ${#current_skill_names[@]} -gt 0 ]]; then
        printf '%s\n' "${current_skill_names[@]}" | sort -u > "$manifest"
    else
        : > "$manifest"
    fi

    # Export curated subset to Augment IDE slash menu
    export_augment_menu_skills
}


# Install rules from rules/ directory
install_rules() {
    log_info "Installing rules from superpowers-plus..."

    local rules_src="$SCRIPT_DIR/rules"
    if [[ ! -d "$rules_src" ]]; then
        log_verbose "No rules directory found, skipping"
        return
    fi

    local augment_rules_dir="${HOME}/.augment/rules"
    local state_dir
    state_dir=$(get_install_state_dir)
    local manifest="${state_dir}/rules.manifest"
    create_dir "$augment_rules_dir"

    local installed=0
    declare -A current_rules=()

    for rule_file in "$rules_src"/*.md; do
        [[ ! -f "$rule_file" ]] && continue
        local rule_name
        rule_name=$(basename "$rule_file")
        current_rules["$rule_name"]=1
    done

    if [[ -f "$manifest" ]]; then
        while IFS= read -r stale_rule; do
            [[ -z "$stale_rule" ]] && continue
            if [[ -z "${current_rules[$stale_rule]:-}" ]] && [[ -e "$augment_rules_dir/$stale_rule" ]]; then
                rm -f "$augment_rules_dir/$stale_rule" || log_warn "Failed to remove stale rule: $stale_rule"
                log_verbose "Removed stale rule: $stale_rule"
            fi
        done < "$manifest"
    fi

    for rule_file in "$rules_src"/*.md; do
        [[ ! -f "$rule_file" ]] && continue
        local rule_name
        rule_name=$(basename "$rule_file")

        cp "$rule_file" "$augment_rules_dir/$rule_name" || error_exit "Failed to install rule: $rule_name"
        log_verbose "Installed rule: $rule_name"
        installed=$((installed + 1))
    done

    if [[ ${#current_rules[@]} -gt 0 ]]; then
        printf '%s\n' "${!current_rules[@]}" | sort > "$manifest"
    else
        : > "$manifest"
    fi

    if [[ $installed -gt 0 ]]; then
        log_success "Installed $installed rule(s) to $augment_rules_dir"
    fi
}

# Install templates from templates/ directory
install_templates() {
    log_info "Installing templates from superpowers-plus..."

    local templates_src="$SCRIPT_DIR/templates"
    if [[ ! -d "$templates_src" ]]; then
        log_verbose "No templates directory found, skipping"
        return
    fi

    local templates_dir="${CODEX_DIR}/templates"
    local state_dir
    state_dir=$(get_install_state_dir)
    local manifest="${state_dir}/templates.manifest"
    create_dir "$templates_dir"

    local installed=0
    declare -A current_templates=()

    for template_file in "$templates_src"/*; do
        [[ ! -f "$template_file" ]] && continue
        local template_name
        template_name=$(basename "$template_file")
        current_templates["$template_name"]=1
    done

    if [[ -f "$manifest" ]]; then
        while IFS= read -r stale_template; do
            [[ -z "$stale_template" ]] && continue
            if [[ -z "${current_templates[$stale_template]:-}" ]] && [[ -e "$templates_dir/$stale_template" ]]; then
                rm -f "$templates_dir/$stale_template" || log_warn "Failed to remove stale template: $stale_template"
                log_verbose "Removed stale template: $stale_template"
            fi
        done < "$manifest"
    fi

    for template_file in "$templates_src"/*; do
        [[ ! -f "$template_file" ]] && continue
        local template_name
        template_name=$(basename "$template_file")

        cp "$template_file" "$templates_dir/$template_name" || error_exit "Failed to install template: $template_name"
        log_verbose "Installed template: $template_name"
        installed=$((installed + 1))
    done

    if [[ ${#current_templates[@]} -gt 0 ]]; then
        printf '%s\n' "${!current_templates[@]}" | sort > "$manifest"
    else
        : > "$manifest"
    fi

    if [[ $installed -gt 0 ]]; then
        log_success "Installed $installed template(s) to $templates_dir"
    fi
}
