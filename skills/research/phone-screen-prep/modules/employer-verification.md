# Employer & Project Verification (DIRECT-APPLY Only)

> **Skip for:** Recruiter-sourced candidates (recruiter has vetted background)
> **Required for:** All direct-apply (Paylocity) candidates

## What to Search

| Item | Search Query | What You're Looking For |
|------|--------------|------------------------|
| **Each employer** | `"[Company Name]" software company` | Is it real? Product company or consultancy? Size? |
| **Consultancies** | `"[Company Name]" IT consulting staffing` | Body shop? Offshore? Client placement? |
| **Projects with URLs** | Visit the URL directly | Is it live? Does it match their claims? |
| **Projects without URLs** | `"[Project Name]" [technology mentioned]` | Can you find evidence it exists? |
| **GitHub URL** | Visit directly | Does it resolve? Repos match resume claims? |

---

## Red Flags to Note

| Pattern | Concern | Question to Add |
|---------|---------|-----------------|
| Company has no web presence | May not exist or be a shell | "Walk me through [Company] — how many people, who were the customers?" |
| Company is clearly a consultancy | Experience may be shallow client rotations | "Were you staffed on client projects or building internal products?" |
| Project URL doesn't resolve | May be fabricated | "Is [Project] still live? What happened to it?" |
| Project listed separately from employment | Unclear relationship | "Was [Project] through [Employer], a side project, or freelance?" |
| GitHub URL 404s | Deleted or fake | "Your GitHub link doesn't resolve — can you explain?" |
| Only appears on job boards (Himalayas, etc.) | Possible resume-padding shell company | "How did you find [Company]? What was the interview process?" |

---

## Cost-Conscious Search Strategy

**⚠️ Perplexity API calls cost real money. Follow this escalation path:**

### Step 1: FREE — Use `web-search` First (ALWAYS)

```
web-search: "[Company Name]" software company
web-search: "[Company Name]" IT consulting
web-search: "[Project Name]" [key technology from resume]
```

For project URLs, use `web-fetch` to check if they're live.

### Step 2: Evaluate Results

After `web-search`, ask yourself:
- Did I find the company website or LinkedIn page?
- Can I determine if it's a product company vs. consultancy?
- Do I have enough to form verification questions?

**If YES to any of these → STOP. Do not call Perplexity.**

### Step 3: PAID — Perplexity Only If Results Are ≥50% Worse Than Expected

Only escalate to `perplexity_search_perplexity` if:
- `web-search` returned no relevant results
- Results are ambiguous and you can't determine company type
- You need synthesis across multiple sources

**Before calling Perplexity, state explicitly:**
> "web-search returned [X]. This is insufficient because [reason]. Escalating to Perplexity."

### Cost Reference

| Tool | Cost | Use When |
|------|------|----------|
| `web-search` | FREE | Always first |
| `web-fetch` | FREE | Checking if URLs are live |
| `perplexity_search_perplexity` | ~$0.005/query | Only after web-search fails |
| `perplexity_research_perplexity` | ~$0.05/query | Never for verification (overkill) |

---

## Output Format

Add a **Verification Summary** section to the phone screen file:

```markdown
## 🔍 Employer/Project Verification

| Item | Type | Finding | Question Added? |
|------|------|---------|-----------------|
| CodingQNA | Employer | ⚠️ No website, only Himalayas.app profiles | Yes — Q1 |
| Thebitsoft | Employer | ✅ Confirmed IT consultancy (thebitsoft.com) | Yes — Q2 |
| HaulHub | Project | ✅ Real company (haulhub.com), but relationship unclear | Yes — Q3 |
| GitHub | Link | ❌ 404 — does not resolve | Yes — header |
```

---

## When to Escalate

If verification reveals:
- **Multiple unverifiable employers** → Add to WATCH FOR, prioritize verification questions
- **Consultancy-only background** → Probe for depth, ownership, engagement length
- **Fabricated claims** → Consider NO-HIRE before phone screen (discuss with hiring manager)
