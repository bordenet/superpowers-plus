# Perplexity Research — Cost Reference

> Reference material for the `perplexity-research` skill.
> See `skill.md` for core agent guidance.

## Cost Efficiency (CRITICAL)

> ⚠️ **Perplexity API calls are NOT free.** Use efficiently but DO use when confident it will help.

### High-Value Use Cases (DO use Perplexity)

| Use Case | Why It's Worth It |
|----------|-------------------|
| **Deep research before major feature work** | Prevents costly rework |
| **PRD/design review and refinement** | High-value feedback on architecture |
| **State-of-the-art research in specialized domains** | Training data may be outdated |
| **Validating architectural decisions** | Industry standards evolve |
| **Complex debugging after 2+ failures** | Time saved > API cost |

### Low-Value Use Cases (Use alternatives instead)

| Use Case | Better Alternative |
|----------|-------------------|
| Simple factual lookups | `web-search` tool |
| Code examples | `codebase-retrieval` or documentation |
| General knowledge questions | Rely on training data |
| Iterative refinement | Batch questions into single call |

### Efficiency Tactics

1. **Batch related questions** - Combine multiple questions into one call
2. **Use `strip_thinking: true`** - Reduces token usage for research/reason tools
3. **Choose the right tool**:
   - `perplexity_search_perplexity` - Quick facts (cheapest)
   - `perplexity_ask_perplexity` - How-to questions (moderate)
   - `perplexity_research_perplexity` - Deep dives (expensive)
   - `perplexity_reason_perplexity` - Complex reasoning (most expensive)
4. **Fallback to web-search** - When Perplexity is unavailable or for simple lookups

### Decision Framework (Cost-Conscious)

```
Step 1: Try web-search first (FREE)
├── Found what I need? → STOP (no Perplexity)
└── Insufficient? → Continue

Step 2: Try web-fetch on promising URLs (FREE)
├── Found what I need? → STOP (no Perplexity)
└── Still insufficient? → Continue

Step 3: Evaluate - Is this a high-value use case?
├── NO → Use alternative (codebase-retrieval, training data)
└── YES → State: "web-search returned [X]. Insufficient because [Y]. Escalating."
          └── Use appropriate Perplexity tool
```

### API Unavailability

If Perplexity returns 401/403/5xx errors:
1. **Limit retries to 1** - Preserve time for alternative approaches
2. **Fallback to `web-search`** - Often sufficient for targeted queries
3. **Use `web-fetch`** - To get full content from authoritative sources
4. **Inform user** - "Perplexity unavailable, using web search fallback"

