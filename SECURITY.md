# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| latest (main) | ✅ |
| older releases | ❌ |

## Reporting a Vulnerability

**Do not open a public GitHub issue for security matters.**

Please report security concerns privately via one of these channels:

- **GitHub Private Vulnerability Reporting**: Use the [Report a vulnerability](https://github.com/bordenet/superpowers-plus/security/advisories/new) button on the Security tab (private reporting is enabled on this repo)
- **GitHub**: Contact [@bordenet](https://github.com/bordenet) directly

Include in your report:
- A description of the issue and its potential impact
- Steps to reproduce
- Any relevant logs or proof-of-concept (if safe to share)

## Response Timeline

| Action | Target |
|--------|--------|
| Initial acknowledgement | 48 hours |
| Triage and severity assessment | 5 business days |
| Fix or mitigation | Depends on severity |

## Scope

superpowers-plus is a collection of skill files and shell scripts installed into AI coding assistant runtimes. The primary security surface is the install scripts (`install.sh`, `install.ps1`) and any hooks that execute shell commands.

## Disclosure Policy

We follow [coordinated disclosure](https://en.wikipedia.org/wiki/Coordinated_vulnerability_disclosure). We ask that you give us reasonable time to address an issue before public disclosure.
