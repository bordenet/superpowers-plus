# Fraud Detection Module

> **Load when:** Direct-apply candidates (Paylocity applications)
> **Skip when:** Recruiter-sourced candidates

## ⚠️ BE PARANOID — Verification Mandate

**Resume fraud is rampant. Assume nothing. Verify everything.**

Before ANY assessment:
1. **Verify LinkedIn exists** — Search `"[Candidate Name]" site:linkedin.com`
2. **Cross-check current employer** — LinkedIn MUST match resume
3. **Validate company exists** — Web search the company
4. **Check Wayback Machine** — For small companies, verify team page history
5. **Validate Big Tech titles** — Amazon/Google/Meta/Microsoft have specific title structures
6. **Search for fraud patterns** — Check if other candidates claimed same employer

**DEFAULT STANCE: Skeptical until verified.**

| If You Find... | Action |
|----------------|--------|
| LinkedIn shows different employer | 🚨 NO HIRE — fabrication |
| Company cannot be verified | 🚨 NO HIRE — fake employer |
| Candidate never on Wayback snapshots | 🚨 NO HIRE — fabricated tenure |
| Big Tech title doesn't exist | 🚨 NO HIRE — resume fraud |
| Multiple candidates with identical employer | 🚨 FLAG — possible fraud ring |

---

## Pre-Screening Checks

### Check 0: Candidate Tracker *(ALWAYS FIRST)*
```
Read: $RECRUITING_DIR/candidate-tracker.csv
Search for: email, phone, name (fuzzy), LinkedIn URL
```
| Match Type | Action |
|------------|--------|
| Exact email/phone | 🚨 STOP — "Already screened on [date]" |
| `fraud_flag` set | 🚨 STOP — "KNOWN FRAUDSTER" |
| Name match, diff email | ⚠️ FLAG — "Possible duplicate" |
| Same employer as flagged fraud | ⚠️ FLAG — "Employer matches fraudster" |

### Check 1: Existing Records
```
Search: $RECRUITING_DIR/Phone Screens/, Screenings/, Interview Prep/, Debriefs/
# Also check legacy: Phone Screen Notes/, DONE/
```
If found → STOP, report to user.

### Check 2: Employer Pattern Matching
Search for other candidates claiming same employer(s). Multiple with identical history = flag.

### Check 3: Big Tech Title Validation

| Company | Invalid Titles | Valid Levels |
|---------|----------------|--------------|
| Amazon | Staff Engineer, Principal Engineer | SDE I-III (L4-L6), Principal SDE (L7) |
| Google | SDE, SDE II | L3-L8, SWE/Senior/Staff/Principal |
| Meta | Staff, Principal (standalone) | E3-E8 |
| Microsoft | L-levels (L6, L7) | SDE, SDE II, Senior SDE, Principal |

### Check 4: LinkedIn/Resume Discrepancy
Search `"[Candidate Name]" site:linkedin.com`. Compare current employer. Mismatch = flag.

### Check 5: Screening Answer Cross-Reference
Every claim in screening answers must map to resume bullet. No evidence = flag.

### Check 6: Title Progression Validation

| Pattern | Signal | Action |
|---------|--------|--------|
| Most recent "Senior" or above | ✅ On track | Proceed |
| Most recent mid-level (SDE II) | ⚠️ Yellow flag | May be stepping up |
| Title regression (Senior → SDE II) | 🚨 Red flag | Performance concern |

### Check 7: Fabricated Employer Detection
Verify current employer exists and matches LinkedIn:
- Different employer on LinkedIn vs resume = 🚨 STOP
- Company not found via web search = 🚨 STOP
- Company exists but different industry = 🚨 STOP

**Common Fraud Pattern:**
1. Real history at known companies
2. Fabricated **current** employer to hide gap
3. All LLM/AI skills claimed at fake employer

### Check 8: Wayback Machine Verification (Small Companies)
For companies <100 employees with team pages:
1. Fetch current team page
2. Check Wayback archives for claimed period
3. If candidate NEVER appears = 🚨 Employment fabricated

### Check 9: Stolen Identity Detection
```
web-search: "[Candidate Name]" stolen identity
web-search: "[Candidate Name]" FBI fraud
```
Name in FBI/DOJ alerts = 🚨 STOP

### Check 10: Identity Cross-Verification
Compare across sources:
| Field | Resume | LinkedIn | Screening Form | Match? |
|-------|--------|----------|----------------|--------|
| Full Name | | | | |
| Location | | | | |
| Education | | | | |
| Current Employer | | | | |

Any mismatch → verification required.

### Check 11: DPRK/China IT Worker Fraud

| Signal | Pattern |
|--------|---------|
| AI-generated resume | 200+ skills dump |
| Selective audio problems | "Connection issues" on hard questions |
| Eyes on second monitor | Reading script |
| Reconnaissance behavior | Architecture questions before rapport |
| Vague Big Tech answers | Claims L6 at Google, no specifics |

**Pivot Question Test:** Ask unexpected question requiring lived experience:
- "Tell me about a time you told a senior engineer they were wrong."
- "What's the worst production incident you caused?"

If audio fakes or incoherent answer → likely fraudulent.
