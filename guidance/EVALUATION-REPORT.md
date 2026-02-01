# Golden Agents Framework Evaluation Report

**Generated:** 2026-02-01  
**Repos Tested:** 16 of 20 in Personal workspace  
**Framework Version:** 3f41bb9 (with --compact mode)

---

## Executive Summary

The Golden Agents Framework was tested against 16 repositories in the Personal workspace. Key findings:

| Metric | Value |
|--------|-------|
| Compact mode output | **129 lines** (consistent) |
| Full mode output | **790-826 lines** (varies by language/type) |
| Compaction ratio | **~6.3:1** |
| Existing file variance | **124-1033 lines** (8.3x range) |
| Coverage improvement | **+40-60%** key topics in generated files |

---

## 1. Size Efficiency Analysis

### Context Budget Impact

Per [Anthropic's research](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents), context window management directly impacts agent performance. The arxiv study (2601.20404v1) found AGENTS.md files reduce runtime by **28.64%** and output tokens by **16.58%**.

| Mode | Lines | Est. Tokens | Context Budget (200K) |
|------|-------|-------------|----------------------|
| Compact | 129 | ~500 | **0.25%** |
| Full | 805 avg | ~3,200 | **1.6%** |
| Existing avg | 381 | ~1,500 | **0.75%** |

### Size Distribution

```
Existing files (14 repos):
  Smallest: 124 lines (genesis-tools/GameWiki)
  Largest:  1033 lines (bloginator)
  Average:  381 lines
  Std Dev:  ~260 lines (high variance)

Generated Compact (16 repos):
  All files: 129 lines (zero variance)

Generated Full (16 repos):
  Range: 790-826 lines
  Average: 805 lines
  Std Dev: ~15 lines (low variance)
```

---

## 2. Coverage Analysis

Coverage measures the presence of key topics essential for AI agent guidance.

### Topic Coverage Comparison

| Topic | Existing (avg) | Compact | Full | Gap Analysis |
|-------|---------------|---------|------|--------------|
| Superpowers bootstrap | 7/14 (50%) | ✓ | ✓ | 50% of repos missing |
| Banned phrases | 1/14 (7%) | ✓ | ✓ | **93% gap** - critical |
| Quality gates | 14/14 (100%) | ✓ | ✓ | All covered |
| Context management | 2/14 (14%) | ✓ | ✓ | **86% gap** - critical |
| Linting rules | 14/14 (100%) | ✓ | ✓ | All covered |
| Testing guidelines | 14/14 (100%) | ✓ | ✓ | All covered |
| Deployment | 8/14 (57%) | ✓ | ✓ | 43% gap |
| Security | 5/14 (36%) | ✓ | ✓ | 64% gap |

### Coverage Depth (Keyword Frequency)

```
Topic               | Existing Avg | Compact | Full
--------------------|--------------|---------|------
Superpowers         |     6.4      |    9    |  21
Testing             |    28.6      |    6    |  31
Linting             |    13.5      |    5    |  18
Deployment          |     7.0      |    1    |   6
Security            |     1.0      |    1    |   9
Context management  |     0.8      |    4    |  12
Banned phrases      |     0.3      |    1    |   4
```

---

## 3. Coherency Analysis

Coherency measures structural consistency across files.

### Section Order Consistency

**Generated files:** 100% consistent ordering:
1. Superpowers Bootstrap
2. Communication Standards
3. Quality Gates
4. Language-specific Rules
5. Project-type Rules
6. Context Management

**Existing files:** Highly variable ordering. Examples:
- RecipeArchive: Starts with "Git Workflow Policy"
- bloginator: Starts with "CRITICAL: YOU ARE THE LLM"
- codebase-reviewer: Starts with "SESSION RESUMPTION"

### Structural Issues in Existing Files

| Issue | Repos Affected | Impact |
|-------|---------------|--------|
| No consistent section order | 14/14 | Hard to navigate |
| Emoji overuse in headers | 4/14 | Noise in context |
| CAPS LOCK sections | 6/14 | Aggressive tone |
| Missing language rules | 3/14 | Incomplete guidance |

---

## 4. Efficiency Projections

Based on the arxiv study "On the Impact of AGENTS.md Files on the Efficiency of AI Coding Agents":

| Metric | Without Agents.md | With Agents.md | Improvement |
|--------|------------------|----------------|-------------|
| Runtime | baseline | -28.64% | ✓ |
| Output tokens | baseline | -16.58% | ✓ |
| Task completion | baseline | +improved | ✓ |

### Compact vs Full Trade-offs

| Scenario | Recommended Mode |
|----------|------------------|
| Long coding sessions | Compact (preserve context) |
| New project setup | Full (comprehensive reference) |
| Context window >75% used | Compact |
| Onboarding new AI tool | Full |
| Production debugging | Compact + targeted modules |

---

## 5. Recommendations

### Immediate Actions

1. **Adopt compact mode** for 14 repos with existing Agents.md
   - Average 66% size reduction (381 → 129 lines)
   - Consistent structure across all repos

2. **Add Agents.md** to 6 repos currently without:
   - Engineering_Culture
   - ai-fundamentals-private ✓ (tested)
   - ai-fundamentals-simple ✓ (tested)
   - blogs
   - bordenet
   - personal-lists

3. **Critical gaps to address:**
   - Banned phrases: Only 1/14 existing files include anti-slop rules
   - Context management: Only 2/14 address context window limits

### Migration Path

```bash
# Generate compact Agents.md (recommended for daily use)
./superpowers-plus/guidance/seed.sh --language=go --type=cli-tools --compact --path=./my-repo

# Generate full Agents.md (for reference/onboarding)
./superpowers-plus/guidance/seed.sh --language=go --type=cli-tools --path=./my-repo
```

---

## Appendix A: Raw Data

### Per-Repo Size Comparison

| Repository | Existing | Compact | Full | Language | Type |
|------------|----------|---------|------|----------|------|
| RecipeArchive | 584 | 129 | 826 | go | cli-tools |
| bloginator | 1033 | 129 | 813 | python | cli-tools |
| codebase-reviewer | 352 | 129 | 826 | go | cli-tools |
| genesis-tools/GameWiki | 124 | 129 | 790 | javascript | genesis-tools |
| genesis-tools/architecture-decision-record | 423 | 129 | 790 | javascript | genesis-tools |
| genesis-tools/genesis | 542 | 129 | 802 | shell | genesis-tools |
| genesis-tools/one-pager | 160 | 129 | 790 | javascript | genesis-tools |
| genesis-tools/power-statement-assistant | 234 | 129 | 790 | javascript | genesis-tools |
| genesis-tools/pr-faq-assistant | 482 | 129 | 790 | javascript | genesis-tools |
| genesis-tools/product-requirements-assistant | 250 | 129 | 790 | javascript | genesis-tools |
| genesis-tools/strategic-proposal | 195 | 129 | 790 | javascript | genesis-tools |
| pr-faq-validator | 204 | 129 | 826 | go | cli-tools |
| scripts | 498 | 129 | 822 | shell | cli-tools |
| superpowers-plus | 264 | 129 | 822 | shell | cli-tools |
| ai-fundamentals-private | 0 | 129 | 813 | python | web-apps |
| ai-fundamentals-simple | 0 | 129 | 813 | python | web-apps |

### Repos Not Tested (4)

| Repository | Reason |
|------------|--------|
| Engineering_Culture | No code - documentation only |
| blogs | No code - content only |
| bordenet | Personal config - no standard type |
| personal-lists | No code - data only |

---

## Appendix B: Methodology

### Metrics Definition

Based on [Anthropic's "Demystifying evals for AI agents"](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents):

1. **Coverage**: Presence of key topics (binary per topic, percentage across repos)
2. **Coverage Depth**: Keyword frequency (grep -ci) for topic saturation
3. **Coherency**: Structural consistency measured by section ordering
4. **Size Efficiency**: Lines of code and estimated token count
5. **Compaction Ratio**: Full lines ÷ Compact lines

### Grader Types (from Anthropic)

| Type | What We Measured | Method |
|------|------------------|--------|
| Code-based | Line counts, keyword frequency | `wc -l`, `grep -c` |
| Model-based | Not applicable (static analysis only) | - |
| Human | Section ordering review | Manual inspection |

### References

1. arxiv 2601.20404v1: "On the Impact of AGENTS.md Files on the Efficiency of AI Coding Agents"
2. Anthropic: "Demystifying evals for AI agents" (2026-01-09)
3. Anthropic: "Building effective agents" context engineering docs

---

*Report generated by Golden Agents Framework v3f41bb9*

