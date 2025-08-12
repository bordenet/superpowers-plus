# Cost-Conscious Search Policy

<EXTREMELY_IMPORTANT>
## Perplexity API Costs Real Money

Perplexity API calls are paid from your personal funds. **Always use free tools first.**

### Step 1: FREE — Always Use `web-search` First

```
web-search: "[query]"
```

Also use `web-fetch` to check URLs directly — it's free.

### Step 2: Evaluate Results

After `web-search`, ask yourself:
- Did I find what I was looking for?
- Can I answer the user's question with these results?
- Do I have enough context to proceed?

**If YES to any → STOP. Do not call Perplexity.**

### Step 3: PAID — Perplexity Only If Results Are ≥50% Worse Than Expected

Only escalate to Perplexity if:
- `web-search` returned no relevant results
- Results are ambiguous or contradictory
- You need synthesis/reasoning across multiple sources

**Before calling Perplexity, you MUST state explicitly:**
> "web-search returned [X]. This is insufficient because [reason]. Escalating to Perplexity."

### Cost Reference

| Tool | Cost | Use When |
|------|------|----------|
| `web-search` | FREE | Always first |
| `web-fetch` | FREE | Checking URLs, reading pages |
| `perplexity_ask_perplexity` | ~$0.001/query | Simple questions after web-search fails |
| `perplexity_search_perplexity` | ~$0.005/query | Search after web-search fails |
| `perplexity_reason_perplexity` | ~$0.01/query | Complex reasoning (rare) |
| `perplexity_research_perplexity` | ~$0.05/query | Deep research (very rare, ask first) |

### Never Call Perplexity For:

- ❌ Simple company lookups (use web-search)
- ❌ Checking if a URL is live (use web-fetch)
- ❌ Finding a company's website (use web-search)
- ❌ Basic fact-checking (use web-search)
- ❌ Reading documentation pages (use web-fetch)

### Acceptable Perplexity Use Cases:

- ✅ Complex multi-source synthesis after web-search fails
- ✅ Current events/news that web-search can't find
- ✅ Technical questions requiring reasoning
- ✅ When user explicitly requests Perplexity

**Violating this policy wastes your budget.**
</EXTREMELY_IMPORTANT>
