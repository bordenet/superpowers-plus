# Superpowers Doctor — Detailed Check Procedures

Each check runs iteratively across EVERY installed skill. No exceptions, no shortcuts.

---

## 🔴 CRITICAL — Skill is broken

### Check 1: Malformed YAML Frontmatter

**What:** Parse the YAML block between `---` delimiters at the top of each skill.md.

```bash
for f in $(find "$INSTALLED_DIR" -name "skill.md" -not -path "*/references/*"); do
  skill=$(basename "$(dirname "$f")")
  # Verify opening and closing --- delimiters exist
  first_line=$(head -1 "$f")
  if [[ "$first_line" != "---" ]]; then
    echo "CRITICAL: $skill — missing opening --- delimiter"
    continue
  fi
  # Count --- lines (should be exactly 2 in the frontmatter region)
  delimiter_count=$(head -30 "$f" | grep -c "^---$")
  if [[ "$delimiter_count" -lt 2 ]]; then
    echo "CRITICAL: $skill — missing closing --- delimiter"
    continue
  fi
  # Extract YAML block between first and second --- (macOS-compatible)
  yaml_block=$(awk 'NR==1 && /^---$/{found++; next} /^---$/{exit} found{print}' "$f")
  echo "$yaml_block" | grep -q "^name:" || echo "CRITICAL: $skill — missing name: field"
  echo "$yaml_block" | grep -q "^description:" || echo "CRITICAL: $skill — missing description: field"
done
```

**Fix:** Add proper `---` delimiters and required `name:` + `description:` fields.

### Check 2: Empty/Stub Skills

**What:** Skills under 10 lines provide zero agent guidance.

```bash
find "$INSTALLED_DIR" -name "skill.md" -not -path "*/references/*" -exec sh -c \
  'lines=$(wc -l < "$1"); skill=$(basename "$(dirname "$1")"); \
   [ "$lines" -lt 10 ] && echo "CRITICAL: $skill — $lines lines (stub)"' _ {} \;
```

**Fix:** Write actual skill content or delete the skill.

### Check 3: Name Mismatch

**What:** The `name:` field in YAML must exactly match the directory name.

```bash
for f in $(find "$INSTALLED_DIR" -name "skill.md" -not -path "*/references/*"); do
  dir_name=$(basename "$(dirname "$f")")
  yaml_name=$(sed -n '/^---$/,/^---$/p' "$f" | grep "^name:" | sed 's/name:[[:space:]]*//' | tr -d '"' | tr -d "'")
  if [[ -n "$yaml_name" && "$yaml_name" != "$dir_name" ]]; then
    echo "CRITICAL: $dir_name — name: '$yaml_name' ≠ directory '$dir_name'"
  fi
done
```

**Fix:** Align `name:` field with directory name (rename one or the other).

### Check 4: Duplicate Skill Names

**What:** Same skill directory name exists in multiple source repos.

```bash
# Collect all skill names from all source dirs
all_skills=()
for dir in "${SOURCE_DIRS[@]}"; do
  for skill_dir in $(find "$dir" -name "skill.md" -not -path "*/references/*" -exec dirname {} \;); do
    name=$(basename "$skill_dir")
    source=$(echo "$skill_dir" | grep -oE "(superpowers-plus|superpowers-callbox)")
    all_skills+=("$name|$source")
  done
done
# Find duplicates
echo "${all_skills[@]}" | tr ' ' '\n' | cut -d'|' -f1 | sort | uniq -d | while read dup; do
  sources=$(printf '%s\n' "${all_skills[@]}" | grep "^$dup|" | cut -d'|' -f2 | tr '\n' ', ')
  echo "CRITICAL: $dup — exists in: $sources"
done
```

**Fix:** Remove from one repo. superpowers-callbox overrides superpowers-plus by convention.

### Check 5: Broken Internal References

**What:** skill.md references files that don't exist on disk.

```bash
for f in $(find "$INSTALLED_DIR" -name "skill.md" -not -path "*/references/*"); do
  skill=$(basename "$(dirname "$f")")
  skill_dir=$(dirname "$f")
  # Look for references to local files: modules/, references/, examples.md, etc.
  grep -oE '(references/[a-zA-Z0-9_-]+\.md|modules/[a-zA-Z0-9_-]+\.md|examples\.md|reference\.md)' "$f" | while read ref; do
    if [[ ! -f "$skill_dir/$ref" ]]; then
      echo "CRITICAL: $skill — references '$ref' but file does not exist"
    fi
  done
done
```

**Fix:** Create the missing file or remove the reference.

---

## 🟠 ERROR — Skill is degraded

### Check 6: Oversized Skills

**Threshold:** 250 lines. Skills above this get truncated in agent context windows.

```bash
find "$INSTALLED_DIR" -name "skill.md" -not -path "*/references/*" -exec sh -c \
  'lines=$(wc -l < "$1"); skill=$(basename "$(dirname "$1")"); \
   [ "$lines" -gt 250 ] && printf "ERROR: %s — %d lines (%.1f× limit)\n" "$skill" "$lines" "$(echo "$lines / 250" | bc -l)"' _ {} \;
```

**Fix:** Split into `skill.md` (core ≤250) + `references/*.md` for detailed procedures.

### Check 7: Missing Description

**What:** No `description:` field in YAML frontmatter. The skill router uses this for discovery.

```bash
for f in $(find "$INSTALLED_DIR" -name "skill.md" -not -path "*/references/*"); do
  skill=$(basename "$(dirname "$f")")
  yaml_block=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$f" | head -20)
  echo "$yaml_block" | grep -q "^description:" || echo "ERROR: $skill — no description: field"
done
```

**Fix:** Add `description: "Use when..."` to YAML frontmatter.

### Check 8: Orphaned Installs

**What:** Skill is installed but doesn't exist in any source repo.

```bash
for installed in $(find "$INSTALLED_DIR" -maxdepth 1 -mindepth 1 -type d); do
  skill=$(basename "$installed")
  found=false
  for dir in "${SOURCE_DIRS[@]}"; do
    if find "$dir" -type d -name "$skill" 2>/dev/null | grep -q .; then
      found=true; break
    fi
  done
  [[ "$found" == "false" ]] && echo "ERROR: $skill — installed but not in any source repo (orphan)"
done
```

**Fix:** `rm -rf ~/.codex/skills/<orphan>` or re-add to source repo.

### Check 9: Source-Install Content Drift

**What:** Content-diff every installed skill.md against its git source. Catches:
- Content regression (installed has older/simpler version)
- Content corruption (installed file contains unrelated content)
- Bidirectional drift (source and installed diverged independently)

Timestamp comparison is **insufficient** — a corrupted file can have a newer timestamp.

```bash
for dir in "${SOURCE_DIRS[@]}"; do
  find "$dir" -name "skill.md" -not -path "*/references/*" | while read src; do
    skill=$(basename "$(dirname "$src")")
    installed="$INSTALLED_DIR/$skill/skill.md"
    [[ ! -f "$installed" ]] && continue

    # Content diff (not timestamp)
    if ! diff -q "$src" "$installed" > /dev/null 2>&1; then
      src_lines=$(wc -l < "$src" | tr -d ' ')
      inst_lines=$(wc -l < "$installed" | tr -d ' ')
      # Check for corruption: do the files share at least 30% of lines?
      common=$(comm -12 <(sort "$src") <(sort "$installed") | wc -l | tr -d ' ')
      total=$(( src_lines > inst_lines ? src_lines : inst_lines ))
      if [[ "$total" -gt 0 ]]; then
        overlap_pct=$(( common * 100 / total ))
      else
        overlap_pct=0
      fi

      if [[ "$overlap_pct" -lt 30 ]]; then
        echo "CRITICAL: $skill — content CORRUPTION (${overlap_pct}% overlap, likely wrong file)"
        echo "  Source: $src ($src_lines lines)"
        echo "  Installed: $installed ($inst_lines lines)"
        echo "  Fix: cp \"$src\" \"$installed\""
      else
        echo "ERROR: $skill — content drift ($src_lines src vs $inst_lines installed, ${overlap_pct}% overlap)"
        echo "  Fix: Run ./install.sh or cp \"$src\" \"$installed\""
      fi
    fi
  done
done
```

**Severity:** CRITICAL if <30% content overlap (corruption). ERROR if content differs but is recognizably the same skill.

**Fix:** `cp "$src" "$installed"` or run `./install.sh`. For corruption, investigate how the wrong content got there.

---

## 🟡 WARNING — Quality/hygiene issue

### Check 10: Missing Triggers (Not Explicit)

**What:** Skill has no `triggers:` array AND is not in the EXPLICIT_SKILLS list in `skill-trigger-validator.sh`.

```bash
# Load EXPLICIT_SKILLS list
VALIDATOR="$SP_PLUS_DIR/tools/skill-trigger-validator.sh"
EXPLICIT_LIST=$(grep -A50 "^EXPLICIT_SKILLS=" "$VALIDATOR" 2>/dev/null | grep '^\s*"' | tr -d ' "' || echo "")

for f in $(find "$INSTALLED_DIR" -name "skill.md" -not -path "*/references/*"); do
  skill=$(basename "$(dirname "$f")")
  yaml_block=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$f" | head -20)
  has_triggers=$(echo "$yaml_block" | grep "^triggers:" | grep -v 'triggers: \[\]' | grep -v 'triggers:$')
  if [[ -z "$has_triggers" ]]; then
    if ! echo "$EXPLICIT_LIST" | grep -q "^${skill}$"; then
      echo "WARNING: $skill — no triggers and not in EXPLICIT_SKILLS list"
    fi
  fi
done
```

**Fix:** Add `triggers: [...]` to YAML or add skill to EXPLICIT_SKILLS in `skill-trigger-validator.sh`.

### Check 11: Trigger Overlap

**What:** Two or more skills share an identical trigger phrase, causing ambiguous routing.

```bash
# Build trigger→skill mapping
declare -A trigger_map
for f in $(find "$INSTALLED_DIR" -name "skill.md" -not -path "*/references/*"); do
  skill=$(basename "$(dirname "$f")")
  triggers=$(sed -n '/^---$/,/^---$/p' "$f" | grep "^triggers:" | \
    sed 's/triggers://' | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*"//;s/"[[:space:]]*$//' | grep -v '^$')
  while IFS= read -r trigger; do
    [[ -z "$trigger" ]] && continue
    lower_trigger=$(echo "$trigger" | tr '[:upper:]' '[:lower:]')
    if [[ -n "${trigger_map[$lower_trigger]:-}" ]]; then
      echo "WARNING: trigger '$trigger' shared by: ${trigger_map[$lower_trigger]} AND $skill"
    fi
    trigger_map["$lower_trigger"]="${trigger_map[$lower_trigger]:-}${trigger_map[$lower_trigger]:+, }$skill"
  done <<< "$triggers"
done
```

**Fix:** Differentiate triggers or document intentional overlap in both skills.

### Check 12: Deprecated But Active

**What:** Skill body contains "deprecated" or "replaced by" but still has active triggers.

```bash
for f in $(find "$INSTALLED_DIR" -name "skill.md" -not -path "*/references/*"); do
  skill=$(basename "$(dirname "$f")")
  body=$(tail -n +2 "$f")  # Skip first line
  if echo "$body" | grep -qi "deprecated\|replaced by\|superseded by\|use .* instead"; then
    yaml_block=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$f" | head -20)
    has_triggers=$(echo "$yaml_block" | grep "^triggers:" | grep -v 'triggers: \[\]')
    if [[ -n "$has_triggers" ]]; then
      echo "WARNING: $skill — contains deprecation language but still has active triggers"
    fi
  fi
done
```

**Fix:** Remove triggers from deprecated skill, or remove the deprecation language if skill is actually active.

### Check 13: Dead External References

**What:** skill.md contains URLs or wiki links that don't resolve.

```bash
for f in $(find "$INSTALLED_DIR" -name "skill.md" -not -path "*/references/*"); do
  skill=$(basename "$(dirname "$f")")
  # Extract wiki URLs
  grep -oE 'https://wiki\.int\.callbox\.net/doc/[a-zA-Z0-9_-]+' "$f" | while read url; do
    slug=$(echo "$url" | sed 's|.*/doc/||')
    # Use Outline MCP or curl to verify
    echo "CHECK: $skill — wiki link $slug (verify with get_document_outline)"
  done
  # Extract file path references (e.g., ~/GitHub/..., ~/.codex/...)
  grep -oE '(~/[a-zA-Z0-9_./-]+|/Users/[a-zA-Z0-9_./-]+)' "$f" | while read path; do
    expanded=$(eval echo "$path" 2>/dev/null)
    [[ ! -e "$expanded" ]] && echo "WARNING: $skill — references path '$path' which does not exist"
  done
done
```

**Note:** Wiki URL verification requires network. Skip gracefully if offline and note in report.

**Fix:** Update or remove dead links.

---

## 🔵 INFO — Recommendations

### Check 14: Junk Files

**What:** Non-skill files in source repo roots that shouldn't be committed.

```bash
for dir in "${SOURCE_DIRS[@]}"; do
  # Check repo root for junk
  root=$(echo "$dir" | sed 's|/skills$||')
  find "$root" -maxdepth 1 -type f \
    ! -name "*.md" ! -name "*.sh" ! -name "*.js" ! -name "*.json" \
    ! -name "*.yaml" ! -name "*.yml" ! -name "*.txt" \
    ! -name "CODEOWNERS" ! -name ".gitignore" ! -name ".gitattributes" \
    ! -name ".editorconfig" ! -name ".env*" ! -name "LICENSE" \
    ! -name ".DS_Store" ! -name "Makefile" ! -name "package.json" \
    2>/dev/null | while read junk; do
      echo "INFO: junk file in $(basename "$root")/: $(basename "$junk")"
    done
done
```

**Fix:** Delete the junk file and add to `.gitignore` if it recurs.

### Check 15: Skill Structure Quality

**What:** Scan each skill for structural best practices.

```bash
for f in $(find "$INSTALLED_DIR" -name "skill.md" -not -path "*/references/*"); do
  skill=$(basename "$(dirname "$f")")
  content=$(cat "$f")
  issues=()

  # Check for "When to Use" / "When to Invoke" section
  echo "$content" | grep -qi "when to use\|when to invoke" || \
    issues+=("missing 'When to Use' section")

  # Check for at least one example or code block
  echo "$content" | grep -q '```' || \
    issues+=("no code examples")

  # Check for "Fix:" or "Failure" section (actionable guidance)
  echo "$content" | grep -qi "failure\|fix:\|recovery\|troubleshoot" || \
    issues+=("no failure modes or troubleshooting")

  # Check description starts with "Use when" (best practice)
  desc=$(sed -n '/^---$/,/^---$/p' "$f" | grep "^description:" | head -1)
  echo "$desc" | grep -qi "use when\|invoke when\|diagnose\|enforce\|track\|generate\|scan\|verify" || \
    issues+=("description doesn't start with action verb")

  if [[ ${#issues[@]} -gt 0 ]]; then
    echo "INFO: $skill — $(IFS='; '; echo "${issues[*]}")"
  fi
done
```

**Fix:** Add missing sections. See `skill-authoring` skill for the recommended template.

---

## 🔴 CRITICAL — Content Integrity

### Check 16: Reference File Integrity

**What:** Content-diff every installed `references/*.md` against its git source. Catches:
- Missing reference files (source has them, installed doesn't — or vice versa)
- Corrupted reference files (installed contains unrelated content, e.g., a bash script in a checks.md)
- Stale reference files (content has diverged between source and installed)

```bash
for dir in "${SOURCE_DIRS[@]}"; do
  find "$dir" -path "*/references/*.md" | while read src_ref; do
    skill_dir=$(basename "$(dirname "$(dirname "$src_ref")")")
    ref_name=$(basename "$src_ref")
    installed_ref="$INSTALLED_DIR/$skill_dir/references/$ref_name"

    if [[ ! -f "$installed_ref" ]]; then
      echo "ERROR: $skill_dir — missing installed reference: references/$ref_name"
      echo "  Fix: cp \"$src_ref\" \"$installed_ref\""
      continue
    fi

    if ! diff -q "$src_ref" "$installed_ref" > /dev/null 2>&1; then
      src_lines=$(wc -l < "$src_ref" | tr -d ' ')
      inst_lines=$(wc -l < "$installed_ref" | tr -d ' ')
      # Corruption check: do they share meaningful content?
      common=$(comm -12 <(sort "$src_ref") <(sort "$installed_ref") | wc -l | tr -d ' ')
      total=$(( src_lines > inst_lines ? src_lines : inst_lines ))
      overlap_pct=$(( total > 0 ? common * 100 / total : 0 ))

      if [[ "$overlap_pct" -lt 30 ]]; then
        echo "CRITICAL: $skill_dir/references/$ref_name — CORRUPTION (${overlap_pct}% overlap)"
        echo "  Installed file may contain content from a DIFFERENT file"
        echo "  Source: $src_lines lines | Installed: $inst_lines lines"
        echo "  Fix: cp \"$src_ref\" \"$installed_ref\""
      else
        echo "ERROR: $skill_dir/references/$ref_name — content drift (${overlap_pct}% overlap)"
        echo "  Fix: cp \"$src_ref\" \"$installed_ref\""
      fi
    fi
  done
done

# Reverse check: installed references not in source
for inst_ref in $(find "$INSTALLED_DIR" -path "*/references/*.md" 2>/dev/null); do
  skill_dir=$(basename "$(dirname "$(dirname "$inst_ref")")")
  ref_name=$(basename "$inst_ref")
  found=false
  for dir in "${SOURCE_DIRS[@]}"; do
    src_skill=$(find "$dir" -maxdepth 3 -type d -name "$skill_dir" 2>/dev/null | head -1)
    if [[ -n "$src_skill" ]] && [[ -f "$src_skill/references/$ref_name" ]]; then
      found=true
      break
    fi
  done
  if ! $found; then
    echo "WARNING: $skill_dir/references/$ref_name — installed but not in any source repo (orphaned reference)"
  fi
done
```

**Real incident (2026-03-19):** `superpowers-doctor/references/checks.md` installed copy contained `write-archives.sh` bash script content instead of the 331-line check procedures. 0% content overlap. Went undetected because no check compared file content — only timestamps.

**Fix:** `cp "$src_ref" "$installed_ref"`. For corruption, investigate the install pipeline for copy errors.
