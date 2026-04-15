# ADR-002: Dynamic Augment Slash Menu Discovery via `augment_menu: true`

**Status:** Accepted  
**Date:** 2026-04-15  
**Affects:** `lib/install/deploy.sh`, all overlay repos

---

## Context

The Augment IDE slash menu reads skills from `~/.agents/skills/`. Each subdirectory name becomes a slash command. Skills must be copied there during install.

Prior to this ADR, `export_augment_menu_skills()` iterated over a hardcoded `AUGMENT_MENU_SKILLS` array. This produced two failure modes:

1. **Overlay skills never appear.** Overlay repos install to `~/.codex/skills/` but `AUGMENT_MENU_SKILLS` only listed superpowers-plus skills. No mechanism for overlays to declare participation without editing superpowers-plus source.

2. **Manual list drift.** Adding a new skill required two PRs: one to the skill repo, one to superpowers-plus to update the array. Routinely missed — confirmed by the `model-selector` incident (2026-04-15), where the skill was absent from the slash menu for two weeks despite being correctly installed.

**Rejected intermediate design (also 2026-04-15):** A first attempt replaced the hardcoded array with `/sp-*` trigger presence as the selection gate. This was rejected because it conflated two concerns: `/sp-*` is a *shorthand invocation convention*, not a *menu membership declaration*. Every skill with a shorthand trigger would have flooded the palette — the opposite of the desired curated subset.

---

## Decision

Replace the hardcoded `AUGMENT_MENU_SKILLS` array with **explicit frontmatter opt-in**:

> A skill is exported to `~/.agents/skills/` if and only if its `skill.md` declares `augment_menu: true`.

The slash-command directory name is derived from the first `/sp*` trigger in `triggers:` (covering `/sp-`, `/spr-`, `/spc-` prefixes), falling back to the skill directory name if no such trigger exists.

```yaml
augment_menu: true                        # opt in to the Augment slash menu
triggers: ["/sp-debug", "debug this"]    # /sp-debug becomes the slash command name
```

### Why `augment_menu: true` over `/sp-*` trigger presence

- **Explicit, not implicit.** Slash menu inclusion is a deployment decision, not a naming convention. A skill author who adds `/sp-foo` for shorthand should not automatically push that skill into every user's command palette.
- **Curated by design.** The slash menu is meant to surface a focused subset of skills. `augment_menu: true` makes that selection visible and intentional in the skill file itself.
- **No cross-repo coordination.** Overlay repos mark their own skills. superpowers-plus never needs to know about overlay skill names.

### Stale-prune isolation

`export_augment_menu_skills` accepts a `prune_source` argument (the calling installer's `source:` value). Pruning only removes `~/.agents/skills/` entries whose `SKILL.md` contains `source: <prune_source>`. This guarantees installers from different repos never delete each other's slash menu entries.

**Direct-deploy overlay exception:** Some overlay repos deploy their skills directly to `~/.agents/skills/` by skill name via their own mechanism (not `augment_menu: true`). These repos manage their own stale-prune logic and are not affected by this ADR.

---

## Overlay Repo Requirements

For an overlay repo to participate in dynamic discovery:

1. Set `export AUGMENT_MENU_DIR="${HOME}/.agents/skills"` in `install.sh`
2. Add `_extract_sp_trigger()` and `export_augment_menu_skills()` to `lib/install/deploy.sh` (copy from sp+ deploy.sh)
3. Call `export_augment_menu_skills "source-name"` at the end of `install_skills()`, passing the repo's own `source:` value

Skills that want a slash menu entry set `augment_menu: true`. All others are unaffected.

---

## Consequences

- The `AUGMENT_MENU_SKILLS` hardcoded array is deleted permanently.
- Slash menu contents are now auditable from skill frontmatter — `grep -r 'augment_menu: true' ~/.codex/skills/` shows exactly what will appear.
- Skills that were exported by name fallback in the old system (no `/sp-*` trigger) must add `augment_menu: true` to retain menu presence.
- All overlay repos can independently manage their slash menu contributions with no superpowers-plus changes required.
