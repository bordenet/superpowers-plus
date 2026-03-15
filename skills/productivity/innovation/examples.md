# Innovation Skill — Examples

These examples demonstrate when the innovation skill should and should NOT fire.

---

## ✅ Example 1: LLM Agent Innovation

**User prompt:**
> "We have an LLM agent that books service appointments. Propose step-change improvements to conversion and dealer satisfaction."

**Why innovation fires:** User explicitly asks for "step-change improvements" — a transformation trigger.

**Expected output structure:**
```markdown
# Innovation Analysis: Appointment Booking Agent

**Input context:** LLM agent for service appointments; goals are conversion + dealer satisfaction

**Current state:** Agent handles booking flow, likely rule-based routing

---

## Idea 1: Predictive Service Bundling ⭐ Recommended — Score: 28/35

**What it is:** Agent proactively suggests service bundles based on vehicle history, 
seasonal patterns, and dealer inventory — converting single appointments to multi-service visits.

**Why it's transformative:** Increases revenue per visit 40-60% while reducing customer 
return trips. Dealers see higher ticket values; customers get convenience.

| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Impact | 5 | Direct revenue lift + satisfaction |
| Feasibility | 4 | Requires service history access |
| Alignment | 4 | Extends current booking flow |
| Uniqueness | 3 | Competitors could replicate |

**What it would require:**
- Vehicle service history API integration
- ML model for service correlation
- Estimated effort: 1 quarter

**Risks & Unknowns:**
- Service history data quality varies by dealer
- Over-suggestion could feel pushy

**🧪 Next-Week Prototype:**
Build a rules-based version for top 5 service pairs (oil change + tire rotation, etc.) 
and A/B test with 3 dealers.
```

---

## ✅ Example 2: Architecture Rethink

**User prompt:**
> "What if we started from scratch on the notification service?"

**Why innovation fires:** Explicit "from scratch" language signals paradigm shift thinking.

---

## ✅ Example 3: Business Model Exploration

**User prompt:**
> "What would a world-class team do with our internal developer tools?"

**Why innovation fires:** Benchmark language ("world-class") + scope expansion implied.

---

## ❌ Example 4: Bug Fix (Do NOT Fire)

**User prompt:**
> "Fix the race condition in the booking queue."

**Why innovation does NOT fire:** This is a bug fix. Use `systematic-debugging`.

---

## ❌ Example 5: Incremental Feature (Do NOT Fire)

**User prompt:**
> "Add email confirmation to the booking flow."

**Why innovation does NOT fire:** This is an incremental feature. Use `brainstorming` if design 
is needed, or implement directly.

---

## ❌ Example 6: Refactor (Do NOT Fire)

**User prompt:**
> "Clean up the service layer abstractions."

**Why innovation does NOT fire:** This is a refactor. Use `engineering-rigor`.

---

## 🤔 Example 7: Ambiguous — Propose, Don't Auto-Fire

**User prompt:**
> "What's next for this project?"

**Why propose:** Could be innovation (transformative direction) or roadmap planning 
(incremental). Ask:
```
Would you like me to:
(a) Run **Innovation** mode for transformative 10x ideas?
(b) Help with roadmap planning for incremental improvements?
```

---

## High-Signal Trigger Phrases

Phrases that should reliably cause innovation to fire:

1. "How could we 10x this?"
2. "What's the moonshot version?"
3. "Reimagine this from first principles"
4. "What would make this a platform?"
5. "New business model for this capability"
6. "Rethink the architecture entirely"
7. "Step-change improvement to [metric]"
8. "What if we started from scratch?"
9. "Paradigm shift opportunity"
10. "What would a world-class team do?"
