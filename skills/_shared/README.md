# Shared Modules

Reusable components shared across multiple skills.

## Files

| Module | Purpose | Used By |
|--------|---------|---------|
| `secret-detection.md` | Regex patterns for API keys, tokens, passwords | wiki/wiki-secret-audit, security/* |

## Usage

Skills can reference shared modules inline or import patterns as needed. These are not standalone skills — they don't have `skill.md` files.

