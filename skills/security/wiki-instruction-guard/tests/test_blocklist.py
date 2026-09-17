#!/usr/bin/env python3
"""
CI test runner for wiki-instruction-guard blocklist patterns.

Validates that:
1. Canonical JSON field types and safety semantics are exact and fail closed
2. Every command in known-bad-commands.txt matches at least one pattern
3. Every line in known-bad-prose.txt matches at least one prose pattern
4. Every line in known-good-commands.txt matches NO patterns
"""

import copy
import json
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Canonical pattern source. The skill points agents to this same file, so the
# executable corpus test and the instruction artifact cannot maintain copies.
# ---------------------------------------------------------------------------
PATTERN_FILE = Path(__file__).parent.parent / "references" / "blocklist-patterns.json"
EXPECTED_CATEGORY_VERDICTS = {
    "CAT1": "BLOCK",
    "CAT2": "BLOCK",
    "CAT3": "BLOCK",
    "CAT4": "BLOCK",
    "CAT5": "BLOCK",
    "CAT5_WARN": "WARN",
    "CAT6": "BLOCK",
    "CAT7": "NON_OVERRIDABLE",
    "CAT8": "BLOCK",
    "CAT9": "BLOCK",
    "OBFUSC": "BLOCK",
}
EXPECTED_CATEGORIES = set(EXPECTED_CATEGORY_VERDICTS)
EXPECTED_ROOT_FIELDS = {"schema_version", "code_case_sensitive", "code_categories", "prose"}
EXPECTED_CATEGORY_FIELDS = {"name", "verdict", "patterns"}
EXPECTED_PROSE_FIELDS = {"case_insensitive", "verdict", "patterns"}


def validate_pattern_contract(document):
    """Reject malformed or semantically weakened canonical blocklist data."""
    errors = []

    if type(document) is not dict:
        raise ValueError("blocklist pattern source must be a JSON object")

    def require_fields(value, expected, path):
        if type(value) is not dict:
            errors.append(f"{path} must be an object")
            return False
        actual = set(value)
        if actual != expected:
            errors.append(
                f"{path} fields must be exactly {sorted(expected)}; got {sorted(actual)}"
            )
        return True

    def require_type(value, expected_type, path):
        if type(value) is not expected_type:
            errors.append(f"{path} must be {expected_type.__name__}")
            return False
        return True

    require_fields(document, EXPECTED_ROOT_FIELDS, "root")

    schema_version = document.get("schema_version")
    if require_type(schema_version, int, "schema_version") and schema_version != 1:
        errors.append("schema_version must be 1")

    code_case_sensitive = document.get("code_case_sensitive")
    if require_type(code_case_sensitive, bool, "code_case_sensitive") and code_case_sensitive is not True:
        errors.append("code_case_sensitive must be true")

    categories = document.get("code_categories")
    if require_type(categories, dict, "code_categories"):
        actual_categories = set(categories)
        if actual_categories != EXPECTED_CATEGORIES:
            errors.append(
                "code_categories keys must be exactly "
                f"{sorted(EXPECTED_CATEGORIES)}; got {sorted(actual_categories)}"
            )

        for category, expected_verdict in EXPECTED_CATEGORY_VERDICTS.items():
            if category not in categories:
                continue
            config = categories[category]
            path = f"code_categories.{category}"
            if not require_fields(config, EXPECTED_CATEGORY_FIELDS, path):
                continue

            name = config.get("name")
            if require_type(name, str, f"{path}.name") and not name:
                errors.append(f"{path}.name must be non-empty")

            verdict = config.get("verdict")
            if require_type(verdict, str, f"{path}.verdict") and verdict != expected_verdict:
                errors.append(f"{path}.verdict must be {expected_verdict}")

            patterns = config.get("patterns")
            if require_type(patterns, list, f"{path}.patterns"):
                if not patterns:
                    errors.append(f"{path}.patterns must be non-empty")
                for index, pattern in enumerate(patterns):
                    pattern_path = f"{path}.patterns[{index}]"
                    if require_type(pattern, str, pattern_path) and not pattern:
                        errors.append(f"{pattern_path} must be non-empty")

    prose = document.get("prose")
    if require_fields(prose, EXPECTED_PROSE_FIELDS, "prose"):
        case_insensitive = prose.get("case_insensitive")
        if require_type(case_insensitive, bool, "prose.case_insensitive") and case_insensitive is not True:
            errors.append("prose.case_insensitive must be true")

        verdict = prose.get("verdict")
        if require_type(verdict, str, "prose.verdict") and verdict != "WARN":
            errors.append("prose.verdict must be WARN")

        patterns = prose.get("patterns")
        if require_type(patterns, list, "prose.patterns"):
            if not patterns:
                errors.append("prose.patterns must be non-empty")
            for index, pattern in enumerate(patterns):
                pattern_path = f"prose.patterns[{index}]"
                if require_type(pattern, str, pattern_path) and not pattern:
                    errors.append(f"{pattern_path} must be non-empty")

    if errors:
        raise ValueError("invalid blocklist pattern contract:\n- " + "\n- ".join(errors))


PATTERN_DATA = json.loads(PATTERN_FILE.read_text(encoding="utf-8"))
validate_pattern_contract(PATTERN_DATA)
CATEGORIES = {
    name: config["patterns"]
    for name, config in PATTERN_DATA["code_categories"].items()
}
PROSE_PATTERNS = PATTERN_DATA["prose"]["patterns"]
CODE_FLAGS = 0 if PATTERN_DATA["code_case_sensitive"] else re.IGNORECASE
PROSE_FLAGS = re.IGNORECASE if PATTERN_DATA["prose"]["case_insensitive"] else 0
for patterns in CATEGORIES.values():
    for pattern in patterns:
        re.compile(pattern, CODE_FLAGS)
for pattern in PROSE_PATTERNS:
    re.compile(pattern, PROSE_FLAGS)

# All code-block patterns flattened (for false-positive testing)
ALL_CODE_PATTERNS = []
for cat, patterns in CATEGORIES.items():
    ALL_CODE_PATTERNS.extend(patterns)


def _mutated_document(mutator):
    document = copy.deepcopy(PATTERN_DATA)
    mutator(document)
    return document


def contract_mutation_cases():
    """Build independent mutations that every canonical contract check must reject."""
    cases = [
        ("root type", []),
        ("missing schema_version", _mutated_document(lambda d: d.pop("schema_version"))),
        ("schema_version type", _mutated_document(lambda d: d.__setitem__("schema_version", "1"))),
        ("schema_version value", _mutated_document(lambda d: d.__setitem__("schema_version", 2))),
        ("missing code_case_sensitive", _mutated_document(lambda d: d.pop("code_case_sensitive"))),
        ("code_case_sensitive type", _mutated_document(lambda d: d.__setitem__("code_case_sensitive", 1))),
        ("code_case_sensitive value", _mutated_document(lambda d: d.__setitem__("code_case_sensitive", False))),
        ("missing code_categories", _mutated_document(lambda d: d.pop("code_categories"))),
        ("code_categories type", _mutated_document(lambda d: d.__setitem__("code_categories", []))),
        ("unexpected category", _mutated_document(lambda d: d["code_categories"].__setitem__("CAT10", {}))),
        ("missing prose", _mutated_document(lambda d: d.pop("prose"))),
        ("prose type", _mutated_document(lambda d: d.__setitem__("prose", []))),
        ("missing prose.case_insensitive", _mutated_document(lambda d: d["prose"].pop("case_insensitive"))),
        ("prose.case_insensitive type", _mutated_document(lambda d: d["prose"].__setitem__("case_insensitive", 1))),
        ("prose.case_insensitive value", _mutated_document(lambda d: d["prose"].__setitem__("case_insensitive", False))),
        ("missing prose.verdict", _mutated_document(lambda d: d["prose"].pop("verdict"))),
        ("prose.verdict type", _mutated_document(lambda d: d["prose"].__setitem__("verdict", None))),
        ("prose.verdict value", _mutated_document(lambda d: d["prose"].__setitem__("verdict", "BLOCK"))),
        ("missing prose.patterns", _mutated_document(lambda d: d["prose"].pop("patterns"))),
        ("prose.patterns type", _mutated_document(lambda d: d["prose"].__setitem__("patterns", {}))),
        ("empty prose.patterns", _mutated_document(lambda d: d["prose"].__setitem__("patterns", []))),
        ("prose pattern type", _mutated_document(lambda d: d["prose"]["patterns"].__setitem__(0, 7))),
    ]

    for category in EXPECTED_CATEGORY_VERDICTS:
        cases.extend([
            (f"missing {category}", _mutated_document(lambda d, c=category: d["code_categories"].pop(c))),
            (f"{category} type", _mutated_document(lambda d, c=category: d["code_categories"].__setitem__(c, []))),
            (f"missing {category}.name", _mutated_document(lambda d, c=category: d["code_categories"][c].pop("name"))),
            (f"{category}.name type", _mutated_document(lambda d, c=category: d["code_categories"][c].__setitem__("name", None))),
            (f"missing {category}.verdict", _mutated_document(lambda d, c=category: d["code_categories"][c].pop("verdict"))),
            (f"{category}.verdict type", _mutated_document(lambda d, c=category: d["code_categories"][c].__setitem__("verdict", None))),
            (f"{category}.verdict value", _mutated_document(lambda d, c=category: d["code_categories"][c].__setitem__("verdict", "MUTATED"))),
            (f"missing {category}.patterns", _mutated_document(lambda d, c=category: d["code_categories"][c].pop("patterns"))),
            (f"{category}.patterns type", _mutated_document(lambda d, c=category: d["code_categories"][c].__setitem__("patterns", {}))),
            (f"empty {category}.patterns", _mutated_document(lambda d, c=category: d["code_categories"][c].__setitem__("patterns", []))),
            (f"{category} pattern type", _mutated_document(lambda d, c=category: d["code_categories"][c]["patterns"].__setitem__(0, 7))),
        ])

    return cases


def test_canonical_contract_mutations():
    """Every required-field or semantic mutation must fail closed."""
    failures = []
    for label, document in contract_mutation_cases():
        try:
            validate_pattern_contract(document)
        except ValueError:
            continue
        failures.append(f"  CONTRACT MUTATION ACCEPTED: {label}")
    return failures


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
            if re.search(pattern, command, CODE_FLAGS):
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
            if re.search(pattern, text, PROSE_FLAGS):
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
    warn_categories = {
        name
        for name, config in PATTERN_DATA["code_categories"].items()
        if config["verdict"] == "WARN"
    }

    for _, command in entries:
        for cat_name, patterns in CATEGORIES.items():
            if cat_name in warn_categories:
                continue
            for pattern in patterns:
                if re.search(pattern, command, CODE_FLAGS):
                    failures.append(
                        f"  FALSE POSITIVE [{cat_name}]: {command}\n"
                        f"    Matched: {pattern}"
                    )

        # Also check prose patterns (case-insensitive)
        for pattern in PROSE_PATTERNS:
            if re.search(pattern, command, PROSE_FLAGS):
                failures.append(
                    f"  FALSE POSITIVE [PROSE]: {command}\n"
                    f"    Matched: {pattern}"
                )

    return failures


def main():
    print("wiki-instruction-guard blocklist test suite")
    print("=" * 60)

    all_failures = []

    # Test 1: Canonical JSON schema and semantics
    print("\n[1/4] Testing canonical contract mutations...")
    failures = test_canonical_contract_mutations()
    if failures:
        print(f"  FAIL: {len(failures)} mutations were accepted")
        all_failures.extend(failures)
    else:
        print(f"  PASS: {len(contract_mutation_cases())} mutations rejected")

    # Test 2: Known-bad commands
    print("\n[2/4] Testing known-bad-commands.txt...")
    failures = test_known_bad_commands()
    if failures:
        print(f"  FAIL: {len(failures)} commands did not match")
        all_failures.extend(failures)
    else:
        entries = load_test_file("known-bad-commands.txt")
        print(f"  PASS: {len(entries)} commands matched their categories")

    # Test 3: Known-bad prose
    print("\n[3/4] Testing known-bad-prose.txt...")
    failures = test_known_bad_prose()
    if failures:
        print(f"  FAIL: {len(failures)} prose lines did not match")
        all_failures.extend(failures)
    else:
        entries = load_test_file("known-bad-prose.txt")
        print(f"  PASS: {len(entries)} prose lines matched")

    # Test 4: Known-good commands (false positive check)
    print("\n[4/4] Testing known-good-commands.txt...")
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
