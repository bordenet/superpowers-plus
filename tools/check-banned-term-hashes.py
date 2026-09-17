#!/usr/bin/env python3
"""check-banned-term-hashes.py — hash-based denylist scanner.

Reads text on stdin (a diff, a commit message, a file's contents) and exits
non-zero if it contains a permanently banned term: an internal product or
company codename that must never appear in this public repo, in any form
(commit message, code, comment, branch name, PR title text embedded in a
merge commit, etc.) -- see incident: full-history rewrite required after a
codename plus real internal infrastructure detail (AWS account IDs, an SSO
URL, DB schema) was committed and later only removed from the tree, not
from history.

Terms are stored as salted SHA-256 hashes rather than plaintext, so a casual
grep of this file or repo cannot recover the banned words, and the guard
does not itself put the codename in the diff of whatever change introduces
a new entry. This is obfuscation, not cryptographic secrecy: the salt is
public (committed alongside the hashes), so a reader who already suspects a
specific term can still confirm it by hashing their guess. The goal is
preventing accidental/casual disclosure, not defeating a targeted attacker
who already knows what they're looking for.

Matching is whole-token (and adjacent-token-pair, scoped to a single line,
to catch two-word phrases and hyphen/underscore-joined spellings) so it
does not false-positive on unrelated words that merely contain a banned
term as a substring, or on two unrelated words that happen to land next to
each other across a line or file boundary.

Exit codes: 0 = clean, 1 = banned term found (message on stderr), 2 = usage.
"""
import hashlib
import os
import re
import sys

SALT = "sp-plus-ip-guard-v1:"

# One entry per banned term, computed offline as:
#   hashlib.sha256((SALT + "<lowercase term, letters only>").encode()).hexdigest()
# To add a term: compute its hash the same way and append it here. Never add
# the plaintext term anywhere in this repo (commit message, comment, test
# fixture, or otherwise) -- that defeats the entire point of this file.
BANNED_HASHES = {
    "71ed989267c8720f035a4d83bf49b4f5d5e88ecfc572d9b45ba5b97b222ff461",  # single token
    "cec947ca1e552b469bb8fe2ab4040357dc7162a86b91858b89d287564d0172be",  # single token
    "c6a602dfdb7eed402610ba9d86b5132218ab6b26604abd977130257ec9a306ba",  # adjacent-pair term
}

TOKEN_RE = re.compile(r"[a-z]+")


def _hash(candidate):
    return hashlib.sha256((SALT + candidate).encode("utf-8")).hexdigest()


def _active_hashes():
    # Test-only addition: lets the test suite verify the tokenize/hash/match
    # mechanism using an obviously-fake term (e.g. "acme-test-codename")
    # instead of the real banned terms, so no test file ever has to contain
    # them in plaintext. Mirrors the CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE
    # pattern already used by tools/claude-hooks/pre-tool-use-internal-terms.sh.
    #
    # This is a UNION with BANNED_HASHES, never a replacement. An override
    # that replaced the real set would let anyone with control of an env var
    # (a shell rc file, a compromised CI step) silently disable the guard for
    # every real banned term -- the whole point of this file -- while a
    # union can only add extra test-only detection on top of the real set.
    override = os.environ.get("BANNED_HASH_TEST_OVERRIDE")
    if override:
        return BANNED_HASHES | {h.strip() for h in override.split(",") if h.strip()}
    return BANNED_HASHES


def scan(text):
    """Return True if text contains a banned term (single token, or an
    adjacent word-pair joined with no separator, within one line).

    Tokenization is scoped per line so that e.g. a line ending in one half
    of a two-word banned phrase and the next, unrelated line starting with
    the other half never pairs up into a false match.
    """
    active = _active_hashes()
    for line in text.split("\n"):
        tokens = TOKEN_RE.findall(line.lower())
        for i, tok in enumerate(tokens):
            if _hash(tok) in active:
                return True
            if i + 1 < len(tokens) and _hash(tok + tokens[i + 1]) in active:
                return True
    return False


def main():
    text = sys.stdin.read()
    if scan(text):
        print(
            "BLOCKED: banned internal term detected (hash-matched; see "
            "tools/check-banned-term-hashes.py). This repo is public -- "
            "internal product/company codenames must never be committed, "
            "in messages or content.",
            file=sys.stderr,
        )
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
