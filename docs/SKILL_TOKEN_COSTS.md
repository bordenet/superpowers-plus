# Skill Token Costs

> **Note:** Costs below are estimated from **raw, uncompressed** file sizes (`fileSize / 4`). Actual injection cost is lower — `lib/compress.js` strips boilerplate sections (20–40% reduction). Operative content (`<EXTREMELY_IMPORTANT>` blocks, `Failure Modes`, `Incident Log`, `References`, `Hallucination Prevention`) is preserved. See `docs/ARCHITECTURE.md § Skill Content Compression`.
>
> **Generated:** 2026-04-15 · **Skills analyzed:** 88
> **Regenerate:** `bash tools/skill-cost-analyzer.sh`

## Column Key

| Column | Description |
|--------|-------------|
| **Size** | Raw skill.md lines |
| **Aux** | Auxiliary/reference file lines loaded at runtime |
| **Refs** | Reference files count / total lines |
| **Chains** | Number of outbound skill chains declared |
| **Verify** | Verification sub-calls count |
| **Sub-Agents** | Parallel sub-agent dispatches |
| **Est. Cost** | Composite cost score (higher = more tokens/complexity) |

## Skills by Cost

| Domain | Skill | Size | Aux | Refs | Chains | Verify | Sub-Agents | Est. Cost |
|--------|-------|-----:|----:|-----:|-------:|-------:|-----------:|-----------|
| engineering | code-review-battery | 248 | 0 | 0/0 | 9 | 1 | 20 | 83.9 🔴 |
| engineering | subagent-driven-development | 116 | 0 | 3/513 | 4 | 0 | 19 | 77.5 🔴 |
| engineering | progressive-code-review-gate | 194 | 0 | 0/0 | 11 | 0 | 12 | 61.8 🔴 |
| productivity | think-twice | 120 | 0 | 2/120 | 11 | 1 | 9 | 56.2 🔴 |
| engineering | verification-before-completion | 244 | 0 | 0/0 | 5 | 2 | 13 | 55.8 🔴 |
| engineering | feature-development | 181 | 0 | 0/0 | 18 | 0 | 5 | 54.6 🔴 |
| productivity | thinking-orchestrator | 152 | 0 | 0/0 | 18 | 0 | 5 | 54.0 🔴 |
| engineering | requesting-code-review | 178 | 0 | 0/0 | 6 | 0 | 11 | 48.5 🔴 |
| productivity | plan-and-execute | 249 | 0 | 6/628 | 11 | 1 | 2 | 46.5 🔴 |
| engineering | debate | 196 | 0 | 0/0 | 11 | 1 | 3 | 35.9 🔴 |
| productivity | autonomous-chain-controller | 128 | 0 | 0/0 | 16 | 0 | 0 | 34.5 🔴 |
| engineering | progressive-harsh-review | 199 | 0 | 0/0 | 10 | 1 | 3 | 33.9 🔴 |
| engineering | sp-bughunt | 142 | 0 | 0/0 | 0 | 1 | 10 | 33.8 🔴 |
| engineering | brainstorming | 119 | 0 | 3/498 | 5 | 0 | 3 | 31.3 🔴 |
| wiki | wiki-refactor | 158 | 0 | 7/757 | 6 | 0 | 0 | 30.3 🔴 |
| engineering | debug-conductor | 178 | 0 | 1/41 | 7 | 0 | 4 | 30.3 🔴 |
| engineering | finishing-a-development-branch | 148 | 0 | 0/0 | 6 | 2 | 4 | 28.9 🔴 |
| wiki | wiki-orchestrator | 200 | 0 | 2/136 | 9 | 3 | 0 | 27.7 🔴 |
| engineering | investigation-state | 164 | 0 | 4/564 | 6 | 0 | 0 | 26.5 🔴 |
| engineering | systematic-debugging | 116 | 0 | 0/0 | 10 | 0 | 1 | 25.3 🔴 |
| writing | readme-authoring | 166 | 0 | 3/147 | 9 | 0 | 0 | 24.2 🔴 |
| engineering | test-driven-development | 125 | 0 | 0/0 | 9 | 0 | 1 | 23.5 🔴 |
| writing | detecting-ai-slop | 186 | 575 | 0/0 | 4 | 0 | 0 | 23.2 🔴 |
| engineering | pre-commit-gate | 154 | 0 | 0/0 | 10 | 0 | 0 | 23.0 🔴 |
| writing | professional-language-audit | 176 | 0 | 0/0 | 9 | 0 | 0 | 21.5 🔴 |
| writing | eliminating-ai-slop | 105 | 371 | 0/0 | 6 | 0 | 0 | 21.5 🔴 |
| security | public-repo-ip-audit | 120 | 0 | 0/0 | 9 | 0 | 0 | 20.4 🔴 |
| productivity | skill-authoring | 184 | 0 | 1/21 | 8 | 0 | 0 | 20.1 🔴 |
| observability | exhaustive-audit-validation | 190 | 0 | 0/0 | 8 | 0 | 0 | 19.8 🔴 |
| productivity | adversarial-search | 108 | 0 | 0/0 | 7 | 3 | 0 | 19.1 🔴 |
| issue-tracking | issue-comment-debunker | 206 | 0 | 0/0 | 7 | 1 | 0 | 19.1 🔴 |
| engineering | unified-commit-gate | 160 | 0 | 0/0 | 6 | 0 | 1 | 18.2 🔴 |
| engineering | providing-code-review | 209 | 0 | 0/0 | 7 | 0 | 0 | 18.1 🔴 |
| engineering | output-verification | 148 | 0 | 0/0 | 5 | 5 | 0 | 17.9 🔴 |
| wiki | link-verification | 175 | 0 | 1/18 | 7 | 0 | 0 | 17.8 🔴 |
| productivity | innovation | 136 | 106 | 1/51 | 6 | 0 | 0 | 17.8 🔴 |
| wiki | wiki-debunker | 95 | 0 | 2/175 | 6 | 0 | 0 | 17.4 🔴 |
| productivity | golden-agents | 184 | 0 | 1/182 | 5 | 0 | 0 | 17.3 🔴 |
| observability | completeness-check | 166 | 0 | 0/0 | 7 | 0 | 0 | 17.3 🔴 |
| productivity | enforce-style-guide | 157 | 0 | 0/0 | 7 | 0 | 0 | 17.1 🔴 |
| engineering | blast-radius-check | 154 | 0 | 0/0 | 7 | 0 | 0 | 17.0 🔴 |
| productivity | todo-management | 245 | 0 | 3/197 | 4 | 0 | 0 | 16.8 🔴 |
| research | perplexity-research | 145 | 0 | 2/94 | 3 | 0 | 2 | 16.7 🔴 |
| observability | failure-autopsy | 117 | 0 | 0/0 | 7 | 0 | 0 | 16.3 🔴 |
| engineering | micro-harsh-review | 117 | 0 | 0/0 | 7 | 0 | 0 | 16.3 🔴 |
| engineering | evidence-adjudicator | 165 | 0 | 0/0 | 2 | 0 | 3 | 16.3 🔴 |
| writing | writing-skills | 108 | 0 | 0/0 | 7 | 0 | 0 | 16.1 🔴 |
| productivity | code-review-respond | 152 | 0 | 0/0 | 5 | 3 | 0 | 16.0 🔴 |
| observability | holistic-repo-verification | 150 | 0 | 0/0 | 6 | 1 | 0 | 16.0 🔴 |
| observability | superpowers-doctor | 100 | 0 | 1/84 | 3 | 0 | 2 | 15.6 🔴 |
| engineering | receiving-code-review | 177 | 0 | 0/0 | 6 | 0 | 0 | 15.5 🔴 |
| engineering | field-rename-verification | 173 | 0 | 0/0 | 6 | 0 | 0 | 15.4 🔴 |
| engineering | reproduction-experiment-investigator | 135 | 0 | 0/0 | 1 | 1 | 3 | 14.7 🟡 |
| issue-tracking | issue-verify | 166 | 0 | 0/0 | 4 | 3 | 0 | 14.3 🟡 |
| productivity | domain-design | 98 | 0 | 0/0 | 6 | 0 | 0 | 13.9 🟡 |
| engineering | llm-behavior-investigator | 147 | 0 | 0/0 | 1 | 0 | 3 | 13.9 🟡 |
| writing | plan-quality-gates | 193 | 0 | 0/0 | 5 | 0 | 0 | 13.8 🟡 |
| issue-tracking | issue-authoring | 191 | 0 | 0/0 | 5 | 0 | 0 | 13.8 🟡 |
| experimental | experimental-self-prompting | 186 | 0 | 0/0 | 3 | 4 | 0 | 13.7 🟡 |
| engineering | timeline-trace-investigator | 138 | 0 | 0/0 | 1 | 0 | 3 | 13.7 🟡 |
| engineering | state-consistency-investigator | 137 | 0 | 0/0 | 1 | 0 | 3 | 13.7 🟡 |
| engineering | infra-config-investigator | 131 | 0 | 0/0 | 1 | 0 | 3 | 13.6 🟡 |
| issue-tracking | issue-editing | 177 | 0 | 0/0 | 5 | 0 | 0 | 13.5 🟡 |
| wiki | wiki-verify | 173 | 0 | 0/0 | 5 | 0 | 0 | 13.4 🟡 |
| productivity | superpowers-help | 155 | 0 | 0/0 | 5 | 0 | 0 | 13.1 🟡 |
| engineering | requirements-validation | 150 | 0 | 0/0 | 5 | 0 | 0 | 13.0 🟡 |
| security | wiki-instruction-guard | 153 | 0 | 1/141 | 3 | 1 | 0 | 12.8 🟡 |
| productivity | inter-agent-review-protocol | 141 | 0 | 0/0 | 5 | 0 | 0 | 12.8 🟡 |
| writing | markdown-table-discipline | 184 | 0 | 1/42 | 4 | 0 | 0 | 12.5 🟡 |
| issue-tracking | issue-link-verification | 117 | 0 | 0/0 | 5 | 0 | 0 | 12.3 🟡 |
| productivity | quantitative-decision-gate | 113 | 0 | 0/0 | 5 | 0 | 0 | 12.2 🟡 |
| observability | evolution-loop | 105 | 0 | 0/0 | 5 | 0 | 0 | 12.1 🟡 |
| security | repo-security-scan | 196 | 0 | 0/0 | 4 | 0 | 0 | 11.9 🟡 |
| observability | skill-health-check | 99 | 0 | 0/0 | 5 | 0 | 0 | 11.9 🟡 |
| wiki | wiki-secret-audit | 188 | 0 | 0/0 | 4 | 0 | 0 | 11.7 🟡 |
| security | security-upgrade | 189 | 0 | 0/0 | 4 | 0 | 0 | 11.7 🟡 |
| research | incorporating-research | 182 | 0 | 0/0 | 4 | 0 | 0 | 11.6 🟡 |
| productivity | todo-guardian | 133 | 0 | 0/0 | 4 | 0 | 0 | 10.6 🟡 |
| wiki | wiki-content-coherence | 119 | 0 | 0/0 | 4 | 0 | 0 | 10.3 🟡 |
| productivity | fallback-planning | 118 | 0 | 0/0 | 4 | 0 | 0 | 10.3 🟡 |
| observability | measurement-integrity | 103 | 0 | 0/0 | 4 | 0 | 0 | 10.0 🟡 |
| wiki | wiki-markdown-structure-gate | 101 | 0 | 0/0 | 3 | 0 | 0 | 8.0 🟡 |
| research | expert-interviewer | 147 | 0 | 0/0 | 1 | 0 | 1 | 7.9 🟢 |
| productivity | todo-archive | 196 | 0 | 0/0 | 1 | 0 | 0 | 5.9 🟢 |
| engineering | implementation-tracker | 112 | 0 | 0/0 | 1 | 0 | 0 | 4.2 🟢 |
| productivity | update-superpowers | 170 | 0 | 0/0 | 0 | 0 | 0 | 3.4 🟢 |
| engineering | cognitive-complexity-refactoring | 174 | 0 | 0/0 | 0 | 0 | 0 | 3.4 🟢 |
| engineering | git-branch-conventions | 123 | 0 | 0/0 | 0 | 0 | 0 | 2.4 🟢 |

## Cost Tiers

| Tier | Range | Indicator |
|------|-------|-----------|
| High | ≥ 15.0 | 🔴 |
| Medium | 7.5 – 14.9 | 🟡 |
| Low | < 7.5 | 🟢 |
