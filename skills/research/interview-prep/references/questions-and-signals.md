# Behavioral Questions — Full Detail

## Growth Mindset (REQUIRED — L2 Level)
> "Tell me about a time you received critical feedback that was hard to hear. How did you respond, and what changed? **Focus on something out of the ordinary, though. Something you didn't really expect.**"

**Follow-up:** "What changed in your approach after that?"
**Good signals (L2):** Specific example, moved past initial defensiveness, sought to understand, made real behavioral change
**Red flags:** Can't recall feedback, dismissed it, acknowledged but didn't change

## Customer Obsession (REQUIRED — L2 Level)
> "Describe a time you advocated for a customer need that wasn't popular or convenient internally. What happened? **Please be as specific as possible so I can understand what you did, especially in the very first steps.**"

**Follow-up:** "How did you validate you understood correctly?"
**Good signals (L2):** Identified real need vs. internal priorities, advocated with data, navigated resistance, maintained relationships
**Red flags:** Can't recall advocating for customers, gave up immediately, advocated without data

## Conflict Management (REQUIRED — L2 Level)
> "Describe a conflict that got worse before it got better. What happened, and what did you learn about how you handle conflict? **Focus on a situation where you weren't sure you were right — where it was genuinely ambiguous.**"

**Follow-up:** "What would you do differently if you could replay that situation?"
**Good signals (L2):** Honest about their role in escalation, identifies what they could have done differently, shows learning
**Red flags:** Blames other person entirely, no self-reflection, pattern of escalating conflicts

---

## Systems Design Options

### Option A: Context Carryover
> "A customer calls, books an appointment, then calls back 2 hours later to change it. Design the system that lets [Product] remember the first call. Start with the data model, then walk me through retrieval and LLM injection."

### Option B: Interruption Handling
> "Design the interruption handling system. How do you detect the interruption? What do you do when you detect it? What are the edge cases?"

### Option C: Custom (based on candidate background)
> Tailor to candidate's experience (e.g., if they have RAG experience, ask about retrieval architecture).

**Probing questions:**
- "What's the latency budget here?"
- "How do you handle stale or wrong context?"
- "What metrics would you track?"

**Senior-level signals:**
- Thinks about data model first
- Considers real-time constraints
- Addresses tradeoffs explicitly
- Asks clarifying questions

**Red flags:**
- No consideration of latency or cost
- Can't articulate tradeoffs
- Surface-level "just use X" answers

**Behavioral probe (embed in design):**
> "Imagine you and another engineer disagree on the approach. How would you resolve it?"

---

## General Deepening Probes

Use when candidate answers are shallow:

| Probe | Purpose |
|-------|---------|
| "What did that cost?" | Understand stakes and consequences |
| "What would you do differently now?" | Test for learning and growth |
| "How did the other person experience that?" | Test for empathy and perspective-taking |
| "What was the hardest part?" | Get past rehearsed answers |
| "What did you learn about yourself?" | Test for self-awareness |
| "How did that change how you operate today?" | Verify lasting impact |

---

## Flex Coverage Probes

For **reactive use** during the interview:
- When candidate's answer is shallow and needs deepening
- When a prior interviewer pings you mid-loop: "I ran out of time on X, can you cover?"

Reference: [Flex Coverage & Follow-up Probes](https://wiki.int.[company].net/doc/sr-sde-interview-flex-coverage-and-follow-up-probes-x0yBsXvMH1)

## Candidate Experience & Closing

Final section of interview sheet:
- Selling points (for strong candidates)
- Common questions + honest answers
- Closing script

Reference: [Candidate Experience & Closing](https://wiki.int.[company].net/doc/sr-sde-interview-candidate-experience-and-closing-nQui9kY7Dv)
