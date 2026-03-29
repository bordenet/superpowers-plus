# AI-Detection Questions (24 Designated Probes)

> **Purpose:** Thwart candidates using AI assistance during phone screens.
> **Usage:** Include 3-5 of these strategically in every phone screen. Don't use all 24.
> **Reference:** [AI & Interview Integrity Policy](https://wiki.int.callbox.net/doc/ai-interview-integrity-policy-U0AU2Qv67Q)

## Behavioral Signals to Watch

Before using these questions, observe for:
- Eyes tracking to a second monitor or phone
- Unnaturally polished, comprehensive answers (real people have "ums" and tangents)
- Delay before speaking while "reading"
- Inability to pivot mid-answer when interrupted

---

## Category 1: Interrupt & Redirect (Tests real-time thinking)

**AI-1. The Mid-Answer Interrupt**
> Let candidate get 30 seconds into any answer, then cut in:
> "Actually — hold that thought. Before you finish, what was the *second* option you considered but rejected?"

**AI-2. The Rapid Pivot**
> After any technical answer:
> "Now explain that same thing to a non-technical stakeholder in 30 seconds."

---

## Category 2: Specificity Escalation (Tests real memory)

**AI-3. The Three-Level Drill**
> Pick any technical claim and drill three levels deep in rapid succession:
> - "What was the exact error message?"
> - "What line of code was it?"
> - "What did the stack trace show?"

**AI-4. The Timestamp Probe**
> "What time of day did that incident happen? How do you remember that?"

**AI-5. The Sensory Detail**
> "Where were you sitting when you got that page? What were you doing?"

---

## Category 3: Dead Ends & Failures (Tests authenticity)

**AI-6. The Dead-End Probe**
> After any success story:
> "What was your first approach that *didn't* work before you got to that solution?"

**AI-7. The Embarrassing Detail**
> "What's something you tried during that debugging that you're a little embarrassed about in hindsight?"

**AI-8. The Unfinished Story**
> "Tell me about something you started but never finished. Why did it stall?"

---

## Category 4: Contradiction & Callback (Tests consistency)

**AI-9. The "Wrong" Assertion**
> Make a slightly incorrect statement about something they said:
> "So you were using PostgreSQL for that, right?" *(when they said MongoDB)*

**AI-10. The Casual Callback**
> 10+ minutes after they mention something, circle back casually:
> "Earlier you mentioned [specific detail]. How did that connect to [unrelated thing]?"

---

## Category 5: Visual & Collaborative (Forces attention)

**AI-11. The Diagram Request**
> "Can you sketch that for me real quick? Doesn't need to be pretty — just show me how the pieces connect."

**AI-12. The Screen Share Moment** *(use sparingly)*
> "Hey, can you share your screen for a sec? I want to sketch something together."

---

## Category 6: Cadence & Delivery Breakers (Tests natural speech)

**AI-13. The Rapid-Fire Round**
> Fire 3-4 simple questions in quick succession without pausing:
> "What's your favorite IDE? What's the last command you typed in terminal? What's your go-to debugging technique? What's the worst bug you shipped?"

**AI-14. The Equivocation Probe**
> Ask something genuinely ambiguous:
> "Is that a good pattern or a bad pattern?"

**AI-15. The "I Don't Know" Trap**
> Ask about something obscure in their claimed stack:
> "What's the default connection pool size in [their database]?"

**AI-16. The Unscripted Personal**
> "What did you have for lunch today?" or "What's the weather like where you are?"

---

## Category 7: Eye Movement & Attention (Tests physical behavior)

**AI-17. The Direct Gaze Request**
> "Hey, look at me for a sec — I want to make sure I'm explaining this clearly."
> Then ask a technical question while maintaining eye contact.

**AI-18. The Sudden Topic Switch**
> Mid-sentence, completely change topics:
> "—actually, forget that. What's your favorite thing about your current manager?"

**AI-19. The "What Are You Looking At?" Direct**
> If you notice consistent eye movement:
> "I notice you're looking at something — are you taking notes or do you have something pulled up?"

---

## Category 8: Meta-Questions (Tests self-awareness)

**AI-20. The Process Question**
> "How are you approaching this interview? Are you taking notes? Using any tools?"

**AI-21. The Confidence Calibration**
> "On a scale of 1-10, how confident are you in that answer? What would make it a 10?"

**AI-22. The "Teach Me" Flip**
> "Pretend I'm a junior engineer who just joined your team. Explain [their technical claim] like you're onboarding me."

**AI-23. The Contradiction Setup**
> State something that contradicts their earlier answer:
> "So you prefer monoliths over microservices, right?" *(when they advocated microservices)*

**AI-24. The "What Would You Google?" Probe**
> "If you had to solve this right now and could Google one thing, what would you search for?"

---

## Integration into Phone Screen Flow

| When | Which Questions |
|------|-----------------|
| **After "Tell me about yourself"** | AI-6 (Dead-End) or AI-8 (Unfinished Story) |
| **During technical probes (Q2-Q4)** | AI-3 (Three-Level Drill) or AI-1 (Mid-Answer Interrupt) |
| **Mid-interview** | AI-10 (Casual Callback) referencing something from earlier |
| **If cadence seems robotic** | AI-13 (Rapid-Fire) or AI-14 (Equivocation Probe) |
| **If eye movement is suspicious** | AI-17 (Direct Gaze) or AI-19 (Direct Ask) |
| **If suspicion rises** | AI-9 (Wrong Assertion) or AI-11 (Diagram Request) |
| **To establish baseline** | AI-16 (Unscripted Personal) or AI-20 (Process Question) |
| **Nuclear option** | AI-12 (Screen Share) — only if you're willing to make it awkward |

---

## Scoring AI-Detection Signals

| Signal | Interpretation |
|--------|----------------|
| Answers all probes naturally with vivid detail | ✅ Likely authentic |
| Stumbles on 1-2 but recovers with real examples | ✅ Probably authentic, may be nervous |
| Consistently generic, no failures, no sensory detail | ⚠️ Possible AI assistance |
| Can't handle interrupts, needs time to "think" after pivots | ⚠️ Possible AI assistance |
| Refuses diagram/screen share with weak excuse | 🚨 High suspicion |
| **All answers delivered at identical cadence** | 🚨 High suspicion — real speech varies |
| **Zero equivocation on ambiguous questions** | ⚠️ Real engineers hedge and qualify |
| **Never says "I don't know"** | ⚠️ Suspiciously comprehensive |

---

## What to Do If You Suspect AI Assistance

1. **Don't accuse during the call** — you could be wrong
2. **Note specific observations** in your raw notes (e.g., "looked left before every answer")
3. **Recommend on-site verification** if candidate is otherwise strong
4. **Discuss in debrief** — other interviewers may have seen the same pattern
5. **Reference the integrity policy** — candidate agreed to no AI assistance at start of call
