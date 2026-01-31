# Shell Script Conventions

> **Priority**: HIGH - Apply to all shell scripts  
> **Source**: scripts/Agents.md (extensive documentation)

## Common Pitfalls to Avoid

### SC2155 - Declare and assign separately

```bash
# ❌ Wrong - masks return value
local output=$(some_command)

# ✅ Correct - preserves return value
local output
output=$(some_command)
```

### Filename Handling

```bash
# ❌ Wrong - breaks on spaces/special chars
for file in $(ls); do

# ✅ Correct - safe iteration
for file in *; do
    [[ -e "$file" ]] || continue
```

### Input Sanitization

```bash
# ✅ Always quote variables
"$variable"

# ✅ Use [[ ]] for conditionals (safer than [ ])
if [[ -z "$var" ]]; then

# ✅ Validate inputs before use
[[ -f "$file" ]] || { echo "File not found"; exit 1; }
```

## Script Template

```bash
#!/usr/bin/env bash
set -euo pipefail

# Description: [What this script does]
# Usage: script.sh [options] <args>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
    # Implementation here
    :
}

main "$@"
```

## Pre-Commit Checklist

1. [ ] Run ShellCheck: `shellcheck script.sh`
2. [ ] Test with `set -euo pipefail`
3. [ ] Test with empty inputs
4. [ ] Test with paths containing spaces
5. [ ] Verify works on macOS (BSD tools vs GNU)
6. [ ] Check variable exports for libraries

## Platform Compatibility

macOS uses BSD tools, Linux uses GNU. Common differences:

| Command | macOS (BSD) | Linux (GNU) |
|---------|-------------|-------------|
| sed -i | `sed -i ''` | `sed -i` |
| grep -P | Not available | Available |
| date | Different flags | Different flags |

```bash
# ✅ Portable sed in-place
if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' 's/old/new/' file
else
    sed -i 's/old/new/' file
fi
```

## Commands

```bash
# Lint with ShellCheck
shellcheck -x script.sh

# Check syntax
bash -n script.sh
```

