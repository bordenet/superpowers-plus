# Innovation Skill — Examples

When this skill fires, it answers ONE question with depth: **"What's the single smartest, most radically innovative, accretive, useful, and compelling addition I could make to this project right now?"**

---

## ✅ Example 1: Full Worked Example

**User prompt:**
> "We have an LLM agent that books service appointments. What's the smartest addition we could make?"

**Phase 1 (agent reads):** README, booking flow code, open issues, conversion metrics, competitor landscape via `perplexity-research`.

**Phase 2 (agent asks — one question per message):**

Agent message 1:
> "What's the single biggest pain point or missed opportunity you see right now?"

User reply:
> "Dealers complain about no-shows. 30% of booked appointments never happen."

Agent message 2:
> "Who benefits most, and what do they wish it did?"

User reply:
> "Dealers. They wish it filled their empty bays."

Agent message 3:
> "What constraints should I respect — team size, timeline, tech stack, politics?"

User reply:
> "Small team, 2 engineers. Can't build ML infrastructure from scratch."

**Phase 3 — The Answer:**

> # The Smartest Addition to Booking Agent Right Now
>
> > What's the single smartest, most radically innovative, accretive, useful,
> > and compelling addition I could make to this project right now?
>
> ## The Answer: The smartest addition is predictive overbooking with automatic waitlist backfill.
>
> ### Why This, Why Now
> 30% no-show rate means dealers are losing nearly a third of their capacity.
> The agent already knows booking patterns and has dealer calendar access.
> Competitors are still doing dumb reminder texts. The opportunity is to
> treat this like airlines treat seat inventory — overbook intelligently
> and backfill from a waitlist when cancellations happen.
>
> ### How It's Accretive
> The agent already handles the booking flow and has historical data on
> which appointment types no-show most. This adds a layer on top of
> existing infrastructure — no new systems, just smarter scheduling logic.
>
> ### What It Unlocks
> Once you have a working overbooking model, you have a **yield management
> system** for service bays. That's a platform capability — dynamic pricing,
> priority booking for high-value customers, predictive staffing. The
> overbooking model is the foundation for all of it.
>
> ### The Hard Parts
> - Getting the overbooking rate wrong means double-bookings and angry dealers.
>   Need per-dealer, per-service-type calibration.
> - Waitlist UX — customers need to feel like they're getting a benefit,
>   not a consolation prize.
> - Dealer trust — "your AI is overbooking my shop" is a hard sell until
>   they see utilization go up.
>
> ### First Move (This Week)
> Pull 90 days of booking data for 5 dealers. Calculate per-service-type
> no-show rates. Build a rules-based overbooking calculator (if no-show
> rate >25%, book 1 extra per 4 slots). Run it in shadow mode for 4 days
> — log what it WOULD have done, compare against actual no-shows.
>
> ---
>
> Want me to: (a) draft an RFC for this, (b) prototype the first move right now, (c) challenge this idea with `think-twice` to stress-test it, (d) generate alternatives via `brainstorming`, or (e) turn this into a phased execution plan via `plan-and-execute`?

---

## ✅ Example 2: Architecture Question

**User prompt:**
> "What if we started from scratch on the notification service?"

**Why innovation fires:** "From scratch" language — but the skill's job is to answer whether starting from scratch is actually the smartest move, or whether an accretive approach is better. It doesn't just validate the premise.

---

## ❌ Do NOT Fire

| Prompt | Why Not | Use Instead |
|--------|---------|-------------|
| "Fix the race condition in the booking queue" | Bug fix | `systematic-debugging` |
| "Add email confirmation to the booking flow" | Incremental feature | `brainstorming` or implement directly |
| "Clean up the service layer abstractions" | Refactor | `pre-commit-gate` |

---

## 🤔 Ambiguous — Ask, Don't Assume

**User prompt:** "What's next for this project?"

Could be innovation or roadmap. Ask:

> "Do you want me to answer the big question — *what's the single smartest addition to this project right now?* — or help with incremental roadmap planning?"
