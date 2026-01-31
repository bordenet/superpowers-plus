# CLI Tools Conventions

> **Priority**: HIGH - Apply to CLI/terminal tools  
> **Source**: codebase-reviewer, scripts Agents.md

## 🚨 CLI Integration Testing - QUALITY GATE

CLI tools MUST have integration tests that verify:
- Command execution with various inputs
- Exit codes (0 for success, non-zero for errors)
- Output format correctness
- Error message quality

## Shell Script Standards

### Self-Contained

Scripts should be:
- Executable without external setup
- Include all needed helpers inline
- Document dependencies at top

### Robust

Scripts should:
- Use `set -euo pipefail`
- Handle empty inputs gracefully
- Quote all variables
- Provide helpful error messages

### macOS-Aware

Test on macOS and Linux:
- BSD vs GNU tool differences
- Path conventions
- Available commands

## Output Patterns

### Progress Indicators

```bash
echo "Processing files..."
for file in "${files[@]}"; do
    echo "  - $file"
    process "$file"
done
echo "Done. Processed ${#files[@]} files."
```

### Error Output

```bash
# Errors to stderr
echo "Error: File not found: $file" >&2
exit 1
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Misuse/invalid args |
| 126 | Permission denied |
| 127 | Command not found |

## Help Text Pattern

```bash
usage() {
    cat << EOF
Usage: ${0##*/} [OPTIONS] <input>

Description of what the command does.

Options:
    -h, --help     Show this help message
    -v, --verbose  Enable verbose output
    -o, --output   Output directory (default: .)

Examples:
    ${0##*/} input.txt
    ${0##*/} -v -o ./out input.txt
EOF
}
```

