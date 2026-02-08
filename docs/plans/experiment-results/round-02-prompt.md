# ADVERSARIAL ALIGNMENT REVIEW PROMPT

## CONTEXT

You are reviewing the **pr-faq-assistant** tool, a genesis-based document assistant that helps users write Amazon-style PR/FAQ documents. The tool has a 5-component alignment chain:

1. **phase1.md** - User-facing generation prompt
2. **phase2.md** - Review prompt  
3. **phase3.md** - Synthesis prompt
4. **prompts.js** - LLM scoring rubric (347 lines)
5. **validator.js** - JavaScript pattern-matching scorer (1427 lines)

## THE PROBLEM

If phase1.md tells users to generate Format X, but validator.js rewards Format Y, users get **silently penalized** for following instructions correctly.

## YOUR MISSION

Find MISALIGNMENTS where a user following phase1.md exactly would lose points in validator.js.

## SPECIFIC AREAS TO INVESTIGATE

### 1. Quote Requirements
- phase1.md specifies "exactly 2 quotes"
- How does validator.js score 1, 2, 3+ quotes?
- Is there asymmetric penalty/bonus?

### 2. Headline Scoring (8 pts total)
- Action verb requirement
- Length constraints  
- Mechanism detection (how specific?)
- Metric inclusion

### 3. FAQ Sections
- External vs Internal FAQ detection
- Softball question detection patterns
- Hard question detection patterns
- Answer rigor validation

### 4. Dateline Format
- What format does phase1.md specify?
- What formats does validator.js accept?
- Is there format drift?

### 5. Gaming Vulnerabilities
- Can users stuff fake metrics?
- Can users write softball questions that bypass detection?
- Can users use vague mechanisms that still score points?

## VERIFICATION REQUIREMENTS

For EACH finding:
1. **State the claim clearly**
2. **Cite exact file and line number**
3. **Show the regex or code that proves it**
4. **Categorize**: TRUE POSITIVE / FALSE POSITIVE / NEEDS INVESTIGATION

## FILES TO EXAMINE

- `genesis-tools/pr-faq-assistant/validator/js/validator.js`
- `genesis-tools/pr-faq-assistant/validator/js/prompts.js`
- `genesis-tools/pr-faq-assistant/shared/prompts/phase1.md`

## OUTPUT FORMAT

Provide findings in this structure:

```markdown
### Finding N: [Title]

**Claim:** [What you believe is misaligned]

**Evidence:**
- File: [path]
- Lines: [N-M]
- Code: [relevant snippet]

**Verification:** TRUE POSITIVE / FALSE POSITIVE / NEEDS INVESTIGATION

**Impact:** [How many points affected]
```

Focus on ACTIONABLE findings with CODE EVIDENCE. No speculation.

