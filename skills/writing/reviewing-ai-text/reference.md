# Reviewing AI Text - Reference

> **Parent skill:** [skill.md](./skill.md)
> **Last Updated:** 2026-03-12

Complete pattern tables for AI text detection.

---

## Category 1: Generic Boosters (Kill or Quantify)

These add no information. Delete or replace with specific metrics.

| Phrase | Action | Example Fix |
|--------|--------|-------------|
| incredibly | delete | "incredibly fast" → "processes 1000 req/s" |
| extremely | delete | "extremely important" → "blocks release" |
| highly | delete | "highly scalable" → "handles 10x load" |
| very | delete | "very large" → "2TB" |
| truly | delete | "truly innovative" → [describe the innovation] |
| absolutely | delete | "absolutely essential" → "required for X" |
| definitely | delete | "definitely works" → "tested with Y" |
| really | delete | "really good" → [specific quality] |
| quite | delete | "quite complex" → "47 dependencies" |
| remarkably | delete | "remarkably efficient" → "3x faster than Z" |
| significantly | quantify | "significantly faster" → "40% faster" |
| substantially | quantify | [same pattern] |
| considerably | quantify | [same pattern] |
| dramatically | quantify | [same pattern] |

---

## Category 2: Vague Quality Words (Describe Instead)

| Phrase | Problem | Fix |
|--------|---------|-----|
| robust | meaningless | "handles network failures with retry" |
| seamless | meaningless | "no config required" |
| comprehensive | meaningless | "covers 47 edge cases" |
| powerful | meaningless | "supports X, Y, Z operations" |
| flexible | meaningless | "configurable via YAML" |
| intuitive | subjective | "no docs needed for basic use" |
| scalable | meaningless | "tested to 1M concurrent users" |
| reliable | meaningless | "99.9% uptime over 12 months" |
| secure | meaningless | "SOC2 certified" |
| state-of-the-art | meaningless | cite benchmark |
| enterprise-ready | meaningless | list enterprise features |
| production-grade | meaningless | describe testing |
| battle-tested | meaningless | cite production usage |

---

## Category 3: Hype Words (Delete Always)

Marketing speak with zero information content.

| Phrase | Replacement |
|--------|-------------|
| game-changing | describe the actual change |
| revolutionary | describe what's different |
| cutting-edge | name the specific technology |
| next-generation | describe the improvement |
| paradigm-shifting | delete entirely |
| synergy | delete or explain the interaction |
| holistic | delete or list components |
| leverage | use "use" |
| utilize | use "use" |
| enable | use "let" |
| empower | use "let" or "give" |
| unlock | describe what becomes possible |
| drive | use "cause" or be specific |

---

## Category 4: Glue Phrases (Delete Entirely)

| Phrase | Action |
|--------|--------|
| It's important to note that | delete, say the thing |
| It's worth mentioning that | delete |
| It goes without saying | delete |
| In today's world | delete |
| In today's digital age | delete |
| In today's fast-paced environment | delete |
| At the end of the day | delete |
| Let me explain | delete, just explain |
| Let's dive in | delete |
| Let's explore | delete |
| In order to | use "to" |
| Due to the fact that | use "because" |
| In the event that | use "if" |
| In terms of | use "for" or rephrase |
| First and foremost | use "first" |

---

## Category 5: Hedge Patterns (Commit or Delete)

| Phrase | Problem | Fix |
|--------|---------|-----|
| of course | claims obviousness | delete or prove it |
| obviously | claims obviousness | delete or prove it |
| certainly | false confidence | provide evidence |
| in many ways | weasel | specify which ways |
| in some cases | weasel | specify which cases |
| it depends | lazy | rank the conditions |
| generally speaking | weasel | specify exceptions |
| kind of | weasel | be specific |
| sort of | weasel | be specific |
| potentially | weasel | assess probability |
| might | weasel | assess probability |
| seems to | weasel | verify and commit |

---

## Category 6: Sycophantic Phrases (Delete Always)

| Phrase | Action |
|--------|--------|
| Great question! | delete |
| Excellent question! | delete |
| That's a great point! | delete |
| Happy to help! | delete |
| I'd be happy to help | delete |
| I'm glad you asked | delete |
| Absolutely! | delete, just answer |
| Of course! | delete, just answer |
| No problem! | delete, just answer |

---

## Category 7: Transitional Filler (Simplify)

| Phrase | Replacement |
|--------|-------------|
| Furthermore | use "Also" or delete |
| Moreover | use "Also" or delete |
| Additionally | use "Also" or delete |
| Nevertheless | use "But" or "Still" |
| On the other hand | use "But" or delete |
| Consequently | use "So" |
| Therefore | use "So" |
| Thus | use "So" |
| As mentioned earlier | delete |
| Moving forward | delete |
| Going forward | delete |

---

## Technical Documentation Slop

| Pattern | Example | Fix |
|---------|---------|-----|
| Passive function opener | "This function is used to..." | "Parses JSON from stdin" |
| Dismissive "simply" | "Simply call the API..." | Delete "simply", add error handling |
| Vague "easy" claims | "Easy to use" | "Requires 3 env vars" |
| Capability laundry list | "Supports X, Y, and more" | List all or link to full list |
| Empty "powerful" | "A powerful library" | Describe what it does |
| Vague error handling | "Handle errors appropriately" | Show error handling code |
| "Best practices" without specifics | "Follow best practices" | Name the practices |

**Technical Doc Red Flags:**
- README longer than the code
- "Getting Started" that doesn't get you started in 5 minutes
- API docs that restate signatures without explaining when to use them
