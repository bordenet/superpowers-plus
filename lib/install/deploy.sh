#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# lib/install/deploy.sh
# PURPOSE: Skill, adapter, rule, and template deployment to platform-specific
#          directories (~/.codex/skills/, ~/.claude/skills/).
# SOURCED BY: install.sh — do not run directly.
# GLOBALS READ: SCRIPT_DIR, SKILLS_DIR, CLAUDE_SKILLS_DIR,
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
            # Other sources (superpowers-plus, superpowers-[company], etc.)
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
            log_warn "Managed checkout has diverged from origin/main — skipping sync"
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
