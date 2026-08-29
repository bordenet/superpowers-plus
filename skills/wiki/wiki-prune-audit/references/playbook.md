# playbook.md — LLM wiki refactoring playbook

Embed this in every published prune-audit report.

Recommended procedure for an LLM tasked with pruning and refactoring a wiki. Ordered from safest to most judgment-heavy. **Never delete without human approval** — recommend, then let a human confirm.

### Order of operations (safest first)

1. **Fix link-rot (mechanical, reversible).** Bare short-id links that can 404 in the browser — resolve each to its full slug via a page-info API call and replace. Pure upside, zero content risk. Do it first to build trust.
2. **Fix structural defects in place.** Literal `\toc` (should be a TOC toggle), escaped `\n`/`·` rendering as text, malformed tables, unbalanced code/callout fences. Re-fetch → repair → re-publish through the gate chain.
3. **Merge true duplicates.** When two pages are >70% the same content, pick the canonical one (most complete, most linked-to, most recently maintained), fold in anything unique from the other, redirect inbound links, then recommend the redundant one for deletion. Never delete the copy that has more inbound links.
4. **Fill or delete unfinished skeletons.** A page that is mostly `TBD` placeholder fields months after creation implies coverage that doesn't exist. Assign an owner to fill it or recommend deletion.
5. **Retitle ambiguous pages.** Same-title collisions break search and cross-linking. Give each a disambiguating title.
6. **Archive stale one-shots.** Ephemeral execution logs, expired-deadline migration notes, and abandoned design drafts should move under an explicit **Archive** parent with an "archived + why" note — not linger in the active tree pretending to be current.
7. **Give empty containers a purpose.** A 0-char page with children is a nav node: add a one-line intro + a child index. A 0-char page with NO children is dead weight: recommend deletion.

### Standing rules for every edit

- **Re-fetch before editing.** Never edit from stale/remembered text — other edits may have landed.
- **One gate per write.** Scope-check → snapshot → secret scan → language scan → structural gate → link verification → write → re-fetch to verify length/sections survived.
- **Preserve provenance.** Keep "Migrated from…", "Last updated…", and owner footers when rewriting.
- **Cross-link, don't copy.** If two pages need the same table, one owns it and the other links to it.
- **Batch by risk, not by page.** Do all link fixes, then all structural fixes, then merges — so a reviewer can approve a whole low-risk batch at once.
- **Log every change** (page, what changed, why) so the audit trail is reviewable.

### Signals worth automating

A recurring scan should flag: pages <250 chars, pages not updated in >365 days, `TBD`/`TODO`/placeholder density, bare short-id links, duplicate titles, and >70% content overlap between any two pages. This audit's scoring script is a working starting point.
