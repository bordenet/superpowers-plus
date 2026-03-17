#!/usr/bin/env bash
# test-content-coherence.sh — Validate wiki-content-coherence skill algorithm
# Implements Check 1 (TF-IDF duplication) and Check 3 (structural integrity)
# against inline test cases.
#
# Usage: ./tools/test-content-coherence.sh

set -euo pipefail

PASS=0
FAIL=0
TOTAL=0

assert() {
    local desc="$1" expected="$2" actual="$3"
    TOTAL=$((TOTAL + 1))
    if [[ "$expected" == "$actual" ]]; then
        echo "  ✅ PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ FAIL: $desc (expected=$expected, actual=$actual)"
        FAIL=$((FAIL + 1))
    fi
}

# --- Stop words list (from skill.md) ---
STOP_WORDS="the a an is are was were be been being have has had do does did will would shall should may might can could of in to for with on at by from as into through during before after above below between and but or nor not so yet both either neither each every all any few more most other some such no only own same than too very just because about it its this that these those which who whom what when where how if then also up out their there they them we our us he she him her my your i you me"

tokenize_and_fingerprint() {
    local text="$1"
    # Lowercase, split on non-alpha, remove stop words, filter <4 chars, top 8 by freq
    echo "$text" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alpha:]' '\n' | \
        grep -vxF "" | \
        awk -v stops="$STOP_WORDS" '
        BEGIN { split(stops, sa, " "); for (i in sa) sw[sa[i]]=1 }
        length >= 4 && !sw[$0] { freq[$0]++ }
        END { for (w in freq) print freq[w], w }
        ' | sort -rn | head -8 | awk '{print $2}' | sort
}

jaccard() {
    local fp1="$1" fp2="$2"
    local intersection union
    intersection=$(comm -12 <(echo "$fp1") <(echo "$fp2") | wc -l | tr -d ' ')
    union=$(sort -u <(echo "$fp1") <(echo "$fp2") | wc -l | tr -d ' ')
    if [[ "$union" -eq 0 ]]; then
        echo "0"
    else
        awk "BEGIN { printf \"%.2f\", $intersection / $union }"
    fi
}

# =========================================================================
echo ""
echo "=== Test Case 1: Page with duplicate sections ==="
echo ""

SEC1_HEADING="Setup"
SEC1_BODY="Install the service by running the setup script. Configure the environment variables for the database connection. Set the port and hostname in the configuration file. Run the installation wizard to complete the initial setup process."
SEC2_HEADING="Getting Started"
SEC2_BODY="To get started, install the service using the setup installer. Configure environment variables for database connectivity. Set your hostname and port settings in the config file. Complete the setup by running the initial configuration wizard."
SEC3_HEADING="API Reference"
SEC3_BODY="The endpoint accepts POST requests with JSON payloads. Authentication uses Bearer tokens in the Authorization header. Rate limiting applies at 100 requests per minute per client. Response codes follow standard HTTP semantics with detailed error messages."

FP1=$(tokenize_and_fingerprint "$SEC1_BODY")
FP2=$(tokenize_and_fingerprint "$SEC2_BODY")
FP3=$(tokenize_and_fingerprint "$SEC3_BODY")

J12=$(jaccard "$FP1" "$FP2")
J13=$(jaccard "$FP1" "$FP3")
J23=$(jaccard "$FP2" "$FP3")

echo "  Fingerprints:"
echo "    §1 '$SEC1_HEADING': $(echo "$FP1" | tr '\n' ', ')"
echo "    §2 '$SEC2_HEADING': $(echo "$FP2" | tr '\n' ', ')"
echo "    §3 '$SEC3_HEADING': $(echo "$FP3" | tr '\n' ', ')"
echo "  Jaccard scores: §1↔§2=$J12  §1↔§3=$J13  §2↔§3=$J23"

# §1 and §2 should be flagged as duplicates (>=0.40)
dup_detected="false"
if awk "BEGIN { exit ($J12 >= 0.40) ? 0 : 1 }"; then dup_detected="true"; fi
assert "Detects duplication between Setup and Getting Started" "true" "$dup_detected"

# §1 and §3 should NOT be flagged (different topics)
no_false_pos="true"
if awk "BEGIN { exit ($J13 >= 0.40) ? 0 : 1 }"; then no_false_pos="false"; fi
assert "No false positive between Setup and API Reference" "true" "$no_false_pos"

# =========================================================================
echo ""
echo "=== Test Case 2: Clean page (no issues expected) ==="
echo ""

CLEAN1="Overview of the payment processing service including architecture decisions and system boundaries for the platform."
CLEAN2="Database schema design with entity relationship diagrams showing the normalized tables for transaction records and audit logs."
CLEAN3="Deployment procedures including Docker container configuration with health checks, rolling updates, and rollback strategies."

CFP1=$(tokenize_and_fingerprint "$CLEAN1")
CFP2=$(tokenize_and_fingerprint "$CLEAN2")
CFP3=$(tokenize_and_fingerprint "$CLEAN3")

CJ12=$(jaccard "$CFP1" "$CFP2")
CJ13=$(jaccard "$CFP1" "$CFP3")
CJ23=$(jaccard "$CFP2" "$CFP3")

echo "  Jaccard scores: §1↔§2=$CJ12  §1↔§3=$CJ13  §2↔§3=$CJ23"

false_pos_count=0
if awk "BEGIN { exit ($CJ12 >= 0.40) ? 0 : 1 }"; then false_pos_count=$((false_pos_count + 1)); fi
if awk "BEGIN { exit ($CJ13 >= 0.40) ? 0 : 1 }"; then false_pos_count=$((false_pos_count + 1)); fi
if awk "BEGIN { exit ($CJ23 >= 0.40) ? 0 : 1 }"; then false_pos_count=$((false_pos_count + 1)); fi
assert "Zero false positives on clean page" "0" "$false_pos_count"

# =========================================================================
echo ""
echo "=== Test Case 3: H2 → H4 heading jump ==="
echo ""

HEADINGS="## Overview
Some content here about the overview section.
## Configuration
Details about configuration options.
#### Advanced Settings
This section has an H4 without a preceding H3."

nesting_violation="false"
prev_level=0
while IFS= read -r line; do
    case "$line" in
        '#####'*) level=5 ;;
        '####'*) level=4 ;;
        '###'*) level=3 ;;
        '##'*) level=2 ;;
        *) continue ;;
    esac
    if [[ $prev_level -gt 0 ]] && [[ $((level - prev_level)) -gt 1 ]]; then
        nesting_violation="true"
    fi
    prev_level=$level
done <<< "$HEADINGS"
assert "Detects H2→H4 heading nesting violation" "true" "$nesting_violation"

# =========================================================================
echo ""
echo "=== Test Case 4: Section length anomaly ==="
echo ""
# Section word counts: 15, 120, 130, 125, 800
# Median of sorted [15, 120, 125, 130, 800] = 125
# 800 > 5 * 125 = 625 → flagged
# 15 < 20 → flagged

WORD_COUNTS=(15 120 130 125 800)
sorted=($(printf '%s\n' "${WORD_COUNTS[@]}" | sort -n))
mid=$(( ${#sorted[@]} / 2 ))
median=${sorted[$mid]}

anomaly_found="false"
short_found="false"
for wc in "${WORD_COUNTS[@]}"; do
    if [[ $wc -gt $((median * 5)) ]]; then anomaly_found="true"; fi
    if [[ $wc -lt 20 ]] && [[ $wc -gt 0 ]]; then short_found="true"; fi
done

assert "Detects section length anomaly (800 > 5×$median)" "true" "$anomaly_found"
assert "Detects short section (15 < 20 words)" "true" "$short_found"

# =========================================================================
echo ""
echo "=== Test Case 5: Orphaned H3 (no preceding H2) ==="
echo ""

ORPHAN_HEADINGS="### Subsection Without Parent
Some orphaned content here.
## Actual Section
More content here."

orphan_found="false"
seen_h2="false"
while IFS= read -r line; do
    case "$line" in
        '## '*) seen_h2="true" ;;
        '### '*)
            if [[ "$seen_h2" == "false" ]]; then orphan_found="true"; fi
            ;;
    esac
done <<< "$ORPHAN_HEADINGS"
assert "Detects orphaned H3 before any H2" "true" "$orphan_found"

# =========================================================================
echo ""
echo "========================================"
echo "  Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"
echo ""

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
