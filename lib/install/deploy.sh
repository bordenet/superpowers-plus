#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# lib/install/deploy.sh
# PURPOSE: Skill, adapter, rule, and template deployment to platform-specific
#          directories (~/.codex/skills/, ~/.claude/skills/, ~/.augment/skills/).
# SOURCED BY: install.sh — do not run directly.
# GLOBALS READ: SCRIPT_DIR, SKILLS_DIR, CLAUDE_SKILLS_DIR, AUGMENT_SKILLS_DIR,
#               CODEX_DIR, FORCE, VERBOSE
# REQUIRES: lib/install/logging.sh
# -----------------------------------------------------------------------------

# Install a single skill to all platform-specific paths
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

    # --- Deploy to Augment Agent (~/.codex/skills/) ---
    if [[ -d "$SKILLS_DIR/$skill_name" ]]; then
        rm -rf "${SKILLS_DIR:?}/${skill_name:?}" || \
            error_exit "Failed to remove existing skill: $skill_name (Augment/codex)"
    fi
    cp -r "$skill_dir" "$SKILLS_DIR/$skill_name" || \
        error_exit "Failed to install skill: $skill_name (Augment/codex)"

    # --- Deploy to Claude Code (~/.claude/skills/) ---
    mkdir -p "$CLAUDE_SKILLS_DIR"
    if [[ -d "$CLAUDE_SKILLS_DIR/$skill_name" ]]; then
        rm -rf "${CLAUDE_SKILLS_DIR:?}/${skill_name:?}" || \
            error_exit "Failed to remove existing skill: $skill_name (Claude Code)"
    fi
    cp -r "$skill_dir" "$CLAUDE_SKILLS_DIR/$skill_name" || \
        error_exit "Failed to install skill: $skill_name (Claude Code)"

    # --- Deploy to Augment Agent (~/.augment/skills/) ---
    mkdir -p "$AUGMENT_SKILLS_DIR"
    if [[ -d "$AUGMENT_SKILLS_DIR/$skill_name" ]]; then
        rm -rf "${AUGMENT_SKILLS_DIR:?}/${skill_name:?}" || \
            error_exit "Failed to remove existing skill: $skill_name (Augment)"
    fi
    cp -r "$skill_dir" "$AUGMENT_SKILLS_DIR/$skill_name" || \
        error_exit "Failed to install skill: $skill_name (Augment)"

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
        rm -rf "$lib_dest" 2>/dev/null
        cp -r "$lib_src" "$lib_dest" || error_exit "Failed to copy lib/ to $lib_dest"
        log_verbose "Installed lib/ directory"
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
    create_dir "$AUGMENT_SKILLS_DIR"

    local installed=0
    local skipped=0

    for domain_or_skill in "$SCRIPT_DIR/skills/"*/; do
        [[ ! -d "$domain_or_skill" ]] && continue
        local dir_name
        dir_name=$(basename "$domain_or_skill")

        [[ "$dir_name" == "_shared" ]] && continue
        [[ "$dir_name" == "_archive" ]] && continue

        if [[ -f "$domain_or_skill/skill.md" ]] || [[ -f "$domain_or_skill/SKILL.md" ]]; then
            if install_skill "$domain_or_skill"; then
                ((installed++)) || true
            else
                ((skipped++)) || true
            fi
        else
            for skill_dir in "$domain_or_skill"*/; do
                [[ ! -d "$skill_dir" ]] && continue
                if [[ -f "$skill_dir/skill.md" ]] || [[ -f "$skill_dir/SKILL.md" ]]; then
                    if install_skill "$skill_dir"; then
                        ((installed++)) || true
                    else
                        ((skipped++)) || true
                    fi
                fi
            done
        fi
    done

    if [[ $installed -eq 0 ]]; then
        log_warn "No skills were installed"
    else
        log_success "Installed $installed skill(s)"
    fi

    if [[ $skipped -gt 0 ]] && [[ "$VERBOSE" == "true" ]]; then
        log_verbose "Skipped $skipped item(s)"
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
    create_dir "$augment_rules_dir"

    local installed=0

    for rule_file in "$rules_src"/*.md; do
        [[ ! -f "$rule_file" ]] && continue
        local rule_name
        rule_name=$(basename "$rule_file")

        if [[ "$FORCE" == "true" ]] || [[ ! -f "$augment_rules_dir/$rule_name" ]]; then
            cp "$rule_file" "$augment_rules_dir/$rule_name"
            log_verbose "Installed rule: $rule_name"
            ((installed++)) || true
        else
            log_verbose "Rule already exists (use --force to overwrite): $rule_name"
        fi
    done

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
    create_dir "$templates_dir"

    local installed=0

    for template_file in "$templates_src"/*; do
        [[ ! -f "$template_file" ]] && continue
        local template_name
        template_name=$(basename "$template_file")

        if [[ "$FORCE" == "true" ]] || [[ ! -f "$templates_dir/$template_name" ]]; then
            cp "$template_file" "$templates_dir/$template_name"
            log_verbose "Installed template: $template_name"
            ((installed++)) || true
        else
            log_verbose "Template already exists (use --force to overwrite): $template_name"
        fi
    done

    if [[ $installed -gt 0 ]]; then
        log_success "Installed $installed template(s) to $templates_dir"
    fi
}
