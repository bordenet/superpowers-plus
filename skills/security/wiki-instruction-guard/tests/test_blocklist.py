#!/usr/bin/env python3
"""
CI test runner for wiki-instruction-guard blocklist patterns.

Validates that:
1. Every command in known-bad-commands.txt matches at least one pattern
2. Every line in known-bad-prose.txt matches at least one prose pattern
3. Every line in known-good-commands.txt matches NO patterns
"""

import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Pattern definitions (must match skill.md exactly)
# ---------------------------------------------------------------------------

CATEGORIES = {
    "CAT1": [
        r'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)',
        r'rm\s+-[a-zA-Z]*r\s+-[a-zA-Z]*f',
        r'rm\s+.*\s+(/(etc|var|home|root|usr|opt|boot|srv|lib|bin|sbin)/|~/|\$HOME/)',
        r'(mkfs[.\s]|dd\s+if=|shred\s)',
        r'(wipefs|sgdisk\s+--zap)',
        r'truncate\s+-s\s+0',
        r'crontab\s+-r',
        r'>\s*(~/\.(bashrc|profile|zshrc|ssh)|/etc/)',
        r'find\s+.*(-delete|-exec\s+rm)',
    ],
    "CAT2": [
        r'(cat|less|head|tail|grep).*\.env.*\|.*(curl|wget|nc|ncat|netcat)',
        r'curl.*[$].*(_KEY|_TOKEN|_SECRET|_PAT|PASSWORD)',
        r'nc\s+-l',
        r'(cat|cp|scp|rsync).*~/\.ssh/(id_|known_hosts|authorized_keys)',
        r'(env|printenv|set)\s*\|.*(curl|wget|nc)',
    ],
    "CAT3": [
        r'git\s+push\s+.*--force($|\s[^-])',
        r'git\s+push\s+-[a-zA-Z]*f',
        r'git\s+reset\s+--hard\s+(origin|upstream)',
        r'git\s+push\s+.*\s+:refs/',
        r'git\s+filter-branch',
    ],
    "CAT4": [
        r'curl\s.*\|\s*(bash|sh|zsh|python[23]?|perl|ruby|node)',
        r'wget\s.*-O\s*-\s*\|\s*(bash|sh|zsh|python[23]?)',
        r'(bash|sh|zsh)\s+<\(curl',
        r'sh\s+-c\s+.*(curl|wget|rm|dd|mkfs|chmod|chown)',
        r'eval\s+"\$\((curl|wget)',
        r'(python[23]?|ruby|perl|node)\s+-[ce]\s+"\$\((curl|wget)',
    ],
    "CAT5": [
        r'chmod\s+777',
        r'chown\s+(root|0:)',
        r'chmod\s+[ugo]*\+s',
        r'docker\s+run\s+.*--privileged',
    ],
    "CAT5_WARN": [
        r'sudo\s',
    ],
    "CAT6": [
        r'security\s+(find-generic-password|find-internet-password|dump-keychain)',
        r'export\s+[A-Z_]*(_TOKEN|_KEY|_SECRET|_PAT)=["\']?[A-Za-z0-9]',
    ],
    "CAT7": [
        r'(skip|ignore|disable|bypass)\s+.*(safety|security|guard|scan|check|wiki-instruction-guard)',
        r'(override|disregard)\s+(previous|system|safety)\s+(instructions|rules|constraints)',
        r'(already\s+verified|pre-?approved|security\s+team\s+has\s+reviewed|safe\s+to\s+execute\s+directly)',
        r'(ignore\s+previous\s+instructions|you\s+are\s+now|new\s+system\s+prompt|act\s+as\s+if)',
    ],
    "CAT8": [
        r':\(\)\{.*:\|:.*\};:',
        r'kill\s+-9\s+-1',
        r'(shutdown|reboot|halt|poweroff)\s',
    ],
    "CAT9": [
        r'(>|>>|tee|cp|mv|cat\s*<<).*wiki-instruction-guard/references/',
        r'(>|>>|tee|cp|mv|cat\s*<<).*domain-allowlist',
    ],
    "OBFUSC": [
        r'base64\s+(-d|--decode).*\|\s*(bash|sh)',
        r'echo.*\|\s*base64.*\|\s*(bash|sh)',
        r"r['\"]" + "{2}m",
        r'printf\s+.*\\x.*\|\s*(bash|sh)',
        r'alias\s+[a-zA-Z0-9_]+=.*rm\s',
        r'python[23]?\s+-c\s+.*\b(os\.system|subprocess|exec\(|eval\()',
        r'cat\s*<<.*>\s*(~/\.ssh|/etc/)',
        r'echo\s+.*rm\s',
        r'echo\s+.*curl.*\|.*bash',
        r'tee\s+.*\|\s*(bash|sh)',
        r'perl\s+-e\s+.*\b(unlink|rmdir|system)',
        r'ruby\s+-e\s+.*\b(FileUtils\.(rm|remove)|system|exec)',
        r'\$\(.*\brm\b',
    ],
}

PROSE_PATTERNS = [
    r'(delete|remove|wipe|clean|clear|purge|destroy|erase)\s+.*(all|entire|contents\s+of|everything\s+in)\s+.*(\.ssh|\.env|\.codex|home\s+directory|credentials|secrets|keys)',
    r'(send|upload|post|share|transmit|forward|email)\s+.*(all|every|entire|contents\s+of)\s+.*(secret|key|token|credential|password|\.env|\.ssh)',
    r'(force[\s-]push|rewrite\s+history|reset\s+.*hard|delete\s+.*branch)',
]

# All code-block patterns flattened (for false-positive testing)
ALL_CODE_PATTERNS = []
for cat, patterns in CATEGORIES.items():
    ALL_CODE_PATTERNS.extend(patterns)


def load_test_file(filename):
    """Load test file, skip comments and blank lines. Returns list of (category, command)."""
    path = Path(__file__).parent / filename
    entries = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "|" in line:
            cat, cmd = line.split("|", 1)
            entries.append((cat.strip(), cmd.strip()))
        else:
            entries.append((None, line))
    return entries


def test_known_bad_commands():
    """Every command in known-bad-commands.txt must match its category."""
    entries = load_test_file("known-bad-commands.txt")
    failures = []

    for category, command in entries:
        if category not in CATEGORIES:
            failures.append(f"  UNKNOWN CATEGORY '{category}': {command}")
            continue

        patterns = CATEGORIES[category]
        matched = False
        for pattern in patterns:
            if re.search(pattern, command):
                matched = True
                break

        if not matched:
            failures.append(f"  {category} NO MATCH: {command}")

    return failures


def test_known_bad_prose():
    """Every line in known-bad-prose.txt must match at least one prose pattern."""
    entries = load_test_file("known-bad-prose.txt")
    failures = []

    for _, text in entries:
        matched = False
        for pattern in PROSE_PATTERNS:
            if re.search(pattern, text, re.IGNORECASE):
                matched = True
                break

        if not matched:
            failures.append(f"  PROSE NO MATCH: {text}")

    return failures


def test_known_good_commands():
    """No command in known-good-commands.txt should match any pattern."""
    entries = load_test_file("known-good-commands.txt")
    failures = []

    # Categories that produce WARN (not BLOCK) are excluded from false-positive checks
    # because some good commands intentionally match them (e.g., sudo)
    warn_categories = {"CAT5_WARN"}

    for _, command in entries:
        for cat_name, patterns in CATEGORIES.items():
            if cat_name in warn_categories:
                continue
            for pattern in patterns:
                if re.search(pattern, command):
                    failures.append(
                        f"  FALSE POSITIVE [{cat_name}]: {command}\n"
                        f"    Matched: {pattern}"
                    )

        # Also check prose patterns (case-insensitive)
        for pattern in PROSE_PATTERNS:
            if re.search(pattern, command, re.IGNORECASE):
                failures.append(
                    f"  FALSE POSITIVE [PROSE]: {command}\n"
                    f"    Matched: {pattern}"
                )

    return failures


def main():
    print("wiki-instruction-guard blocklist test suite")
    print("=" * 60)

    all_failures = []

    # Test 1: Known-bad commands
    print("\n[1/3] Testing known-bad-commands.txt...")
    failures = test_known_bad_commands()
    if failures:
        print(f"  FAIL: {len(failures)} commands did not match")
        all_failures.extend(failures)
    else:
        entries = load_test_file("known-bad-commands.txt")
        print(f"  PASS: {len(entries)} commands matched their categories")

    # Test 2: Known-bad prose
    print("\n[2/3] Testing known-bad-prose.txt...")
    failures = test_known_bad_prose()
    if failures:
        print(f"  FAIL: {len(failures)} prose lines did not match")
        all_failures.extend(failures)
    else:
        entries = load_test_file("known-bad-prose.txt")
        print(f"  PASS: {len(entries)} prose lines matched")

    # Test 3: Known-good commands (false positive check)
    print("\n[3/3] Testing known-good-commands.txt...")
    failures = test_known_good_commands()
    if failures:
        print(f"  FAIL: {len(failures)} false positives detected")
        all_failures.extend(failures)
    else:
        entries = load_test_file("known-good-commands.txt")
        print(f"  PASS: {len(entries)} commands correctly not matched")

    # Summary
    print("\n" + "=" * 60)
    if all_failures:
        print(f"FAILED: {len(all_failures)} total failures\n")
        for f in all_failures:
            print(f)
        sys.exit(1)
    else:
        print("ALL TESTS PASSED")
        sys.exit(0)


if __name__ == "__main__":
    main()
