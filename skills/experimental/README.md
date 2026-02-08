# ⚠️ EXPERIMENTAL SKILLS - USE WITH CAUTION ⚠️

> **WARNING**: Skills in this directory are EXPERIMENTAL and NOT PRODUCTION-READY.
> They may produce incorrect results, hallucinate, or behave unexpectedly.
> Use at your own risk and ALWAYS verify outputs manually.

---

## What Makes a Skill "Experimental"?

A skill is placed in the experimental directory when:

1. **Limited validation** - Tested in controlled experiments but not battle-tested in production
2. **Known failure modes** - Has documented failure cases that haven't been fully addressed
3. **Methodology still evolving** - The approach may change significantly based on further testing
4. **Requires manual verification** - Outputs should NEVER be trusted without human review

---

## Experimental Skills

### experimental-self-prompting

**Status**: Validated in 20-round experiment, but methodology still evolving

**What it does**: Write comprehensive adversarial prompts before analyzing code to discover issues that direct analysis misses.

**Key findings from experiment**:
- Condition B (Reframe-Self) won: 21 VH, 1 HR (20% HR rate)
- DO NOT use with external models (100% hallucination rate)
- Expect ~20% false positive rate

**Why experimental**:
- Only tested on 5 genesis-tools projects
- May not generalize to other codebases
- Optimal prompt templates still being refined
- No automated verification pipeline yet

**Graduation criteria**:
- [ ] Tested on 10+ diverse codebases
- [ ] False positive rate consistently <15%
- [ ] Automated verification integrated
- [ ] User feedback loop established

---

## How to Use Experimental Skills

### Explicit Invocation Only

Experimental skills should NEVER be auto-invoked. Always use explicit invocation:

```
Use the experimental-self-prompting skill to analyze [system]
```

### Always Verify Outputs

Every finding from an experimental skill MUST be verified:

1. Run grep/view commands to confirm claims
2. Run tests to confirm behavior
3. Mark findings as VERIFIED or FALSE POSITIVE
4. Track your own VH/HR metrics

### Report Issues

If you encounter problems:

1. Document the failure mode
2. Add to the skill's "Known Issues" section
3. Consider whether the skill should be deprecated

---

## Promoting Skills to Production

A skill can be promoted from experimental to production when:

1. **Validation threshold met** - Tested on required number of diverse cases
2. **Metrics meet targets** - False positive rate, accuracy, etc.
3. **Failure modes addressed** - Known issues resolved or documented with workarounds
4. **User feedback positive** - Real-world usage confirms value

To promote a skill:

1. Move from `skills/experimental/` to `skills/`
2. Remove "experimental-" prefix from name
3. Update SKILLS.md with production entry
4. Remove experimental warnings from SKILL.md

---

## ⚠️ FINAL WARNING ⚠️

**DO NOT rely on experimental skills for critical decisions.**

These skills are research tools, not production systems. They exist to:
- Test new methodologies
- Gather data on effectiveness
- Iterate toward production-ready solutions

If you need reliable results, use production skills or manual analysis.

