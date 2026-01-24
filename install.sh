#!/bin/bash
# Install superpowers-plus skills to ~/.codex/skills (personal skills directory)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${HOME}/.codex/skills"

echo "Installing superpowers-plus skills..."

# Create skills directory if it doesn't exist
mkdir -p "$SKILLS_DIR"

# Install all skills from this repo
for skill_dir in "$SCRIPT_DIR/skills/"*/; do
    skill_name=$(basename "$skill_dir")
    echo "  → Installing $skill_name..."
    rm -rf "$SKILLS_DIR/$skill_name"
    cp -r "$skill_dir" "$SKILLS_DIR/$skill_name"
done

echo ""
echo "✓ Skills installed successfully to $SKILLS_DIR"
echo ""
echo "Verify with:"
echo "  node ~/.codex/superpowers-augment/superpowers-augment.js find-skills"
echo ""
echo "Available skills:"
for skill_dir in "$SCRIPT_DIR/skills/"*/; do
    skill_name=$(basename "$skill_dir")
    echo "  • $skill_name"
done

